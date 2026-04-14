using Toybox.Graphics;

class ForceGraph {
    const BUFFER_SIZE = 50;  // 5 seconds at 10Hz
    var samples;
    var sampleIndex = 0;
    var sampleCount = 0;
    var targetForce = 0.0;

    function initialize() {
        samples = new [BUFFER_SIZE];
        for (var i = 0; i < BUFFER_SIZE; i++) {
            samples[i] = 0.0;
        }
    }

    function addSample(force) {
        samples[sampleIndex] = force;
        sampleIndex = (sampleIndex + 1) % BUFFER_SIZE;
        if (sampleCount < BUFFER_SIZE) {
            sampleCount++;
        }
    }

    function setTarget(target) {
        targetForce = target;
    }

    function clear() {
        sampleIndex = 0;
        sampleCount = 0;
        for (var i = 0; i < BUFFER_SIZE; i++) {
            samples[i] = 0.0;
        }
    }

    function draw(dc, x, y, width, height) {
        if (sampleCount < 2) { return; }

        // Find max for Y scale
        var maxVal = 1.0;
        for (var i = 0; i < sampleCount; i++) {
            var idx = (sampleIndex - sampleCount + i + BUFFER_SIZE) % BUFFER_SIZE;
            if (samples[idx] > maxVal) {
                maxVal = samples[idx];
            }
        }
        if (targetForce > maxVal) { maxVal = targetForce; }
        maxVal = maxVal * 1.2;

        // Background
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, height, 4);

        // Target force line (red)
        if (targetForce > 0) {
            var targetY = y + height - ((targetForce / maxVal) * height).toNumber();
            if (targetY > y && targetY < y + height) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(x, targetY, x + width, targetY);
            }
        }

        // Force curve (green)
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        var prevX = -1;
        var prevY = -1;

        for (var i = 0; i < sampleCount; i++) {
            var idx = (sampleIndex - sampleCount + i + BUFFER_SIZE) % BUFFER_SIZE;
            var val = samples[idx];
            if (val < 0) { val = 0.0; }

            var px = x + ((i.toFloat() / (BUFFER_SIZE - 1)) * width).toNumber();
            var py = y + height - ((val / maxVal) * height).toNumber();

            if (py < y) { py = y; }
            if (py > y + height) { py = y + height; }

            if (prevX >= 0) {
                dc.drawLine(prevX, prevY, px, py);
            }
            prevX = px;
            prevY = py;
        }
    }
}
