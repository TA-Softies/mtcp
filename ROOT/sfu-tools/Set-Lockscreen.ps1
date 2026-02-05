# Description: Technical Assistant: Wallpaper Update System
# Usage: .\Set-Lockscreen.ps1
# Author: Meesum
# Date: 2026-01-28
# Version: 1.2.4-GA

# --- CONFIGURATION ---
$ErrorActionPreference = 'Stop'
$lockscreenFolder = "C:\ProgramData\Wallpaper"
$lockscreenPath   = Join-Path $lockscreenFolder 'lockscreen.png'
$registryPath     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
$serverHost       = "wall.tasw.qzz.io"
$baseUrl          = "https://$serverHost"
$scriptDir        = $PSScriptRoot 

# --- UI INTERFACE ---
function Show-Interface {
    param([string]$StatusText = "Initializing...")
    Clear-Host
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Cyan"
    
    # INCREASED SPACING: 8 newlines to explicitly clear the progress bar area
    $Line = "======================================================================"
    Write-Host "`n`n`n`n`n`n`n`n`n`n$Line" -ForegroundColor DarkGray
    Write-Host "   TECHNICAL ASSISTANT | WALLPAPER UPDATE SYSTEM" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "   STATUS: $StatusText" -ForegroundColor Yellow
    Write-Host "$Line`n" -ForegroundColor DarkGray
}

# --- LOGGING & REPORTING ---
function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $LogFilePath = "C:\ProgramData\Wallpaper\wallpaper.log"
    if (-not (Test-Path (Split-Path $LogFilePath))) { New-Item -Path (Split-Path $LogFilePath) -ItemType Directory -Force | Out-Null }
    
    # Sub-expression $() ensures the date command runs and prints the actual time
    $LogEntry = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $LogFilePath -Value $LogEntry
}

