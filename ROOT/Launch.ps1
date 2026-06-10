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
$GitHubRepo    = "TA-Softies/mtcp"
$GitHubRepoUrl = "https://github.com/$GitHubRepo"
$GitHubZipUrl  = "$GitHubRepoUrl/archive/refs/heads/main.zip"

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

# ── Helper: Fetch source from GitHub (git clone or zip) ───
function Get-SourceFromGitHub {
    Write-Step "🌐" "Fetching source from GitHub..."

    $tmpDir = Join-Path $env:TEMP "mtcp_src_$([System.IO.Path]::GetRandomFileName().Split('.')[0])"
    $tmpZip = "$tmpDir.zip"

    # --- Try git clone first ---
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-SubStep "Cloning $GitHubRepoUrl ..."
        try {
            if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
            & git clone --quiet --depth 1 $GitHubRepoUrl $tmpDir | Out-Null
            if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $tmpDir "ROOT"))) {
                Copy-SourceFiles -SrcRoot (Join-Path $tmpDir "ROOT")
                Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Step "✅" "Source ready." "Green"
                return $true
            }
        } catch {}
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- Fall back to zip download ---
    Write-SubStep "Downloading archive from $GitHubZipUrl ..."
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $GitHubZipUrl -OutFile $tmpZip -UseBasicParsing
        $ProgressPreference = 'Continue'

        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
        Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue

        # Zip extracts to mtcp-main/ (or similar)
        $inner = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
        $srcRoot = Join-Path $inner.FullName "ROOT"
        if (Test-Path $srcRoot) {
            Copy-SourceFiles -SrcRoot $srcRoot
            Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Step "✅" "Source ready." "Green"
            return $true
        }
    } catch {
        Write-Error-Styled "Download Failed" $_.Exception.Message
    }

    Remove-Item $tmpDir  -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpZip  -Force          -ErrorAction SilentlyContinue
    return $false
}

function Copy-SourceFiles {
    param([string]$SrcRoot)
    # mtcp package (always overwrite)
    $srcMtcp = Join-Path $SrcRoot "mtcp"
    if (Test-Path $srcMtcp) {
        if (Test-Path $MTCPDir) { Remove-Item $MTCPDir -Recurse -Force }
        Copy-Item -Path $srcMtcp -Destination $ScriptRoot -Recurse -Force
        Write-SubStep "mtcp/ updated."
    }
    # sfu-tools (only if missing locally)
    $srcSfu  = Join-Path $SrcRoot "sfu-tools"
    $destSfu = Join-Path $ScriptRoot "sfu-tools"
    if ((Test-Path $srcSfu) -and (-not (Test-Path $destSfu))) {
        Copy-Item -Path $srcSfu -Destination $ScriptRoot -Recurse -Force
        Write-SubStep "sfu-tools/ installed."
    }
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

# ── Mode 2: Fetch source from GitHub if mtcp/ is missing ──
if (-not (Test-Path $MTCPDir)) {
    $fetched = Get-SourceFromGitHub
    if (-not $fetched -and -not (Test-Path $MTCPDir)) {
        Write-Error-Styled "Missing Source" "Could not fetch source from GitHub."
        Write-Host "  Clone manually: git clone $GitHubRepoUrl" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Press any key to exit..." -ForegroundColor Gray
        $null = [Console]::ReadKey($true)
        Exit 1
    }
}

# ── Mode 3: Python source mode ────────────────────────────
Write-Step "📜" "Running in Python source mode..." "Yellow"
Write-Host ""

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
