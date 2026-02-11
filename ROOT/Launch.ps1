<#
    .SYNOPSIS
    MTCP Launcher - Launches MTCP executable or falls back to Python
    
    .DESCRIPTION
    This script:
    1. Checks for admin privileges (elevates if needed)
    2. Checks if MTCP.exe exists locally - runs it directly
    3. If not, tries to download latest release from GitHub
    4. If download fails, falls back to Python source mode
#>

# ── Require Administrator ──────────────────────────────────
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ── Configuration ──────────────────────────────────────────
$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$MTCPExe = Join-Path $ScriptRoot "MTCP.exe"
$MTCPDir = Join-Path $ScriptRoot "mtcp"
$RequirementsFile = Join-Path $MTCPDir "requirements.txt"
$VenvDir = Join-Path $ScriptRoot ".venv"
$MinPythonMajor = 3
$MinPythonMinor = 10
$PythonInstallerUrl = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
$PythonInstallerFile = Join-Path $env:TEMP "python-installer.exe"
$GitHubRepo = "TA-Softies/mtcp"
$GitHubReleaseApi = "https://api.github.com/repos/$GitHubRepo/releases/latest"

# ── UTF-8 ──────────────────────────────────────────────────
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "MTCP - Multi-Tool Control Panel"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

# ── Set Console Size ───────────────────────────────────────
try {
    $Width = 120
    $Height = 42
    $BufferSize = $Host.UI.RawUI.BufferSize
    $WindowSize = $Host.UI.RawUI.WindowSize
    
    # Adjust buffer first (must be >= window)
    if ($BufferSize.Width -lt $Width) {
        $BufferSize.Width = $Width
        $Host.UI.RawUI.BufferSize = $BufferSize
    }
    if ($BufferSize.Height -lt $Height) {
        $BufferSize.Height = $Height
        $Host.UI.RawUI.BufferSize = $BufferSize
    }
    
    # Now set window size
    $WindowSize.Width = $Width
    $WindowSize.Height = $Height
    $Host.UI.RawUI.WindowSize = $WindowSize
    
    # Set buffer to match window (no scrollback)
    $BufferSize.Width = $Width
    $BufferSize.Height = $Height
    $Host.UI.RawUI.BufferSize = $BufferSize
} catch {
    # Ignore - some terminals don't support resizing
}

Clear-Host

# ── Helper: Styled Output ─────────────────────────────────
function Write-Banner {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ║   █▄█ ▀█▀ █▀▀ █▀█   ▀█▀ ▄▀█   MULTI-TOOL CONTROL PANEL     ║" -ForegroundColor Cyan
    Write-Host "  ║   █░█ ░█░ █▄▄ █▀    ░█░ █▀█   Technical Assistants          ║" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Icon, [string]$Message, [string]$Color = "White")
    Write-Host "  $Icon " -NoNewline -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor $Color
}

function Write-SubStep {
    param([string]$Message, [string]$Color = "Gray")
    Write-Host "     $Message" -ForegroundColor $Color
}

function Write-Error-Styled {
    param([string]$Title, [string]$Message)
    Write-Host ""
    Write-Host "  ❌ $Title" -ForegroundColor Red
    Write-Host "     $Message" -ForegroundColor Yellow
    Write-Host ""
}

# ── Helper: Download from GitHub Releases ─────────────────
function Get-LatestRelease {
    Write-Step "🌐" "Checking for latest release..."
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        $headers = @{ "User-Agent" = "MTCP-Launcher" }
        $release = Invoke-RestMethod -Uri $GitHubReleaseApi -Headers $headers -TimeoutSec 10
        $ProgressPreference = 'Continue'
        
        $asset = $release.assets | Where-Object { $_.name -eq "MTCP.exe" } | Select-Object -First 1
        
        if ($asset) {
            Write-SubStep "Found release: $($release.tag_name)"
            return @{
                Version = $release.tag_name
                DownloadUrl = $asset.browser_download_url
                Size = $asset.size
            }
        }
    } catch {
        Write-SubStep "Could not check releases: $($_.Exception.Message)" "DarkGray"
    }
    
    return $null
}

