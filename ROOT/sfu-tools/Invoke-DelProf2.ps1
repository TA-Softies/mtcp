<#
    .SYNOPSIS
    Wrapper script for DelProf2 - Remove inactive user profiles
    
    .DESCRIPTION
    Downloads DelProf2 if not available and removes domain user profiles
    Filters profiles with id:tp* and excludes local accounts: student, localadmin
#>

# Requires Run as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges."
    Start-Sleep 2
    Exit 1
}

# Configuration
$DelProf2Url = "https://helgeklein.com/files/DelProf2/current/Delprof2%201.6.0.zip"
$ScriptRoot = Split-Path -Parent $PSCommandPath
$BinDir = Join-Path $ScriptRoot "bin"
$DelProf2Dir = Join-Path $BinDir "DelProf2"
$DelProf2Exe = Join-Path $DelProf2Dir "Delprof2 1.6.0\DelProf2.exe"
$TempZip = Join-Path $env:TEMP "DelProf2.zip"
$DFPath = "C:\Windows\SysWOW64\DFC.exe"

# Check Deep Freeze Status
if (Test-Path $DFPath) {
    try {
        $result = & $DFPath /ISFROZEN
        $isFrozen = $LASTEXITCODE -eq 1
        
        if ($isFrozen) {
            Write-Host "`n========================================" -ForegroundColor Red
            Write-Host " WARNING: SYSTEM IS FROZEN" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "[WARNING] This computer is currently frozen by Deep Freeze." -ForegroundColor Yellow
            Write-Host "[WARNING] Deleting user profiles on a frozen system will:" -ForegroundColor Yellow
            Write-Host "  - Only temporarily remove profiles until next reboot" -ForegroundColor Gray
            Write-Host "  - Profiles will be restored after restart" -ForegroundColor Gray
            Write-Host ""
            Write-Host "[RECOMMENDATION] Please thaw the system first using the [D] key" -ForegroundColor Cyan
            Write-Host "                 from the main menu for permanent changes." -ForegroundColor Cyan
            Write-Host ""
            
            $confirm = Read-Host "Do you want to continue anyway? Type 'YES' to proceed"
            
            if ($confirm -ne "YES") {
                Write-Host "`n[INFO] Operation cancelled. Please thaw the system first." -ForegroundColor Yellow
                Start-Sleep 2
                Exit 0
            }
            Write-Host "`n[INFO] Proceeding on frozen system (changes will be temporary)..." -ForegroundColor Yellow
            Start-Sleep 1
        }
    } catch {
        # If we can't check DF status, just continue
    }
}

# Ensure bin directory exists
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

# Function to download and extract DelProf2
function Install-DelProf2 {
    Write-Host "`n[INFO] DelProf2 not found. Downloading..." -ForegroundColor Yellow
    
    try {
        # Download
        Write-Host "[INFO] Downloading from: $DelProf2Url" -ForegroundColor Cyan
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DelProf2Url -OutFile $TempZip -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        # Extract
        Write-Host "[INFO] Extracting to: $DelProf2Dir" -ForegroundColor Cyan
        if (Test-Path $DelProf2Dir) {
            Remove-Item -Path $DelProf2Dir -Recurse -Force
        }
        
        # Extract using .NET (built-in, no external dependencies)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $DelProf2Dir)
        
        # Clean up
        Remove-Item -Path $TempZip -Force
        
        Write-Host "[SUCCESS] DelProf2 downloaded and extracted successfully!`n" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to download/extract DelProf2: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[INFO] Please download manually from: $DelProf2Url" -ForegroundColor Yellow
        Start-Sleep 3
        return $false
    }
}

# Check if DelProf2 exists, if not download it
if (-not (Test-Path $DelProf2Exe)) {
    $installed = Install-DelProf2
    if (-not $installed) {
        Exit 1
    }
}

# Verify DelProf2 exists after installation attempt
if (-not (Test-Path $DelProf2Exe)) {
    Write-Host "[ERROR] DelProf2 executable not found at: $DelProf2Exe" -ForegroundColor Red
    Start-Sleep 2
    Exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " USER PROFILE CLEANUP TOOL" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get all user profiles to preview what will be deleted
Write-Host "[INFO] Scanning user profiles..." -ForegroundColor Yellow

# Run DelProf2 in list mode to see what would be deleted
# /id:tp* - Filter profiles starting with "tp"
# /ed:student /ed:localadmin - Exclude local accounts
# /l - List mode (don't delete)
$listArgs = @("/l", "/id:tp*", "/ed:student", "/ed:localadmin")

Write-Host "[INFO] Running DelProf2 with filters..." -ForegroundColor Cyan
Write-Host "  - Include: Profiles starting with 'tp*'" -ForegroundColor Gray
Write-Host "  - Exclude: student, localadmin (local accounts)" -ForegroundColor Gray
Write-Host ""

try {
    $output = & $DelProf2Exe $listArgs 2>&1 | Out-String
    Write-Host $output
    
    # Parse output to count profiles
    $profileCount = 0
    $profileLines = $output -split "`n" | Where-Object { $_ -match "Deleting profile" -or $_ -match "Would delete" }
    $profileCount = $profileLines.Count
    
    if ($profileCount -eq 0) {
        Write-Host "`n[INFO] No matching profiles found to delete." -ForegroundColor Green
        Write-Host "[INFO] Criteria: Profiles starting with 'tp*', excluding student and localadmin" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Exit 0
    }
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host " PROFILES TO BE DELETED: $profileCount" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[WARNING] This will permanently delete the profiles listed above!" -ForegroundColor Red
    Write-Host ""
    
    # Confirmation prompt
    $confirmation = Read-Host "Do you want to proceed with deletion? Type 'DELETE' to confirm"
    
    if ($confirmation -ne "DELETE") {
        Write-Host "`n[INFO] Operation cancelled by user." -ForegroundColor Yellow
        Start-Sleep 1
        Exit 0
    }
    
    # Proceed with deletion
    Write-Host "`n[INFO] Deleting profiles..." -ForegroundColor Yellow
    
    $deleteArgs = @("/id:tp*", "/ed:student", "/ed:localadmin")
    $deleteOutput = & $DelProf2Exe $deleteArgs 2>&1 | Out-String
    Write-Host $deleteOutput
    
    Write-Host "`n[SUCCESS] Profile cleanup completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Host "`n[ERROR] Failed to run DelProf2: $($_.Exception.Message)" -ForegroundColor Red
    Start-Sleep 3
    Exit 1
}
