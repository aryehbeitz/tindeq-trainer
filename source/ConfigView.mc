using Toybox.WatchUi;
using Toybox.Graphics;

enum {
    CFG_HANG_TIME,
    CFG_REP_REST,
    CFG_REPS,
    CFG_SET_REST,
    CFG_SETS,
    CFG_COUNT
}

class ConfigView extends WatchUi.View {
    var selectedField = CFG_HANG_TIME;
    var config;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        config = getApp().trainingManager.config;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // Round-safe layout
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_SMALL, "SETUP", Graphics.TEXT_JUSTIFY_CENTER);

        var labels = ["Hang", "Rest", "Reps", "Set Rest", "Sets"];
        var values = [
            config.hangTime + "s",
            config.repRest + "s",
            config.repsPerSet.toString(),
            formatTime(config.setRest),
            config.numSets.toString()
        ];

        var startY = h * 0.24;
        var lineH = h * 0.12;

        for (var i = 0; i < CFG_COUNT; i++) {
            var y = startY + (i * lineH);
            var isSelected = (i == selectedField);

            if (isSelected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - w * 0.38, y - 2, w * 0.76, lineH - 4, 6);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }

            dc.drawText(cx - w * 0.30, y, Graphics.FONT_TINY, labels[i], Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(cx + w * 0.30, y, Graphics.FONT_TINY, values[i], Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Hint at bottom (within round safe zone)
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, "START=Go  BACK=Exit", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function formatTime(seconds) {
        var min = seconds / 60;
        var sec = seconds % 60;
        if (min > 0) {
            return min + "m" + (sec > 0 ? sec + "s" : "");
        }
        return sec + "s";
    }

    function moveSelection(delta) {
        selectedField = (selectedField + delta + CFG_COUNT) % CFG_COUNT;
        WatchUi.requestUpdate();
    }

    function adjustValue(delta) {
        switch (selectedField) {
            case CFG_HANG_TIME:
                config.hangTime = clamp(config.hangTime + delta, 1, 60);
                break;
            case CFG_REP_REST:
                config.repRest = clamp(config.repRest + delta, 1, 60);
                break;
            case CFG_REPS:
                config.repsPerSet = clamp(config.repsPerSet + delta, 1, 20);
                break;
            case CFG_SET_REST:
                config.setRest = clamp(config.setRest + delta * 10, 10, 600);
                break;
            case CFG_SETS:
                config.numSets = clamp(config.numSets + delta, 1, 10);
                break;
        }
        WatchUi.requestUpdate();
    }

    function clamp(val, min, max) {
        if (val < min) { return min; }
        if (val > max) { return max; }
        return val;
    }
}

class ConfigDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() {
        var ble = getApp().bleManager;
        ble.startMeasurement();

        var tm = getApp().trainingManager;
        tm.start();

        var trainView = new TrainingView();
        WatchUi.switchToView(trainView, new TrainingDelegate(trainView), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() {
        // Exit app - disconnect BLE
        var ble = getApp().bleManager;
        ble.disconnect();
        return false;  // false = exit app
    }

    function onNextPage() {
        view.moveSelection(1);
        return true;
    }

    function onPreviousPage() {
        view.moveSelection(-1);
        return true;
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            view.adjustValue(1);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            view.adjustValue(-1);
            return true;
        }
        return false;
    }
}
