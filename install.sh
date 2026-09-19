#!/usr/bin/env bash
# ==============================================================================
# wsl-apfs-mount installer
#
# FULL AI DISCLOSURE:
# This software was conceptualized, designed, and implemented entirely by
# AI (Antigravity by Google DeepMind) in an interactive pair-programming session
# with Love Grover (@tolovegrover).
# ==============================================================================

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/tolovegrover/wsl-apfs-mount/main/bin/wsl-apfs-mount"
INSTALL_DIR="/usr/local/bin"
TARGET="$INSTALL_DIR/wsl-apfs-mount"

echo "==> Installing wsl-apfs-mount..."

if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
fi

if command -v curl >/dev/null 2>&1; then
    sudo curl -fsSL "$REPO_URL" -o "$TARGET"
elif command -v wget >/dev/null 2>&1; then
    sudo wget -qO "$TARGET" "$REPO_URL"
else
    echo "Error: curl or wget is required to install wsl-apfs-mount." >&2
    exit 1
fi

sudo chmod +x "$TARGET"

echo "==> wsl-apfs-mount installed successfully to $TARGET"
echo "==> Run 'wsl-apfs-mount install-deps' to set up apfs-fuse and system build tools."
echo "==> Run 'wsl-apfs-mount help' for usage instructions."
