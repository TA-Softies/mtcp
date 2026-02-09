# Fix-Encoding.ps1
# Converts all .json and .ps1 files to UTF-8 with BOM encoding
# Run this from the SFU-TOOLS folder before launching MTCP

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $scriptDir -Recurse -Include *.json, *.ps1

$count = 0
foreach ($file in $files) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($true))
        Write-Host "[OK] $($file.FullName)" -ForegroundColor Green
        $count++
    } catch {
        Write-Host "[FAIL] $($file.FullName): $_" -ForegroundColor Red
    }
}

Write-Host "`nConverted $count file(s) to UTF-8 with BOM." -ForegroundColor Cyan
