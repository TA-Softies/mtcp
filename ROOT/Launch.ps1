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

# Set window size to match banner (76 chars wide, 35 lines tall)
try {
    $windowSize = New-Object System.Management.Automation.Host.Size(76, 35)
    $bufferSize = New-Object System.Management.Automation.Host.Size(76, 9999)
    $Host.UI.RawUI.WindowSize = $windowSize
    $Host.UI.RawUI.BufferSize = $bufferSize
} catch {
    # Ignore if window size cannot be set (e.g., in ISE or unsupported terminal)
}

Clear-Host

# --- Configuration ---
$ScriptRoot = $PSScriptRoot
$ConfigPath = Join-Path $ScriptRoot "sfu-tools\config.json"
$DFPath     = "C:\Windows\SysWOW64\DFC.exe" # Deep Freeze Console CLI
$AppTitle   = "TECHNICAL ASSISTANTS"

# --- Helper Functions ---

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
    $windowHeight = 35
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
    Write-Host "  ========================================================================" -ForegroundColor Cyan
    Write-Host ""
    $line1 = "  " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2588 + [char]0x2591 + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2591 + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2584 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2591 + [char]0x2591 + "   " + [char]0x2584 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + " " + [char]0x2588 + [char]0x2580 + " " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2584 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2591 + [char]0x2588 + " " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580
    $line2 = "  " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2588 + [char]0x2584 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2591 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + "   " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2584 + [char]0x2588 + " " + [char]0x2584 + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2584 + [char]0x2588 + " " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2591 + [char]0x2580 + [char]0x2588 + " " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2584 + [char]0x2588
    [Console]::WriteLine($line1)
    [Console]::WriteLine($line2)
    Write-Host ""
    Write-Host "                  MULTI-TOOL CONTROL PANEL v$Version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ""
    Write-Host ""
    Write-Host "                  Checking for updates" -ForegroundColor Yellow -NoNewline
    
    # Animated dots
    for ($i = 0; $i -lt 3; $i++) {
        Start-Sleep -Milliseconds 300
        Write-Host "." -NoNewline -ForegroundColor Yellow
    }
    
    Write-Host ""
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
    param($Info, $Version, $Breadcrumb = "Main Menu", $Subtitle = "")
    Clear-Host
    
    # ASCII Banner - TECHNICAL ASSISTANTS
    Write-Host ""
    Write-Host "  ========================================================================" -ForegroundColor Cyan
    Write-Host ""
    $line1 = "  " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2588 + [char]0x2591 + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2591 + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + [char]0x2580 + [char]0x2580 + " " + [char]0x2584 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2591 + [char]0x2591 + "   " + [char]0x2584 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + " " + [char]0x2588 + [char]0x2580 + " " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2584 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2591 + [char]0x2588 + " " + [char]0x2580 + [char]0x2588 + [char]0x2580 + " " + [char]0x2588 + [char]0x2580
    $line2 = "  " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2588 + [char]0x2584 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2591 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2584 + [char]0x2584 + "   " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2584 + [char]0x2588 + " " + [char]0x2584 + [char]0x2588 + " " + [char]0x2588 + " " + [char]0x2584 + [char]0x2588 + " " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2588 + [char]0x2580 + [char]0x2588 + " " + [char]0x2588 + [char]0x2591 + [char]0x2580 + [char]0x2588 + " " + [char]0x2591 + [char]0x2588 + [char]0x2591 + " " + [char]0x2584 + [char]0x2588
    [Console]::WriteLine($line1)
    [Console]::WriteLine($line2)
    Write-Host ""
    Write-Host "                  MULTI-TOOL CONTROL PANEL v$Version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ========================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Info Grid - Compact Layout
    # Row 1: System
    Write-Host " [SYS] " -NoNewline -ForegroundColor Yellow
    Write-Host "HOST: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.Name)" -ForegroundColor White
    
    Write-Host " [MDL] " -NoNewline -ForegroundColor Yellow
    Write-Host "MODEL: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.Model)" -ForegroundColor White
    
    Write-Host " [WIN] " -NoNewline -ForegroundColor Yellow
    Write-Host "NAME: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.OS)" -ForegroundColor White
    
    Write-Host " [UPT] " -NoNewline -ForegroundColor Yellow
    Write-Host "TIME: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.BootTime)" -NoNewline -ForegroundColor White
    Write-Host "  |  " -NoNewline -ForegroundColor DarkGray
    Write-Host "UPTIME: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.Uptime)" -ForegroundColor White
    
    Write-Host " [NET] " -NoNewline -ForegroundColor Yellow
    Write-Host "MODE: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.Net)" -NoNewline -ForegroundColor White
    Write-Host "  |  " -NoNewline -ForegroundColor DarkGray
    Write-Host "STATUS: " -NoNewline -ForegroundColor DarkGray
    if ($Info.NetStatus -eq "Connected") { Write-Host "ONLINE " -NoNewline -ForegroundColor Green } else { Write-Host "OFFLINE " -NoNewline -ForegroundColor Red }
    
    # Row 2: Hardware
    Write-Host "`n [H/W] " -NoNewline -ForegroundColor Yellow
    Write-Host "MOBO: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.Mobo)" -NoNewline -ForegroundColor White
    Write-Host "  |  " -NoNewline -ForegroundColor DarkGray
    Write-Host "RAM: " -NoNewline -ForegroundColor DarkGray; Write-Host "$($Info.RAM)" -ForegroundColor White

    # Column 3: Deep Freeze (Highlighted)
    Write-Host " [DFC] " -NoNewline -ForegroundColor Yellow
    Write-Host "STATUS: " -NoNewline -ForegroundColor DarkGray
    Write-Host " $($Info.DF) " -ForegroundColor Black -BackgroundColor $Info.DFCol
    
    Write-Host ("-" * 76) -ForegroundColor DarkGray
    Write-Host " Navigation: " -NoNewline -ForegroundColor Yellow
    Write-Host "$Breadcrumb" -ForegroundColor White
    if ($Subtitle) {
        Write-Host "             " -NoNewline
        Write-Host "$Subtitle" -ForegroundColor DarkCyan
    }
    Write-Host ("-" * 76) -ForegroundColor DarkGray
    $dfAction = if ($Info.DF -eq "FROZEN") { "Thaw" } elseif ($Info.DF -eq "THAWED") { "Freeze" } else { "DF" }
    Write-Host " [ENTER] Run  |  [W] Wallpaper  |  [D] $dfAction  |  " -NoNewline -ForegroundColor Yellow
    Write-Host "[ESC] Back/Exit" -ForegroundColor Red
    Write-Host ("-" * 76) -ForegroundColor DarkGray
}

