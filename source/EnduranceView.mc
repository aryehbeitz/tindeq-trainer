using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Attention;

enum {
    ENDUR_READY,
    ENDUR_COUNTDOWN,
    ENDUR_HANGING,
    ENDUR_DONE
}

class EnduranceView extends WatchUi.View {
    var ble;
    var graph;
    var timer;
    var state = ENDUR_READY;
    var maxForce = 0.0;
    var currentForce = 0.0;
    var elapsedMs = 0;
    var countdownSec = 3;
    var failThreshold = 0.0;
    var failMs = 0;

    function initialize() {
        View.initialize();
        graph = new ForceGraph();
    }

    function onLayout(dc) {
        ble = getApp().bleManager;
    }

    function startCountdown() {
        state = ENDUR_COUNTDOWN;
        countdownSec = 3;
        elapsedMs = 0;
        timer = new Timer.Timer();
        timer.start(method(:onTick), 100, true);
    }

    function onTick() as Void {
        if (ble == null) { return; }
        currentForce = ble.currentForce;
        if (currentForce < 0) { currentForce = 0.0; }

        if (state == ENDUR_COUNTDOWN) {
            elapsedMs += 100;
            if (elapsedMs >= 1000) {
                elapsedMs -= 1000;
                countdownSec--;
                if (countdownSec <= 0) {
                    state = ENDUR_HANGING;
                    elapsedMs = 0;
                    maxForce = 0.0;
                    failMs = 0;
                    if (Attention has :vibrate) {
                        Attention.vibrate([new Attention.VibeProfile(100, 300)]);
                    }
                }
            }
        } else if (state == ENDUR_HANGING) {
            elapsedMs += 100;
            graph.addSample(currentForce);

            if (currentForce > maxForce) {
                maxForce = currentForce;
                failThreshold = maxForce * 0.2;
            }

            // Detect failure: force below 20% of peak for >1s
            if (maxForce > 2.0 && currentForce < failThreshold) {
                failMs += 100;
                if (failMs >= 1000) {
                    finishTest();
                    return;
                }
            } else {
                failMs = 0;
            }
        }
        WatchUi.requestUpdate();
    }

    function finishTest() {
        state = ENDUR_DONE;
        if (timer != null) { timer.stop(); }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 500)]);
        }
        // Save to history
        var durSec = elapsedMs / 1000;
        getApp().historyManager.saveSession("endurance", maxForce, 0.0, 0, 0, durSec);
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        if (state == ENDUR_READY) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.20, Graphics.FONT_MEDIUM, "ENDURANCE", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.40, Graphics.FONT_SMALL, "Hang until\nfailure", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.70, Graphics.FONT_SMALL, "Press START", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == ENDUR_COUNTDOWN) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.15, Graphics.FONT_SMALL, "GET READY", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.35, Graphics.FONT_NUMBER_THAI_HOT, countdownSec.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == ENDUR_HANGING) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.13, Graphics.FONT_SMALL, "HANG!", Graphics.TEXT_JUSTIFY_CENTER);

            // Current force
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.22, Graphics.FONT_NUMBER_HOT, currentForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.46, Graphics.FONT_TINY, "kg", Graphics.TEXT_JUSTIFY_CENTER);

            // Elapsed time
            var sec = elapsedMs / 1000;
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.54, Graphics.FONT_MEDIUM, formatTime(sec), Graphics.TEXT_JUSTIFY_CENTER);

            // Max
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.67, Graphics.FONT_XTINY, "Peak: " + maxForce.format("%.1f") + "kg", Graphics.TEXT_JUSTIFY_CENTER);

            // Graph
            var gx = (w * 0.12).toNumber();
            var gy = (h * 0.73).toNumber();
            var gw = (w * 0.76).toNumber();
            var gh = (h * 0.12).toNumber();
            graph.draw(dc, gx, gy, gw, gh);
        } else if (state == ENDUR_DONE) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.15, Graphics.FONT_MEDIUM, "DONE", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.30, Graphics.FONT_NUMBER_MILD, maxForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.48, Graphics.FONT_TINY, "kg peak", Graphics.TEXT_JUSTIFY_CENTER);

            var sec = elapsedMs / 1000;
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.60, Graphics.FONT_MEDIUM, formatTime(sec), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.75, Graphics.FONT_TINY, "time held", Graphics.TEXT_JUSTIFY_CENTER);

            dc.drawText(cx, h * 0.85, Graphics.FONT_XTINY, "BACK=Menu", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function formatTime(sec) {
        var m = sec / 60;
        var s = sec % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }

    function onHide() {
        if (timer != null) { timer.stop(); }
    }
}

class EnduranceDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() {
        if (view.state == ENDUR_READY) {
            view.startCountdown();
        }
        return true;
    }

    function onBack() {
        if (view.timer != null) { view.timer.stop(); }
        getApp().bleManager.stopMeasurement();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() {
        // DOWN = tare
        getApp().bleManager.tareScale();
        WatchUi.requestUpdate();
        return true;
    }
}
