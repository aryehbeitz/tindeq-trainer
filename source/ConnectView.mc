using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class ConnectView extends WatchUi.View {
    var bleManager;
    var statusText = "Press START\nto scan";
    var refreshTimer;
    var dotCount = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        bleManager = getApp().bleManager;
        refreshTimer = new Timer.Timer();
        refreshTimer.start(method(:onRefresh), 500, true);
    }

    function onRefresh() as Void {
        if (bleManager.isScanning()) {
            dotCount = (dotCount + 1) % 4;
            var dots = "";
            for (var i = 0; i < dotCount; i++) { dots += "."; }
            statusText = "Scanning" + dots + "\n\nTurn on your\nProgressor";
        } else if (bleManager.connectionState == STATE_CONNECTING) {
            statusText = "Connecting...";
        } else if (bleManager.isConnected()) {
            refreshTimer.stop();
            var menu = new MainMenuView();
            WatchUi.switchToView(menu, new MainMenuDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // Round-safe layout (13%-85%)
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.20, Graphics.FONT_MEDIUM, "TINDEQ", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.40, Graphics.FONT_SMALL, statusText, Graphics.TEXT_JUSTIFY_CENTER);

        if (bleManager != null && bleManager.batteryMv > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            var battPct = batteryPercent(bleManager.batteryMv);
            dc.drawText(cx, h * 0.72, Graphics.FONT_TINY, "Batt: " + battPct + "%", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function batteryPercent(mv) {
        if (mv >= 4200) { return 100; }
        if (mv <= 3000) { return 0; }
        return ((mv - 3000) * 100 / 1200).toNumber();
    }
}

class ConnectDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() {
        var ble = getApp().bleManager;
        if (!ble.isScanning() && !ble.isConnected()) {
            ble.startScanning();
            view.statusText = "Scanning...";
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onBack() {
        var ble = getApp().bleManager;
        if (ble.isScanning()) {
            ble.stopScanning();
            view.statusText = "Press START\nto scan";
            WatchUi.requestUpdate();
            return true;
        }
        // Exit app
        return false;
    }
}
