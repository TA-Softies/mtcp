<#
    .SYNOPSIS
    Technical Assistants Multi-Tool Launcher
#>
# Requires Run as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Force UTF-8 encoding for console
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Set black background
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
$Host.UI.RawUI.WindowTitle = "TECHNICAL ASSISTANTS - Multi-Tool Panel"

# Set UTF-8 encoding for proper Unicode display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Set window size wider to fit content, no scrolling
try {
    $w = 77; $h = 46
    # Must shrink window before buffer if current window is larger than target
    $curWin = $Host.UI.RawUI.WindowSize
    $curBuf = $Host.UI.RawUI.BufferSize
    # Step 1: Shrink window to fit within both current buffer and target
    $tmpW = [Math]::Min($w, $curBuf.Width)
    $tmpH = [Math]::Min($h, $curBuf.Height)
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($tmpW, $tmpH)
    # Step 2: Set buffer (width matches window, height large to prevent overflow)
    $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($w, 9999)
    # Step 3: Set window to target
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($w, $h)
} catch {
    # Ignore if window size cannot be set (e.g., in ISE or unsupported terminal)
}

Clear-Host
[Console]::CursorVisible = $false

# --- Configuration ---
$ScriptRoot = $PSScriptRoot
$ConfigPath = Join-Path $ScriptRoot "sfu-tools\config.json"
$IconsPath = Join-Path $ScriptRoot "sfu-tools\icons.json"
$DFPath     = "C:\Windows\SysWOW64\DFC.exe" # Deep Freeze Console CLI
$AppTitle   = "TECHNICAL ASSISTANTS"
$DebugMode  = $false

# --- Helper Functions ---

# Scroll tick for marquee animation
$script:ScrollTick = 0
$script:HasScrollText = $false

# Writes text that scrolls if too long for available space
function Write-ScrollText {
    param(
        [string]$Text,
        [int]$TargetCol = 74,
        [string]$Color = "White"
    )
    $curPos = [Console]::CursorLeft
    $available = $TargetCol - $curPos - 1
    if ($available -lt 5) { $available = 5 }
    if ($Text.Length -le $available) {
        Write-Host $Text -NoNewline -ForegroundColor $Color
    } else {
        $script:HasScrollText = $true
        $pauseTicks = 6
        $scrollRange = $Text.Length - $available
        $cycleLen = $pauseTicks + $scrollRange + $pauseTicks + $scrollRange
        $pos = $script:ScrollTick % $cycleLen
        if ($pos -lt $pauseTicks) {
            $offset = 0
        } elseif ($pos -lt ($pauseTicks + $scrollRange)) {
            $offset = $pos - $pauseTicks
        } elseif ($pos -lt ($pauseTicks + $scrollRange + $pauseTicks)) {
            $offset = $scrollRange
        } else {
            $offset = $scrollRange - ($pos - $pauseTicks - $scrollRange - $pauseTicks)
        }
        $visible = $Text.Substring($offset, $available)
        Write-Host $visible -NoNewline -ForegroundColor $Color
    }
}

# Pads with spaces to column 74 then writes closing border char
# This handles emoji display widths automatically via CursorLeft
function Write-BorderEnd {
    param(
        [string]$Char = ([string][char]0x2502),
        [string]$Color = "DarkCyan"
    )
    $targetCol = 74  # 2 prefix + 1 border + 71 inner = col 74
    $cur = [Console]::CursorLeft
    $n = $targetCol - $cur
    if ($n -lt 1) { $n = 1 }
    Write-Host (" " * $n) -NoNewline
    Write-Host $Char -ForegroundColor $Color
}

function Show-BSOD {
    param(
        [string]$ErrorTitle,
        [string]$ErrorMessage,
        [string]$ErrorCode = "0x00000001"
    )
    
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
    
    Write-Host ""
    Write-Host ""
    Write-Host "  :(" -ForegroundColor White
    Write-Host ""
    Write-Host "  Your system ran into a problem and needs to restart." -ForegroundColor White
    Write-Host ""
    Write-Host "  TECHNICAL ASSISTANTS PANEL - CRITICAL ERROR" -ForegroundColor White
    Write-Host ""
    Write-Host "  Error: $ErrorTitle" -ForegroundColor White
    Write-Host "  $ErrorMessage" -ForegroundColor White
    Write-Host ""
    Write-Host "  Error Code: $ErrorCode" -ForegroundColor White
    Write-Host "  " -NoNewline
    Write-Host "[ESC]" -ForegroundColor Black -BackgroundColor White -NoNewline
    Write-Host " Press ESC to exit" -ForegroundColor White
    Write-Host ""
    
    # Wait for ESC key
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "Escape") {
            break
        }
    }
    
    Exit
}

function Show-AlertScreen {
    param(
        [string]$Title,
        [string]$Message,
        [string[]]$Options = @(),
        [string]$PromptText = "Select an option",
        [string]$Icon = "(!)"
    )
    
    $Host.UI.RawUI.BackgroundColor = "DarkYellow"
    $Host.UI.RawUI.ForegroundColor = "Black"
    Clear-Host
    
    # Calculate vertical centering
    $windowHeight = 43
    $contentLines = 10 + $Options.Count + ($Message -split "`n").Count
    $topPadding = [Math]::Max(2, [Math]::Floor(($windowHeight - $contentLines) / 2))
    
    # Add top padding
    Write-Host ("`n" * $topPadding)
    
    # Icon and Title
    Write-Host "  $Icon" -ForegroundColor Black
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Black
    Write-Host ""
    
    # Message (support multi-line)
    $messageLines = $Message -split "`n"
    foreach ($line in $messageLines) {
        Write-Host "  $line" -ForegroundColor Black
    }
    Write-Host ""
    
    # Options
    if ($Options.Count -gt 0) {
        Write-Host "  $PromptText" -ForegroundColor Black
        Write-Host ""
        
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $optionKey = $Options[$i].Substring(0, 1).ToUpper()
            $optionText = $Options[$i]
            
            Write-Host "  " -NoNewline
            Write-Host "[$optionKey]" -ForegroundColor White -BackgroundColor Black -NoNewline
            Write-Host " $optionText" -ForegroundColor Black
        }
        Write-Host ""
        
        # Wait for valid key input
        while ($true) {
            $key = [Console]::ReadKey($true)
            $keyChar = $key.KeyChar.ToString().ToUpper()
            
            # Check if pressed key matches any option
            foreach ($option in $Options) {
                if ($keyChar -eq $option.Substring(0, 1).ToUpper()) {
                    # Reset colors
                    $Host.UI.RawUI.BackgroundColor = "Black"
                    $Host.UI.RawUI.ForegroundColor = "White"
                    Clear-Host
                    return $option
                }
            }
            
            # Also check for ESC key
            if ($key.Key -eq "Escape") {
                # Reset colors
                $Host.UI.RawUI.BackgroundColor = "Black"
                $Host.UI.RawUI.ForegroundColor = "White"
                Clear-Host
                return "Escape"
            }
        }
    } else {
        # No options, just show message and wait for any key
        Write-Host "  Press any key to continue..." -ForegroundColor Black
        $null = [Console]::ReadKey($true)
        
        # Reset colors
        $Host.UI.RawUI.BackgroundColor = "Black"
        $Host.UI.RawUI.ForegroundColor = "White"
        Clear-Host
        return $null
    }
}

