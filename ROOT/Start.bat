<#
    .SYNOPSIS
    SFU-TOOLS SINGLE DEVICE INSTALLER
    Structure on Device will be:
      D:\code.py
      D:\lib\
      D:\ROOT\Start.bat
#>
param (
    [string]$FirmwareFile = "adafruit-circuitpython-vcc_gnd_yd_rp2040-en_US-10.0.3.uf2",
    [string]$BundleZip    = "adafruit-circuitpython-bundle-9.x-mpy-20260129.zip",
    [string]$CodeFile     = "code.py",
    [string]$SourceFolder = "ROOT"
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSScriptRoot
$RootPath   = Join-Path $ScriptPath $SourceFolder

function Show-Header {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor DarkBlue
    Write-Host "       SFU-TOOLS DEVICE SETUP             " -ForegroundColor Cyan -BackgroundColor DarkBlue
    Write-Host "==========================================" -ForegroundColor DarkBlue
}

Show-Header

# --- STEP 1: SIZE CHECK ---
if (-not (Test-Path $RootPath)) { Write-Error "ROOT folder not found!"; exit }

Write-Host " Checking Payload Size..." -NoNewline
$measure = Get-ChildItem -Path $RootPath -Recurse | Measure-Object -Property Length -Sum
$sizeMB = [math]::Round($measure.Sum / 1MB, 2)

if ($sizeMB -gt 10) {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host "`n [CRITICAL ERROR] Payload is too large!" -ForegroundColor Red
    Write-Host " Size: $sizeMB MB (Limit: 10 MB)" -ForegroundColor Yellow
    exit
} else {
    Write-Host " [OK] ($sizeMB MB)" -ForegroundColor Green
}

# --- STEP 2: MODE SELECTION ---
Write-Host "`n Choose Installation Mode:" -ForegroundColor Yellow
Write-Host " [1] FULL INSTALL (Factory Reset)"
Write-Host "     - Erasure + Firmware + Drivers + Tools"
Write-Host " [2] UPDATE ONLY (Fast)"
Write-Host "     - Updates code.py + ROOT folder only"

$choice = Read-Host "`n Select Option (1/2)"

if ($choice -ne "1" -and $choice -ne "2") { Write-Warning "Invalid choice."; exit }

# --- STEP 3: EXECUTION ---

# [MODE 1] FIRMWARE
if ($choice -eq "1") {
    Write-Host "`n [PHASE 1] FIRMWARE" -ForegroundColor Cyan
    Write-Host " Please hold BOOT button, plug in device, then release."
    Read-Host " Press ENTER when ready..."

    $bootloader = Get-Volume | Where-Object { $_.FileSystemLabel -eq "RPI-RP2" }
    
    if (-not $bootloader) { 
        Write-Error "Bootloader (RPI-RP2) not found. Did you hold the button?" 
        exit
    }

    Write-Host " > Flashing Firmware..." -NoNewline
    Copy-Item (Join-Path $ScriptPath $FirmwareFile) -Destination "$($bootloader.DriveLetter):"
    Write-Host " Done." -ForegroundColor Green
    
    Write-Host " > Waiting for Reboot..." -NoNewline
    for ($i=0; $i -lt 30; $i++) { 
        Start-Sleep 1
        if (Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }) { break }
        Write-Host "." -NoNewline 
    }
    Write-Host ""
}

# [COMMON] FIND CIRCUITPY
$circuitpy = Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }
if (-not $circuitpy) { Write-Error "Device 'CIRCUITPY' not found! Plug it in."; exit }
$dest = "$($circuitpy.DriveLetter):"

# [MODE 1] LIB INSTALLATION
if ($choice -eq "1") {
    Write-Host "`n [PHASE 2] DRIVERS" -ForegroundColor Cyan
    Write-Host " > Extracting HID Libs..."
    $temp = Join-Path $env:TEMP "sfu_install_$(Get-Random)"
    Expand-Archive -Path (Join-Path $ScriptPath $BundleZip) -DestinationPath $temp -Force
    $libSrc = Get-ChildItem -Path $temp -Recurse -Directory | Where-Object { $_.Name -eq "adafruit_hid" } | Select-Object -First 1
    
    if ($libSrc) {
        $libDest = Join-Path $dest "lib"
        if (-not (Test-Path $libDest)) { New-Item -ItemType Directory -Path $libDest | Out-Null }
        Copy-Item -Path $libSrc.FullName -Destination $libDest -Recurse -Force
        Write-Host " > Drivers Installed." -ForegroundColor Green
    }
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}

# [COMMON] PAYLOAD UPDATE
Write-Host "`n [PHASE 3] PAYLOAD UPDATE" -ForegroundColor Cyan

# Copy Code.py
Write-Host " > Updating code.py..."
Copy-Item -Path (Join-Path $ScriptPath $CodeFile) -Destination (Join-Path $dest "code.py") -Force

# Copy ROOT Folder (As a folder)
Write-Host " > Syncing ROOT folder..."
# Check if ROOT already exists on device to avoid merging weirdness, delete it first
if (Test-Path (Join-Path $dest "ROOT")) {
    Remove-Item (Join-Path $dest "ROOT") -Recurse -Force
}
Copy-Item -Path $RootPath -Destination $dest -Recurse -Force

Write-Host "`n==========================================" -ForegroundColor DarkBlue
Write-Host "       INSTALLATION COMPLETE              " -ForegroundColor Cyan -BackgroundColor DarkBlue
Write-Host "==========================================" -ForegroundColor DarkBlue
Write-Host " Device: $dest"
Write-Host " Structure: $dest\ROOT\Start.bat"
Start-Sleep 2