<#
    .SYNOPSIS
    TA Rounding Util USB Setup (Wizard Mode)
    Step 1: Configures the RP2040 Key.
    Step 2: Configures the Main USB Storage.
#>
param (
    [string]$FirmwareFile = "adafruit-circuitpython-vcc_gnd_yd_rp2040-en_US-10.0.3.uf2",
    [string]$BundleZip    = "adafruit-circuitpython-bundle-9.x-mpy-20260129.zip",
    [string]$CodeFile     = "code.py",
    [string]$SourceFolder = "ROOT",
    [string]$TargetLabel  = "TA-RoundingUtilsUSB"
)

$ErrorActionPreference = "Stop"

function Show-Header {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor DarkBlue
    Write-Host "        TA ROUNDING UTIL USB SETUP        " -ForegroundColor Cyan -BackgroundColor DarkBlue
    Write-Host "==========================================" -ForegroundColor DarkBlue
    Write-Host ""
}

function Pause-Step {
    param($Message)
    Write-Host ""
    Write-Host " $Message" -ForegroundColor Yellow
    Read-Host " Press [ENTER] to continue..."
}

# --- PRE-FLIGHT CHECK ---
Show-Header
Write-Host " Checking files..." -ForegroundColor DarkGray
if (-not (Test-Path $FirmwareFile)) { Write-Error "Missing Firmware: $FirmwareFile"; exit }
if (-not (Test-Path $BundleZip))    { Write-Error "Missing Zip: $BundleZip"; exit }
if (-not (Test-Path $CodeFile))     { Write-Error "Missing Script: $CodeFile"; exit }
if (-not (Test-Path $SourceFolder)) { Write-Error "Missing Folder: $SourceFolder"; exit }
Write-Host " Files OK." -ForegroundColor Green

# ==========================================
# STEP 1: INSTALL KEY (RP2040)
# ==========================================
Write-Host "`n [STEP 1/2] CONFIGURE LAUNCH KEY (RP2040)" -ForegroundColor Cyan
Write-Host " ---------------------------------------" -ForegroundColor DarkGray
Write-Host " 1. Unplug the board."
Write-Host " 2. Hold the BOOT button."
Write-Host " 3. Plug it into USB."
Write-Host " 4. Release BOOT button."

Pause-Step "Ready to flash?"

# 1. Detect & Flash
Write-Host " > Searching for board..." -NoNewline
$bootloader = Get-Volume | Where-Object { $_.FileSystemLabel -eq "RPI-RP2" }
$circuitpy  = Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }

if ($bootloader) {
    Write-Host " Found Bootloader ($($bootloader.DriveLetter):)" -ForegroundColor Green
    Write-Host " > Flashing Firmware..." -NoNewline
    Copy-Item $FirmwareFile -Destination "$($bootloader.DriveLetter):"
    Write-Host " Done."
    
    Write-Host " > Waiting for Reboot..." -NoNewline
    for ($i=0; $i -lt 30; $i++) { 
        Start-Sleep 1
        if (Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }) { break }
        Write-Host "." -NoNewline 
    }
    Write-Host ""
    $circuitpy = Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }
} elseif ($circuitpy) {
    Write-Host " Found existing CIRCUITPY ($($circuitpy.DriveLetter):)" -ForegroundColor Green
} else {
    Write-Warning " Board not found. Skipping Key setup."
}

if ($circuitpy) {
    $dest = "$($circuitpy.DriveLetter):"
    
    # 2. Install Libs
    Write-Host " > Installing Drivers (HID)..."
    $temp = Join-Path $env:TEMP "ta_install_$(Get-Random)"
    Expand-Archive -Path $BundleZip -DestinationPath $temp -Force
    $libSrc = Get-ChildItem -Path $temp -Recurse -Directory | Where-Object { $_.Name -eq "adafruit_hid" } | Select-Object -First 1
    
    if ($libSrc) {
        $libDest = Join-Path $dest "lib"
        if (-not (Test-Path $libDest)) { New-Item -ItemType Directory -Path $libDest | Out-Null }
        Copy-Item -Path $libSrc.FullName -Destination $libDest -Recurse -Force
    }
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue

    # 3. Install Code
    Write-Host " > Uploading Payload..."
    Copy-Item -Path $CodeFile -Destination (Join-Path $dest "code.py") -Force
    Write-Host " [KEY SETUP COMPLETE]" -ForegroundColor Green
}

# ==========================================
# STEP 2: INSTALL STORAGE (MAIN USB)
# ==========================================
Write-Host "`n [STEP 2/2] CONFIGURE MAIN STORAGE" -ForegroundColor Cyan
Write-Host " ---------------------------------------" -ForegroundColor DarkGray
Write-Host " Plug in your large USB Flash Drive (SanDisk, Kingston, etc)."

Pause-Step "Ready to configure storage?"

# 1. List Drives (Filter out the Key)
$drives = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -and $_.FileSystemLabel -ne "CIRCUITPY" -and $_.FileSystemLabel -ne "RPI-RP2" }

if (-not $drives) {
    Write-Warning " No generic USB drives found. Setup complete."
    exit
}

Write-Host " Select target drive:"
$i = 1
foreach ($d in $drives) {
    $size = [math]::Round($d.SizeRemaining/1GB, 1)
    Write-Host " [$i] ($($d.DriveLetter):) $($d.FileSystemLabel) [Free: $size GB]"
    $i++
}

$sel = Read-Host " Enter Number"
if ($sel -lt 1 -or $sel -gt $drives.Count) { 
    Write-Error " Invalid selection. Exiting."
    exit 
}

$target = $drives[$sel-1]
$dLetter = "$($target.DriveLetter):"

# 2. Install
Write-Host " > Renaming drive to '$TargetLabel'..."
Set-Volume -DriveLetter $target.DriveLetter -NewFileSystemLabel $TargetLabel

Write-Host " > Copying ROOT files..."
Copy-Item -Path "$SourceFolder\*" -Destination $dLetter -Recurse -Force

Write-Host " [STORAGE SETUP COMPLETE]" -ForegroundColor Green
Write-Host "`n==========================================" -ForegroundColor DarkBlue
Write-Host "       ALL SYSTEMS OPERATIONAL            " -ForegroundColor Cyan -BackgroundColor DarkBlue
Write-Host "==========================================" -ForegroundColor DarkBlue
Write-Host " 1. Remove both devices."
Write-Host " 2. To use: Plug in Storage first, then Key."
Start-Sleep 2