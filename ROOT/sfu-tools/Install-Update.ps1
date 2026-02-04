<#
    .SYNOPSIS
    Download and install update from GitHub
#>

param(
    [string]$DownloadUrl,
    [string]$CurrentVersion,
    [string]$NewVersion
)

$ScriptRoot = Split-Path -Parent $PSScriptRoot
$TempDir = Join-Path $env:TEMP "MTCP_Update"
$ZipFile = Join-Path $TempDir "update.zip"
$ExtractDir = Join-Path $TempDir "extracted"

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "                    MTCP UPDATE INSTALLER" -ForegroundColor White
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Current Version: " -NoNewline -ForegroundColor Gray
Write-Host $CurrentVersion -ForegroundColor Yellow
Write-Host "New Version:     " -NoNewline -ForegroundColor Gray
Write-Host $NewVersion -ForegroundColor Green
Write-Host ""

# Create temp directory
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null

try {
    # Download update
    Write-Host "[1/4] Downloading update..." -ForegroundColor Cyan
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($DownloadUrl, $ZipFile)
    Write-Host "      Download complete." -ForegroundColor Green
    
    # Extract archive
    Write-Host "[2/4] Extracting files..." -ForegroundColor Cyan
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $ExtractDir)
    
    # Find the ROOT folder in extracted files (GitHub adds repo name prefix)
    $extractedRoot = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
    $sourceRoot = Join-Path $extractedRoot.FullName "ROOT"
    
    if (-not (Test-Path $sourceRoot)) {
        throw "ROOT folder not found in update package"
    }
    Write-Host "      Extraction complete." -ForegroundColor Green
    
    # Backup current version
    Write-Host "[3/4] Backing up current version..." -ForegroundColor Cyan
    $backupDir = Join-Path $TempDir "backup"
    Copy-Item -Path $ScriptRoot -Destination $backupDir -Recurse -Force
    Write-Host "      Backup created at: $backupDir" -ForegroundColor Green
    
    # Copy new files
    Write-Host "[4/4] Installing update..." -ForegroundColor Cyan
    
    # Copy all files from source to destination, overwriting existing
    Get-ChildItem -Path $sourceRoot -Recurse | ForEach-Object {
        $targetPath = $_.FullName.Replace($sourceRoot, $ScriptRoot)
        
        if ($_.PSIsContainer) {
            if (-not (Test-Path $targetPath)) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            }
        } else {
            $targetDir = Split-Path -Parent $targetPath
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $targetPath -Force
        }
    }
    
    Write-Host "      Installation complete." -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "                   UPDATE SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The application will now restart with version $NewVersion" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to restart..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Restart application
    $launchScript = Join-Path $ScriptRoot "Launch.ps1"
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$launchScript`"" -Verb RunAs
    
    # Close all parent PowerShell processes running Launch.ps1
    Get-Process -Name "powershell*" -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowTitle -like "*TECHNICAL ASSISTANTS*"
    } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Exit current installer process
    [Environment]::Exit(0)
    
} catch {
    Write-Host ""
    Write-Host "ERROR: Update failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    
    # Restore backup if available
    if (Test-Path $backupDir) {
        Write-Host "Attempting to restore backup..." -ForegroundColor Yellow
        try {
            Get-ChildItem -Path $backupDir -Recurse | ForEach-Object {
                $targetPath = $_.FullName.Replace($backupDir, $ScriptRoot)
                
                if ($_.PSIsContainer) {
                    if (-not (Test-Path $targetPath)) {
                        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                    }
                } else {
                    Copy-Item -Path $_.FullName -Destination $targetPath -Force
                }
            }
            Write-Host "Backup restored successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to restore backup: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Backup location: $backupDir" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Cleanup temp directory
try {
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    # Ignore cleanup errors
}
