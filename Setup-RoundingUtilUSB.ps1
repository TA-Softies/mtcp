<#
    .SYNOPSIS
    SFU-TOOLS MASTER INSTALLER (Memory-Safe Edition)
    - Auto-Detects Firmware/Drivers
    - CLEAN INSTALLS Libraries (Deletes old junk to fix Memory Errors)
    - Supports Factory Reset (Nuke)
#>
param (
    [string]$CodeFile     = "code.py",
    [string]$SourceFolder = "ROOT",
    [string]$FirmwareDir  = "firmware",
    [string]$NukeFile     = "flash_nuke.uf2"
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSScriptRoot
$RootPath   = Join-Path $ScriptPath $SourceFolder
$FirmwarePath = Join-Path $ScriptPath $FirmwareDir
$NukePath   = Join-Path $FirmwarePath $NukeFile

# --- HELPER: LOGGING ---
function Exec-Cmd {
    param([string]$Message, [scriptblock]$Action)
    Write-Host " [EXEC] $Message" -ForegroundColor DarkGray
    & $Action
}

function Copy-WithProgress {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Activity = "Copying Files"
    )
    
    if (Test-Path -LiteralPath $Source -PathType Container) {
        # Directory copy with progress
        $files = Get-ChildItem -Path $Source -Recurse -File
        $totalFiles = $files.Count
        $counter = 0
        
        foreach ($file in $files) {
            $counter++
            $relativePath = $file.FullName.Substring($Source.Length)
            $destPath = Join-Path $Destination $relativePath
            $destDir = Split-Path $destPath -Parent
            
            if (-not (Test-Path $destDir)) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }
            
            $percentComplete = [math]::Round(($counter / $totalFiles) * 100)
            Write-Progress -Activity $Activity -Status "$counter of $totalFiles files" -CurrentOperation $file.Name -PercentComplete $percentComplete
            
            Copy-Item -Path $file.FullName -Destination $destPath -Force
        }
        Write-Progress -Activity $Activity -Completed
    } else {
        # Single file copy with progress
        $fileSize = (Get-Item $Source).Length
        Write-Progress -Activity $Activity -Status "Copying $(Split-Path $Source -Leaf)" -PercentComplete 0
        Copy-Item -Path $Source -Destination $Destination -Force
        Write-Progress -Activity $Activity -Status "Copying $(Split-Path $Source -Leaf)" -PercentComplete 100
        Start-Sleep -Milliseconds 500
        Write-Progress -Activity $Activity -Completed
    }
}

function Show-Header {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor DarkBlue
    Write-Host "       SFU-TOOLS MASTER SETUP             " -ForegroundColor Cyan -BackgroundColor DarkBlue
    Write-Host "==========================================" -ForegroundColor DarkBlue
}

Show-Header

# ==========================================
# PHASE 1: SCANNING
# ==========================================
if (-not (Test-Path $FirmwarePath)) { Write-Error "Firmware folder missing!"; exit }

Write-Host " Scanning firmware..." -ForegroundColor Yellow
$allZips = Get-ChildItem -Path $FirmwarePath -Filter "*.zip"
$allUf2s = Get-ChildItem -Path $FirmwarePath -Filter "*.uf2"
$validPairs = @{}

# Pair Logic
foreach ($zip in $allZips) {
    if ($zip.Name -match "bundle-(\d+)\.x") {
        $ver = [int]$matches[1]
        if (-not $validPairs.ContainsKey($ver)) { $validPairs[$ver] = @{} }
        $validPairs[$ver]["Zip"] = $zip
    }
}
foreach ($uf2 in $allUf2s) {
    if ($uf2.Name -notmatch "nuke" -and $uf2.Name -match "[-_](\d+)\.\d+\.\d+") {
        $ver = [int]$matches[1]
        if ($validPairs.ContainsKey($ver)) {
            $validPairs[$ver]["Uf2"] = $uf2 # Simple take-last logic
        }
    }
}

# Select Best Pair
$sortedVersions = $validPairs.Keys | Sort-Object -Descending
$selected = $null
foreach ($v in $sortedVersions) {
    if ($validPairs[$v].ContainsKey("Zip") -and $validPairs[$v].ContainsKey("Uf2")) {
        $selected = $validPairs[$v]
        break
    }
}

if (-not $selected) { Write-Error "No matching Firmware+Driver pairs found."; exit }
Write-Host " [LOADED] Version: v$($sortedVersions[0]).x" -ForegroundColor Green

# ==========================================
# PHASE 2: MENU
# ==========================================
Write-Host "`n SELECT OPERATION:" -ForegroundColor Yellow
Write-Host " [1] SMART INSTALL (Auto-Detect)"
Write-Host " [2] FORCE NUKE (Factory Reset)"
Write-Host " [3] UPDATE CODE & PAYLOAD (Skip Firmware)"
Write-Host " [Q] QUIT"

$menuChoice = Read-Host " > Selection"
if ($menuChoice -eq "Q") { exit }

# ==========================================
# PHASE 3: EXECUTION
# ==========================================

