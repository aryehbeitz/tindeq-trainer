using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.FitContributor;

class TindeqFieldView extends WatchUi.DataField {
    var ble;
    var forceField = null;
    var peakField = null;

    function initialize() {
        DataField.initialize();
    }

    function onLayout(dc) {
        ble = getApp().bleManager;

        // Create custom FIT fields
        forceField = createField("force_kg", 0,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "kg"});
        peakField = createField("peak_kg", 1,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "kg"});
    }

    function compute(info) {
        if (ble == null) { return; }
        // Update FIT data
        var force = ble.currentForce;
        if (force < 0) { force = 0.0; }
        if (forceField != null) {
            forceField.setData(force);
        }
        if (peakField != null) {
            peakField.setData(ble.maxForce);
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

        if (ble == null) { ble = getApp().bleManager; }

        // Force value
        var force = 0.0;
        if (ble != null) {
            force = ble.currentForce;
            if (force < 0) { force = 0.0; }
        }

        // Connection status
        var connected = (ble != null && ble.isConnected());

        if (!connected) {
            // Scanning/disconnected state
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.15, Graphics.FONT_XTINY, "TINDEQ", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.40, Graphics.FONT_SMALL, "Scanning...", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Connected — show force data
            // Label
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.05, Graphics.FONT_XTINY, "TINDEQ kg", Graphics.TEXT_JUSTIFY_CENTER);

            // Current force (big)
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            if (h > 80) {
                dc.drawText(cx, h * 0.20, Graphics.FONT_NUMBER_MILD, force.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(cx, h * 0.20, Graphics.FONT_MEDIUM, force.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Max force
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.72, Graphics.FONT_XTINY, "Max: " + ble.maxForce.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

            // Connection dot
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w - 6, 6, 3);
        }
    }
}
