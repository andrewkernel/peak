@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "VERSION=0.1.0"
set "APP_NAME=Peak Utility"
set "DEFAULT_ROOT=C:\Users\Andrew\Downloads\Insstincts Optimizations-main-20260411T030202Z-3-001\Insstincts Optimizations-main"
set "LOG_FILE=%~dp0PeakUtility.log"

if /i "%~1"=="--help" goto Help
if /i "%~1"=="-h" goto Help
if /i "%~1"=="/?" goto Help
if /i "%~1"=="--self-test" goto SelfTest

title %APP_NAME% %VERSION%
color 0B

call :RequireAdmin
call :ResolveRoot
if errorlevel 1 exit /b 1
call :InitLog
call :AskRestorePoint
goto MainMenu

:MainMenu
cls
call :Header
echo [1] Check / Diagnostics
echo [2] Refresh
echo [3] Setup
echo [4] Installers
echo [5] Graphics
echo [6] Windows
echo [7] Hardware
echo [8] Advanced
echo.
echo [A] Allow Scripts helper
echo [R] Create restore point
echo [O] Open Insstincts folder
echo [Q] Quit
echo.
set "MENU_CHOICE="
set /p "MENU_CHOICE=Select: "

if /i "%MENU_CHOICE%"=="Q" goto End
if /i "%MENU_CHOICE%"=="A" (
    call :RunFile "%OPT_ROOT%\Allow Scripts.cmd"
    goto MainMenu
)
if /i "%MENU_CHOICE%"=="R" (
    call :CreateRestorePoint
    goto MainMenu
)
if /i "%MENU_CHOICE%"=="O" (
    start "" "%OPT_ROOT%"
    goto MainMenu
)
if "%MENU_CHOICE%"=="1" (
    call :CategoryMenu "1 Check" "Check / Diagnostics"
    goto MainMenu
)
if "%MENU_CHOICE%"=="2" (
    call :CategoryMenu "2 Refresh" "Refresh"
    goto MainMenu
)
if "%MENU_CHOICE%"=="3" (
    call :CategoryMenu "3 Setup" "Setup"
    goto MainMenu
)
if "%MENU_CHOICE%"=="4" (
    call :CategoryMenu "4 Installers" "Installers"
    goto MainMenu
)
if "%MENU_CHOICE%"=="5" (
    call :CategoryMenu "5 Graphics" "Graphics"
    goto MainMenu
)
if "%MENU_CHOICE%"=="6" (
    call :CategoryMenu "6 Windows" "Windows"
    goto MainMenu
)
if "%MENU_CHOICE%"=="7" (
    call :CategoryMenu "7 Hardware" "Hardware"
    goto MainMenu
)
if "%MENU_CHOICE%"=="8" (
    call :CategoryMenu "8 Advanced" "Advanced"
    goto MainMenu
)

echo.
echo Invalid choice.
timeout /t 1 /nobreak >nul
goto MainMenu

:CategoryMenu
set "CAT_FOLDER=%~1"
set "CAT_TITLE=%~2"
set "CAT_PATH=%OPT_ROOT%\%CAT_FOLDER%"

if not exist "%CAT_PATH%\" (
    echo.
    echo Missing category folder:
    echo %CAT_PATH%
    pause
    exit /b 1
)

:CategoryLoop
cls
call :Header
echo %CAT_TITLE%
echo.
set "ITEM_COUNT=0"
for /l %%N in (1,1,99) do (
    for %%F in ("%CAT_PATH%\%%N *") do (
        if exist "%%~fF" (
            set /a ITEM_COUNT+=1
            set "ITEM!ITEM_COUNT!=%%~fF"
            set "DISPLAY=%%~nF"
            for /f "tokens=1,* delims= " %%A in ("!DISPLAY!") do set "DISPLAY=%%B"
            if not defined DISPLAY set "DISPLAY=%%~nF"
            echo [!ITEM_COUNT!] !DISPLAY! %%~xF
        )
    )
)

if "%ITEM_COUNT%"=="0" (
    echo No runnable items found in this section.
    echo.
)

echo.
echo [A] Run every item in this section
echo [B] Back
echo [Q] Quit
echo.
set "ITEM_CHOICE="
set /p "ITEM_CHOICE=Select: "

if /i "%ITEM_CHOICE%"=="B" exit /b 0
if /i "%ITEM_CHOICE%"=="Q" goto End
if /i "%ITEM_CHOICE%"=="A" (
    call :RunAllCurrent "%CAT_TITLE%"
    goto CategoryLoop
)
if not defined ITEM_CHOICE goto CategoryLoop

set "INVALID_CHOICE="
for /f "delims=0123456789" %%A in ("%ITEM_CHOICE%") do set "INVALID_CHOICE=1"
if defined INVALID_CHOICE (
    echo.
    echo Invalid choice.
    timeout /t 1 /nobreak >nul
    goto CategoryLoop
)

set "TARGET="
call set "TARGET=%%ITEM%ITEM_CHOICE%%%"
if not defined TARGET (
    echo.
    echo Invalid choice.
    timeout /t 1 /nobreak >nul
    goto CategoryLoop
)

call :RunFile "%TARGET%"
goto CategoryLoop

:RunAllCurrent
set "SECTION_NAME=%~1"
echo.
echo This will run every item in "%SECTION_NAME%" one at a time.
echo Some items may open browser pages, Windows settings, installers, or scripts.
choice /c YN /n /m "Continue? [Y/N]: "
if errorlevel 2 exit /b 0

for /l %%I in (1,1,%ITEM_COUNT%) do (
    set "TARGET="
    call set "TARGET=%%ITEM%%I%%"
    call :RunFile "!TARGET!" "nopause"
)

