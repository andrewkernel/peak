@echo off
setlocal EnableExtensions

set "SCRIPT=%~dp0PeakUtility.ps1"

if not exist "%SCRIPT%" (
    echo PeakUtility.ps1 was not found next to this file.
    echo Expected: %SCRIPT%
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %errorlevel%