function Download-MTCP {
    param([hashtable]$ReleaseInfo)
    
    Write-Step "📥" "Downloading MTCP $($ReleaseInfo.Version)..."
    $sizeMB = [math]::Round($ReleaseInfo.Size / 1MB, 1)
    Write-SubStep "Size: $sizeMB MB"
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $ReleaseInfo.DownloadUrl -OutFile $MTCPExe -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        if (Test-Path $MTCPExe) {
            Write-Step "✅" "Downloaded successfully!" "Green"
            
            # Remove Python source files to save space (keep sfu-tools config)
            if (Test-Path $MTCPDir) {
                Write-SubStep "Cleaning up Python source files..."
                Remove-Item -Path $MTCPDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $VenvDir) {
                Remove-Item -Path $VenvDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            return $true
        }
    } catch {
        Write-Error-Styled "Download Failed" $_.Exception.Message
    }
    
    return $false
}

# ── Helper: Find Python ───────────────────────────────────
function Find-Python {
    # 1. Check venv first
    $venvPython = Join-Path $VenvDir "Scripts\python.exe"
    if (Test-Path $venvPython) {
        $ver = & $venvPython --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if ($major -ge $MinPythonMajor -and $minor -ge $MinPythonMinor) {
                return $venvPython
            }
        }
    }
    
    # 2. Check system PATH (skip MSYS2 / Cygwin builds)
    $candidates = @("python", "python3", "py")
    foreach ($cmd in $candidates) {
        try {
            $path = (Get-Command $cmd -ErrorAction SilentlyContinue).Source
            if (-not $path) { continue }
            if ($path -match 'msys|cygwin|mingw') { continue }
            $result = & $path --version 2>&1
            if ($result -match "Python (\d+)\.(\d+)") {
                $major = [int]$Matches[1]
                $minor = [int]$Matches[2]
                if ($major -ge $MinPythonMajor -and $minor -ge $MinPythonMinor) {
                    return $path
                }
            }
        } catch { }
    }
    
    # 3. Check common installation paths
    $commonPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "C:\Python312\python.exe",
        "C:\Python311\python.exe",
        "C:\Python310\python.exe",
        "$env:ProgramFiles\Python312\python.exe",
        "$env:ProgramFiles\Python311\python.exe",
        "$env:ProgramFiles\Python310\python.exe"
    )
    
    foreach ($p in $commonPaths) {
        $expanded = [Environment]::ExpandEnvironmentVariables($p)
        if (Test-Path $expanded) {
            if ($expanded -match 'msys|cygwin|mingw') { continue }
            $ver = & $expanded --version 2>&1
            if ($ver -match "Python (\d+)\.(\d+)") {
                $major = [int]$Matches[1]
                $minor = [int]$Matches[2]
                if ($major -ge $MinPythonMajor -and $minor -ge $MinPythonMinor) {
                    return $expanded
                }
            }
        }
    }
    
    return $null
}

