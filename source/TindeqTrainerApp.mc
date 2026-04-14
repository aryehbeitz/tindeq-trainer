using Toybox.Application;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.WatchUi;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class TindeqTrainerApp extends Application.AppBase {
    var bleManager;
    var trainingManager;
    var programManager;
    var historyManager;

    // FIT recording
    var fitSession = null;
    var forceField = null;
    var peakField = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        bleManager = new TindeqBleManager();
        trainingManager = new TrainingManager();
        programManager = new ProgramManager();
        historyManager = new HistoryManager();
        bleManager.registerProfiles();
    }

    function onStop(state) {
        if (fitSession != null && fitSession.isRecording()) {
            fitSession.stop();
            fitSession.save();
            fitSession = null;
        }
        if (bleManager != null) {
            bleManager.disconnect();
        }
    }

    function getInitialView() {
        var view = new ConnectView();
        return [view, new ConnectDelegate(view)];
    }

    function startFitRecording() {
        if (fitSession != null) { return; }
        fitSession = ActivityRecording.createSession({
            :name => "Hangboard",
            :sport => Activity.SPORT_TRAINING,
            :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
        });
        forceField = fitSession.createField("force_kg", 0,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "kg"});
        peakField = fitSession.createField("peak_kg", 1,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "kg"});
        fitSession.start();
    }

    function updateFitForce(force) {
        if (forceField != null) {
            forceField.setData(force);
        }
    }

    function addFitLap() {
        if (fitSession != null && fitSession.isRecording()) {
            fitSession.addLap();
        }
    }

    function stopFitRecording(peakForce) {
        if (fitSession == null) { return; }
        if (peakField != null) {
            peakField.setData(peakForce);
        }
        fitSession.stop();
        fitSession.save();
        fitSession = null;
        forceField = null;
        peakField = null;
    }
}

function getApp() {
    return Application.getApp();
}