# --- MODE: NUKE ---
if ($menuChoice -eq "2") {
    Write-Host "`n [MODE] FORCE FACTORY RESET" -ForegroundColor Red
    $bootloader = Get-Volume | Where-Object { $_.FileSystemLabel -eq "RPI-RP2" }
    
    if (-not $bootloader) {
        Write-Host " Please switch device to BOOTLOADER mode (Hold BOOT -> Plug in)."
        while (-not $bootloader) {
            $bootloader = Get-Volume | Where-Object { $_.FileSystemLabel -eq "RPI-RP2" }
            Start-Sleep 1
        }
    }
    
    Write-Host " [EXEC] Nuking Device..." -ForegroundColor DarkGray
    Copy-WithProgress -Source $NukePath -Destination "$($bootloader.DriveLetter):" -Activity "Flashing Nuke Firmware"
    Write-Host " > Waiting for reset..."
    Start-Sleep 5
    
    while (-not (Get-Volume | Where-Object { $_.FileSystemLabel -eq "RPI-RP2" })) { Start-Sleep 1 }
    $targetDrive = Get-Volume | Where-Object { $_.FileSystemLabel -eq "RPI-RP2" }
    $installType = "FULL"
}
# --- MODE: SMART ---
elseif ($menuChoice -eq "1") {
    Write-Host " > Waiting for device..."
    while ($true) {
        if ($b = Get-Volume | Where-Object { $_.FileSystemLabel -eq "RPI-RP2" }) { 
            $targetDrive = $b; $installType = "FULL"; break 
        }
        if ($c = Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }) {
            $targetDrive = $c; $installType = "UPDATE"; break
        }
        Start-Sleep 1
    }
}
# --- MODE: UPDATE ---
elseif ($menuChoice -eq "3") {
    $targetDrive = Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }
    if (-not $targetDrive) { Write-Error "Device not found."; exit }
    $installType = "UPDATE"
}

# ==========================================
# PHASE 4: INSTALLATION
# ==========================================
$dest = "$($targetDrive.DriveLetter):"

# 1. FIRMWARE
if ($installType -eq "FULL") {
    Write-Host "`n [STEP 1] FLASHING FIRMWARE" -ForegroundColor Cyan
    Write-Host " [EXEC] Copying Firmware..." -ForegroundColor DarkGray
    Copy-WithProgress -Source $selected["Uf2"].FullName -Destination $dest -Activity "Flashing CircuitPython Firmware"
    
    Write-Host " > Rebooting..."
    for ($i=0; $i -lt 30; $i++) { 
        Start-Sleep 1
        if ($c = Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }) { 
            $targetDrive = $c; break 
        }
    }
    $dest = "$($targetDrive.DriveLetter):"
}

# 2. LIBRARIES (CRITICAL FIX FOR MEMORY ERROR)
if ($installType -eq "FULL" -or $installType -eq "UPDATE") {
    Write-Host "`n [STEP 2] INSTALLING LIBRARIES" -ForegroundColor Cyan
    
    # Force Clean Old Libs
    $libDir = Join-Path $dest "lib"
    if (Test-Path $libDir) {
        Exec-Cmd "Deleting old 'lib' folder (Clean Install)" { Remove-Item $libDir -Recurse -Force }
    }
    New-Item -Path $libDir -ItemType Directory | Out-Null
    
    # Extract & Install New Libs
    $temp = Join-Path $env:TEMP "sfu_install_$(Get-Random)"
    Write-Host " [EXEC] Extracting Bundle..." -ForegroundColor DarkGray
    Write-Progress -Activity "Extracting Library Bundle" -Status "Extracting archive..." -PercentComplete 0
    Expand-Archive -Path $selected["Zip"].FullName -DestinationPath $temp -Force
    Write-Progress -Activity "Extracting Library Bundle" -Status "Complete" -PercentComplete 100
    Start-Sleep -Milliseconds 500
    Write-Progress -Activity "Extracting Library Bundle" -Completed
    
    $libSrc = Get-ChildItem -Path $temp -Recurse -Directory | Where-Object { $_.Name -eq "adafruit_hid" } | Select-Object -First 1
    
    if ($libSrc) {
        Write-Host " [EXEC] Installing adafruit_hid (MPY version)" -ForegroundColor DarkGray
        Copy-WithProgress -Source $libSrc.FullName -Destination $libDir -Activity "Installing HID Library"
    }
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}

# 3. PAYLOAD
Write-Host "`n [STEP 3] SYNCING PAYLOAD" -ForegroundColor Cyan
Write-Host " [EXEC] Updating code.py" -ForegroundColor DarkGray
Copy-WithProgress -Source (Join-Path $ScriptPath $CodeFile) -Destination (Join-Path $dest "code.py") -Activity "Updating Main Script"

$targetRoot = Join-Path $dest "ROOT"
if (Test-Path $targetRoot) { 
    Write-Host " [EXEC] Cleaning old ROOT" -ForegroundColor DarkGray
    Write-Progress -Activity "Cleaning Old Files" -Status "Removing old ROOT folder" -PercentComplete 50
    Remove-Item $targetRoot -Recurse -Force
    Write-Progress -Activity "Cleaning Old Files" -Completed
}
Write-Host " [EXEC] Copying new ROOT" -ForegroundColor DarkGray
Copy-WithProgress -Source $RootPath -Destination $dest -Activity "Installing ROOT Folder"

Write-Host "`n [SUCCESS] Device Ready." -ForegroundColor Green
Start-Sleep 2
pause