function Show-UpdateNotification {
    param(
        [string]$CurrentVersion,
        [string]$NewVersion,
        [string]$DownloadUrl
    )
    
    $Host.UI.RawUI.BackgroundColor = "DarkGreen"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
    
    Write-Host ""
    Write-Host ""
    Write-Host "  :)" -ForegroundColor White
    Write-Host ""
    Write-Host "  A new update is available and ready to install!" -ForegroundColor White
    Write-Host ""
    Write-Host "  MTCP - MULTI-TOOL CONTROL PANEL UPDATE" -ForegroundColor White
    Write-Host ""
    Write-Host "  Current Version: $CurrentVersion" -ForegroundColor White
    Write-Host "  New Version:     $NewVersion" -ForegroundColor Green
    Write-Host ""
    Write-Host "  The update will:" -ForegroundColor White
    Write-Host "    - Backup your current installation" -ForegroundColor Gray
    Write-Host "    - Download and install the new version" -ForegroundColor Gray
    Write-Host "    - Restart the application automatically" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "[U]" -ForegroundColor Black -BackgroundColor White -NoNewline
    Write-Host " Press U to Update  " -ForegroundColor White -NoNewline
    Write-Host "[ENTER]" -ForegroundColor Black -BackgroundColor White -NoNewline
    Write-Host " Press ENTER to Skip" -ForegroundColor White
    Write-Host ""
    
    # Wait for U or ENTER key
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "Enter") {
            # Reset colors
            $Host.UI.RawUI.BackgroundColor = "Black"
            $Host.UI.RawUI.ForegroundColor = "White"
            Clear-Host
            return $false
        } elseif ($key.KeyChar.ToString().ToUpper() -eq "U") {
            # Reset colors
            $Host.UI.RawUI.BackgroundColor = "Black"
            $Host.UI.RawUI.ForegroundColor = "White"
            Clear-Host
            return $true
        }
    }
}

