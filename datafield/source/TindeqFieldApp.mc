using Toybox.Application;
using Toybox.BluetoothLowEnergy as Ble;

class TindeqFieldApp extends Application.AppBase {
    var bleManager;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        bleManager = new TindeqFieldBle();
        bleManager.registerProfiles();
        // Auto-start scanning
        bleManager.startScanning();
    }

    function onStop(state) {
        if (bleManager != null) {
            bleManager.disconnect();
        }
    }

    function getInitialView() {
        return [new TindeqFieldView()];
    }
}

function getApp() {
    return Application.getApp();
}
