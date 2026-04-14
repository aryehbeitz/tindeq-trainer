using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class FreePullView extends WatchUi.View {
    var ble;
    var graph;
    var timer;
    var maxForce = 0.0;
    var measuring = true;

    function initialize() {
        View.initialize();
        graph = new ForceGraph();
    }

    function onLayout(dc) {
        ble = getApp().bleManager;
        timer = new Timer.Timer();
        timer.start(method(:onTick), 100, true);
    }

    function onTick() as Void {
        if (ble == null) { return; }
        var force = ble.currentForce;
        if (force < 0) { force = 0.0; }
        graph.addSample(force);
        if (force > maxForce) {
            maxForce = force;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // Title
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Graphics.FONT_SMALL, "FREE PULL", Graphics.TEXT_JUSTIFY_CENTER);

        // Current force (big)
        var force = 0.0;
        if (ble != null) { force = ble.currentForce; }
        if (force < 0) { force = 0.0; }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.22, Graphics.FONT_NUMBER_HOT, force.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.46, Graphics.FONT_TINY, "kg", Graphics.TEXT_JUSTIFY_CENTER);

        // Max force
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.54, Graphics.FONT_SMALL, "MAX " + maxForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        // Force graph (large area)
        var graphX = (w * 0.12).toNumber();
        var graphY = (h * 0.65).toNumber();
        var graphW = (w * 0.76).toNumber();
        var graphH = (h * 0.18).toNumber();
        graph.draw(dc, graphX, graphY, graphW, graphH);

        // Hint
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.85, Graphics.FONT_XTINY, "DOWN=Tare  BACK=Stop", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onHide() {
        if (timer != null) { timer.stop(); }
    }
}

class FreePullDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onBack() {
        var ble = getApp().bleManager;
        ble.stopMeasurement();
        if (view.timer != null) { view.timer.stop(); }

        // Save to history if we had meaningful data
        if (view.maxForce > 0.5) {
            getApp().historyManager.saveSession("free", view.maxForce, 0.0, 0, 0, 0);
        }

        // Back to main menu
        var menu = new MainMenuView();
        WatchUi.switchToView(menu, new MainMenuDelegate(), WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() {
        // DOWN = tare
        getApp().bleManager.tareScale();
        view.maxForce = 0.0;
        view.graph.clear();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {
        // Reset max
        view.maxForce = 0.0;
        view.graph.clear();
        WatchUi.requestUpdate();
        return true;
    }
}
