<#
    .SYNOPSIS
    Toggle Deep Freeze between Frozen and Thawed states
#>

$DFPath = "C:\Windows\SysWOW64\DFC.exe"

if (-not (Test-Path $DFPath)) {
    Write-Host "`nDeep Freeze executable (DFC.exe) not found in SysWOW64." -ForegroundColor Red
    Write-Host "Deep Freeze may not be installed on this system." -ForegroundColor Yellow
    return
}

# Check current status
Write-Host "`nChecking Deep Freeze status..." -ForegroundColor Cyan
$null = & $DFPath get /ISFROZEN 2>&1
$currentStatus = $LASTEXITCODE

if ($currentStatus -eq 1) {
    $statusText = "FROZEN"
    $action = "THAW"
    $actionCmd = "/BOOTTHAWED"
    $statusColor = "Cyan"
} elseif ($currentStatus -eq 0) {
    $statusText = "THAWED"
    $action = "FREEZE"
    $actionCmd = "/BOOTFROZEN"
    $statusColor = "Red"
} else {
    Write-Host "Unable to determine Deep Freeze status (Exit Code: $currentStatus)" -ForegroundColor Yellow
    return
}

Write-Host "`nCurrent Status: " -NoNewline
Write-Host $statusText -ForegroundColor $statusColor
Write-Host "`nThis will restart the computer and $action Deep Freeze." -ForegroundColor Yellow
Write-Host ""

# Confirm action
$confirm = Read-Host "Do you want to proceed? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "`nOperation cancelled." -ForegroundColor Gray
    return
}

# Get password
Write-Host "`nEnter Deep Freeze password:" -ForegroundColor Cyan
$password = Read-Host -AsSecureString
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    Write-Host "`nPassword cannot be empty." -ForegroundColor Red
    return
}

# Execute command
Write-Host "`nExecuting Deep Freeze command..." -ForegroundColor Cyan
try {
    $output = & $DFPath $plainPassword $actionCmd 2>&1
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "`nSuccess! System will restart in a $statusText state." -ForegroundColor Green
        Write-Host "The computer will restart shortly..." -ForegroundColor Yellow
    } else {
        Write-Host "`nCommand failed with exit code: $exitCode" -ForegroundColor Red
        if ($output) {
            Write-Host "Output: $output" -ForegroundColor Gray
        }
        Write-Host "`nPossible issues:" -ForegroundColor Yellow
        Write-Host "  - Incorrect password" -ForegroundColor Gray
        Write-Host "  - Password does not have command line rights" -ForegroundColor Gray
        Write-Host "  - Deep Freeze configuration issue" -ForegroundColor Gray
    }
} catch {
    Write-Host "`nError executing DFC command:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
}

# Clear password from memory
$plainPassword = $null
[System.GC]::Collect()
