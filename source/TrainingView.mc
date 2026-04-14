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

        // Round display safe zone: keep content between 13%-87% vertically
        var accentColor = getAccentColor();

        // State label
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_SMALL, tm.getStateLabel(), Graphics.TEXT_JUSTIFY_CENTER);

        // Set / Rep counter
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var setRepText = "S" + tm.currentSet + "/" + tm.config.numSets +
                         "  R" + tm.currentRep + "/" + tm.config.repsPerSet;
        dc.drawText(cx, h * 0.23, Graphics.FONT_XTINY, setRepText, Graphics.TEXT_JUSTIFY_CENTER);

        // === MAIN FORCE DISPLAY ===
        var forceKg = tm.currentForce;
        if (forceKg < 0) { forceKg = 0.0; }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.30, Graphics.FONT_NUMBER_HOT, forceKg.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.53, Graphics.FONT_TINY, "kg", Graphics.TEXT_JUSTIFY_CENTER);

        // Max force this rep
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.62, Graphics.FONT_SMALL, "MAX " + tm.maxForceRep.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        // Timer countdown
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.73, Graphics.FONT_MEDIUM, formatTimer(tm.timeRemaining), Graphics.TEXT_JUSTIFY_CENTER);

        // Session best (compact, within round safe zone)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, "Best:" + tm.maxForceSession.format("%.1f") + "kg", Graphics.TEXT_JUSTIFY_CENTER);
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

        if (tm.setResults.size() > 0 || tm.repResults.size() > 0) {
            tm.enterComplete();
            var resultsView = new ResultsView();
            WatchUi.switchToView(resultsView, new ResultsDelegate(), WatchUi.SLIDE_LEFT);
        } else {
            var configView = new ConfigView();
            WatchUi.switchToView(configView, new ConfigDelegate(configView), WatchUi.SLIDE_RIGHT);
        }
        return true;
    }
}
