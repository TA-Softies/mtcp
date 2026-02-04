@echo off
:: This script detects the current drive and launches the PowerShell panel
:: It uses %~dp0 to get the script's current folder

CLS
ECHO Launching Technical Assistants Panel...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch.ps1"