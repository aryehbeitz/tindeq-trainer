# Tindeq Trainer — Garmin Connect IQ App

A full-featured Garmin watch app for training with the [Tindeq Progressor](https://tindeq.com/) force gauge. No phone needed during training — the watch connects directly to the Progressor via Bluetooth Low Energy.

**Target device:** Forerunner 955 (round 260×260 MIP display)

> **Note:** This is the first Tindeq Progressor app on the Garmin Connect IQ platform.

## Features

### Training Modes

| Mode | Description |
|------|-------------|
| **Free Pull** | Live force display with real-time graph. No timer — just hang and see numbers. Tare with DOWN button. |
| **Repeaters** | Configurable hang/rest intervals with set tracking. Vibration alerts on transitions. Force graph + target force line. |
| **Endurance** | Single hang until failure. Auto-detects when force drops below 20% of peak for >1 second. Shows time held. |
| **Peak Test** | 3-2-1 countdown → 5-second max pull window. Shows peak force with progress bar. |

### Data & History

- **Session history** — Last 50 sessions stored on watch with date, mode, peak force, avg force, sets, reps, duration
- **FIT file recording** — Sessions recorded as Garmin activities with custom force data fields. Syncs to Garmin Connect.
- **Saved programs** — Name and store training protocols. Load them from the Programs menu.
- **Per-set results** — Post-session breakdown showing max/avg force per set

### Smart Features

- **Auto-reconnect** — If BLE drops, the watch automatically rescans and reconnects (up to 5 retries)
- **Target force** — Set a goal in kg. Watch vibrates if you drop below target during a hang.
- **Force graph** — Real-time force-time curve displayed during training (last 5 seconds, 50 samples)
- **Battery monitoring** — Progressor battery level queried on connect
- **Haptic feedback** — Vibration on hang/rest transitions, countdown warnings, target force alerts

## Installation

### Sideloading (Developer Mode)

1. Build the `.prg` file (see [Building](#building))
2. Connect FR955 via USB
3. Copy the `.prg` to `GARMIN/APPS/` on the watch
4. Disconnect — app appears in Activities & Apps

### Building

**Prerequisites:** Garmin Connect IQ SDK 9.1+ with FR955 device profile, Java 17+

```bash
# On a Linux server with the SDK installed:
SDK_DIR=$(ls -d ~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-*/ | head -1)
export PATH="$SDK_DIR/bin:$PATH"
cd /path/to/tindeq-trainer

monkeyc -d fr955 \
  -f monkey.jungle \
  -o build/TindeqTrainer.prg \
  -y ~/.connectiq-sdk/developer_key.der \
  -w
```

Or use the automated setup script (installs SDK, generates key, compiles):
```bash
bash setup-and-build.sh
```

### SDK Setup (one-time)

```bash
# Install CLI SDK manager
gh release download --repo lindell/connect-iq-sdk-manager-cli \
  --pattern "*Linux_x86_64.tar.gz" -O /tmp/ciq-cli.tar.gz
tar xzf /tmp/ciq-cli.tar.gz -C ~/.local/bin/ connect-iq-sdk-manager

# Accept agreement and download SDK
connect-iq-sdk-manager agreement accept -H $(connect-iq-sdk-manager agreement view 2>&1 | grep Hash | awk '{print $NF}')
connect-iq-sdk-manager sdk download ">=9.0.0"
connect-iq-sdk-manager sdk set 9.1.0

# Login and download device profile (requires Garmin account)
connect-iq-sdk-manager login --username "YOUR_EMAIL" --password "YOUR_PASS"
connect-iq-sdk-manager device download -d fr955

# Generate developer key
openssl genrsa -out /tmp/key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/key.pem \
  -out ~/.connectiq-sdk/developer_key.der -nocrypt
```

## Usage

1. **Turn on** your Tindeq Progressor (hold button until LED blinks)
2. **Close** the Tindeq phone app (frees the BLE connection)
3. **Open** Tindeq Trainer on your FR955
4. **Press START** to scan — watch connects automatically
5. **Choose a mode** from the main menu
6. **Train!** — force data streams at ~80Hz from the Progressor

### Button Mapping

| Screen | START | BACK | UP | DOWN |
|--------|-------|------|-----|------|
| Connect | Scan | Exit | — | — |
| Main Menu | Select | Exit app | Scroll | Scroll |
| Config | Begin training | Back to menu | Select field / +1 | Select field / -1 |
| Training | View results (when done) | Stop → results | — | Tare |
| Free Pull | Reset max | Stop → menu | — | Tare |
| Results | Back to menu | Back to menu | — | — |

## Architecture

### BLE Protocol (Tindeq Progressor)

| Component | UUID |
|-----------|------|
| Service | `7e4e1701-1ea6-40c9-9dcc-13d34ffead57` |
| Data (notify) | `7e4e1702-1ea6-40c9-9dcc-13d34ffead57` |
| Control (write) | `7e4e1703-1ea6-40c9-9dcc-13d34ffead57` |

**Commands:** Tare (100), Start measurement (101), Stop (102), Peak RFD (103), Battery (111), Sleep (110)

**Data format:** TLV — `[type, length, float32_weight_LE, uint32_timestamp_LE, ...]` per sample

### Source Files

| File | Purpose |
|------|---------|
| `TindeqTrainerApp.mc` | App entry, FIT recording lifecycle, manager initialization |
| `TindeqBleManager.mc` | BLE scanning, connection, auto-reconnect, data parsing, IEEE754 float decode |
| `TrainingManager.mc` | Repeater state machine (countdown→hang→rest→set rest→complete), target force |
| `ForceGraph.mc` | Reusable ring-buffer force-time graph renderer |
| `ProgramManager.mc` | Save/load named training configs via Application.Storage |
| `HistoryManager.mc` | Session persistence (last 50 sessions) via Application.Storage |
| `MainMenuView.mc` | Mode selection menu (Menu2) |
| `ConnectView.mc` | BLE scan/connect screen with auto-transition |
| `ConfigView.mc` | Training parameter editor (hang, rest, reps, sets, target) |
| `TrainingView.mc` | Live training display with force graph |
| `FreePullView.mc` | Free pull mode — live force + graph |
| `EnduranceView.mc` | Endurance mode — time to failure |
| `PeakTestView.mc` | Peak test mode — max force in 5s window |
| `HistoryView.mc` | Session history browser |
| `ResultsView.mc` | Post-session summary |

### Navigation Flow

```
ConnectView → MainMenuView
                ├── FreePullView → MainMenuView
                ├── ConfigView → TrainingView → ResultsView → MainMenuView
                ├── EnduranceView → MainMenuView
                ├── PeakTestView → MainMenuView
                ├── Programs (Menu2) → ConfigView
                └── HistoryView → HistoryDetailView
```

### Data Storage

- **Programs:** `Application.Storage` with keys `prog_{name}` and `program_list`
- **History:** `Application.Storage` with keys `ses_{timestamp}` and `session_list` (max 50)
- **FIT:** Custom fields `force_kg` (per-record) and `peak_kg` (per-session) via `FitContributor`

## Limitations

- Watch connects directly to Progressor — phone Tindeq app must be closed
- No float32 struct unpacking in Monkey C — manual IEEE 754 decode
- FIT recording writes at ~1Hz (Garmin Smart Recording), not the full 80Hz sensor rate
- Watch may blacklist the app after a runtime crash — rebuild with new app UUID to reinstall
- Round display constrains layout — content kept within 13%–85% vertical safe zone

## License

GPL-3.0 — see [LICENSE](LICENSE)
