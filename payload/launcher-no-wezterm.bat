@echo off
title Portable OpenCode AI USB (Direct)
setlocal enabledelayedexpansion

:: ============================================
:: Portable OpenCode AI - Direct Console Launcher
:: ============================================

:: Get USB root directory
set "USB_ROOT=%~dp0"
if "%USB_ROOT:~-1%"=="\" set "USB_ROOT=%USB_ROOT:~0,-1%"

:: Add USB binary paths to PATH
set "PATH=%USB_ROOT%\bin;%USB_ROOT%\nodejs;%USB_ROOT%\wezterm;%PATH%"

:: Create timestamped session folder.
:: WMIC is deprecated and absent on current Windows 11 builds, so fall back to
:: PowerShell. Both yield yyyyMMddHHmmss... so the substring maths below is unchanged.
set "DT="
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "DT=%%I"
if not defined DT (
    for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "DT=%%I"
)
set "SESSION_FOLDER=%USB_ROOT%\sessions\%DT:~0,4%-%DT:~4,2%-%DT:~6,2%_%DT:~8,2%-%DT:~10,2%-%DT:~12,2%"
if not exist "%USB_ROOT%\sessions" mkdir "%USB_ROOT%\sessions"
mkdir "%SESSION_FOLDER%"

:: Create initial session markdown
echo # Session - %DT:~0,4%-%DT:~4,2%-%DT:~6,2% %DT:~8,2%:%DT:~10,2%:%DT:~12,2% > "%SESSION_FOLDER%\session.md"
echo. >> "%SESSION_FOLDER%\session.md"
echo **Date:** %DT:~0,4%-%DT:~4,2%-%DT:~6,2% >> "%SESSION_FOLDER%\session.md"
echo **Start Time:** %DT:~8,2%:%DT:~10,2%:%DT:~12,2% >> "%SESSION_FOLDER%\session.md"
echo **USB Drive:** %USB_ROOT% >> "%SESSION_FOLDER%\session.md"
echo. >> "%SESSION_FOLDER%\session.md"
echo _Session in progress - will be updated when you exit OpenCode._ >> "%SESSION_FOLDER%\session.md"
echo. >> "%SESSION_FOLDER%\session.md"
echo --- >> "%SESSION_FOLDER%\session.md"
echo. >> "%SESSION_FOLDER%\session.md"

:: OpenCode environment variables for full portability
::
:: The XDG_* vars are the important ones. opencode resolves credentials,
:: its database, logs, cache and state through the XDG base directories,
:: which default to the HOST user's profile (~\.local\share, ~\.cache, ...).
:: Without all four of these, API keys and session data are left on every
:: PC the stick is plugged into, and the stick carries no credentials to
:: a new machine.
set "XDG_DATA_HOME=%USB_ROOT%\data\xdg\data"
set "XDG_CONFIG_HOME=%USB_ROOT%\data\xdg\config"
set "XDG_CACHE_HOME=%USB_ROOT%\data\xdg\cache"
set "XDG_STATE_HOME=%USB_ROOT%\data\xdg\state"

:: Redirect the temp dir onto the stick. Without this, opencode and other
:: tools drop temp files (native addons, blob leases) into the host's
:: %LOCALAPPDATA%\Temp, leaving traces on every PC.
set "TEMP=%USB_ROOT%\data\tmp"
set "TMP=%USB_ROOT%\data\tmp"
if not exist "%USB_ROOT%\data\tmp" mkdir "%USB_ROOT%\data\tmp"

set "OPENCODE_CONFIG_DIR=%USB_ROOT%\data\config"
set "OPENCODE_DATA_DIR=%SESSION_FOLDER%\opencode-data"
set "OPENCODE_CACHE_DIR=%SESSION_FOLDER%\cache"
set "OPENCODE_LOG_DIR=%SESSION_FOLDER%\logs"
set "OPENCODE_STATE_DIR=%SESSION_FOLDER%\state"

set "NODE_PATH=%USB_ROOT%\nodejs\node_modules"
set "NODE_SKIP_PLATFORM_CHECK=1"

cls
echo.
echo  ===============================================
echo    Portable OpenCode AI USB (Direct Mode)
echo    Session: %SESSION_FOLDER%
echo  ===============================================
echo.
echo  Starting opencode in this window...
echo  Type "exit" when done to save session log.
echo.

cd /d "%USB_ROOT%"

:: Launch opencode directly (waits for exit)
opencode.exe

:: Post-processing
echo.
echo  Processing session data into markdown...
powershell.exe -ExecutionPolicy Bypass -File "%USB_ROOT%\bin\session-to-md.ps1" ^
    -SessionDir "%SESSION_FOLDER%" ^
    -OpenCodeDataDir "%SESSION_FOLDER%\opencode-data" ^
    -OpenCodeBin "%USB_ROOT%\bin\opencode.exe"

echo.
echo  Session log saved to:
echo    %SESSION_FOLDER%\session.md
echo.
:: NO 'pause' HERE. This window is launched hidden (CreateNoWindow=true in
:: launcher.cs), so a 'press any key' prompt can never be satisfied and the
:: cmd.exe process would hang forever, leaking one shell per launch.
:: Wait 10 seconds then auto-close so post-processing has time to finish.
timeout /t 10 /nobreak >nul