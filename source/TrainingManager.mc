using Toybox.Timer;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Attention;
using Toybox.Application.Storage;

// Training states
enum {
    TRAIN_IDLE,
    TRAIN_COUNTDOWN,
    TRAIN_HANG,
    TRAIN_REP_REST,
    TRAIN_SET_REST,
    TRAIN_COMPLETE
}

class TrainingConfig {
    var hangTime = 7;       // seconds
    var repRest = 3;        // seconds between reps
    var repsPerSet = 6;     // reps per set
    var setRest = 180;      // seconds between sets
    var numSets = 4;        // total sets
    var countdownTime = 5;  // countdown before first hang
    var targetForce = 0;    // kg, 0 = disabled

    function initialize() {
        load();
    }

    function load() {
        var v;
        v = Storage.getValue("cfg_hangTime");    if (v != null) { hangTime = v; }
        v = Storage.getValue("cfg_repRest");     if (v != null) { repRest = v; }
        v = Storage.getValue("cfg_repsPerSet");  if (v != null) { repsPerSet = v; }
        v = Storage.getValue("cfg_setRest");     if (v != null) { setRest = v; }
        v = Storage.getValue("cfg_numSets");     if (v != null) { numSets = v; }
        v = Storage.getValue("cfg_targetForce"); if (v != null) { targetForce = v; }
    }

    function save() {
        Storage.setValue("cfg_hangTime", hangTime);
        Storage.setValue("cfg_repRest", repRest);
        Storage.setValue("cfg_repsPerSet", repsPerSet);
        Storage.setValue("cfg_setRest", setRest);
        Storage.setValue("cfg_numSets", numSets);
        Storage.setValue("cfg_targetForce", targetForce);
    }
}

class RepResult {
    var maxForce = 0.0;
    var avgForce = 0.0;
    var forceSum = 0.0;
    var sampleCount = 0;
    var duration = 0;

    function initialize() {}

    function addSample(force) {
        if (force > maxForce) {
            maxForce = force;
        }
        forceSum += force;
        sampleCount++;
        if (sampleCount > 0) {
            avgForce = forceSum / sampleCount;
        }
    }
}

class TrainingManager {
    var config;
    var state = TRAIN_IDLE;
    var timer;

    // Counters
    var currentSet = 0;
    var currentRep = 0;
    var timeRemaining = 0;  // seconds remaining in current phase
    var elapsedMs = 0;      // ms elapsed in current phase

    // Current rep tracking
    var currentForce = 0.0;
    var maxForceRep = 0.0;
    var maxForceSession = 0.0;

    // Results storage
    var repResults = [];
    var setResults = [];     // array of arrays of RepResult

    // Target force tracking
    var belowTargetMs = 0;
    var targetWarned = false;

    // Force graph
    var graph;

    // Session timing
    var sessionStartMs = 0;

    function initialize() {
        config = new TrainingConfig();
        timer = new Timer.Timer();
        graph = new ForceGraph();
    }

    function start() {
        currentSet = 1;
        currentRep = 0;
        maxForceSession = 0.0;
        repResults = [];
        setResults = [];
        graph.clear();
        if (config.targetForce > 0) {
            graph.setTarget(config.targetForce.toFloat());
        }
        sessionStartMs = System.getTimer();
        getApp().startFitRecording();
        enterCountdown();
    }

    function stop() {
        timer.stop();
        state = TRAIN_IDLE;
        notifyStateChange();
    }

    function enterCountdown() {
        state = TRAIN_COUNTDOWN;
        timeRemaining = config.countdownTime;
        elapsedMs = 0;
        startTimer();
        notifyStateChange();
    }

    function enterHang() {
        state = TRAIN_HANG;
        currentRep++;
        timeRemaining = config.hangTime;
        elapsedMs = 0;
        maxForceRep = 0.0;
        repResults.add(new RepResult());
        startTimer();
        notifyStateChange();
        vibeShort();
    }

    function enterRepRest() {
        state = TRAIN_REP_REST;
        timeRemaining = config.repRest;
        elapsedMs = 0;
        startTimer();
        notifyStateChange();
        vibeShort();
    }

    function enterSetRest() {
        state = TRAIN_SET_REST;
        // Save current set results
        setResults.add(repResults);
        repResults = [];
        timeRemaining = config.setRest;
        elapsedMs = 0;
        startTimer();
        notifyStateChange();
        vibeLong();
    }

