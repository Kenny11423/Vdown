#!/bin/sh
# ==============================================================================
# Setup script for VDownloader CLI
# Supports both Standard Linux (Ubuntu/Debian, Arch, Fedora) and iSH (iOS)
# ==============================================================================
set -e

SCRIPT_DIR="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "   VDownloader CLI - Environment Setup    "
echo "=========================================="

# Detect environment: iSH (Alpine Linux on iOS) vs Standard Linux
IS_ISH=0
if [ -f /etc/alpine-release ] || command -v apk >/dev/null 2>&1 || uname -a | grep -qi "ish"; then
    IS_ISH=1
fi

if [ "$IS_ISH" -eq 1 ]; then
    echo "Environment: iSH (Alpine Linux on iOS)"
    echo "------------------------------------------"

    # Check and install system packages via apk
    MISSING_PKGS=""
    command -v python3 >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS python3"
    command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS py3-pip"
    command -v ffmpeg >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS ffmpeg"
    command -v node >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS nodejs"
    command -v git >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS git"
    command -v bash >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS bash"

    if [ -n "$MISSING_PKGS" ]; then
        echo "Installing missing system packages via apk:$MISSING_PKGS ..."
        apk update
        apk add $MISSING_PKGS
    else
        echo "System packages (python3, ffmpeg, nodejs) are ready."
    fi

    # Install Python dependencies
    echo "Installing Python dependencies (yt-dlp, mutagen)..."
    if pip install --break-system-packages -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null; then
        echo "Dependencies installed with pip."
    else
        python3 -m venv "$SCRIPT_DIR/venv"
        "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    fi

    # Link executable to /usr/local/bin or /usr/bin
    chmod +x "$SCRIPT_DIR/vdown"
    if [ -d "/usr/local/bin" ]; then
        ln -sf "$SCRIPT_DIR/vdown" /usr/local/bin/vdown
        echo "Linked 'vdown' to /usr/local/bin/vdown"
    elif [ -d "/usr/bin" ]; then
        ln -sf "$SCRIPT_DIR/vdown" /usr/bin/vdown
        echo "Linked 'vdown' to /usr/bin/vdown"
    fi

    echo ""
    echo "iSH Setup Completed Successfully!"
    echo "You can now run: vdown \"<link>\""
    echo ""
    echo "Note on iOS Files app:"
    echo "  Downloads are saved to: ~/Downloads (i.e. /root/Downloads)"
    echo "  Access them in: Files app -> On My iPhone -> iSH -> root -> Downloads"

else
    echo "Environment: Standard Linux"
    echo "------------------------------------------"

    # Check Python 3
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: Python 3 not found. Please install Python 3 first."
        exit 1
    fi
    echo "Python 3: $(python3 --version)"

    # Check FFmpeg
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Warning: FFmpeg is not installed."
        echo "Please install ffmpeg for video merging and MP3 conversion:"
        if command -v apt >/dev/null 2>&1; then
            echo "   sudo apt install ffmpeg"
        elif command -v pacman >/dev/null 2>&1; then
            echo "   sudo pacman -S ffmpeg"
        elif command -v dnf >/dev/null 2>&1; then
            echo "   sudo dnf install ffmpeg"
        fi
    else
        echo "FFmpeg: installed"
    fi

    # Check Node.js
    if ! command -v node >/dev/null 2>&1; then
        echo "Tip: Node.js is recommended for YouTube bot-check challenges."
    else
        echo "Node.js: installed"
    fi

    # Setup Virtual Environment
    echo "Setting up Python virtual environment..."
    python3 -m venv "$SCRIPT_DIR/venv"
    "$SCRIPT_DIR/venv/bin/pip" install --upgrade pip -q
    "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" -q
    echo "Dependencies installed in virtualenv."

    chmod +x "$SCRIPT_DIR/vdown"

    # Link executable to ~/.local/bin or /usr/local/bin
    LOCAL_BIN="$HOME/.local/bin"
    if [ -d "$LOCAL_BIN" ] && echo ":$PATH:" | grep -q ":$LOCAL_BIN:"; then
        ln -sf "$SCRIPT_DIR/vdown" "$LOCAL_BIN/vdown"
        echo "Linked 'vdown' to $LOCAL_BIN/vdown"
        echo "You can run 'vdown' from anywhere in your terminal."
    elif [ -w "/usr/local/bin" ]; then
        ln -sf "$SCRIPT_DIR/vdown" /usr/local/bin/vdown
        echo "Linked 'vdown' to /usr/local/bin/vdown"
    else
        echo "To run 'vdown' from anywhere, you can run:"
        echo "   sudo ln -sf \"$SCRIPT_DIR/vdown\" /usr/local/bin/vdown"
    fi

    echo ""
    echo "Linux Setup Completed Successfully!"
    echo "Run: vdown --help"
fi
