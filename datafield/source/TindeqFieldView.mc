using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.FitContributor;

class TindeqFieldView extends WatchUi.DataField {
    var ble = null;
    var forceField = null;
    var fitReady = false;

    function initialize() {
        DataField.initialize();
    }

    function onLayout(dc) {
    }

    function onTimerStart() {
        // Activity started — create FIT fields now
        if (!fitReady) {
            forceField = createField("force_kg", 0,
                FitContributor.DATA_TYPE_FLOAT,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "kg"});
            fitReady = true;
        }
    }

    function compute(info) {
        if (ble == null) {
            var app = getApp();
            if (app != null) {
                ble = app.bleManager;
            }
        }
        if (ble == null) { return; }

        // Retry connection if idle
        ble.ensureConnected();

        // Update FIT
        if (fitReady && forceField != null) {
            var force = ble.currentForce;
            if (force < 0) { force = 0.0; }
            forceField.setData(force);
        }
    }

    function onUpdate(dc) {
        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        dc.setColor(bgColor, bgColor);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        if (ble == null) {
            var app = getApp();
            if (app != null) { ble = app.bleManager; }
        }

        var connected = (ble != null && ble.isConnected());
        var force = 0.0;
        if (ble != null) {
            force = ble.currentForce;
            if (force < 0) { force = 0.0; }
        }

        if (!connected) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 10, Graphics.FONT_XTINY, "TINDEQ", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 8, Graphics.FONT_XTINY, "Scanning...", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Label
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 2, Graphics.FONT_XTINY, "TINDEQ kg", Graphics.TEXT_JUSTIFY_CENTER);

            // Force — pick font based on field height
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            if (h > 80) {
                dc.drawText(cx, cy - 18, Graphics.FONT_NUMBER_MILD, force.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            } else if (h > 50) {
                dc.drawText(cx, cy - 12, Graphics.FONT_MEDIUM, force.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(cx, cy - 8, Graphics.FONT_SMALL, force.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Max
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h - 16, Graphics.FONT_XTINY, "Max:" + ble.maxForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
