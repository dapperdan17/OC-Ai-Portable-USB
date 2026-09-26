@echo off
title Portable OpenCode AI USB
setlocal enabledelayedexpansion

:: ============================================
:: Portable OpenCode AI - USB Launcher
:: Creates dated session logs automatically
:: ============================================

:: Get USB root directory (where this batch file is)
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
:: The OPENCODE_*_DIR vars below do NOT cover these paths - verified by
:: watching ~\.cache\opencode get written while they were set. Without all
:: four of these, API keys and session data are left on every PC the stick
:: is plugged into, and the stick carries no credentials to a new machine.
set "XDG_DATA_HOME=%USB_ROOT%\data\xdg\data"
set "XDG_CONFIG_HOME=%USB_ROOT%\data\xdg\config"
set "XDG_CACHE_HOME=%USB_ROOT%\data\xdg\cache"
set "XDG_STATE_HOME=%USB_ROOT%\data\xdg\state"

:: Redirect the temp dir onto the stick as well. Measured on a clean host,
:: leaving these at their defaults drops two files into %LOCALAPPDATA%\Temp:
:: a native addon opencode extracts at startup (.<hash>-00000001.node) and
:: wezterm's blob lease file. Both are traces on the host device.
set "TEMP=%USB_ROOT%\data\tmp"
set "TMP=%USB_ROOT%\data\tmp"
if not exist "%USB_ROOT%\data\tmp" mkdir "%USB_ROOT%\data\tmp"

set "OPENCODE_CONFIG_DIR=%USB_ROOT%\data\config"
set "OPENCODE_DATA_DIR=%SESSION_FOLDER%\opencode-data"
set "OPENCODE_CACHE_DIR=%SESSION_FOLDER%\cache"
set "OPENCODE_LOG_DIR=%SESSION_FOLDER%\logs"
set "OPENCODE_STATE_DIR=%SESSION_FOLDER%\state"

:: Node.js portable
set "NODE_PATH=%USB_ROOT%\nodejs\node_modules"
set "NODE_SKIP_PLATFORM_CHECK=1"

cls
echo.
echo  ===============================================
echo    Portable OpenCode AI
echo    USB: %USB_ROOT%
echo    Session: %SESSION_FOLDER%
echo  ===============================================
echo.
echo  Starting OpenCode...
echo  When you exit, session log will be saved to:
echo    %SESSION_FOLDER%\session.md
echo.
echo  To RESUME this session later, run:
echo    %SESSION_FOLDER%\resume.bat
echo.

:: Launch WezTerm with opencode and WAIT for it to close
:: NOTE: --config-file is a GLOBAL wezterm option and must come BEFORE the
:: 'start' subcommand. Placing it after 'start' makes wezterm exit immediately
:: with "unexpected argument '--config-file' found" and no window ever opens.
"%USB_ROOT%\wezterm\wezterm.exe" --config-file "%USB_ROOT%\config\wezterm.lua" start --always-new-process --cwd "%USB_ROOT%" opencode.exe

:: Post-processing: convert session data to markdown
echo.
echo  OpenCode session ended.
echo  Processing session data into markdown...
echo.

powershell.exe -ExecutionPolicy Bypass -File "%USB_ROOT%\bin\session-to-md.ps1" ^
    -SessionDir "%SESSION_FOLDER%" ^
    -OpenCodeDataDir "%SESSION_FOLDER%\opencode-data" ^
    -OpenCodeBin "%USB_ROOT%\bin\opencode.exe"

echo.
echo  Session log saved to:
echo    %SESSION_FOLDER%\session.md
echo.

:: NO 'pause' HERE. This window is launched hidden (CreateNoWindow=true in
:: launcher.cs), so a "press any key" prompt can never be satisfied and the
:: cmd.exe process would hang forever, leaking one shell per launch.
exit /b 0
