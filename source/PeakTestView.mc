using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Attention;

enum {
    PEAK_READY,
    PEAK_COUNTDOWN,
    PEAK_PULLING,
    PEAK_RESULT
}

class PeakTestView extends WatchUi.View {
    var ble;
    var timer;
    var state = PEAK_READY;
    var maxForce = 0.0;
    var currentForce = 0.0;
    var countdownSec = 3;
    var elapsedMs = 0;
    const TEST_DURATION = 5000;  // 5 second test window

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        ble = getApp().bleManager;
    }

    function startTest() {
        state = PEAK_COUNTDOWN;
        countdownSec = 3;
        elapsedMs = 0;
        ble.startMeasurement();
        timer = new Timer.Timer();
        timer.start(method(:onTick), 100, true);
    }

    function onTick() as Void {
        if (ble == null) { return; }
        currentForce = ble.currentForce;
        if (currentForce < 0) { currentForce = 0.0; }

        if (state == PEAK_COUNTDOWN) {
            elapsedMs += 100;
            if (elapsedMs >= 1000) {
                elapsedMs -= 1000;
                countdownSec--;
                if (Attention has :vibrate) {
                    Attention.vibrate([new Attention.VibeProfile(50, 150)]);
                }
                if (countdownSec <= 0) {
                    state = PEAK_PULLING;
                    elapsedMs = 0;
                    maxForce = 0.0;
                    if (Attention has :vibrate) {
                        Attention.vibrate([new Attention.VibeProfile(100, 400)]);
                    }
                }
            }
        } else if (state == PEAK_PULLING) {
            elapsedMs += 100;
            if (currentForce > maxForce) {
                maxForce = currentForce;
            }
            if (elapsedMs >= TEST_DURATION) {
                finishTest();
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function finishTest() {
        state = PEAK_RESULT;
        if (timer != null) { timer.stop(); }
        ble.stopMeasurement();
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 500)]);
        }
        // Save to history
        getApp().historyManager.saveSession("peak", maxForce, 0.0, 0, 0, 5);
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        if (state == PEAK_READY) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.20, Graphics.FONT_MEDIUM, "PEAK TEST", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.40, Graphics.FONT_SMALL, "Pull as hard\nas you can!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.65, Graphics.FONT_SMALL, "Press START", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.80, Graphics.FONT_XTINY, "5 second window", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == PEAK_COUNTDOWN) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.15, Graphics.FONT_SMALL, "GET READY", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.35, Graphics.FONT_NUMBER_THAI_HOT, countdownSec.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == PEAK_PULLING) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.13, Graphics.FONT_MEDIUM, "PULL!", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.28, Graphics.FONT_NUMBER_HOT, currentForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.52, Graphics.FONT_TINY, "kg", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.62, Graphics.FONT_SMALL, "MAX " + maxForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

            // Time remaining bar
            var remaining = TEST_DURATION - elapsedMs;
            var pct = remaining.toFloat() / TEST_DURATION;
            var barW = (w * 0.6 * pct).toNumber();
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - (w * 0.3).toNumber(), (h * 0.76).toNumber(), barW, 6);
        } else if (state == PEAK_RESULT) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.15, Graphics.FONT_SMALL, "PEAK FORCE", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.30, Graphics.FONT_NUMBER_THAI_HOT, maxForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.62, Graphics.FONT_MEDIUM, "kg", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY, "START=Again  BACK=Menu", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() {
        if (timer != null) { timer.stop(); }
    }
}

class PeakTestDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() {
        if (view.state == PEAK_READY || view.state == PEAK_RESULT) {
            view.startTest();
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