function Show-LoadingScreen {
    param(
        [string]$Version
    )
    
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
    
    Write-Host ""
    Write-Host ("  " + [char]0x2554 + ([string]([char]0x2550) * 71) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host (" " * 71) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    $a1 = "                      " + [char]0x2588 + [char]0x2584 + [char]0x2588 + " " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + "   " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2584 + [char]0x2580 + [char]0x2588
    Write-Host $a1 -NoNewline -ForegroundColor Cyan
    $pad1 = 71 - $a1.Length; if ($pad1 -lt 0) { $pad1 = 1 }
    Write-Host (" " * $pad1) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    $a2 = "                      " + [char]0x2588 + [char]0x2591 + [char]0x2588 + " " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + " " + [char]0x2588 + [char]0x2580 + " " + "   " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588
    Write-Host $a2 -NoNewline -ForegroundColor Cyan
    $pad2 = 71 - $a2.Length; if ($pad2 -lt 0) { $pad2 = 1 }
    Write-Host (" " * $pad2) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host (" " * 71) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    $mtcpText = "            MULTI-TOOL CONTROL PANEL v$Version"
    Write-Host $mtcpText -NoNewline -ForegroundColor Gray
    $spaces = 71 - $mtcpText.Length; if ($spaces -lt 0) { $spaces = 1 }
    Write-Host (" " * $spaces) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host "                         Technical Assistants" -NoNewline -ForegroundColor DarkCyan
    Write-Host (" " * 26) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host (" " * 71) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x255A + ([string]([char]0x2550) * 71) + [char]0x255D) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "                    🔄 Checking for updates" -ForegroundColor Yellow -NoNewline
    
    # Animated dots
    for ($i = 0; $i -lt 3; $i++) {
        Start-Sleep -Milliseconds 300
        Write-Host "." -NoNewline -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Get-Icon {
    param(
        [string]$Category,
        [string]$Type
    )
    
    if (-not $script:Icons) { return "" }
    
    # Try to find icon in the specified category
    if ($script:Icons.$Category -and $script:Icons.$Category.$Type) {
        return $script:Icons.$Category.$Type + " "
    }
    
    # Fallback to default
    if ($script:Icons.$Category -and $script:Icons.$Category.default) {
        return $script:Icons.$Category.default + " "
    }
    
    return ""
}

function Get-ProcessInfo {
    $process = Get-Process -Id $PID
    $cpuTime = $process.TotalProcessorTime.TotalSeconds
    $memoryMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
    $threads = $process.Threads.Count
    $handles = $process.HandleCount
    
    return [PSCustomObject]@{
        CPU = "$cpuTime s"
        Memory = "$memoryMB MB"
        Threads = $threads
        Handles = $handles
        StartTime = $process.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Show-HelpScreen {
    param(
        [hashtable]$Commands
    )
    
    Clear-Host
    Write-Host ""
    Write-Host ("  " + [char]0x2554 + ([string]([char]0x2550) * 71) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host "                                  ❓ HELP MENU" -NoNewline -ForegroundColor Yellow
    Write-BorderEnd -Char ([string][char]0x2551) -Color "Cyan"
    Write-Host ("  " + [char]0x255A + ([string]([char]0x2550) * 71) + [char]0x255D) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  💬 Available Commands:" -ForegroundColor Yellow
    Write-Host "  " -NoNewline
    Write-Host (([char]0x2500).ToString() * 71) -ForegroundColor DarkGray
    Write-Host ""
    
    foreach ($cmdName in ($Commands.Keys | Sort-Object)) {
        $cmd = $Commands[$cmdName]
        Write-Host "    /$cmdName" -NoNewline -ForegroundColor Cyan
        $padding = 20 - $cmdName.Length
        if ($padding -lt 2) { $padding = 2 }
        Write-Host (" " * $padding) -NoNewline
        Write-Host $cmd.description -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  🎮 Navigation:" -ForegroundColor Yellow
    Write-Host "    • Press " -NoNewline -ForegroundColor Gray
    Write-Host "/" -NoNewline -ForegroundColor Cyan
    Write-Host " to open command prompt" -ForegroundColor Gray
    Write-Host "    • Use " -NoNewline -ForegroundColor Gray
    Write-Host ([string]([char]0x25B2) + "/" + [string]([char]0x25BC)) -NoNewline -ForegroundColor Cyan
    Write-Host " arrows to navigate menu" -ForegroundColor Gray
    Write-Host "    • Press " -NoNewline -ForegroundColor Gray
    Write-Host "ENTER" -NoNewline -ForegroundColor Cyan
    Write-Host " to select an item" -ForegroundColor Gray
    Write-Host "    • Press " -NoNewline -ForegroundColor Gray
    Write-Host "ESC" -NoNewline -ForegroundColor Red
    Write-Host " to go back or exit" -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to continue"
}

function Show-CreditsScreen {
    param(
        [string]$Version,
        [string]$Author
    )
    
    Clear-Host
    Write-Host ""
    Write-Host ("  " + [char]0x2554 + ([string]([char]0x2550) * 71) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host "                                 ⭐ CREDITS" -NoNewline -ForegroundColor Yellow
    Write-BorderEnd -Char ([string][char]0x2551) -Color "Cyan"
    Write-Host ("  " + [char]0x255A + ([string]([char]0x2550) * 71) + [char]0x255D) -ForegroundColor Cyan
    Write-Host ""
    Write-Host ""
    $line1 = "                      " + [char]0x2588 + [char]0x2584 + [char]0x2588 + " " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + "   " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2584 + [char]0x2580 + [char]0x2588
    $line2 = "                      " + [char]0x2588 + [char]0x2591 + [char]0x2588 + " " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + " " + [char]0x2588 + [char]0x2580 + " " + "   " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588
    [Console]::WriteLine($line1)
    [Console]::WriteLine($line2)
    Write-Host ""
    Write-Host "                    MULTI-TOOL CONTROL PANEL" -ForegroundColor Cyan
    Write-Host "                         Version $Version" -ForegroundColor Gray
    Write-Host ""
    Write-Host ""
    Write-Host "  👥 Developed by:" -ForegroundColor Yellow
    Write-Host "     $Author" -ForegroundColor White
    Write-Host ""
    Write-Host "  🏢 Organization:" -ForegroundColor Yellow
    Write-Host "     Technical Assistants" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔗 Repository:" -ForegroundColor Yellow
    Write-Host "     https://github.com/TA-Softies/mtcp" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ⚙️  Built with:" -ForegroundColor Yellow
    Write-Host "     PowerShell 5.1+" -ForegroundColor White
    Write-Host "     Windows 10/11 Compatible" -ForegroundColor White
    Write-Host ""
    Write-Host "  ❤️  Special Thanks:" -ForegroundColor Yellow
    Write-Host "     SFU Technical Team" -ForegroundColor White
    Write-Host "     GitHub Copilot Assistant" -ForegroundColor White
    Write-Host ""
    Read-Host "  Press Enter to continue"
}

function Invoke-SlashCommand {
    param(
        [string]$CommandName,
        [hashtable]$Commands,
        [string]$Version,
        [string]$Author,
        [string]$ScriptRoot
    )
    
    # Remove leading slash if present
    $CommandName = $CommandName.TrimStart('/')
    
    if (-not $Commands.ContainsKey($CommandName)) {
        Clear-Host
        Write-Host ""
        Write-Host "  ❌ Command not found: " -NoNewline -ForegroundColor Red
        Write-Host "/$CommandName" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Type " -NoNewline -ForegroundColor Gray
        Write-Host "/help" -NoNewline -ForegroundColor Cyan
        Write-Host " to see available commands." -ForegroundColor Gray
        Write-Host ""
        Start-Sleep -Seconds 2
        return $false
    }
    
    $cmd = $Commands[$CommandName]
    
    switch ($cmd.action) {
        "show-help" {
            Show-HelpScreen -Commands $Commands
            return $true
        }
        "show-credits" {
            Show-CreditsScreen -Version $Version -Author $Author
            return $true
        }
        "show-debug" {
            Show-DebugMenu -Version $Version -ScriptRoot $ScriptRoot
            return $true
        }
        "show-version" {
            Clear-Host
            Write-Host ""
            Write-Host "  📄 Current Version: " -NoNewline -ForegroundColor Yellow
            Write-Host "v$Version" -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 2
            return $true
        }
        "check-update" {
            Clear-Host
            Write-Host ""
            Write-Host "  🔄 Checking for updates..." -ForegroundColor Yellow
            Write-Host ""
            
            $updateCheckScript = Join-Path $ScriptRoot "sfu-tools\Check-Update.ps1"
            if (Test-Path $updateCheckScript) {
                $updateInfo = & $updateCheckScript -CurrentVersion $Version
                
                if ($updateInfo -and $updateInfo.UpdateAvailable) {
                    Write-Host "  ✅ Update available!" -ForegroundColor Green
                    Write-Host "     Current: v$($updateInfo.CurrentVersion)" -ForegroundColor White
                    Write-Host "     Latest:  v$($updateInfo.RemoteVersion)" -ForegroundColor Cyan
                    Write-Host ""
                    $confirm = Read-Host "  Install update? (Y/N)"
                    if ($confirm -eq 'Y') {
                        $installScript = Join-Path $ScriptRoot "sfu-tools\Install-Update.ps1"
                        if (Test-Path $installScript) {
                            & $installScript -DownloadUrl $updateInfo.DownloadUrl -CurrentVersion $updateInfo.CurrentVersion -NewVersion $updateInfo.RemoteVersion
                            Exit
                        }
                    }
                } else {
                    Write-Host "  ✅ You are running the latest version!" -ForegroundColor Green
                    Write-Host ""
                    Start-Sleep -Seconds 2
                }
            }
            return $true
        }
        "run-script" {
            $scriptPath = $cmd.script -replace '\$PSScriptRoot', $ScriptRoot
            if (Test-Path $scriptPath) {
                Clear-Host
                Write-Host "Executing: $CommandName..." -ForegroundColor Yellow
                Write-Host ""
                & $scriptPath
                Write-Host ""
                Write-Host "Done." -ForegroundColor Green
                Write-Host ""
                Read-Host "Press Enter to continue"
            } else {
                Write-Host "  ❌ Script not found: $scriptPath" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
            return $true
        }
        "run-command" {
            Clear-Host
            Write-Host "Executing: $CommandName..." -ForegroundColor Yellow
            Write-Host ""
            Invoke-Expression $cmd.command
            Write-Host ""
            Write-Host "Done." -ForegroundColor Green
            Write-Host ""
            Read-Host "Press Enter to continue"
            return $true
        }
        "exit" {
            return "EXIT"
        }
        default {
            Write-Host "  ❌ Unknown action: $($cmd.action)" -ForegroundColor Red
            Start-Sleep -Seconds 2
            return $false
        }
    }
}

function Get-SysInfo {
    $comp = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $mem  = [math]::Round($comp.TotalPhysicalMemory / 1GB, 1)
    $boardInfo = Get-CimInstance Win32_BaseBoard
    $board = "$($boardInfo.Product) (S/N: $($boardInfo.SerialNumber))"
    
    # Hostname with Domain
    $hostname = $env:COMPUTERNAME
    $domain = $comp.Domain
    if ($domain -and $domain -ne "WORKGROUP") {
        $hostname = "$hostname ($domain)"
    }
    
    # System Model
    $model = "$($comp.Manufacturer) $($comp.Model)"
    
    # OS Information
    $osName = $os.Caption
    $osVersion = $os.Version
    $osBuild = $os.BuildNumber
    $osInfo = "$osName ($osBuild)"
    
    # Boot Time and Uptime
    $bootTime = $os.LastBootUpTime
    $uptime = (Get-Date) - $bootTime
    $uptimeString = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    $bootTimeString = $bootTime.ToString("yyyy-MM-dd HH:mm:ss")
    
    # Network Information - Get active adapters with IP addresses
    $activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notmatch "Virtual|Loopback|Bluetooth" }
    $netTypes = @()
    $ipAddresses = @()
    
    foreach ($adapter in $activeAdapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ipConfig) {
            $ipAddresses += $ipConfig.IPAddress
            if ($adapter.InterfaceDescription -match "Wi-Fi|Wireless|802.11") {
                if ("WiFi" -notin $netTypes) { $netTypes += "WiFi" }
            } elseif ($adapter.InterfaceDescription -match "Ethernet|LAN|Gigabit") {
                if ("Ethernet" -notin $netTypes) { $netTypes += "Ethernet" }
            }
        }
    }
    
    # Check internet connectivity using DNS query (faster, no banner)
    $internetStatus = "Disconnected"
    try {
        $null = [System.Net.Dns]::GetHostAddresses("www.google.com")
        $internetStatus = "Connected"
    } catch {
        $internetStatus = "Disconnected"
    }
    
    $netMode = if ($netTypes.Count -gt 0) { $netTypes -join " + " } else { "Unknown" }
    $netIP = if ($ipAddresses.Count -gt 0) { $ipAddresses[0] } else { "No IP" }
    $netInfo = "$netMode ($netIP) - $internetStatus"
    
    # Deep Freeze Status Check
    $dfStatus = "Not Installed"
    $dfColor  = "Gray"
    
    if (Test-Path $DFPath) {
        # DFC get /ISFROZEN returns exit code: 0 = Thawed, 1 = Frozen
        try {
            $null = & $DFPath get /ISFROZEN 2>&1
            if ($LASTEXITCODE -eq 1) { 
                $dfStatus = "FROZEN"; $dfColor = "Cyan" 
            } elseif ($LASTEXITCODE -eq 0) { 
                $dfStatus = "THAWED"; $dfColor = "Red" 
            } else {
                $dfStatus = "Unknown (Code: $LASTEXITCODE)"; $dfColor = "Yellow"
            }
        } catch {
            $dfStatus = "Error Reading Status"; $dfColor = "Yellow"
        }
    }

    return [PSCustomObject]@{
        Name = $hostname
        Model = $model
        OS = $osInfo
        BootTime = $bootTimeString
        Uptime = $uptimeString
        Mobo = $board
        RAM  = "$mem GB"
        Net  = $netInfo
        NetStatus = $internetStatus
        DF   = $dfStatus
        DFCol = $dfColor
    }
}

function Draw-Header {
    param($Info, $Version, $Breadcrumb = "Main Menu", $Subtitle = "", [switch]$NoClear)
    $script:HasScrollText = $false
    if ($NoClear) { [Console]::SetCursorPosition(0, 0) } else { Clear-Host }
    
    # Modern ASCII Banner with box drawing
    Write-Host ""
    Write-Host ("  " + [char]0x2554 + ([string]([char]0x2550) * 71) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host (" " * 71) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    $a1 = "                      " + [char]0x2588 + [char]0x2584 + [char]0x2588 + " " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + "   " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2584 + [char]0x2580 + [char]0x2588
    Write-Host $a1 -NoNewline -ForegroundColor Cyan
    $hp1 = 71 - $a1.Length; if ($hp1 -lt 0) { $hp1 = 1 }
    Write-Host (" " * $hp1) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    $a2 = "                      " + [char]0x2588 + [char]0x2591 + [char]0x2588 + " " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + " " + [char]0x2588 + [char]0x2580 + " " + "   " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588
    Write-Host $a2 -NoNewline -ForegroundColor Cyan
    $hp2 = 71 - $a2.Length; if ($hp2 -lt 0) { $hp2 = 1 }
    Write-Host (" " * $hp2) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host (" " * 71) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    $mtcpText = "                  MULTI-TOOL CONTROL PANEL v$Version"
    Write-Host $mtcpText -NoNewline -ForegroundColor Gray
    $spaces = 71 - $mtcpText.Length; if ($spaces -lt 0) { $spaces = 1 }
    Write-Host (" " * $spaces) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host "                         Technical Assistants" -NoNewline -ForegroundColor DarkCyan
    Write-Host (" " * 26) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Cyan
    Write-Host (" " * 71) -NoNewline
    Write-Host ([char]0x2551) -ForegroundColor Cyan
    Write-Host ("  " + [char]0x255A + ([string]([char]0x2550) * 71) + [char]0x255D) -ForegroundColor Cyan
    Write-Host ""

    # Modern Info Grid with Icons
    Write-Host ("  " + [char]0x250C + ([string]([char]0x2500) * 71) + [char]0x2510) -ForegroundColor DarkCyan
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkCyan
    Write-Host "💻 " -NoNewline -ForegroundColor Yellow
    Write-Host "HOST: " -NoNewline -ForegroundColor DarkGray; Write-ScrollText -Text "$($Info.Name)" -Color "White"
    Write-BorderEnd -Color "DarkCyan"
    
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkCyan
    Write-Host "🖥️  " -NoNewline -ForegroundColor Yellow
    Write-Host "MODEL: " -NoNewline -ForegroundColor DarkGray; Write-ScrollText -Text "$($Info.Model)" -Color "White"
    Write-BorderEnd -Color "DarkCyan"
    
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkCyan
    Write-Host "🪟 " -NoNewline -ForegroundColor Yellow
    Write-Host "OS: " -NoNewline -ForegroundColor DarkGray; Write-ScrollText -Text "$($Info.OS)" -Color "White"
    Write-BorderEnd -Color "DarkCyan"
    
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkCyan
    Write-Host "⏱️  " -NoNewline -ForegroundColor Yellow
    Write-Host "UPTIME: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.Uptime)" -NoNewline -ForegroundColor White
    Write-Host " " -NoNewline; Write-Host ([char]0x2502) -NoNewline -ForegroundColor DarkGray; Write-Host " " -NoNewline
    Write-Host "BOOT: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.BootTime)" -NoNewline -ForegroundColor White
    Write-BorderEnd -Color "DarkCyan"
    
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkCyan
    if ($Info.NetStatus -eq "Connected") { 
        Write-Host "🌐 " -NoNewline -ForegroundColor Green
        Write-Host "NETWORK: " -NoNewline -ForegroundColor DarkGray
        Write-Host "ONLINE" -NoNewline -ForegroundColor Green
    } else { 
        Write-Host "🌐 " -NoNewline -ForegroundColor Red
        Write-Host "NETWORK: " -NoNewline -ForegroundColor DarkGray
        Write-Host "OFFLINE" -NoNewline -ForegroundColor Red
    }
    Write-Host " " -NoNewline; Write-Host ([char]0x2502) -NoNewline -ForegroundColor DarkGray; Write-Host " " -NoNewline
    Write-Host "$($Info.Net)" -NoNewline -ForegroundColor White
    Write-BorderEnd -Color "DarkCyan"
    
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkCyan
    Write-Host "🔩 " -NoNewline -ForegroundColor Yellow
    Write-Host "MOBO: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.Mobo)" -NoNewline -ForegroundColor White
    Write-Host " " -NoNewline; Write-Host ([char]0x2502) -NoNewline -ForegroundColor DarkGray; Write-Host " " -NoNewline
    Write-Host "💾 " -NoNewline -ForegroundColor Yellow
    Write-Host "RAM: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.RAM)" -NoNewline -ForegroundColor White
    Write-BorderEnd -Color "DarkCyan"

    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkCyan
    if ($Info.DF -eq "FROZEN") {
        Write-Host "❄️  " -NoNewline -ForegroundColor Cyan
    } elseif ($Info.DF -eq "THAWED") {
        Write-Host "🔥 " -NoNewline -ForegroundColor Red
    } else {
        Write-Host "🔒 " -NoNewline -ForegroundColor Gray
    }
    Write-Host "DEEP FREEZE: " -NoNewline -ForegroundColor DarkGray
    Write-Host " $($Info.DF) " -ForegroundColor Black -BackgroundColor $Info.DFCol -NoNewline
    Write-BorderEnd -Color "DarkCyan"
    Write-Host ("  " + [char]0x2514 + ([string]([char]0x2500) * 71) + [char]0x2518) -ForegroundColor DarkCyan
    
    Write-Host ""
    Write-Host ("  " + [char]0x250C + ([string]([char]0x2500) * 71) + [char]0x2510) -ForegroundColor DarkGray
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
    Write-Host "📍 " -NoNewline -ForegroundColor Yellow
    Write-Host "$Breadcrumb" -NoNewline -ForegroundColor White
    Write-BorderEnd -Color "DarkGray"
    if ($Subtitle) {
        Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
        Write-Host "ℹ️  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "$Subtitle" -NoNewline -ForegroundColor DarkCyan
        Write-BorderEnd -Color "DarkGray"
    }
    Write-Host ("  " + [char]0x2514 + ([string]([char]0x2500) * 71) + [char]0x2518) -ForegroundColor DarkGray
    Write-Host ""
    $dfAction = if ($Info.DF -eq "FROZEN") { "Thaw" } elseif ($Info.DF -eq "THAWED") { "Freeze" } else { "DF" }
    Write-Host "  ⌨️  " -NoNewline -ForegroundColor Yellow
    Write-Host "`[ENTER`]" -NoNewline -ForegroundColor Black -BackgroundColor White
    Write-Host " Run  " -NoNewline -ForegroundColor Yellow
    Write-Host "`[◄►`]" -NoNewline -ForegroundColor Black -BackgroundColor White
    Write-Host " Nav  " -NoNewline -ForegroundColor Yellow
    Write-Host "`[W`]" -NoNewline -ForegroundColor Black -BackgroundColor White
    Write-Host " Wallpaper  " -NoNewline -ForegroundColor Yellow
    Write-Host "`[D`]" -NoNewline -ForegroundColor Black -BackgroundColor White
    Write-Host " $dfAction  " -NoNewline -ForegroundColor Yellow
    Write-Host "`[E`]" -NoNewline -ForegroundColor White -BackgroundColor Red
    Write-Host " Exit" -ForegroundColor Red
    Write-Host "  " -NoNewline
    Write-Host ([string]([char]0x2500) * 71) -ForegroundColor DarkGray
}

function Draw-Menu {
    param($MenuItems, $Selection)
    
    # Save cursor position to return here
    $startPos = [Console]::CursorTop
    
    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $prefix = "    "
        $color = "White"
        $icon = ""
        
        # Add icons and colors based on item type
        if ($MenuItems[$i].Type -eq "category") {
            $icon = Get-Icon "categories" "default"
            $color = "Gray"
        } elseif ($MenuItems[$i].Type -eq "subcategory") {
            $icon = Get-Icon "ui" "folder_open"
            $color = "DarkGray"
        } else {
            $icon = Get-Icon "tools" "default"
            $color = "White"
        }
        
        if ($i -eq $Selection) {
            $prefix = "  $([char]0x25B6) "
            if ($MenuItems[$i].Type -eq "category") {
                Write-Host "$prefix$icon$($MenuItems[$i].Name)" -ForegroundColor Black -BackgroundColor White
            } elseif ($MenuItems[$i].Type -eq "subcategory") {
                Write-Host "$prefix$icon$($MenuItems[$i].Name)" -ForegroundColor Black -BackgroundColor Gray
            } else {
                Write-Host "$prefix$icon$($MenuItems[$i].Name)" -ForegroundColor Black -BackgroundColor Cyan
            }
        } else {
            Write-Host "$prefix$icon$($MenuItems[$i].Name)" -ForegroundColor $color
        }
    }
}

function Draw-Footer {
    param($Version, $Author)
    
    # Calculate cursor position for bottom of window
    $windowHeight = 43
    $currentPos = [Console]::CursorTop
    $linesToBottom = $windowHeight - $currentPos - 2
    
    if ($linesToBottom -gt 0) {
        Write-Host ("`n" * $linesToBottom)
    }
    
    Write-Host "  $([char]0x2554)$([string]([char]0x2550) * 71)$([char]0x2557)" -ForegroundColor DarkGray
    Write-Host "  $([char]0x2551) " -NoNewline -ForegroundColor DarkGray
    
    # Navigation hints
    Write-Host "$([char]0x25B2)" -NoNewline -ForegroundColor Yellow
    Write-Host "/" -NoNewline -ForegroundColor DarkGray
    Write-Host "$([char]0x25BC)" -NoNewline -ForegroundColor Yellow
    Write-Host " Nav  " -NoNewline -ForegroundColor White
    Write-Host "`[ESC`]" -NoNewline -ForegroundColor White -BackgroundColor Red
    Write-Host " Exit  " -NoNewline -ForegroundColor White
    Write-Host "`[/`]" -NoNewline -ForegroundColor Black -BackgroundColor Cyan
    Write-Host " Command" -NoNewline -ForegroundColor White
    
    # Right-align version and author
    $rightText = "v$Version $([char]0x2502) $Author"
    $targetCol = 74
    $cur = [Console]::CursorLeft
    $rightLen = $rightText.Length + 1  # +1 for trailing space before border
    $spacesNeeded = $targetCol - $cur - $rightLen
    if ($spacesNeeded -gt 0) {
        Write-Host (" " * $spacesNeeded) -NoNewline
    }
    Write-Host $rightText -NoNewline -ForegroundColor DarkGray
    Write-Host " $([char]0x2551)" -ForegroundColor DarkGray
    Write-Host "  $([char]0x255A)$([string]([char]0x2550) * 71)$([char]0x255D)" -ForegroundColor DarkGray
}

function Manage-DeepFreeze {
    param($Action)
    
    if (-not (Test-Path $DFPath)) {
        Write-Warning "Deep Freeze executable (DFC.exe) not found in SysWOW64."
        Start-Sleep 2
        return
    }

    $confirm = Read-Host "Are you sure you want to $Action Deep Freeze? (Y/N)"
    if ($confirm -eq 'Y') {
        # Note: DFC usually requires a password argument like: DFC password /ThawedNextBoot
        $pw = Read-Host "Enter Deep Freeze Password (leave blank if none)" -AsSecureString
        $plainPw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw))
        
        $args = if ($plainPw) { @($plainPw) } else { @() }
        
        if ($Action -eq "THAW") {
            $args += "/BOOTTHAWED" 
        } else {
            $args += "/BOOTFROZEN"
        }

        try {
            Start-Process -FilePath $DFPath -ArgumentList $args -Wait -NoNewWindow
            Write-Host "`nCommand sent. Reboot may be required." -ForegroundColor Green
        } catch {
            Write-Error "Failed to execute DFC."
        }
        Pause
    }
}

function Show-DebugMenu {
    param(
        [string]$Version,
        [string]$ScriptRoot
    )
    
    # Get process information
    $procInfo = Get-ProcessInfo
    
    Clear-Host
    Write-Host ""
    Write-Host ("  " + [char]0x2554 + ([string]([char]0x2550) * 71) + [char]0x2557) -ForegroundColor Yellow
    Write-Host ("  " + [char]0x2551) -NoNewline -ForegroundColor Yellow
    Write-Host "                               🐛 DEBUG MENU" -NoNewline -ForegroundColor Yellow
    Write-BorderEnd -Char ([string][char]0x2551) -Color "Yellow"
    Write-Host ("  " + [char]0x255A + ([string]([char]0x2550) * 71) + [char]0x255D) -ForegroundColor Yellow
    Write-Host ""
    Write-Host ("  " + [char]0x250C + ([string]([char]0x2500) * 71) + [char]0x2510) -ForegroundColor DarkGray
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
    Write-Host "📊 Version: " -NoNewline -ForegroundColor White
    Write-Host "v$Version" -NoNewline -ForegroundColor Cyan
    Write-BorderEnd -Color "DarkGray"
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
    Write-Host "📋 Path: " -NoNewline -ForegroundColor White
    $shortPath = $ScriptRoot.Replace($env:USERPROFILE, "~")
    Write-Host "$shortPath" -NoNewline -ForegroundColor Gray
    Write-BorderEnd -Color "DarkGray"
    Write-Host ("  " + [char]0x2514 + ([string]([char]0x2500) * 71) + [char]0x2518) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  📊 Process Information:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    💻 CPU Time:     " -NoNewline -ForegroundColor Cyan
    Write-Host "$($procInfo.CPU)" -ForegroundColor White
    Write-Host "    💾 Memory Usage: " -NoNewline -ForegroundColor Cyan
    Write-Host "$($procInfo.Memory)" -ForegroundColor White
    Write-Host "    🧵 Threads:      " -NoNewline -ForegroundColor Cyan
    Write-Host "$($procInfo.Threads)" -ForegroundColor White
    Write-Host "    🔗 Handles:      " -NoNewline -ForegroundColor Cyan
    Write-Host "$($procInfo.Handles)" -ForegroundColor White
    Write-Host "    ⏰ Start Time:   " -NoNewline -ForegroundColor Cyan
    Write-Host "$($procInfo.StartTime)" -ForegroundColor White
    Write-Host "    🆔 Process ID:   " -NoNewline -ForegroundColor Cyan
    Write-Host "$PID" -ForegroundColor White
    Write-Host "    📐 Window Size:  " -NoNewline -ForegroundColor Cyan
    Write-Host "$($Host.UI.RawUI.WindowSize.Width)x$($Host.UI.RawUI.WindowSize.Height) (Buffer: $($Host.UI.RawUI.BufferSize.Width)x$($Host.UI.RawUI.BufferSize.Height))" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔧 Debug Options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    1. 🔄 Check for Updates Manually" -ForegroundColor White
    Write-Host "    2. 📝 View Configuration Files" -ForegroundColor White
    Write-Host "    3. 📊 System Diagnostics" -ForegroundColor White
    Write-Host "    4. 🐛 Toggle Debug Mode" -ForegroundColor White
    Write-Host "    5. ❌ Exit Debug Menu" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Select option (1-5): " -NoNewline -ForegroundColor Yellow
    
    $choice = [Console]::ReadKey($true)
    
    switch ($choice.KeyChar) {
        '1' {
            # Manual update check
            Clear-Host
            Write-Host ""
            Write-Host "  🔄 Checking for updates..." -ForegroundColor Yellow
            Write-Host ""
            
            $updateCheckScript = Join-Path $ScriptRoot "sfu-tools\Check-Update.ps1"
            if (Test-Path $updateCheckScript) {
                $updateInfo = & $updateCheckScript -CurrentVersion $Version
                
                if ($updateInfo -and $updateInfo.UpdateAvailable) {
                    Write-Host "  ✅ Update available!" -ForegroundColor Green
                    Write-Host "     Current: v$($updateInfo.CurrentVersion)" -ForegroundColor White
                    Write-Host "     Latest:  v$($updateInfo.RemoteVersion)" -ForegroundColor Cyan
                    Write-Host ""
                    $confirm = Read-Host "  Install update? (Y/N)"
                    if ($confirm -eq 'Y') {
                        $installScript = Join-Path $ScriptRoot "sfu-tools\Install-Update.ps1"
                        if (Test-Path $installScript) {
                            & $installScript -DownloadUrl $updateInfo.DownloadUrl -CurrentVersion $updateInfo.CurrentVersion -NewVersion $updateInfo.RemoteVersion
                            Exit
                        }
                    }
                } else {
                    Write-Host "  ✅ You are running the latest version!" -ForegroundColor Green
                }
            } else {
                Write-Host "  ❌ Update check script not found" -ForegroundColor Red
            }
            
            Write-Host ""
            Read-Host "  Press Enter to continue"
        }
        '2' {
            # View config files
            Clear-Host
            Write-Host ""
            Write-Host "  📝 Configuration Files:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  config.json:" -ForegroundColor Cyan
            Get-Content (Join-Path $ScriptRoot "sfu-tools\config.json") | Write-Host -ForegroundColor Gray
            Write-Host ""
            Read-Host "  Press Enter to continue"
        }
        '3' {
            # System diagnostics
            Clear-Host
            Write-Host ""
            Write-Host "  📊 System Diagnostics:" -ForegroundColor Yellow
            Write-Host ""
            $sysInfo = Get-SysInfo
            Write-Host "  Hostname:    $($sysInfo.Name)" -ForegroundColor White
            Write-Host "  Model:       $($sysInfo.Model)" -ForegroundColor White
            Write-Host "  OS:          $($sysInfo.OS)" -ForegroundColor White
            Write-Host "  Uptime:      $($sysInfo.Uptime)" -ForegroundColor White
            Write-Host "  RAM:         $($sysInfo.RAM)" -ForegroundColor White
            Write-Host "  Network:     $($sysInfo.Net)" -ForegroundColor White
            Write-Host "  Deep Freeze: $($sysInfo.DF)" -ForegroundColor White
            Write-Host ""
            Read-Host "  Press Enter to continue"
        }
        '4' {
            # Toggle debug mode
            $script:DebugMode = -not $script:DebugMode
            $status = if ($script:DebugMode) { "ENABLED" } else { "DISABLED" }
            Clear-Host
            Write-Host ""
            Write-Host "  🐛 Debug Mode: $status" -ForegroundColor $(if ($script:DebugMode) { "Green" } else { "Red" })
            Write-Host ""
            Start-Sleep -Seconds 1
        }
        '5' {
            # Exit debug menu
            return
        }
        default {
            # Invalid choice
            Clear-Host
            Write-Host ""
            Write-Host "  ❌ Invalid option" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

# --- Main Logic ---

# 1. Load Config
if (-not (Test-Path $ConfigPath)) {
    $errorMsg = "The configuration file could not be found at:`n  $ConfigPath`n`n  Please ensure the config.json file exists in the sfu-tools directory."
    Show-BSOD -ErrorTitle "CONFIG_FILE_NOT_FOUND" -ErrorMessage $errorMsg -ErrorCode "0xC0000001"
}

# Load Icons
$script:Icons = $null
if (Test-Path $IconsPath) {
    try {
        $script:Icons = Get-Content $IconsPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning "Could not load icons file: $($_.Exception.Message)"
    }
}

try {
    $json = Get-Content $ConfigPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    
    # Validate required properties
    if (-not $json.categories) {
        $errorMsg = "The configuration file is missing the categories property.`n`n  File: $ConfigPath`n`n  Please check the JSON structure."
        Show-BSOD -ErrorTitle "CONFIG_FILE_CORRUPTED" -ErrorMessage $errorMsg -ErrorCode "0xC0000002"
    }
    
    if (-not $json.meta -or -not $json.meta.version) {
        $errorMsg = "The configuration file is missing version information.`n`n  File: $ConfigPath`n`n  Please check the JSON structure (meta.version)."
        Show-BSOD -ErrorTitle "CONFIG_FILE_CORRUPTED" -ErrorMessage $errorMsg -ErrorCode "0xC0000003"
    }
    
    $Categories = $json.categories
    $Version = $json.meta.version
    $Author = if ($json.meta.author) { $json.meta.author } else { "Technical Assistants" }
    
    # Load slash commands
    $script:SlashCommands = @{}
    if ($json.commands) {
        foreach ($cmdName in $json.commands.PSObject.Properties.Name) {
            $script:SlashCommands[$cmdName] = $json.commands.$cmdName
        }
    }
    
    # Build hotkey map for quick access
    $HotkeyMap = @{}
    foreach ($cat in $Categories) {
        if ($cat.tools) {
            foreach ($tool in $cat.tools) {
                if ($tool.hotkey) {
                    $HotkeyMap[$tool.hotkey] = $tool.command
                }
            }
        }
        if ($cat.subcategories) {
            foreach ($subcat in $cat.subcategories) {
                if ($subcat.tools) {
                    foreach ($tool in $subcat.tools) {
                        if ($tool.hotkey) {
                            $HotkeyMap[$tool.hotkey] = $tool.command
                        }
                    }
                }
            }
        }
    }
    
    # Update window title with version
    $Host.UI.RawUI.WindowTitle = "TECHNICAL ASSISTANTS v$Version - Multi-Tool Panel"
    
} catch {
    $errorMsg = "The configuration file could not be parsed.`n`n  File: $ConfigPath`n  Error: $($_.Exception.Message)`n`n  Please check the JSON syntax."
    Show-BSOD -ErrorTitle "CONFIG_FILE_CORRUPTED" -ErrorMessage $errorMsg -ErrorCode "0xC0000004"
}

# Check for updates with loading screen
Show-LoadingScreen -Version $Version

$updateCheckScript = Join-Path $ScriptRoot "sfu-tools\Check-Update.ps1"
$updateInfo = $null

if (Test-Path $updateCheckScript) {
    $updateJob = Start-Job -ScriptBlock {
        param($ScriptPath, $CurrentVersion)
        & $ScriptPath -CurrentVersion $CurrentVersion -Silent
    } -ArgumentList $updateCheckScript, $Version
    
    # Wait up to 5 seconds for update check to complete
    $timeout = 50 # 50 x 100ms = 5 seconds
    $count = 0
    while ($count -lt $timeout -and $updateJob.State -eq "Running") {
        Start-Sleep -Milliseconds 100
        $count++
    }
    
    # Check if job completed
    if ($updateJob.State -eq "Completed") {
        $updateInfo = Receive-Job -Job $updateJob
        Remove-Job -Job $updateJob
        
        # If update available, show notification
        if ($updateInfo -and $updateInfo.UpdateAvailable) {
            $shouldUpdate = Show-UpdateNotification -CurrentVersion $updateInfo.CurrentVersion -NewVersion $updateInfo.RemoteVersion -DownloadUrl $updateInfo.DownloadUrl
            
            if ($shouldUpdate) {
                $installScript = Join-Path $ScriptRoot "sfu-tools\Install-Update.ps1"
                if (Test-Path $installScript) {
                    & $installScript -DownloadUrl $updateInfo.DownloadUrl -CurrentVersion $updateInfo.CurrentVersion -NewVersion $updateInfo.RemoteVersion
                    Exit
                }
            }
        }
    } elseif ($updateJob.State -eq "Running") {
        # Timeout - stop the job
        Stop-Job -Job $updateJob
        Remove-Job -Job $updateJob -Force
    } else {
        # Job failed
        Remove-Job -Job $updateJob -Force
    }
}

# 2. Navigation State
$navStack = @()
$currentView = "categories"
$currentCategory = $null
$currentSubcategory = $null
$selection = 0
$running = $true
$needsFullRedraw = $true
$menuStartLine = 0
$sysInfo = $null

while ($running) {
    # Determine what to display
    $menuItems = @()
    $breadcrumb = "Main Menu"
    $subtitle = ""
    
    if ($currentView -eq "categories") {
        $menuItems = $Categories | ForEach-Object { [PSCustomObject]@{ Name = $_.name; Type = "category"; Data = $_ } }
        $breadcrumb = "Main Menu"
        $subtitle = "Select a category to continue"
    }
    elseif ($currentView -eq "subcategories") {
        $menuItems = $currentCategory.subcategories | ForEach-Object { [PSCustomObject]@{ Name = $_.name; Type = "subcategory"; Data = $_ } }
        $breadcrumb = "Main Menu ``> $($currentCategory.name)"
        $subtitle = $currentCategory.description
    }
    elseif ($currentView -eq "tools") {
        if ($currentSubcategory) {
            $menuItems = $currentSubcategory.tools | ForEach-Object { [PSCustomObject]@{ Name = $_.name; Type = "tool"; Data = $_ } }
            $breadcrumb = "Main Menu > $($currentCategory.name) ``> $($currentSubcategory.name)"
        } else {
            $menuItems = $currentCategory.tools | ForEach-Object { [PSCustomObject]@{ Name = $_.name; Type = "tool"; Data = $_ } }
            $breadcrumb = "Main Menu ``> $($currentCategory.name)"
            $subtitle = $currentCategory.description
        }
        # Update subtitle with selected tool description
        if ($menuItems.Count -gt 0 -and $selection -ge 0 -and $selection -lt $menuItems.Count) {
            $selectedTool = $menuItems[$selection]
            if ($selectedTool.Data.description) {
                $subtitle = $selectedTool.Data.description
            }
        }
    }
    
    # Full redraw when needed (view change, initial load)
    if ($needsFullRedraw) {
        $sysInfo = Get-SysInfo
        $needsFullRedraw = $false
    }
    Draw-Header -Info $sysInfo -Version $Version -Breadcrumb $breadcrumb -Subtitle $subtitle
    $menuStartLine = [Console]::CursorTop
    Draw-Menu -MenuItems $menuItems -Selection $selection
    Draw-Footer -Version $Version -Author $Author

    # Input Handling with scroll animation
    $key = $null
    $scrollTimer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($key -eq $null) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
        } else {
            if ($script:HasScrollText -and $scrollTimer.ElapsedMilliseconds -ge 300) {
                $script:ScrollTick++
                $scrollTimer.Restart()
                Draw-Header -Info $sysInfo -Version $Version -Breadcrumb $breadcrumb -Subtitle $subtitle -NoClear
                $menuStartLine = [Console]::CursorTop
                Draw-Menu -MenuItems $menuItems -Selection $selection
                Draw-Footer -Version $Version -Author $Author
            }
            Start-Sleep -Milliseconds 50
        }
    }
    
    switch ($key.Key) {
        "UpArrow" {
            if ($selection -gt 0) { $selection-- }
            # No full redraw needed for navigation
        }
        "DownArrow" {
            if ($selection -lt ($menuItems.Count - 1)) { $selection++ }
        }
        "RightArrow" {
            if ($menuItems.Count -eq 0) { continue }
            $selected = $menuItems[$selection]
            if ($selected.Type -eq "category") {
                $currentCategory = $selected.Data
                if ($currentCategory.subcategories) {
                    $currentView = "subcategories"
                } else {
                    $currentView = "tools"
                }
                $selection = 0
                $needsFullRedraw = $true
            }
            elseif ($selected.Type -eq "subcategory") {
                $currentSubcategory = $selected.Data
                $currentView = "tools"
                $selection = 0
                $needsFullRedraw = $true
            }
            # Do nothing for tools - must press Enter to run
        }
        "LeftArrow" {
            if ($currentView -eq "subcategories") {
                $currentView = "categories"
                $currentCategory = $null
                $selection = 0
                $needsFullRedraw = $true
            }
            elseif ($currentView -eq "tools") {
                if ($currentSubcategory) {
                    $currentView = "subcategories"
                    $currentSubcategory = $null
                } else {
                    $currentView = "categories"
                    $currentCategory = $null
                }
                $selection = 0
                $needsFullRedraw = $true
            }
            # Do nothing at categories level (no exit)
        }
        "Enter" {
            if ($menuItems.Count -eq 0) { continue }
            
            $selected = $menuItems[$selection]
            
            if ($selected.Type -eq "category") {
                $currentCategory = $selected.Data
                if ($currentCategory.subcategories) {
                    $currentView = "subcategories"
                } else {
                    $currentView = "tools"
                }
                $selection = 0
                $needsFullRedraw = $true
            }
            elseif ($selected.Type -eq "subcategory") {
                $currentSubcategory = $selected.Data
                $currentView = "tools"
                $selection = 0
                $needsFullRedraw = $true
            }
            elseif ($selected.Type -eq "tool") {
                $cmd = $selected.Data.command
                # Replace $PSScriptRoot with actual script root path
                $cmd = $cmd -replace '\$PSScriptRoot', $ScriptRoot
                Clear-Host
                Write-Host "Executing: $($selected.Data.name)..." -ForegroundColor Yellow
                Write-Host ""
                Invoke-Expression $cmd
                Write-Host ""
                Write-Host "Done." -ForegroundColor Green
                Read-Host "`nPress Enter to continue"
                $needsFullRedraw = $true
            }
        }
        "Escape" {
            if ($currentView -eq "categories") {
                # At top level, just ignore Escape
                continue
            }
            elseif ($currentView -eq "subcategories") {
                $currentView = "categories"
                $currentCategory = $null
                $selection = 0
                $needsFullRedraw = $true
            }
            elseif ($currentView -eq "tools") {
                if ($currentSubcategory) {
                    $currentView = "subcategories"
                    $currentSubcategory = $null
                } else {
                    $currentView = "categories"
                    $currentCategory = $null
                }
                $selection = 0
                $needsFullRedraw = $true
            }
        }
        default {
            # Check for hotkeys
            $keyChar = $key.KeyChar.ToString().ToUpper()
            # Command input with / key (Minecraft style)
            if ($key.KeyChar -eq '/') {
                # Draw command popup over footer area
                $windowHeight = 43
                $popupRow = $windowHeight - 5
                $boxW = 71
                $tl = [char]0x2554; $tr = [char]0x2557; $bl = [char]0x255A; $br = [char]0x255D
                $hz = [string]([char]0x2550); $vt = [char]0x2551
                
                [Console]::SetCursorPosition(0, $popupRow)
                Write-Host ("  $tl" + ($hz * $boxW) + "$tr") -ForegroundColor Cyan
                [Console]::SetCursorPosition(0, $popupRow + 1)
                Write-Host "  $vt " -NoNewline -ForegroundColor Cyan
                Write-Host "Enter command: " -NoNewline -ForegroundColor Yellow
                Write-Host "/" -NoNewline -ForegroundColor Cyan
                $cmdStartCol = [Console]::CursorLeft
                $inputRowLen = 18  # length of ' Enter command: /'
                $padR = $boxW - $inputRowLen
                if ($padR -gt 0) { Write-Host (" " * $padR) -NoNewline }
                Write-Host "$vt" -ForegroundColor Cyan
                [Console]::SetCursorPosition(0, $popupRow + 2)
                Write-Host "  $vt " -NoNewline -ForegroundColor Cyan
                Write-Host "Type a command and press " -NoNewline -ForegroundColor DarkGray
                Write-Host "ENTER" -NoNewline -ForegroundColor White
                Write-Host " or " -NoNewline -ForegroundColor DarkGray
                Write-Host "ESC" -NoNewline -ForegroundColor Red
                Write-Host " to cancel" -NoNewline -ForegroundColor DarkGray
                $cur2 = [Console]::CursorLeft; $pad2 = 74 - $cur2; if ($pad2 -lt 0) { $pad2 = 0 }
                Write-Host (" " * $pad2) -NoNewline
                Write-Host "$vt" -ForegroundColor Cyan
                [Console]::SetCursorPosition(0, $popupRow + 3)
                Write-Host ("  $bl" + ($hz * $boxW) + "$br") -ForegroundColor Cyan
                
                # Position cursor after /
                [Console]::CursorVisible = $true
                [Console]::SetCursorPosition($cmdStartCol, $popupRow + 1)
                
                # Read command input
                $cmdInput = ""
                $inputRunning = $true
                
                while ($inputRunning) {
                    if ([Console]::KeyAvailable) {
                        $inputKey = [Console]::ReadKey($true)
                        
                        if ($inputKey.Key -eq "Enter") {
                            $inputRunning = $false
                        } elseif ($inputKey.Key -eq "Escape") {
                            $cmdInput = ""
                            $inputRunning = $false
                        } elseif ($inputKey.Key -eq "Backspace" -and $cmdInput.Length -gt 0) {
                            $cmdInput = $cmdInput.Substring(0, $cmdInput.Length - 1)
                            [Console]::SetCursorPosition($cmdStartCol + $cmdInput.Length, $popupRow + 1)
                            Write-Host " " -NoNewline
                            [Console]::SetCursorPosition($cmdStartCol + $cmdInput.Length, $popupRow + 1)
                        } elseif ($inputKey.KeyChar -match '[a-zA-Z0-9\-_/ ]') {
                            $cmdInput += $inputKey.KeyChar
                            Write-Host $inputKey.KeyChar -NoNewline -ForegroundColor White
                        }
                    }
                    Start-Sleep -Milliseconds 50
                }
                [Console]::CursorVisible = $false
                
                # Execute command if not empty
                if ($cmdInput.Trim().Length -gt 0) {
                    $result = Invoke-SlashCommand -CommandName $cmdInput -Commands $script:SlashCommands -Version $Version -Author $Author -ScriptRoot $ScriptRoot
                    if ($result -is [string] -and $result -eq "EXIT") {
                        $running = $false
                    }
                }
                
                $needsFullRedraw = $true
                continue
            }
            # Exit with E key
            if ($keyChar -eq "E") {
                Clear-Host
                Write-Host ""
                Write-Host ""
                Write-Host "  ========================================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "                  Are you sure you want to exit?" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "  ========================================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  " -NoNewline
                Write-Host "`[Y`]" -ForegroundColor Black -BackgroundColor White -NoNewline
                Write-Host " Yes, Exit  " -ForegroundColor White -NoNewline
                Write-Host "`[N`]" -ForegroundColor Black -BackgroundColor White -NoNewline
                Write-Host " No, Go Back" -ForegroundColor White
                Write-Host ""
                
                while ($true) {
                    $confirmKey = [Console]::ReadKey($true)
                    $confirmChar = $confirmKey.KeyChar.ToString().ToUpper()
                    if ($confirmChar -eq "Y") {
                        $running = $false
                        break
                    } elseif ($confirmChar -eq "N" -or $confirmKey.Key -eq "Escape") {
                        $needsFullRedraw = $true
                        break
                    }
                }
                continue
            }
            # Deep Freeze toggle hotkey
            if ($keyChar -eq "D") {
                $toggleScript = Join-Path $ScriptRoot "sfu-tools\Toggle-DeepFreeze.ps1"
                if (Test-Path $toggleScript) {
                    Clear-Host
                    & $toggleScript
                    Read-Host "`nPress Enter to continue"
                    $needsFullRedraw = $true
                } else {
                    Clear-Host
                    Write-Host "Deep Freeze toggle script not found." -ForegroundColor Red
                    Read-Host "`nPress Enter to continue"
                    $needsFullRedraw = $true
                }
            }
            elseif ($HotkeyMap.ContainsKey($keyChar)) {
                $cmd = $HotkeyMap[$keyChar]
                # Replace $PSScriptRoot with actual script root path
                $cmd = $cmd -replace '\$PSScriptRoot', $ScriptRoot
                Clear-Host
                Write-Host "Executing hotkey action..." -ForegroundColor Yellow
                Write-Host ""
                Invoke-Expression $cmd
                Write-Host ""
                Write-Host "Done." -ForegroundColor Green
                Write-Host ""
                Read-Host "Press Enter to continue"
                $needsFullRedraw = $true
            }
        }
    }
}
[Console]::CursorVisible = $true
Clear-Host