using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

enum {
    CFG_HANG_TIME,
    CFG_REP_REST,
    CFG_REPS,
    CFG_SET_REST,
    CFG_SETS,
    CFG_TARGET,
    CFG_COUNT
}

class ConfigView extends WatchUi.View {
    var selectedField = CFG_HANG_TIME;
    var config;
    var statusMsg = "";
    var statusTimer = 0;

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
        dc.drawText(cx, h * 0.13, Graphics.FONT_SMALL, "REPEATERS", Graphics.TEXT_JUSTIFY_CENTER);

        var labels = ["Hang", "Rest", "Reps", "Set Rest", "Sets", "Target"];
        var values = [
            config.hangTime + "s",
            config.repRest + "s",
            config.repsPerSet.toString(),
            formatTime(config.setRest),
            config.numSets.toString(),
            config.targetForce > 0 ? config.targetForce + "kg" : "Off"
        ];

        var startY = h * 0.23;
        var lineH = h * 0.10;

        for (var i = 0; i < CFG_COUNT; i++) {
            var y = startY + (i * lineH);
            var isSelected = (i == selectedField);

            if (isSelected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - w * 0.38, y - 2, w * 0.76, lineH - 2, 5);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }

            dc.drawText(cx - w * 0.30, y, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(cx + w * 0.30, y, Graphics.FONT_XTINY, values[i], Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Status message (tare feedback, save feedback)
        if (!statusMsg.equals("")) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, statusMsg, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, "START=Go  BACK=Menu", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function showStatus(msg) {
        statusMsg = msg;
        statusTimer = 20;  // ~2 seconds at 10Hz update
        WatchUi.requestUpdate();
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
            case CFG_TARGET:
                config.targetForce = clamp(config.targetForce + delta, 0, 100);
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
        // Pop back to main menu
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
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
