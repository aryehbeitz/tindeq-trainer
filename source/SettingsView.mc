using Toybox.WatchUi;
using Toybox.Application.Storage;

class SettingsView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => "Settings"});

        // Vibrate toggle
        var vibrateOn = getVibrateEnabled();
        addItem(new WatchUi.ToggleMenuItem("Vibrate", null, :vibrate, vibrateOn, null));

        // Info (non-interactive)
        addItem(new WatchUi.MenuItem("Version", "v1.7", :version, null));

        var ble = getApp().bleManager;
        if (!ble.firmwareVersion.equals("")) {
            addItem(new WatchUi.MenuItem("Progressor FW", ble.firmwareVersion, :fw, null));
        }
        if (ble.batteryMv > 0) {
            var pct = batteryPercent(ble.batteryMv);
            addItem(new WatchUi.MenuItem("Progressor Batt", pct + "%", :batt, null));
        }
    }

    function batteryPercent(mv) {
        if (mv >= 4200) { return 100; }
        if (mv <= 3000) { return 0; }
        return ((mv - 3000) * 100 / 1200).toNumber();
    }

    static function getVibrateEnabled() {
        var val = Storage.getValue("vibrate");
        if (val == null) { return true; }  // default on
        return val;
    }

    static function setVibrateEnabled(enabled) {
        Storage.setValue("vibrate", enabled);
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :vibrate) {
            var toggle = item as WatchUi.ToggleMenuItem;
            SettingsView.setVibrateEnabled(toggle.isEnabled());
        } else if (id == :batt) {
            // Refresh battery
            getApp().bleManager.getBatteryVoltage();
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