function Draw-Menu {
    param($MenuItems, $Selection)
    
    # Save cursor position to return here
    $startPos = [Console]::CursorTop
    
    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $prefix = "   "
        $color = "White"
        $itemPrefix = ""
        
        # Add prefix and colors based on item type
        if ($MenuItems[$i].Type -eq "category") {
            $itemPrefix = "[+] "
            $color = "DarkGreen"
        } elseif ($MenuItems[$i].Type -eq "subcategory") {
            $itemPrefix = "[-] "
            $color = "Green"
        }
        
        if ($i -eq $Selection) {
            $prefix = " > "
            if ($MenuItems[$i].Type -eq "category") {
                Write-Host "$prefix$itemPrefix$($MenuItems[$i].Name)" -ForegroundColor Black -BackgroundColor DarkGreen
            } elseif ($MenuItems[$i].Type -eq "subcategory") {
                Write-Host "$prefix$itemPrefix$($MenuItems[$i].Name)" -ForegroundColor Black -BackgroundColor Green
            } else {
                Write-Host "$prefix$itemPrefix$($MenuItems[$i].Name)" -ForegroundColor Black -BackgroundColor Cyan
            }
        } else {
            Write-Host "$prefix$itemPrefix$($MenuItems[$i].Name)" -ForegroundColor $color
        }
    }
}

