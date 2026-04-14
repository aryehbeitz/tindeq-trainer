using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

class ResultsView extends WatchUi.View {
    var tm;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        tm = getApp().trainingManager;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (tm == null) { tm = getApp().trainingManager; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_MEDIUM, "DONE", Graphics.TEXT_JUSTIFY_CENTER);

        // Session max force
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.26, Graphics.FONT_NUMBER_MILD, tm.maxForceSession.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.42, Graphics.FONT_TINY, "kg peak", Graphics.TEXT_JUSTIFY_CENTER);

        // Per-set breakdown (max 3)
        var startY = h * 0.52;
        var lineH = h * 0.10;
        var maxVisible = 3;
        if (tm.setResults.size() < maxVisible) { maxVisible = tm.setResults.size(); }

        for (var s = 0; s < maxVisible; s++) {
            var setData = tm.setResults[s];
            var setMax = 0.0;
            var setAvg = 0.0;
            var count = 0;

            for (var r = 0; r < setData.size(); r++) {
                if (setData[r].maxForce > setMax) {
                    setMax = setData[r].maxForce;
                }
                setAvg += setData[r].avgForce;
                count++;
            }
            if (count > 0) { setAvg = setAvg / count; }

            var y = startY + (s * lineH);
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - w * 0.30, y, Graphics.FONT_XTINY, "Set " + (s + 1), Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + w * 0.30, y, Graphics.FONT_XTINY, setMax.format("%.1f") + "/" + setAvg.format("%.1f"), Graphics.TEXT_JUSTIFY_RIGHT);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, tm.getTotalReps() + " reps | Saved | BACK=Menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class ResultsDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() {
        var menu = new MainMenuView();
        WatchUi.switchToView(menu, new MainMenuDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() {
        // Also go to menu
        var menu = new MainMenuView();
        WatchUi.switchToView(menu, new MainMenuDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }
}
