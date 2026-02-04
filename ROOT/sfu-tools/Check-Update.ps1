<#
    .SYNOPSIS
    Check for updates from GitHub repository
#>

param(
    [string]$CurrentVersion,
    [switch]$Silent
)

$RepoOwner = "TA-Softies"
$RepoName = "mtcp"
$VersionFileUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main/ROOT/sfu-tools/config.json"
$UpdateArchiveUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/main.zip"

function Compare-Versions {
    param([string]$Current, [string]$Remote)
    
    try {
        $currentParts = $Current.Split('.') | ForEach-Object { [int]$_ }
        $remoteParts = $Remote.Split('.') | ForEach-Object { [int]$_ }
        
        for ($i = 0; $i -lt [Math]::Max($currentParts.Length, $remoteParts.Length); $i++) {
            $c = if ($i -lt $currentParts.Length) { $currentParts[$i] } else { 0 }
            $r = if ($i -lt $remoteParts.Length) { $remoteParts[$i] } else { 0 }
            
            if ($r -gt $c) { return $true }
            if ($r -lt $c) { return $false }
        }
        return $false
    } catch {
        return $false
    }
}

# Check for internet connection
try {
    $null = [System.Net.Dns]::GetHostAddresses("github.com")
} catch {
    if (-not $Silent) {
        Write-Host "No internet connection available." -ForegroundColor Yellow
    }
    return $null
}

# Download version info
try {
    $webClient = New-Object System.Net.WebClient
    $remoteConfig = $webClient.DownloadString($VersionFileUrl) | ConvertFrom-Json
    $remoteVersion = $remoteConfig.meta.version
    
    if (Compare-Versions -Current $CurrentVersion -Remote $remoteVersion) {
        return [PSCustomObject]@{
            UpdateAvailable = $true
            CurrentVersion = $CurrentVersion
            RemoteVersion = $remoteVersion
            DownloadUrl = $UpdateArchiveUrl
        }
    } else {
        return [PSCustomObject]@{
            UpdateAvailable = $false
            CurrentVersion = $CurrentVersion
            RemoteVersion = $remoteVersion
        }
    }
} catch {
    if (-not $Silent) {
        Write-Host "Failed to check for updates: $($_.Exception.Message)" -ForegroundColor Red
    }
    return $null
}
