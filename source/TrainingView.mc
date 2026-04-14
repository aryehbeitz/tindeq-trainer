using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class TrainingView extends WatchUi.View {
    var tm;
    var ble;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        tm = getApp().trainingManager;
        ble = getApp().bleManager;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (tm == null) {
            tm = getApp().trainingManager;
            ble = getApp().bleManager;
        }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var accentColor = getAccentColor();

        // State label
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_SMALL, tm.getStateLabel(), Graphics.TEXT_JUSTIFY_CENTER);

        // Set / Rep counter (hide during countdown, show big countdown instead)
        if (tm.state == TRAIN_COUNTDOWN) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.30, Graphics.FONT_NUMBER_THAI_HOT, tm.timeRemaining.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var setRepText = "S" + tm.currentSet + "/" + tm.config.numSets +
                             "  R" + tm.currentRep + "/" + tm.config.repsPerSet;
            dc.drawText(cx, h * 0.22, Graphics.FONT_XTINY, setRepText, Graphics.TEXT_JUSTIFY_CENTER);

            // Main force display
            var forceKg = tm.currentForce;
            if (forceKg < 0) { forceKg = 0.0; }
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.28, Graphics.FONT_NUMBER_HOT, forceKg.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.50, Graphics.FONT_TINY, "kg", Graphics.TEXT_JUSTIFY_CENTER);

            // Max force this rep + target indicator
            var maxText = "MAX " + tm.maxForceRep.format("%.1f");
            if (tm.config.targetForce > 0) {
                maxText += " / " + tm.config.targetForce;
            }
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.58, Graphics.FONT_XTINY, maxText, Graphics.TEXT_JUSTIFY_CENTER);

            // Force graph
            var gx = (w * 0.12).toNumber();
            var gy = (h * 0.73).toNumber();
            var gw = (w * 0.76).toNumber();
            var gh = (h * 0.12).toNumber();
            tm.graph.draw(dc, gx, gy, gw, gh);
        }

        // Timer — always visible
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.66, Graphics.FONT_MEDIUM, formatTimer(tm.timeRemaining), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function getAccentColor() {
        switch (tm.state) {
            case TRAIN_COUNTDOWN: return Graphics.COLOR_ORANGE;
            case TRAIN_HANG:      return Graphics.COLOR_GREEN;
            case TRAIN_REP_REST:  return Graphics.COLOR_BLUE;
            case TRAIN_SET_REST:  return Graphics.COLOR_PURPLE;
            case TRAIN_COMPLETE:  return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_WHITE;
    }

    function formatTimer(seconds) {
        if (seconds < 0) { seconds = 0; }
        var min = seconds / 60;
        var sec = seconds % 60;
        return min.format("%d") + ":" + sec.format("%02d");
    }
}

class TrainingDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() {
        var tm = getApp().trainingManager;
        if (tm.state == TRAIN_COMPLETE) {
            var resultsView = new ResultsView();
            WatchUi.switchToView(resultsView, new ResultsDelegate(), WatchUi.SLIDE_LEFT);
        }
        return true;
    }

    function onBack() {
        var tm = getApp().trainingManager;
        var ble = getApp().bleManager;
        tm.stop();
        ble.stopMeasurement();
        getApp().stopFitRecording(tm.maxForceSession);

        if (tm.setResults.size() > 0 || tm.repResults.size() > 0) {
            tm.enterComplete();
            var resultsView = new ResultsView();
            WatchUi.switchToView(resultsView, new ResultsDelegate(), WatchUi.SLIDE_LEFT);
        } else {
            // Pop back to menu (Config was pushed from menu, Training replaced Config)
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }

    function onNextPage() {
        // DOWN = tare mid-session
        getApp().bleManager.tareScale();
        return true;
    }
}
