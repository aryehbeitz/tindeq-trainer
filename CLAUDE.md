# Tindeq Trainer - Garmin Connect IQ App

Garmin watch app for training with the Tindeq Progressor force gauge.
Target device: Forerunner 955 (also supports Fenix 7, Epix 2, Venu 2/3).

## Architecture

**BLE Protocol** (Tindeq Progressor):
- Service: `7e4e1701-1ea6-40c9-9dcc-13d34ffead57`
- Data Characteristic (notify): `7e4e1702-...` — weight as float32 + uint32 timestamp (8 bytes/sample, LE)
- Control Characteristic (write): `7e4e1703-...` — single-byte commands (101=start, 102=stop, 100=tare)

**App Flow**: Connect → Configure → Train → Results

**Source Files**:
| File | Purpose |
|------|---------|
| `TindeqTrainerApp.mc` | App entry, initializes BLE + training managers |
| `TindeqBleManager.mc` | BLE scanning, connection, data parsing |
| `TrainingManager.mc` | Timer state machine, rep/set tracking |
| `ConnectView.mc` | BLE scan/connect screen |
| `ConfigView.mc` | Training parameter config (hang time, reps, sets) |
| `TrainingView.mc` | Main training display (live force, timer, counters) |
| `ResultsView.mc` | Post-session summary (max/avg per set) |

## Building

```bash
# On Contabo (Ubuntu):
ssh contabo "cd ~/dev/tindeq-trainer && bash setup-and-build.sh"

# Manual compile (if SDK installed):
monkeyc -d fr955 -f monkey.jungle -o build/TindeqTrainer.prg -y ~/.connectiq-sdk/developer_key.der -w
```

## Training State Machine

`COUNTDOWN → HANG → REP_REST → HANG → ... → SET_REST → COUNTDOWN → ... → COMPLETE`

## Known Limitations

- Watch connects directly to Progressor via BLE (phone Tindeq app must be closed)
- Float32 decoding is manual (Monkey C has no struct.unpack)
- No FIT file export yet (future feature)
