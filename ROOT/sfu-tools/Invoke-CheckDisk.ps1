<#
    .SYNOPSIS
    Interactive Check Disk Tool - Select volume and run chkdsk
#>

# Force UTF-8 encoding
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "==================== CHECK DISK UTILITY ====================" -ForegroundColor Cyan
Write-Host ""

# Get all volumes
$volumes = Get-Volume | Where-Object { $_.DriveLetter -ne $null } | Sort-Object DriveLetter

if ($volumes.Count -eq 0) {
    Write-Host "No volumes with drive letters found." -ForegroundColor Red
    Read-Host "`nPress Enter to exit"
    Exit
}

Write-Host "Available Volumes:" -ForegroundColor Yellow
Write-Host ""

$index = 1
foreach ($vol in $volumes) {
    $sizeGB = [math]::Round($vol.Size / 1GB, 2)
    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 2)
    $usedPercent = [math]::Round((($vol.Size - $vol.SizeRemaining) / $vol.Size) * 100, 1)
    
    $healthColor = switch ($vol.HealthStatus) {
        "Healthy" { "Green" }
        "Warning" { "Yellow" }
        default { "Red" }
    }
    
    Write-Host " [$index] " -NoNewline -ForegroundColor Cyan
    Write-Host "$($vol.DriveLetter):\ " -NoNewline -ForegroundColor White
    Write-Host "[$($vol.FileSystemType)] " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($vol.FileSystemLabel) " -NoNewline -ForegroundColor Gray
    Write-Host "($sizeGB GB, $freeGB GB free, $usedPercent% used) " -NoNewline -ForegroundColor DarkGray
    Write-Host "[$($vol.HealthStatus)]" -ForegroundColor $healthColor
    
    $index++
}

Write-Host ""
Write-Host "Select a volume number (or press Enter to cancel): " -NoNewline -ForegroundColor Yellow
$choice = Read-Host

if ([string]::IsNullOrWhiteSpace($choice)) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    Exit
}

$choiceNum = 0
if (-not [int]::TryParse($choice, [ref]$choiceNum) -or $choiceNum -lt 1 -or $choiceNum -gt $volumes.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    Read-Host "`nPress Enter to exit"
    Exit
}

$selectedVolume = $volumes[$choiceNum - 1]
$driveLetter = $selectedVolume.DriveLetter

Write-Host ""
Write-Host "Selected: $driveLetter`:\" -ForegroundColor Green
Write-Host ""
Write-Host "Check Disk Options:" -ForegroundColor Yellow
Write-Host " [1] Basic scan (read-only)" -ForegroundColor White
Write-Host " [2] Scan and fix errors (requires restart if system drive)" -ForegroundColor White
Write-Host " [3] Full scan with bad sector recovery (slow, requires restart if system drive)" -ForegroundColor White
Write-Host ""
Write-Host "Select option (or press Enter to cancel): " -NoNewline -ForegroundColor Yellow
$option = Read-Host

$chkdskArgs = ""
switch ($option) {
    "1" { 
        $chkdskArgs = "$driveLetter`:"
        Write-Host "`nRunning basic scan on $driveLetter`:\" -ForegroundColor Cyan
    }
    "2" { 
        $chkdskArgs = "$driveLetter`: /F"
        Write-Host "`nRunning scan with fix on $driveLetter`:\" -ForegroundColor Cyan
        Write-Host "Note: If this is the system drive, a restart will be scheduled." -ForegroundColor Yellow
    }
    "3" { 
        $chkdskArgs = "$driveLetter`: /F /R"
        Write-Host "`nRunning full scan with bad sector recovery on $driveLetter`:\" -ForegroundColor Cyan
        Write-Host "Note: This may take several hours. If system drive, restart will be scheduled." -ForegroundColor Yellow
    }
    default {
        Write-Host "Cancelled." -ForegroundColor Yellow
        Read-Host "`nPress Enter to exit"
        Exit
    }
}

Write-Host ""
Write-Host "Executing: chkdsk $chkdskArgs" -ForegroundColor Gray
Write-Host ""

# Run chkdsk
Start-Process "chkdsk" -ArgumentList $chkdskArgs -Wait -NoNewWindow

Write-Host ""
Write-Host "Check Disk completed." -ForegroundColor Green
