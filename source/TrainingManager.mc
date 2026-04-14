using Toybox.Timer;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Attention;

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

    function initialize() {}
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

    // No callbacks - use WatchUi.requestUpdate() directly

    function initialize() {
        config = new TrainingConfig();
        timer = new Timer.Timer();
    }

    function start() {
        currentSet = 1;
        currentRep = 0;
        maxForceSession = 0.0;
        repResults = [];
        setResults = [];
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
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        }
    }

    function vibeLong() {
        if (Attention has :vibrate) {
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
}
