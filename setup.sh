#!/usr/bin/env bash
# ==============================================================================
# Setup script for VDownloader CLI
# ==============================================================================
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_DIR"

echo "Checking system environment..."

# Check Python 3
if ! command -v python3 &>/dev/null; then
    echo "Error: Python 3 not found. Please install Python 3 first."
    exit 1
fi

# Check FFmpeg
if ! command -v ffmpeg &>/dev/null; then
    echo "Warning: ffmpeg was not found on your system."
    echo "FFmpeg is recommended for merging high resolution streams and extracting audio."
else
    echo "FFmpeg is ready!"
fi

# Setup virtual environment
echo "Setting up virtual environment and installing dependencies..."
python3 -m venv venv
./venv/bin/pip install --upgrade pip -q
./venv/bin/pip install -r requirements.txt -q

chmod +x vdown

LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ] && [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
    ln -sf "$SCRIPT_DIR/vdown" "$LOCAL_BIN/vdown"
    echo "Linked executable to $LOCAL_BIN/vdown"
    echo "You can now run 'vdown' from anywhere in your terminal."
fi

echo "Setup completed successfully! Run: vdown --help"