echo.
echo Finished section: %SECTION_NAME%
pause
exit /b 0

:RunFile
set "TARGET=%~1"
set "NO_PAUSE=%~2"
set "RUN_CODE=0"

if not exist "%TARGET%" (
    echo.
    echo File not found:
    echo %TARGET%
    pause
    exit /b 1
)

for %%F in ("%TARGET%") do (
    set "TARGET_NAME=%%~nxF"
    set "TARGET_EXT=%%~xF"
    set "TARGET_DIR=%%~dpF"
)

cls
call :Header
echo Running: %TARGET_NAME%
echo Path: %TARGET%
echo.
>>"%LOG_FILE%" echo [%date% %time%] START %TARGET%

if /i "%TARGET_EXT%"==".ps1" (
    pushd "%TARGET_DIR%"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TARGET%"
    set "RUN_CODE=!errorlevel!"
    popd
    goto RanTarget
)

if /i "%TARGET_EXT%"==".cmd" (
    pushd "%TARGET_DIR%"
    call "%TARGET%"
    set "RUN_CODE=!errorlevel!"
    popd
    goto RanTarget
)

if /i "%TARGET_EXT%"==".bat" (
    pushd "%TARGET_DIR%"
    call "%TARGET%"
    set "RUN_CODE=!errorlevel!"
    popd
    goto RanTarget
)

if /i "%TARGET_EXT%"==".url" (
    start "" "%TARGET%"
    set "RUN_CODE=0"
    goto RanTarget
)

if /i "%TARGET_EXT%"==".lnk" (
    start "" "%TARGET%"
    set "RUN_CODE=0"
    goto RanTarget
)

start "" "%TARGET%"
set "RUN_CODE=0"

:RanTarget
>>"%LOG_FILE%" echo [%date% %time%] END   %TARGET% ^(exit %RUN_CODE%^)
echo.
echo Done. Exit code: %RUN_CODE%
if /i not "%NO_PAUSE%"=="nopause" pause
exit /b %RUN_CODE%

:AskRestorePoint
cls
call :Header
echo Recommended before applying system tweaks:
echo Create a Windows restore point now?
echo.
choice /c YN /n /m "[Y] Yes  [N] No: "
if errorlevel 2 exit /b 0
call :CreateRestorePoint
exit /b 0

:CreateRestorePoint
echo.
echo Creating restore point...
>>"%LOG_FILE%" echo [%date% %time%] CREATE RESTORE POINT
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'Peak Utility' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; Write-Host 'Restore point created.'; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo.
    echo Restore point could not be created. You can still continue, but be careful.
    >>"%LOG_FILE%" echo [%date% %time%] RESTORE POINT FAILED
) else (
    >>"%LOG_FILE%" echo [%date% %time%] RESTORE POINT CREATED
)
pause
exit /b 0

:RequireAdmin
net session >nul 2>&1
if "%errorlevel%"=="0" exit /b 0
echo Requesting administrator permissions...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
exit /b

:ResolveRoot
set "OPT_ROOT="
set "LAUNCHER_DIR=%~dp0"
if "%LAUNCHER_DIR:~-1%"=="\" set "LAUNCHER_DIR=%LAUNCHER_DIR:~0,-1%"

if exist "%LAUNCHER_DIR%\1 Check\" (
    set "OPT_ROOT=%LAUNCHER_DIR%"
    exit /b 0
)

if exist "%DEFAULT_ROOT%\1 Check\" (
    set "OPT_ROOT=%DEFAULT_ROOT%"
    exit /b 0
)

:PromptRoot
cls
call :Header
echo I could not find the Insstincts folders automatically.
echo Paste the path that contains "1 Check", "2 Refresh", and the other sections.
echo.
set "USER_ROOT="
set /p "USER_ROOT=Folder path: "
set "USER_ROOT=%USER_ROOT:"=%"
if "%USER_ROOT:~-1%"=="\" set "USER_ROOT=%USER_ROOT:~0,-1%"

if exist "%USER_ROOT%\1 Check\" (
    set "OPT_ROOT=%USER_ROOT%"
    exit /b 0
)

echo.
echo That path does not look like the Insstincts optimization root.
pause
goto PromptRoot

:InitLog
>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo [%date% %time%] %APP_NAME% %VERSION% started
>>"%LOG_FILE%" echo [%date% %time%] Root: %OPT_ROOT%
exit /b 0

:Header
echo ============================================================
echo  %APP_NAME% %VERSION%
echo ============================================================
echo.
exit /b 0

:SelfTest
call :ResolveRoot
if errorlevel 1 exit /b 1
echo Root: %OPT_ROOT%
echo.
set /a TOTAL_ITEMS=0
for %%C in ("1 Check" "2 Refresh" "3 Setup" "4 Installers" "5 Graphics" "6 Windows" "7 Hardware" "8 Advanced") do (
    set /a SECTION_ITEMS=0
    for /l %%N in (1,1,99) do (
        for %%F in ("%OPT_ROOT%\%%~C\%%N *") do (
            if exist "%%~fF" set /a SECTION_ITEMS+=1
        )
    )
    set /a TOTAL_ITEMS+=SECTION_ITEMS
    echo %%~C: !SECTION_ITEMS! items
)
echo.
echo Total menu items: !TOTAL_ITEMS!
exit /b 0

:Help
echo %APP_NAME% %VERSION%
echo.
echo Usage:
echo   PeakUtility.bat
echo   PeakUtility.bat --self-test
echo.
echo Put this file in the Insstincts optimization root, or leave it
echo where it is and it will use the known source folder when present.
exit /b 0

:End
echo.
echo Exiting %APP_NAME%.
endlocal
exit /b 0
