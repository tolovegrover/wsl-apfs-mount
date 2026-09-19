<#
.SYNOPSIS
    wsl-apfs-mount.ps1 - Read-Only Apple APFS Drive Mounter for WSL2
    
.DESCRIPTION
    Automates detecting, attaching (via usbipd-win), and mounting macOS APFS
    drives directly into WSL2 in strict read-only mode.

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
    [ValidateSet("mount", "unmount", "umount", "list", "status", "install-deps", "help")]
    [string]$Command = "mount",

    [Parameter()]
    [string]$BusId,

    [Parameter()]
    [string]$MountPoint = "/mnt/apfs",

    [Parameter()]
    [string]$Distro,

    [Parameter()]
    [switch]$Explore
)

$ErrorActionPreference = "Stop"
$Version = "1.1.0"

function Show-Banner {
    Write-Host @"
 _       ______  __       ___    ____  ______ _____ 
| |     / / __ \/ /      /   |  / __ \/ ____// ___/ 
| | /| / / /_/ / /      / /| | / /_/ / /_    \__ \  
| |/ |/ /\__, / /___   / ___ |/ ____/ __/   ___/ /  
|__/|__//____/_____/  /_/  |_/_/   /_/     /____/   
                                 MOUNT (WSL2 / PowerShell)
"@ -ForegroundColor Cyan

    Write-Host "Version $Version | Native Windows PowerShell Launcher for WSL2" -ForegroundColor DarkGray
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

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-ApfsBusId {
    Write-Info "Scanning Windows disks for Apple APFS GUID ({7c3457ef-0000-11aa-aa11-00306543ecac})..."
    
    $apfsDisk = $null
    try {
        $disks = Get-Disk -ErrorAction SilentlyContinue
        foreach ($d in $disks) {
            $parts = Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue
            foreach ($p in $parts) {
                if ($p.GptType -eq '{7c3457ef-0000-11aa-aa11-00306543ecac}') {
                    $diskNum = $d.Number
                    $sizeGb = [math]::Round($d.Size / 1GB, 1)
                    Write-Success "Found APFS drive: $($d.FriendlyName) (Disk Number: $diskNum, Size: $sizeGb GB)"
                    break
                }
            }
            if ($apfsDisk) { break }
        }
    } catch {}

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
            if ($devName -match 'Mass Storage' -or ($apfsDisk -and $devName -match ($apfsDisk.FriendlyName.Split()[0]))) {
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

    # Step 1: Resolve USB Device
    $usbDev = $null
    if ($BusId) {
        $usbDev = [PSCustomObject]@{ BusId = $BusId; State = "Unknown"; Name = "Manual" }
    } else {
        $usbDev = Find-ApfsBusId
    }

    if ($usbDev) {
        Write-Info "USB Device: $($usbDev.BusId) ($($usbDev.Name))"

        # Check if sharing / bind is required
        if ($usbDev.State -eq "Not shared") {
            Write-Info "Device is not yet shared in usbipd. Requesting Administrator elevation to bind..."
            $bindCmd = "usbipd bind --busid $($usbDev.BusId)"
            Start-Process powershell -ArgumentList "-NoProfile -Command `"$bindCmd`"" -Verb RunAs -Wait
            Write-Success "Device bound successfully."
        }

        # Attach to WSL if not already attached
        Write-Info "Attaching $($usbDev.BusId) to WSL ($targetDistro)..."
        try {
            usbipd attach --wsl $targetDistro --busid $usbDev.BusId 2>$null
            Write-Success "USB device forwarded to WSL."
        } catch {
            Write-Warn "usbipd attach returned notification (drive may already be forwarded)."
        }
    } else {
        Write-Info "No unattached APFS USB devices found. Checking existing WSL block devices..."
    }

    # Step 2: Trigger read-only mount inside WSL
    Write-Info "Executing read-only mount inside WSL..."
    Start-Sleep -Seconds 2
    wsl.exe -d $targetDistro -e bash -c "wsl-apfs-mount mount '' '$MountPoint'"

    # Step 3: Report paths and optionally open Explorer
    $uncPath = "\\wsl.localhost\$targetDistro$($MountPoint.Replace('/', '\'))\root"
    Write-Host ""
    Write-Host "Access Paths:" -ForegroundColor Cyan
    Write-Host "  WSL2 Terminal:    $MountPoint/root" -ForegroundColor Green
    Write-Host "  Windows Explorer: $uncPath" -ForegroundColor Green
    Write-Host ""

    if ($Explore -or (Test-Path $uncPath)) {
        if ($Explore) {
            Write-Info "Opening Windows File Explorer at $uncPath..."
            explorer.exe $uncPath
        }
    }
}

function Invoke-Unmount {
    $targetDistro = Get-WslDistro
    Write-Info "Unmounting $MountPoint inside WSL ($targetDistro)..."
    wsl.exe -d $targetDistro -e bash -c "wsl-apfs-mount unmount '$MountPoint'"

    if ($BusId) {
        Write-Info "Detaching USB BusId $BusId from WSL..."
        usbipd detach --busid $BusId 2>$null
        Write-Success "Detached USB device."
    }
}

function Show-Status {
    $targetDistro = Get-WslDistro
    wsl.exe -d $targetDistro -e bash -c "wsl-apfs-mount status"
}

function Show-List {
    $targetDistro = Get-WslDistro
    wsl.exe -d $targetDistro -e bash -c "wsl-apfs-mount list"
}

# --- Main Entry Point ---
Show-Banner

switch ($Command) {
    "mount"        { Invoke-Mount }
    "unmount"      { Invoke-Unmount }
    "umount"       { Invoke-Unmount }
    "status"       { Show-Status }
    "list"         { Show-List }
    "install-deps" {
        $targetDistro = Get-WslDistro
        wsl.exe -d $targetDistro -e bash -c "wsl-apfs-mount install-deps"
    }
    default {
        Write-Host 'Usage: .\wsl-apfs-mount.ps1 [command] [-BusId ID] [-MountPoint PATH] [-Explore]'
        Write-Host 'Commands: mount, unmount, status, list, install-deps, help'
    }
}
