#!/bin/bash
# Build script for Tindeq Trainer - runs on Contabo (Ubuntu 24.04)
# Usage: ssh contabo "bash ~/dev/tindeq-trainer/setup-and-build.sh"
set -euo pipefail

PROJECT_DIR="$HOME/dev/tindeq-trainer"
SDK_DIR="$HOME/.connectiq-sdk"
SDK_BIN="$SDK_DIR/bin"
DEVICE="fr955"
KEY="$HOME/.connectiq-sdk/developer_key.der"

echo "=== Tindeq Trainer Build ==="

# Step 1: Install Java if needed
if ! command -v java &>/dev/null; then
    echo "[1/5] Installing Java JDK..."
    sudo apt-get update -qq && sudo apt-get install -y -qq default-jdk-headless
else
    echo "[1/5] Java already installed: $(java -version 2>&1 | head -1)"
fi

# Step 2: Download Connect IQ SDK if needed
if [ ! -f "$SDK_BIN/monkeyc" ]; then
    echo "[2/5] Downloading Connect IQ SDK..."
    mkdir -p "$SDK_DIR"

    # Use the CLI SDK manager to download
    if ! command -v connectiq-sdk-manager &>/dev/null; then
        # Download SDK manager CLI
        echo "  Installing connectiq-sdk-manager-cli..."
        if command -v go &>/dev/null; then
            go install github.com/lindell/connect-iq-sdk-manager-cli/cmd/connectiq-sdk-manager@latest
        else
            # Fallback: download SDK directly
            echo "  Go not available. Downloading SDK manually..."
            echo "  Please download from https://developer.garmin.com/connect-iq/sdk/"
            echo "  Extract to $SDK_DIR and ensure $SDK_BIN/monkeyc exists"
            echo ""
            echo "  Alternative: install Go first:"
            echo "    sudo snap install go --classic"
            echo "    go install github.com/lindell/connect-iq-sdk-manager-cli/cmd/connectiq-sdk-manager@latest"
            exit 1
        fi
    fi

    echo "  Downloading latest SDK..."
    connectiq-sdk-manager download-sdk --dest "$SDK_DIR" 2>/dev/null || true

    # Download FR955 device file
    echo "  Downloading FR955 device profile..."
    connectiq-sdk-manager download-device --device fr955 --dest "$SDK_DIR/Devices" 2>/dev/null || true
else
    echo "[2/5] Connect IQ SDK already installed"
fi

# Step 3: Generate developer key if needed
if [ ! -f "$KEY" ]; then
    echo "[3/5] Generating developer key..."
    openssl genrsa -out /tmp/dev_key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/dev_key.pem -out "$KEY" -nocrypt
    rm /tmp/dev_key.pem
    echo "  Key saved to $KEY"
else
    echo "[3/5] Developer key exists"
fi

# Step 4: Compile
echo "[4/5] Compiling..."
cd "$PROJECT_DIR"

# Find monkeyc
MONKEYC=""
if [ -f "$SDK_BIN/monkeyc" ]; then
    MONKEYC="$SDK_BIN/monkeyc"
elif command -v monkeyc &>/dev/null; then
    MONKEYC="monkeyc"
else
    # Try to find monkeybrains.jar directly
    JAR=$(find "$SDK_DIR" -name "monkeybrains.jar" 2>/dev/null | head -1)
    if [ -n "$JAR" ]; then
        MONKEYC="java -jar $JAR"
    else
        echo "ERROR: monkeyc not found. Check SDK installation."
        exit 1
    fi
fi

OUTPUT="$PROJECT_DIR/build/TindeqTrainer.prg"
mkdir -p "$PROJECT_DIR/build"

$MONKEYC \
    -d "$DEVICE" \
    -f "$PROJECT_DIR/monkey.jungle" \
    -o "$OUTPUT" \
    -y "$KEY" \
    -w

echo "  Build output: $OUTPUT"

# Step 5: Package for distribution (.iq file)
echo "[5/5] Packaging .iq file..."
IQ_OUTPUT="$PROJECT_DIR/build/TindeqTrainer.iq"
$MONKEYC \
    -e \
    -f "$PROJECT_DIR/monkey.jungle" \
    -o "$IQ_OUTPUT" \
    -y "$KEY" \
    -w

echo "  Package: $IQ_OUTPUT"
echo ""
echo "=== Build Complete ==="
echo ""
echo "To install on your FR955:"
echo "  1. Connect watch via USB"
echo "  2. Copy $OUTPUT to GARMIN/APPS/ on the watch"
echo "  OR"
echo "  1. scp build/TindeqTrainer.prg to your phone"
echo "  2. Use Garmin Connect app > Connect IQ > sideload"
echo ""
echo "To transfer to phone:"
echo "  scp $OUTPUT phone:~/dev/tindeq-trainer/"
