using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;

// Tindeq Progressor BLE UUIDs
const PROGRESSOR_SERVICE    = "7e4e1701-1ea6-40c9-9dcc-13d34ffead57";
const DATA_CHAR             = "7e4e1702-1ea6-40c9-9dcc-13d34ffead57";
const CTRL_POINT_CHAR       = "7e4e1703-1ea6-40c9-9dcc-13d34ffead57";
const CCCD_UUID             = "00002902-0000-1000-8000-00805f9b34fb";

// Progressor commands
const CMD_TARE_SCALE            = 100;
const CMD_START_WEIGHT_MEAS     = 101;
const CMD_STOP_WEIGHT_MEAS      = 102;
const CMD_START_PEAK_RFD_MEAS   = 103;
const CMD_START_PEAK_RFD_SERIES = 104;
const CMD_GET_APP_VERSION       = 107;
const CMD_GET_ERROR_INFO        = 108;
const CMD_ENTER_SLEEP           = 110;
const CMD_GET_BATTERY_VOLTAGE   = 111;

// Response codes
const RES_CMD_RESPONSE      = 0;
const RES_WEIGHT_MEAS       = 1;
const RES_RFD_PEAK          = 2;
const RES_RFD_PEAK_SERIES   = 3;
const RES_LOW_PWR_WARNING   = 4;

// Connection states
enum {
    STATE_IDLE,
    STATE_SCANNING,
    STATE_CONNECTING,
    STATE_CONNECTED,
    STATE_READY
}

class TindeqBleManager extends Ble.BleDelegate {
    var device = null;
    var profileRegistered = false;
    var connectionState = STATE_IDLE;
    var scanResult = null;

    // Parsed data
    var currentForce = 0.0;
    var timestamp = 0;
    var batteryMv = 0;
    var firmwareVersion = "";
    var lowBattery = false;

    // Auto-reconnect
    var reconnectTimer = null;
    var reconnectRetries = 0;
    const MAX_RECONNECT = 5;

    // UUIDs
    var progressorServiceUuid;
    var dataCharUuid;
    var ctrlPointCharUuid;
    var cccdUuid;

    function initialize() {
        BleDelegate.initialize();
        Ble.setDelegate(self);

        // UUID: 7e4e1701-1ea6-40c9-9dcc-13d34ffead57
        progressorServiceUuid = Ble.longToUuid(0x7e4e17011ea640c9L, 0x9dcc13d34ffead57L);
        // UUID: 7e4e1702-1ea6-40c9-9dcc-13d34ffead57
        dataCharUuid          = Ble.longToUuid(0x7e4e17021ea640c9L, 0x9dcc13d34ffead57L);
        // UUID: 7e4e1703-1ea6-40c9-9dcc-13d34ffead57
        ctrlPointCharUuid     = Ble.longToUuid(0x7e4e17031ea640c9L, 0x9dcc13d34ffead57L);
        // UUID: 00002902-0000-1000-8000-00805f9b34fb
        cccdUuid              = Ble.longToUuid(0x0000290200001000L, 0x800000805f9b34fbL);
    }

    function registerProfiles() {
        var profile = {
            :uuid => progressorServiceUuid,
            :characteristics => [{
                :uuid => dataCharUuid,
                :descriptors => [cccdUuid]
            }, {
                :uuid => ctrlPointCharUuid,
                :descriptors => []
            }]
        };
        Ble.registerProfile(profile);
    }

    function onProfileRegister(uuid, status) {
        if (status == Ble.STATUS_SUCCESS) {
            profileRegistered = true;
            System.println("Profile registered OK");
        } else {
            System.println("Profile registration failed: " + status);
        }
    }

    function startScanning() {
        if (profileRegistered) {
            connectionState = STATE_SCANNING;
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
            System.println("Scanning for Progressor...");
        }
    }

    function stopScanning() {
        Ble.setScanState(Ble.SCAN_STATE_OFF);
    }

    function onScanResults(scanResults) {
        var result = scanResults.next();
        while (result != null) {
            if (result instanceof Ble.ScanResult) {
                var sr = result as Ble.ScanResult;
                var name = sr.getDeviceName();
                if (name != null && name.find("Progressor") != null) {
                    System.println("Found Progressor: " + name);
                    scanResult = sr;
                    stopScanning();
                    connectionState = STATE_CONNECTING;
                    device = Ble.pairDevice(sr);
                    return;
                }
            }
            result = scanResults.next();
        }
    }

    function onConnectedStateChanged(device, state) {
        if (state == Ble.CONNECTION_STATE_CONNECTED) {
            System.println("Connected to Progressor");
            self.device = device;
            connectionState = STATE_CONNECTED;
            reconnectRetries = 0;
            enableNotifications();
        } else {
            System.println("Disconnected from Progressor");
            connectionState = STATE_IDLE;
            self.device = null;
            // Auto-reconnect
            attemptReconnect();
        }
    }

    function attemptReconnect() {
        if (reconnectRetries >= MAX_RECONNECT) {
            System.println("Max reconnect attempts reached");
            return;
        }
        reconnectRetries++;
        System.println("Reconnecting... attempt " + reconnectRetries);
        connectionState = STATE_SCANNING;
        if (reconnectTimer == null) {
            reconnectTimer = new Timer.Timer();
        }
        reconnectTimer.start(method(:doReconnect), 2000, false);
    }

    function doReconnect() as Void {
        if (connectionState == STATE_SCANNING && profileRegistered) {
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
        }
    }

