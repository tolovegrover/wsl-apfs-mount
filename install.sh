#!/usr/bin/env bash
# ==============================================================================
# wsl-drive-mount Suite Installer (APFS + Generic Linux)
#
# FULL AI DISCLOSURE:
# This software was conceptualized, designed, and implemented entirely by
# AI (Antigravity by Google DeepMind) in an interactive pair-programming session
# with Love Grover (@tolovegrover).
# ==============================================================================

set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/tolovegrover/wsl-apfs-mount/main"
INSTALL_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"

echo "==> Installing WSL Drive Mount Suite (APFS + Linux)..."

if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
fi

download_file() {
    local src="$1"
    local dest="$2"
    if command -v curl >/dev/null 2>&1; then
        sudo curl -fsSL "$src" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        sudo wget -qO "$dest" "$src"
    else
        echo "Error: curl or wget is required." >&2
        exit 1
    fi
}

echo "  -> Installing binaries to $INSTALL_DIR..."
download_file "$BASE_URL/bin/wsl-apfs-mount" "$INSTALL_DIR/wsl-apfs-mount"
download_file "$BASE_URL/bin/wsl-apfs-automount" "$INSTALL_DIR/wsl-apfs-automount"
download_file "$BASE_URL/bin/wsl-linux-mount" "$INSTALL_DIR/wsl-linux-mount"
download_file "$BASE_URL/bin/wsl-linux-automount" "$INSTALL_DIR/wsl-linux-automount"

sudo chmod +x "$INSTALL_DIR"/wsl-*

if [ -d "$SYSTEMD_DIR" ]; then
    echo "  -> Installing systemd auto-mount services..."
    download_file "$BASE_URL/systemd/wsl-apfs-automount.service" "$SYSTEMD_DIR/wsl-apfs-automount.service"
    download_file "$BASE_URL/systemd/wsl-linux-automount.service" "$SYSTEMD_DIR/wsl-linux-automount.service"
    sudo systemctl daemon-reload || true
fi

echo "==> Installation complete!"
echo "==> Available tools:"
echo "    - wsl-apfs-mount   : Mount Apple APFS drives (read-only)"
echo "    - wsl-linux-mount  : Mount generic Linux drives (ext4, btrfs, xfs, etc.)"
echo ""
echo "==> Enable auto-mounting via systemctl:"
echo "    sudo systemctl enable --now wsl-apfs-automount"
echo "    sudo systemctl enable --now wsl-linux-automount"