    function enterComplete() {
        timer.stop();
        // Save final set if not already saved
        if (repResults.size() > 0) {
            setResults.add(repResults);
            repResults = [];
        }
        state = TRAIN_COMPLETE;
        notifyStateChange();
        vibeLong();
        // Stop FIT recording
        getApp().stopFitRecording(maxForceSession);
        // Auto-save to history
        var durSec = (System.getTimer() - sessionStartMs) / 1000;
        var avgForce = 0.0;
        var totalSamples = 0;
        for (var s = 0; s < setResults.size(); s++) {
            for (var r = 0; r < setResults[s].size(); r++) {
                avgForce += setResults[s][r].avgForce;
                totalSamples++;
            }
        }
        if (totalSamples > 0) { avgForce = avgForce / totalSamples; }
        getApp().historyManager.saveSession("repeater", maxForceSession, avgForce,
            setResults.size(), getTotalReps(), durSec);
    }

    function startTimer() {
        timer.stop();
        timer.start(method(:onTimer), 100, true);  // 100ms tick
    }

    function onTimer() as Void {
        elapsedMs += 100;
        if (elapsedMs >= 1000) {
            elapsedMs -= 1000;
            timeRemaining--;

            if (timeRemaining <= 3 && timeRemaining > 0 && state != TRAIN_SET_REST) {
                vibeShort();
            }

            if (timeRemaining <= 0) {
                advanceState();
            }
        }
        // Sync force from BLE manager
        var ble = getApp().bleManager;
        if (ble != null) {
            updateForce(ble.currentForce, ble.timestamp);
        }
        // Update force graph
        graph.addSample(currentForce);
        // Update FIT recording
        getApp().updateFitForce(currentForce);
        // Target force warning during hang
        if (state == TRAIN_HANG && config.targetForce > 0 && currentForce > 1.0) {
            if (currentForce < config.targetForce.toFloat()) {
                belowTargetMs += 100;
                if (belowTargetMs >= 500 && !targetWarned) {
                    vibeShort();
                    targetWarned = true;
                }
            } else {
                belowTargetMs = 0;
                targetWarned = false;
            }
        }
        WatchUi.requestUpdate();
    }

    function advanceState() {
        timer.stop();
        if (state == TRAIN_COUNTDOWN) {
            enterHang();
        } else if (state == TRAIN_HANG) {
            if (currentRep >= config.repsPerSet) {
                if (currentSet >= config.numSets) {
                    enterComplete();
                } else {
                    enterSetRest();
                }
            } else {
                enterRepRest();
            }
        } else if (state == TRAIN_REP_REST) {
            enterHang();
        } else if (state == TRAIN_SET_REST) {
            currentSet++;
            currentRep = 0;
            enterCountdown();
        }
    }

    function updateForce(force, ts) {
        currentForce = force;
        if (force > maxForceRep) {
            maxForceRep = force;
        }
        if (force > maxForceSession) {
            maxForceSession = force;
        }
        // Record in current rep
        if (state == TRAIN_HANG && repResults.size() > 0) {
            repResults[repResults.size() - 1].addSample(force);
        }
    }

    function getStateLabel() {
        switch (state) {
            case TRAIN_IDLE:      return "READY";
            case TRAIN_COUNTDOWN: return "GET READY";
            case TRAIN_HANG:      return "HANG!";
            case TRAIN_REP_REST:  return "REST";
            case TRAIN_SET_REST:  return "SET REST";
            case TRAIN_COMPLETE:  return "DONE";
        }
        return "";
    }

    function vibeShort() {
        if (Attention has :vibrate && SettingsView.getVibrateEnabled()) {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        }
    }

    function vibeLong() {
        if (Attention has :vibrate && SettingsView.getVibrateEnabled()) {
            Attention.vibrate([new Attention.VibeProfile(100, 500)]);
        }
    }

    function notifyStateChange() {
        WatchUi.requestUpdate();
    }

    // Get session summary
    function getTotalReps() {
        var total = 0;
        for (var i = 0; i < setResults.size(); i++) {
            total += setResults[i].size();
        }
        return total;
    }

    // Average force across all HANG samples in the current set
    // (excludes rest periods; repResults is cleared between sets)
    function getSetAverage() {
        var totalSum = 0.0;
        var totalCount = 0;
        for (var i = 0; i < repResults.size(); i++) {
            totalSum += repResults[i].forceSum;
            totalCount += repResults[i].sampleCount;
        }
        if (totalCount == 0) { return 0.0; }
        return totalSum / totalCount;
    }
}
