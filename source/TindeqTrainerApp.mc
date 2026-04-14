using Toybox.Application;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.WatchUi;

class TindeqTrainerApp extends Application.AppBase {
    var bleManager;
    var trainingManager;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        bleManager = new TindeqBleManager();
        trainingManager = new TrainingManager();
        bleManager.registerProfiles();
    }

    function onStop(state) {
        if (bleManager != null) {
            bleManager.disconnect();
        }
    }

    function getInitialView() {
        var view = new ConnectView();
        return [view, new ConnectDelegate(view)];
    }
}

function getApp() {
    return Application.getApp();
}
