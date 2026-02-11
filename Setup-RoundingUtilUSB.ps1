<#
    .SYNOPSIS
    SFU-TOOLS MASTER INSTALLER (External Boot File Edition)
    - Copies boot.py from source (RAM Fix)
    - Copies code.py from source
    - Installs Firmware & Libraries
    - Copies ROOT folder structure correctly
#>
param (
    [string]$CodeFile     = "code.py",
    [string]$BootFile     = "boot.py",
    [string]$SourceFolder = "ROOT",
    [string]$FirmwareDir  = "firmware",
    [string]$NukeFile     = "flash_nuke.uf2"
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSScriptRoot
$RootPath   = Join-Path $ScriptPath $SourceFolder
$FirmwarePath = Join-Path $ScriptPath $FirmwareDir
$NukePath   = Join-Path $FirmwarePath $NukeFile
$BootPath   = Join-Path $ScriptPath $BootFile

# --- PROGRESS BAR COPY FUNCTION ---
function Copy-WithProgress {
    param([string]$Source, [string]$Destination, [string]$Activity = "Copying Files")
    
    if (Test-Path -LiteralPath $Source -PathType Container) {
        $files = Get-ChildItem -Path $Source -Recurse -File
        $totalFiles = $files.Count
        $counter = 0
        
        foreach ($file in $files) {
            $counter++
            $relativePath = $file.FullName.Substring($Source.Length)
            if ($relativePath.StartsWith("\")) { $relativePath = $relativePath.Substring(1) }
            
            $destPath = Join-Path $Destination $relativePath
            $destDir = Split-Path $destPath -Parent
            
            if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
            
            $percent = [math]::Round(($counter / $totalFiles) * 100)
            Write-Progress -Activity $Activity -Status "Copying $relativePath" -PercentComplete $percent
            Copy-Item -Path $file.FullName -Destination $destPath -Force
        }
    } else {
        Write-Progress -Activity $Activity -Status "Copying $(Split-Path $Source -Leaf)" -PercentComplete 0
        Copy-Item -Path $Source -Destination $Destination -Force
        Write-Progress -Activity $Activity -Status "Done" -PercentComplete 100
    }
    Write-Progress -Activity $Activity -Completed
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
if (-not (Test-Path $BootPath)) { Write-Error "File 'boot.py' is missing! Please create it."; exit }
if (-not (Test-Path $RootPath)) { Write-Error "Folder 'ROOT' is missing!"; exit }

Write-Host " Scanning firmware..." -ForegroundColor Yellow

$allZips = Get-ChildItem -Path $FirmwarePath -Filter "*.zip"
$allUf2s = Get-ChildItem -Path $FirmwarePath -Filter "*.uf2"
$validPairs = @{}

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
        if ($validPairs.ContainsKey($ver)) { $validPairs[$ver]["Uf2"] = $uf2 }
    }
}

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
    Copy-WithProgress -Source $selected["Uf2"].FullName -Destination $dest -Activity "Flashing Firmware"
    
    Write-Host " > Rebooting..."
    for ($i=0; $i -lt 30; $i++) { 
        Start-Sleep 1
        if ($c = Get-Volume | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }) { 
            $targetDrive = $c; break 
        }
    }
    if (-not $targetDrive) { Write-Error "Reboot Failed."; exit }
    $dest = "$($targetDrive.DriveLetter):"
}

# 2. LIBRARIES
if ($installType -eq "FULL" -or $installType -eq "UPDATE") {
    Write-Host "`n [STEP 2] INSTALLING LIBRARIES" -ForegroundColor Cyan
    $libDir = Join-Path $dest "lib"
    if (Test-Path $libDir) { Remove-Item $libDir -Recurse -Force }
    New-Item -Path $libDir -ItemType Directory | Out-Null
    
    $temp = Join-Path $env:TEMP "sfu_install_$(Get-Random)"
    Expand-Archive -Path $selected["Zip"].FullName -DestinationPath $temp -Force
    $libSrc = Get-ChildItem -Path $temp -Recurse -Directory | Where-Object { $_.Name -eq "adafruit_hid" } | Select-Object -First 1
    
    if ($libSrc) {
        Write-Host " [EXEC] Installing HID Library..." -ForegroundColor DarkGray
        Copy-WithProgress -Source $libSrc.FullName -Destination $libDir -Activity "Installing Libraries"
    }
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}

# 3. PAYLOAD & BOOT CONFIG
Write-Host "`n [STEP 3] SYNCING PAYLOAD" -ForegroundColor Cyan

# A. COPY BOOT.PY (Source -> Dest)
Write-Host " [EXEC] Installing boot.py..." -ForegroundColor DarkGray
Copy-WithProgress -Source $BootPath -Destination (Join-Path $dest "boot.py") -Activity "Installing Boot Script"

# B. COPY CODE.PY
Write-Host " [EXEC] Updating code.py..." -ForegroundColor DarkGray
Copy-WithProgress -Source (Join-Path $ScriptPath $CodeFile) -Destination (Join-Path $dest "code.py") -Activity "Updating Main Script"

# C. COPY ROOT FOLDER (Corrected Logic)
# If we run 'Copy-Item ROOT D:\', it creates D:\ROOT.
# We ensure the old one is gone first.
$targetRoot = Join-Path $dest "ROOT"
if (Test-Path $targetRoot) { 
    Write-Host " [EXEC] Cleaning old ROOT..." -ForegroundColor DarkGray
    Remove-Item $targetRoot -Recurse -Force
}

Write-Host " [EXEC] Installing ROOT folder..." -ForegroundColor DarkGray
# Copying the FOLDER $RootPath to the DRIVE ROOT $dest will result in D:\ROOT
Copy-Item -Path $RootPath -Destination $dest -Recurse -Force

Write-Host "`n [SUCCESS] Device Ready." -ForegroundColor Green
Write-Host " Unplug and plug in to test."
Start-Sleep 2