function Send-StatusReport {
    param($Status, $Remarks)
    # Skip reporting if we detected offline mode earlier
    if ($global:IsOffline) { 
        Write-Log "Offline mode active. Skipping remote status report." "WARN"
        return 
    }

    $body = @{ type = "wallpaper"; data = @{ name = $env:COMPUTERNAME; time = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"); status = $Status; remarks = $Remarks } } | ConvertTo-Json -Depth 3
    try { 
        Invoke-WebRequest -Uri "https://pi.tasw.qzz.io" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction SilentlyContinue 
    } catch {}
}

# --- CORE LOGIC ---
Function Set-LockScreen {
    param ([string]$WallpaperName)
    $uri = "$baseUrl/$WallpaperName"
    $global:IsOffline = $false

    # 1. Download / Fallback Logic
    Show-Interface "Acquiring Wallpaper..."
    
    if (-not (Test-Path $lockscreenFolder)) { New-Item -Path $lockscreenFolder -ItemType Directory -Force | Out-Null }
    $tmpFile = Join-Path $env:TEMP ("lockscreen-" + [guid]::NewGuid().ToString('N') + ".png")

    try {
        # --- ATTEMPT ONLINE ---
        Write-Progress -Activity "Wallpaper Update System" -Status "Online Download" -PercentComplete 10 -CurrentOperation "Connecting to $serverHost..."
        Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $tmpFile -ErrorAction Stop -TimeoutSec 10
        
        Move-Item -LiteralPath $tmpFile -Destination $lockscreenPath -Force
        Write-Log "Success: Downloaded $WallpaperName from server."
        Write-Progress -Activity "Wallpaper Update System" -Status "Online Download" -PercentComplete 30 -CurrentOperation "Download Complete."

    } catch {
        # --- OFFLINE FALLBACK ---
        $global:IsOffline = $true
        $statusMsg = "Offline Mode: Searching local..."
        Show-Interface $statusMsg
        Write-Log "Connection failed ($($_.Exception.Message)). Attempting local fallback." "WARN"
        
        Write-Progress -Activity "Wallpaper Update System" -Status $statusMsg -PercentComplete 20 -CurrentOperation "Looking in script directory..."
        $localFile = Join-Path $scriptDir $WallpaperName
        
        if (Test-Path $localFile) {
            Write-Progress -Activity "Wallpaper Update System" -Status $statusMsg -PercentComplete 30 -CurrentOperation "Copying local file..."
            Copy-Item -Path $localFile -Destination $lockscreenPath -Force
            Write-Log "Success: Used local fallback file $localFile"
        } else {
            throw "CRITICAL: Server unreachable AND local file ($localFile) missing."
        }
    }

    # 2. Registry Policy Injection
    $statusMsg = "Applying Global Policies..."
    Show-Interface $statusMsg
    Write-Progress -Activity "Wallpaper Update System" -Status $statusMsg -PercentComplete 50 -CurrentOperation "Writing HKLM Keys..."
    
    if (-not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
    Set-ItemProperty -Path $registryPath -Name "LockScreenImage" -Value $lockscreenPath -Type String -Force
    Set-ItemProperty -Path $registryPath -Name "NoChangingLockScreen" -Value 1 -Type DWord -Force
    Write-Log "HKLM Policies Locked."

    # 3. User Override Purge
    $statusMsg = "Purging User Overrides..."
    Show-Interface $statusMsg
    Write-Progress -Activity "Wallpaper Update System" -Status $statusMsg -PercentComplete 70 -CurrentOperation "Scanning User SIDs..."
    
    $userKeyPath = "Software\Microsoft\Windows\CurrentVersion\Lock Screen"
    $users = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }
    foreach ($u in $users) {
        $sid = $u.SID
        if (Test-Path "Registry::HKEY_USERS\$sid\$userKeyPath") {
            Remove-Item -Path "Registry::HKEY_USERS\$sid\$userKeyPath" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log "User registry keys cleaned."

    # 4. Group Policy Refresh with Timeout
    $statusMsg = "Refreshing System Policies..."
    Show-Interface $statusMsg
    Write-Progress -Activity "Wallpaper Update System" -Status $statusMsg -PercentComplete 80 -CurrentOperation "Running GPUpdate..."
    
    $gpProcess = Start-Process gpupdate -ArgumentList "/Target:Computer", "/Force" -Wait -PassThru -WindowStyle Hidden
    $timeout = 15
    $timer = 0
    while (-not $gpProcess.HasExited -and $timer -lt $timeout) {
        Write-Progress -Activity "Wallpaper Update System" -Status $statusMsg -PercentComplete 85 -CurrentOperation "Waiting for Policy Engine ($($timeout - $timer)s)..."
        Start-Sleep -Seconds 1
        $timer++
    }
    Write-Log "Policy refresh completed ($timer seconds)."

    # 5. Restart LogonUI (Immediate Visual Update)
    $statusMsg = "Restarting Logon Graphics..."
    Show-Interface $statusMsg
    Write-Progress -Activity "Wallpaper Update System" -Status $statusMsg -PercentComplete 95 -CurrentOperation "Cycling LogonUI..."
    
    Stop-Process -Name "LogonUI" -Force -ErrorAction SilentlyContinue
    Write-Log "LogonUI process cycled."
    
    # Complete
    Write-Progress -Activity "Wallpaper Update System" -Status "Completed" -PercentComplete 100 -Completed
}

# --- EXECUTION ---
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb runAs -ArgumentList $arguments
    break
}

Show-Interface "Starting Wallpaper Update..."
$winVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
$wallpaperName = if ([int]$winVersion -gt 19045) { "lockscreen11.png" } else { "lockscreen10.png" }

try {
    Set-LockScreen -WallpaperName $wallpaperName
    Show-Interface "Wallpaper Update Successful"
    Write-Log "Process finalized."
    Send-StatusReport -Status "success" -Remarks "Wallpaper $wallpaperName applied. LogonUI Refreshed."
    Start-Sleep -Seconds 3
} catch {
    Write-Progress -Activity "Wallpaper Update System" -Status "Failed" -Completed
    Show-Interface "Error while updating wallpaper"
    Write-Log "CRITICAL: $($_.Exception.Message)" "ERROR"
    Send-StatusReport -Status "error" -Remarks $_.Exception.Message
    Read-Host "`nPress Enter to exit"
}