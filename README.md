# wsl-drive-mount (APFS + Generic Linux) 🍏🐧💾

> **A simple, safe, and generic utility suite to detect, attach, and mount Apple APFS and Linux drives (ext4, btrfs, xfs, f2fs) into Windows Subsystem for Linux (WSL2) — with automatic `systemd` services and dual Bash / PowerShell interfaces.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-WSL2%20%7C%20Windows%20PowerShell-blue.svg)]()
[![Automation](https://img.shields.io/badge/systemd-Automount%20Supported-success.svg)]()
[![Built With AI](https://img.shields.io/badge/Engineered%20With-AI%20(Google%20DeepMind)-8A2BE2.svg)]()

---

> [!IMPORTANT]
> ### 🤖 Full AI Disclosure
> This entire software suite was conceptualized, designed, architected, and coded autonomously by AI (**Antigravity** by the Google DeepMind team) in an interactive pair-programming session with [Love Grover (@tolovegrover)](https://github.com/tolovegrover).
>
> All scripts, automount daemons, systemd unit files, Windows PowerShell companions, and documentation were created and verified on real hardware against:
> 1. A physical **5.0 TB WD My Passport** Apple APFS drive.
> 2. A physical **SanDisk Cruzer Blade** USB drive containing a bootable **Arch Linux** installation (`ext4`).

---

## What This Suite Does

| Drive Type | Supported Filesystems | Tool / CLI | PowerShell Launcher | Default Mountpoint |
| :--- | :--- | :--- | :--- | :--- |
| **macOS Drives** | APFS (Strict Read-Only) | `wsl-apfs-mount` | `.\wsl-apfs-mount.ps1` | `/mnt/apfs/root` |
| **Linux Drives** | `ext4`, `btrfs`, `xfs`, `f2fs`, `vfat` | `wsl-linux-mount` | `.\wsl-linux-mount.ps1` | `/mnt/sandisk_arch` or `/mnt/disks/<label>` |

---

## ⚡ Key Highlights

- **Direct End-to-End Mounting**: Run a single command to find your external USB drive on Windows, forward it to WSL2 via `usbipd-win`, and mount it immediately.
- **🔄 Automatic Background Mounting (`systemctl`)**:
  - Automatically mounts APFS or Linux drives the instant they are attached to WSL!
  - Automatically cleans up stale mount points if a drive is disconnected!
  - Enable once with `systemctl` and never run mount commands manually again.
- **Dual CLI Interfaces**:
  - 🐧 **Linux / WSL2**: Native Bash CLIs (`wsl-apfs-mount`, `wsl-linux-mount`) installed in `/usr/local/bin`.
  - 🪟 **Windows PowerShell**: Native PowerShell companions (`wsl-apfs-mount.ps1`, `wsl-linux-mount.ps1`).
- **Windows File Explorer Integration**: All mounted files are immediately accessible in Windows File Explorer via `\\wsl.localhost\<distro>\<mountpoint>`. Launching with `-Explore` opens Explorer automatically!

---

## 🔄 Automatic Background Mounting via `systemctl`

Both tools include native `systemd` automount background daemons that monitor for drive attachment events and mount them in seconds:

### 1. Enable Auto-Mounting (One Time)

```bash
# Enable & start auto-mounting for APFS drives:
sudo systemctl enable --now wsl-apfs-automount

# Enable & start auto-mounting for Linux drives (e.g. SanDisk Arch Linux):
sudo systemctl enable --now wsl-linux-automount
```

*Or use the built-in CLI helpers:*
```bash
sudo wsl-apfs-mount automount enable
sudo wsl-linux-mount automount enable
```

### 2. Check Service Status
```bash
systemctl status wsl-apfs-automount
systemctl status wsl-linux-automount
```

---

## Installation

### In WSL2 (Linux)

Install all tools and systemd service units:

```bash
curl -fsSL https://raw.githubusercontent.com/tolovegrover/wsl-apfs-mount/main/install.sh | bash
```

For APFS support, install build tools and driver dependencies (one time):
```bash
wsl-apfs-mount install-deps
```

### In Windows PowerShell

Clone the repository:
```powershell
git clone https://github.com/tolovegrover/wsl-apfs-mount.git
cd wsl-apfs-mount
```

Ensure `usbipd-win` is installed:
```powershell
winget install dorssel.usbipd-win
```

---

## Usage Guide

### 1. Mounting Linux Drives (SanDisk Arch Linux / External Disks)

#### From Linux / WSL:
```bash
# Auto-detect and mount (default read-only for safety):
wsl-linux-mount mount

# Mount specific partition to custom location with read-write:
wsl-linux-mount mount /dev/sdf2 /mnt/sandisk_arch --rw

# Check status:
wsl-linux-mount status

# Unmount:
wsl-linux-mount unmount /mnt/sandisk_arch
```

#### From Windows PowerShell:
```powershell
# Auto-detect USB drive, forward to WSL, and mount:
.\wsl-linux-mount.ps1 mount

# Mount and immediately pop open in Windows File Explorer:
.\wsl-linux-mount.ps1 mount -Explore

# Mount with read-write mode:
.\wsl-linux-mount.ps1 mount -Mode rw
```

---

### 2. Mounting Apple APFS Drives

#### From Linux / WSL:
```bash
# Auto-detect and mount read-only:
wsl-apfs-mount mount

# Check status:
wsl-apfs-mount status

# Unmount:
wsl-apfs-mount unmount
```

#### From Windows PowerShell:
```powershell
# Forward from Windows and mount read-only:
.\wsl-apfs-mount.ps1 mount

# Mount and immediately open in Windows File Explorer:
.\wsl-apfs-mount.ps1 mount -Explore
```

---

## Windows File Explorer Paths

Once mounted, you can open File Explorer and paste these paths:

* **Apple APFS Drive:** `\\wsl.localhost\archlinux\mnt\apfs\root`
* **SanDisk Arch Linux Drive:** `\\wsl.localhost\archlinux\mnt\sandisk_arch`
* **Generic Linux Disks:** `\\wsl.localhost\archlinux\mnt\disks\<label>`

---

## Safety & Guarantees

> [!NOTE]
> - **APFS Drives**: Always mounted in **strict read-only (`ro`)** mode via userspace FUSE (`apfs-fuse`), preventing partition or B-tree damage.
> - **Linux Drives (`ext4`, `btrfs`, `xfs`)**: Mounted with native Linux kernel drivers. Defaults to **read-only (`ro`)** for safety, but supports `--rw` when modification is needed.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgments

- [sgan81/apfs-fuse](https://github.com/sgan81/apfs-fuse) for the foundational FUSE driver.
- [dorssel/usbipd-win](https://github.com/dorssel/usbipd-win) for Windows-to-WSL USB device forwarding.
- Google DeepMind **Antigravity** AI Agent system.