    function enableNotifications() {
        if (device == null) { return; }
        var service = device.getService(progressorServiceUuid);
        if (service == null) {
            System.println("Progressor service not found");
            return;
        }
        var dataChar = service.getCharacteristic(dataCharUuid);
        if (dataChar == null) {
            System.println("Data characteristic not found");
            return;
        }
        var cccd = dataChar.getDescriptor(cccdUuid);
        if (cccd != null) {
            cccd.requestWrite([0x01, 0x00]b);
            System.println("Notifications enabled");
            connectionState = STATE_READY;
        }
    }

    function onDescriptorWrite(descriptor, status) {
        if (status == Ble.STATUS_SUCCESS) {
            System.println("CCCD write success - notifications active");
            connectionState = STATE_READY;
            // Query battery on connect
            getBatteryVoltage();
        } else {
            System.println("CCCD write failed: " + status);
        }
    }

    var pendingCommands = [];

    function sendCommand(cmd) {
        if (device == null || connectionState != STATE_READY) { return false; }
        var service = device.getService(progressorServiceUuid);
        if (service == null) { return false; }
        var ctrlChar = service.getCharacteristic(ctrlPointCharUuid);
        if (ctrlChar == null) { return false; }
        var data = new [1]b;
        data[0] = cmd;
        ctrlChar.requestWrite(data, {:writeType => Ble.WRITE_TYPE_WITH_RESPONSE});
        return true;
    }

    function onCharacteristicWrite(char, status) {
        // Process next queued command if any
        if (pendingCommands.size() > 0) {
            var next = pendingCommands[0];
            pendingCommands = pendingCommands.slice(1, null);
            sendCommand(next);
        }
    }

    function queueCommand(cmd) {
        if (pendingCommands.size() == 0) {
            if (!sendCommand(cmd)) {
                return false;
            }
        } else {
            pendingCommands.add(cmd);
        }
        return true;
    }

    function tareScale() {
        return sendCommand(CMD_TARE_SCALE);
    }

    function startMeasurement() {
        return sendCommand(CMD_START_WEIGHT_MEAS);
    }

    function stopMeasurement() {
        return sendCommand(CMD_STOP_WEIGHT_MEAS);
    }

    function getBatteryVoltage() {
        return sendCommand(CMD_GET_BATTERY_VOLTAGE);
    }

    function getFirmwareVersion() {
        return sendCommand(CMD_GET_APP_VERSION);
    }

    function enterSleep() {
        return sendCommand(CMD_ENTER_SLEEP);
    }

    function onCharacteristicChanged(char, value) {
        if (value == null || value.size() < 2) { return; }
        var responseType = value[0];
        var payloadSize = value[1];

        if (responseType == RES_WEIGHT_MEAS) {
            parseWeightData(value);
        } else if (responseType == RES_LOW_PWR_WARNING) {
            lowBattery = true;
        } else if (responseType == RES_CMD_RESPONSE) {
            parseCmdResponse(value);
        } else if (responseType == RES_RFD_PEAK) {
            parseWeightData(value);
        }
    }

    function parseWeightData(value) {
        // Format: [type, length, float32_weight, uint32_timestamp, ...]
        // Each sample is 8 bytes (4 byte float + 4 byte uint32), little-endian
        if (value.size() < 10) { return; }

        // Parse first sample (most recent)
        // Little-endian float32 from bytes [2..5]
        var b0 = value[2]; var b1 = value[3];
        var b2 = value[4]; var b3 = value[5];
        currentForce = bytesToFloat(b0, b1, b2, b3);

        // Little-endian uint32 timestamp from bytes [6..9]
        timestamp = value[6] | (value[7] << 8) | (value[8] << 16) | (value[9] << 24);

        // Data stored in currentForce/timestamp - TrainingManager reads it
    }

    // IEEE 754 float32 decode (little-endian bytes)
    function bytesToFloat(b0, b1, b2, b3) {
        var bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
        if (bits == 0) { return 0.0; }

        var sign = ((bits >> 31) & 1) == 1 ? -1.0 : 1.0;
        var exponent = ((bits >> 23) & 0xFF) - 127;
        var mantissa = (bits & 0x7FFFFF) | 0x800000;

        var result = sign * mantissa.toFloat();
        if (exponent > 0) {
            for (var i = 0; i < exponent; i++) {
                result = result * 2.0;
            }
        } else if (exponent < 0) {
            for (var i = 0; i < -exponent; i++) {
                result = result / 2.0;
            }
        }
        // Mantissa has implicit 23-bit shift
        for (var i = 0; i < 23; i++) {
            result = result / 2.0;
        }
        return result;
    }

    function parseCmdResponse(value) {
        if (value.size() < 3) { return; }
        // Check what command this is responding to
        // Battery voltage: 4 bytes uint32 little-endian
        // Try to detect by payload size
        var payloadSize = value[1];
        if (payloadSize == 4) {
            // Likely battery voltage (mV)
            batteryMv = value[2] | (value[3] << 8) | (value[4] << 16) | (value[5] << 24);
        } else if (payloadSize > 4) {
            // Likely firmware version string
            firmwareVersion = "";
            for (var i = 2; i < value.size(); i++) {
                firmwareVersion += value[i].toChar();
            }
        }
    }

    function disconnect() {
        if (device != null) {
            stopMeasurement();
            Ble.unpairDevice(device);
            device = null;
        }
        connectionState = STATE_IDLE;
    }

    function isConnected() {
        return connectionState == STATE_READY;
    }

    function isScanning() {
        return connectionState == STATE_SCANNING;
    }
}
