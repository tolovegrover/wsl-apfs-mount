<#
.SYNOPSIS
    wsl-linux-mount.ps1 - Generic Linux Drive Mounter for WSL2
    
.DESCRIPTION
    Automates detecting, attaching (via usbipd-win), and mounting external
    Linux drives (Arch Linux, Ubuntu, ext4, btrfs, xfs, etc.) directly into WSL2.

.NOTES
    FULL AI DISCLOSURE:
    This software was conceptualized, designed, and implemented entirely by
    AI (Antigravity by Google DeepMind) in an interactive pair-programming session
    with Love Grover (@tolovegrover).
    
    License: MIT License
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("mount", "unmount", "umount", "list", "status", "automount", "help")]
    [string]$Command = "mount",

    [Parameter()]
    [string]$BusId,

    [Parameter()]
    [string]$MountPoint,

    [Parameter()]
    [ValidateSet("ro", "rw")]
    [string]$Mode = "ro",

    [Parameter()]
    [string]$Distro,

    [Parameter()]
    [switch]$Explore
)

$ErrorActionPreference = "Stop"
$Version = "1.0.0"

function Show-Banner {
    Write-Host @"
 _       ______  __       __    _____   __  ___  ___  __
| |     / / __ \/ /      / /   /  _/ | / / / / / / / / /
| | /| / / /_/ / /      / /    / / /  |/ / / / / / / / / 
| |/ |/ /\__, / /___   / /____/ / / /|  / / /_/ / /_/ /  
|__/|__//____/_____/  /_____/___//_/ |_/  \____/\____/   
                                 MOUNT (WSL2 / PowerShell)
"@ -ForegroundColor Green

    Write-Host "Version $Version | Generic Linux Drive Launcher for WSL2" -ForegroundColor DarkGray
    Write-Host "[AI Disclosure] Engineered by AI (Google DeepMind Antigravity) & @tolovegrover`n" -ForegroundColor Magenta
}

function Write-Info($msg)    { Write-Host "[*] $msg" -ForegroundColor Blue }
function Write-Success($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)     { Write-Host "[-] $msg" -ForegroundColor Red }

function Get-WslDistro {
    if ($Distro) { return $Distro }
    try {
        $raw = wsl.exe -l -v 2>$null | Out-String
        $lines = $raw -split "`r?`n" | Where-Object { $_ -match '^\s*\*\s*' }
        if ($lines) {
            $matched = ($lines[0] -replace '^\s*\*\s*', '') -split '\s+'
            return $matched[0].Trim([char]0, ' ')
        }
    } catch {}
    return "archlinux"
}

function Find-LinuxUsbDevice {
    Write-Info "Scanning Windows USB devices for external mass storage..."

    if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
        Write-Err "'usbipd' is not installed or not in PATH."
        Write-Host "Install it via: winget install dorssel.usbipd-win" -ForegroundColor Yellow
        exit 1
    }

    $rawUsb = usbipd list 2>$null | Out-String
    $usbLines = $rawUsb -split "`r?`n" | Where-Object { $_ -match '^\d+-\d+' }
    
    $candidates = @()
    foreach ($line in $usbLines) {
        if ($line -match '^(\d+-\d+)\s+([0-9a-fA-F:]+)\s+(.+?)\s+(Shared|Not shared|Attached)$') {
            $bid = $matches[1]
            $devName = $matches[3]
            $state = $matches[4]
            if ($devName -match 'Mass Storage' -or $devName -match 'SanDisk' -or $devName -match 'Cruzer') {
                $candidates += [PSCustomObject]@{
                    BusId = $bid
                    Name = $devName
                    State = $state
                }
            }
        }
    }

    if ($candidates.Count -eq 0) {
        return $null
    } elseif ($candidates.Count -eq 1) {
        return $candidates[0]
    } else {
        Write-Warn "Multiple USB storage devices detected:"
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "  [$i] $($candidates[$i].BusId) - $($candidates[$i].Name) ($($candidates[$i].State))"
        }
        $choice = Read-Host "Select device index"
        return $candidates[[int]$choice]
    }
}

function Invoke-Mount {
    $targetDistro = Get-WslDistro
    Write-Info "Target WSL2 Distribution: $targetDistro"

    $usbDev = $null
    if ($BusId) {
        $usbDev = [PSCustomObject]@{ BusId = $BusId; State = "Unknown"; Name = "Manual" }
    } else {
        $usbDev = Find-LinuxUsbDevice
    }

    if ($usbDev) {
        Write-Info "USB Device: $($usbDev.BusId) ($($usbDev.Name))"

        if ($usbDev.State -eq "Not shared") {
            Write-Info "Device is not yet shared in usbipd. Requesting Administrator elevation to bind..."
            $bindCmd = "usbipd bind --busid $($usbDev.BusId)"
            Start-Process powershell -ArgumentList "-NoProfile -Command `"$bindCmd`"" -Verb RunAs -Wait
            Write-Success "Device bound successfully."
        }

        Write-Info "Attaching $($usbDev.BusId) to WSL ($targetDistro)..."
        try {
            usbipd attach --wsl $targetDistro --busid $usbDev.BusId 2>$null
            Write-Success "USB device forwarded to WSL."
        } catch {
            Write-Warn "usbipd attach returned notification (drive may already be forwarded)."
        }
    }

    Write-Info "Mounting Linux partition inside WSL..."
    Start-Sleep -Seconds 2
    $modeFlag = if ($Mode -eq "rw") { "--rw" } else { "--ro" }
    $mntArg = if ($MountPoint) { "'$MountPoint'" } else { "''" }
    wsl.exe -d $targetDistro -e bash -c "wsl-linux-mount mount $mntArg $modeFlag"

    if ($Explore) {
        $targetMnt = if ($MountPoint) { $MountPoint } else { "/mnt/sandisk_arch" }
        $uncPath = "\\wsl.localhost\$targetDistro$($targetMnt.Replace('/', '\'))"
        if (Test-Path $uncPath) {
            Write-Info "Opening Windows File Explorer at $uncPath..."
            explorer.exe $uncPath
        }
    }
}

function Invoke-Unmount {
    $targetDistro = Get-WslDistro
    $mntArg = if ($MountPoint) { "'$MountPoint'" } else { "''" }
    Write-Info "Unmounting inside WSL ($targetDistro)..."
    wsl.exe -d $targetDistro -e bash -c "wsl-linux-mount unmount $mntArg"

    if ($BusId) {
        Write-Info "Detaching USB BusId $BusId from WSL..."
        usbipd detach --busid $BusId 2>$null
        Write-Success "Detached USB device."
    }
}

function Show-Status {
    $targetDistro = Get-WslDistro
    wsl.exe -d $targetDistro -e bash -c "wsl-linux-mount status"
}

function Show-List {
    $targetDistro = Get-WslDistro
    wsl.exe -d $targetDistro -e bash -c "wsl-linux-mount list"
}

# --- Main Entry Point ---
Show-Banner

switch ($Command) {
    "mount"   { Invoke-Mount }
    "unmount" { Invoke-Unmount }
    "umount"  { Invoke-Unmount }
    "status"  { Show-Status }
    "list"    { Show-List }
    default {
        Write-Host 'Usage: .\wsl-linux-mount.ps1 [command] [-BusId ID] [-MountPoint PATH] [-Mode ro|rw] [-Explore]'
        Write-Host 'Commands: mount, unmount, status, list, help'
    }
}