# ── Helper: Install Python ────────────────────────────────
function Install-Python {
    Write-Step "📥" "Downloading Python 3.12..."
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $PythonInstallerUrl -OutFile $PythonInstallerFile -UseBasicParsing
        $ProgressPreference = 'Continue'
    } catch {
        Write-Error-Styled "Download Failed" $_.Exception.Message
        return $false
    }
    
    Write-Step "⚙️" "Installing Python 3.12..."
    
    try {
        $installArgs = @("/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_pip=1", "Include_launcher=1", "Include_test=0")
        $proc = Start-Process -FilePath $PythonInstallerFile -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($proc.ExitCode -ne 0) {
            Write-Error-Styled "Installation Failed" "Exit code: $($proc.ExitCode)"
            return $false
        }
        
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Write-Step "✅" "Python installed!" "Green"
        
    } catch {
        Write-Error-Styled "Installation Error" $_.Exception.Message
        return $false
    } finally {
        if (Test-Path $PythonInstallerFile) {
            Remove-Item $PythonInstallerFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    return $true
}

# ── Helper: Setup Virtual Environment ─────────────────────
function Setup-Venv {
    param([string]$PythonExe)
    
    $venvPython = Join-Path $VenvDir "Scripts\python.exe"
    
    if (-not (Test-Path $venvPython)) {
        Write-Step "🏗️" "Creating virtual environment..."
        
        & $PythonExe -m venv $VenvDir 2>&1 | Out-Null
        
        if (-not (Test-Path $venvPython)) {
            & $PythonExe -m venv --without-pip $VenvDir 2>&1 | Out-Null
        }
        
        if (-not (Test-Path $venvPython)) {
            return $null
        }
        
        $venvPip = Join-Path $VenvDir "Scripts\pip.exe"
        if (-not (Test-Path $venvPip)) {
            & $venvPython -m ensurepip --default-pip 2>&1 | Out-Null
        }
    }
    
    return $venvPython
}

# ── Helper: Install Dependencies ──────────────────────────
function Install-Dependencies {
    param([string]$PythonExe)
    
    if (-not (Test-Path $RequirementsFile)) {
        return $false
    }
    
    Write-Step "📦" "Installing dependencies..."
    & $PythonExe -m pip install --upgrade pip --quiet 2>&1 | Out-Null
    
    try {
        & $PythonExe -m pip install -r $RequirementsFile --quiet 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-Dependencies {
    param([string]$PythonExe)
    try {
        & $PythonExe -c "import textual; import rich; import psutil" 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# ══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ══════════════════════════════════════════════════════════════

Write-Banner
Set-Location $ScriptRoot

# ── Mode 1: Check for existing MTCP.exe ───────────────────
if (Test-Path $MTCPExe) {
    Write-Step "✅" "Found MTCP.exe" "Green"
    Write-Host ""
    Write-Step "🚀" "Launching MTCP..." "Cyan"
    
    Start-Process -FilePath $MTCPExe -WorkingDirectory $ScriptRoot
    
    Write-Host ""
    Write-Host "  MTCP launched. This window will close." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 500
    Exit 0
}

# ── Mode 2: Try to download from GitHub releases ──────────
$release = Get-LatestRelease

if ($release) {
    $downloaded = Download-MTCP -ReleaseInfo $release
    
    if ($downloaded -and (Test-Path $MTCPExe)) {
        Write-Host ""
        Write-Step "🚀" "Launching MTCP..." "Cyan"
        
        Start-Process -FilePath $MTCPExe -WorkingDirectory $ScriptRoot
        
        Write-Host ""
        Write-Host "  MTCP launched. This window will close." -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 500
        Exit 0
    }
}

# ── Mode 3: Fall back to Python source ────────────────────
Write-Step "📜" "No executable found. Using Python source mode..." "Yellow"
Write-Host ""

# Check for Python source files
if (-not (Test-Path $MTCPDir)) {
    Write-Error-Styled "Missing Source" "Neither MTCP.exe nor mtcp/ source folder found."
    Write-Host "  Download MTCP from: https://github.com/$GitHubRepo/releases" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Press any key to exit..." -ForegroundColor Gray
    $null = [Console]::ReadKey($true)
    Exit 1
}

# Find or install Python
Write-Step "🔍" "Checking for Python $MinPythonMajor.$MinPythonMinor+..."

$pythonExe = Find-Python

if (-not $pythonExe) {
    Write-Step "⚠️" "Python not found. Installing..." "Yellow"
    
    $installed = Install-Python
    if (-not $installed) {
        Write-Host "  Please install Python manually from https://python.org" -ForegroundColor Yellow
        Write-Host "  Press any key to exit..." -ForegroundColor Gray
        $null = [Console]::ReadKey($true)
        Exit 1
    }
    
    $pythonExe = Find-Python
    if (-not $pythonExe) {
        Write-Error-Styled "Python Not Found" "Please restart your terminal."
        Write-Host "  Press any key to exit..." -ForegroundColor Gray
        $null = [Console]::ReadKey($true)
        Exit 1
    }
}

$pyVersion = & $pythonExe --version 2>&1
Write-Step "✅" "Found: $pyVersion" "Green"

# Setup venv
$venvPython = Setup-Venv -PythonExe $pythonExe
if ($venvPython) {
    $pythonExe = $venvPython
}

# Install dependencies
if (-not (Test-Dependencies -PythonExe $pythonExe)) {
    $depsOk = Install-Dependencies -PythonExe $pythonExe
    if (-not $depsOk) {
        Write-Error-Styled "Dependencies Failed" "Run: $pythonExe -m pip install -r mtcp/requirements.txt"
        Write-Host "  Press any key to exit..." -ForegroundColor Gray
        $null = [Console]::ReadKey($true)
        Exit 1
    }
}

Write-Step "✅" "Dependencies ready." "Green"

# Launch Python TUI
Write-Host ""
Write-Step "🚀" "Launching MTCP (Python mode)..." "Cyan"

$startCmd = "start `"MTCP - Multi-Tool Control Panel`" /D `"$ScriptRoot`" `"$pythonExe`" -m mtcp"
cmd /c $startCmd

Write-Host ""
Write-Host "  MTCP launched. This window will close." -ForegroundColor DarkGray
Start-Sleep -Milliseconds 500
Exit 0