function Draw-Footer {
    param($Version, $Author)
    
    # Calculate cursor position for bottom of window (line 35)
    $windowHeight = 35
    $currentPos = [Console]::CursorTop
    $linesToBottom = $windowHeight - $currentPos - 3
    
    if ($linesToBottom -gt 0) {
        Write-Host ("`n" * $linesToBottom)
    }
    
    Write-Host ("=" * 76) -ForegroundColor DarkGray
    
    # Build footer line with proper escaping
    $upArrow = [char]0x2191
    $downArrow = [char]0x2193
    $leftBracket = [char]0x5B
    $rightBracket = [char]0x5D
    $pipeChar = [char]0x7C
    
    Write-Host " " -NoNewline
    Write-Host $leftBracket -NoNewline -ForegroundColor DarkGray
    [Console]::Write($upArrow)
    Write-Host "/" -NoNewline -ForegroundColor DarkGray
    [Console]::Write($downArrow)
    Write-Host $rightBracket -NoNewline -ForegroundColor DarkGray
    Write-Host " Navigate  " -NoNewline -ForegroundColor White
    Write-Host $leftBracket -NoNewline -ForegroundColor DarkGray
    Write-Host "ESC" -NoNewline -ForegroundColor Red
    Write-Host $rightBracket -NoNewline -ForegroundColor DarkGray
    Write-Host " Back/Exit" -NoNewline -ForegroundColor White
    
    # Right-align version and author
    $rightText = "v$Version $pipeChar $Author"
    $spacesNeeded = 76 - 37 - $rightText.Length
    if ($spacesNeeded -gt 0) {
        Write-Host (" " * $spacesNeeded) -NoNewline
    }
    Write-Host $rightText -ForegroundColor DarkGray
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

# --- Main Logic ---

# 1. Load Config
if (-not (Test-Path $ConfigPath)) {
    $errorMsg = "The configuration file could not be found at:`n  $ConfigPath`n`n  Please ensure the config.json file exists in the sfu-tools directory."
    Show-BSOD -ErrorTitle "CONFIG_FILE_NOT_FOUND" -ErrorMessage $errorMsg -ErrorCode "0xC0000001"
}

try {
    $json = Get-Content $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    
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
        $breadcrumb = "Main Menu > $($currentCategory.name)"
        $subtitle = $currentCategory.description
    }
    elseif ($currentView -eq "tools") {
        if ($currentSubcategory) {
            $menuItems = $currentSubcategory.tools | ForEach-Object { [PSCustomObject]@{ Name = $_.name; Type = "tool"; Data = $_ } }
            $breadcrumb = "Main Menu > $($currentCategory.name) > $($currentSubcategory.name)"
        } else {
            $menuItems = $currentCategory.tools | ForEach-Object { [PSCustomObject]@{ Name = $_.name; Type = "tool"; Data = $_ } }
            $breadcrumb = "Main Menu > $($currentCategory.name)"
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
        Draw-Header -Info $sysInfo -Version $Version -Breadcrumb $breadcrumb -Subtitle $subtitle
        $menuStartLine = [Console]::CursorTop
        Draw-Menu -MenuItems $menuItems -Selection $selection
        Draw-Footer -Version $Version -Author $Author
        $needsFullRedraw = $false
    } else {
        # Quick redraw - only update menu section
        [Console]::SetCursorPosition(0, $menuStartLine)
        Draw-Menu -MenuItems $menuItems -Selection $selection
        # Clear any remaining lines from previous menu
        $currentLine = [Console]::CursorTop
        $windowHeight = 35
        $footerStart = $windowHeight - 3
        while ($currentLine -lt $footerStart) {
            Write-Host (" " * 76)
            $currentLine++
        }
    }

    # Input Handling
    $key = [Console]::ReadKey($true)
    
    switch ($key.Key) {
        "UpArrow" {
            if ($selection -gt 0) { $selection-- }
            # No full redraw needed for navigation
        }
        "DownArrow" {
            if ($selection -lt ($menuItems.Count - 1)) { $selection++ }
            # No full redraw needed for navigation
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
                # Show exit confirmation
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
                Write-Host "[Y]" -ForegroundColor Black -BackgroundColor White -NoNewline
                Write-Host " Yes, Exit  " -ForegroundColor White -NoNewline
                Write-Host "[N]" -ForegroundColor Black -BackgroundColor White -NoNewline
                Write-Host " No, Go Back" -ForegroundColor White
                Write-Host ""
                
                # Wait for Y or N key
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
                Read-Host "`nPress Enter to continue"
                $needsFullRedraw = $true
            }
        }
    }
} 