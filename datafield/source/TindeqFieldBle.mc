using Toybox.BluetoothLowEnergy as Ble;
using Toybox.System;
using Toybox.Timer;

// Connection states
enum {
    DF_IDLE,
    DF_SCANNING,
    DF_CONNECTING,
    DF_CONNECTED,
    DF_READY
}

class TindeqFieldBle extends Ble.BleDelegate {
    var device = null;
    var profileRegistered = false;
    var connectionState = DF_IDLE;

    var currentForce = 0.0;
    var maxForce = 0.0;
    var timestamp = 0;

    var reconnectTimer = null;
    var reconnectRetries = 0;

    // UUIDs
    var serviceUuid;
    var dataUuid;
    var ctrlUuid;
    var cccdUuid;

    function initialize() {
        BleDelegate.initialize();
        Ble.setDelegate(self);

        serviceUuid = Ble.longToUuid(0x7e4e17011ea640c9L, 0x9dcc13d34ffead57L);
        dataUuid    = Ble.longToUuid(0x7e4e17021ea640c9L, 0x9dcc13d34ffead57L);
        ctrlUuid    = Ble.longToUuid(0x7e4e17031ea640c9L, 0x9dcc13d34ffead57L);
        cccdUuid    = Ble.longToUuid(0x0000290200001000L, 0x800000805f9b34fbL);
    }

    function registerProfiles() {
        Ble.registerProfile({
            :uuid => serviceUuid,
            :characteristics => [{
                :uuid => dataUuid,
                :descriptors => [cccdUuid]
            }, {
                :uuid => ctrlUuid,
                :descriptors => []
            }]
        });
    }

    function onProfileRegister(uuid, status) {
        profileRegistered = (status == Ble.STATUS_SUCCESS);
    }

    function startScanning() {
        if (profileRegistered) {
            if (reconnectTimer != null) { reconnectTimer.stop(); }
            connectionState = DF_SCANNING;
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
        }
    }

    function stopScanning() {
        Ble.setScanState(Ble.SCAN_STATE_OFF);
        connectionState = DF_IDLE;
        if (reconnectTimer != null) { reconnectTimer.stop(); }
        reconnectRetries = 0;
    }

    function onScanResults(scanResults) {
        var result = scanResults.next();
        while (result != null) {
            if (result instanceof Ble.ScanResult) {
                var sr = result as Ble.ScanResult;
                var name = sr.getDeviceName();
                if (name != null && name.find("Progressor") != null) {
                    Ble.setScanState(Ble.SCAN_STATE_OFF);
                    connectionState = DF_CONNECTING;
                    device = Ble.pairDevice(sr);
                    return;
                }
            }
            result = scanResults.next();
        }
    }

    function onConnectedStateChanged(device, state) {
        if (state == Ble.CONNECTION_STATE_CONNECTED) {
            self.device = device;
            connectionState = DF_CONNECTED;
            reconnectRetries = 0;
            enableNotifications();
        } else {
            connectionState = DF_IDLE;
            self.device = null;
            attemptReconnect();
        }
    }

    function attemptReconnect() {
        if (reconnectRetries >= 5) { return; }
        reconnectRetries++;
        connectionState = DF_SCANNING;
        if (reconnectTimer == null) {
            reconnectTimer = new Timer.Timer();
        }
        reconnectTimer.start(method(:doReconnect), 2000, false);
    }

    function doReconnect() as Void {
        if (connectionState == DF_SCANNING && profileRegistered) {
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
        }
    }

    function enableNotifications() {
        if (device == null) { return; }
        var service = device.getService(serviceUuid);
        if (service == null) { return; }
        var dataChar = service.getCharacteristic(dataUuid);
        if (dataChar == null) { return; }
        var cccd = dataChar.getDescriptor(cccdUuid);
        if (cccd != null) {
            cccd.requestWrite([0x01, 0x00]b);
            connectionState = DF_READY;
        }
    }

    function onDescriptorWrite(descriptor, status) {
        if (status == Ble.STATUS_SUCCESS) {
            connectionState = DF_READY;
            startMeasurement();
        }
    }

    function startMeasurement() {
        sendCommand(101);
    }

    function stopMeasurement() {
        sendCommand(102);
    }

    function tareScale() {
        sendCommand(100);
    }

    function sendCommand(cmd) {
        if (device == null || connectionState != DF_READY) { return; }
        var service = device.getService(serviceUuid);
        if (service == null) { return; }
        var ctrlChar = service.getCharacteristic(ctrlUuid);
        if (ctrlChar == null) { return; }
        var data = new [1]b;
        data[0] = cmd;
        ctrlChar.requestWrite(data, {:writeType => Ble.WRITE_TYPE_WITH_RESPONSE});
    }

    function onCharacteristicChanged(char, value) {
        if (value == null || value.size() < 10) { return; }
        if (value[0] != 1) { return; }  // Only weight measurements

        var b0 = value[2]; var b1 = value[3];
        var b2 = value[4]; var b3 = value[5];
        currentForce = bytesToFloat(b0, b1, b2, b3);
        if (currentForce > maxForce) {
            maxForce = currentForce;
        }
    }

    function bytesToFloat(b0, b1, b2, b3) {
        var bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
        if (bits == 0) { return 0.0; }
        var sign = ((bits >> 31) & 1) == 1 ? -1.0 : 1.0;
        var exponent = ((bits >> 23) & 0xFF) - 127;
        var mantissa = (bits & 0x7FFFFF) | 0x800000;
        var result = sign * mantissa.toFloat();
        if (exponent > 0) {
            for (var i = 0; i < exponent; i++) { result = result * 2.0; }
        } else if (exponent < 0) {
            for (var i = 0; i < -exponent; i++) { result = result / 2.0; }
        }
        for (var i = 0; i < 23; i++) { result = result / 2.0; }
        return result;
    }

    function isConnected() {
        return connectionState == DF_READY;
    }

    function disconnect() {
        if (device != null) {
            stopMeasurement();
            Ble.unpairDevice(device);
            device = null;
        }
        connectionState = DF_IDLE;
    }

    function onCharacteristicWrite(char, status) {
    }

    function resetMax() {
        maxForce = 0.0;
    }
}
