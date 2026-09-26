param(
    [string]$SessionDir,
    [string]$OpenCodeDataDir,
    # Derived from this script's own location, never a fixed drive letter -
    # the USB mounts under whatever letter the host PC happens to assign.
    [string]$OpenCodeBin = "$PSScriptRoot\opencode.exe"
)

# USB root = parent of the bin\ folder this script lives in
$UsbRoot = Split-Path $PSScriptRoot -Parent

$mdFile = Join-Path $SessionDir "session.md"
$idFile = Join-Path $SessionDir "session.id"
$resumeFile = Join-Path $SessionDir "resume.bat"

# Read existing header (everything before "## Conversation")
$header = ""
if (Test-Path $mdFile) {
    $lines = Get-Content $mdFile -Encoding UTF8
    $headerLines = @()
    $inHeader = $true
    foreach ($line in $lines) {
        if ($inHeader -and $line.Trim() -eq "---") { $inHeader = $false }
        if ($inHeader) { $headerLines += $line }
    }
    # If the file only has the initial header, use all of it
    if ($headerLines.Count -le 1) { $header = Get-Content $mdFile -Raw -Encoding UTF8 } 
    else { $header = $headerLines -join "`r`n" }
}
if (-not $header) {
    $header = "# Session - $(Split-Path $SessionDir -Leaf)`r`n`r`n_Session log_`r`n"
}

$bodyLines = @()

function Add-Body { param([string]$T); $bodyLines += $T }

try {
    $env:OPENCODE_CONFIG_DIR = "$OpenCodeDataDir\config"
    $env:OPENCODE_DATA_DIR = $OpenCodeDataDir
    $env:OPENCODE_CACHE_DIR = "$SessionDir\cache"
    $env:OPENCODE_LOG_DIR = "$SessionDir\logs"
    $env:OPENCODE_STATE_DIR = "$SessionDir\state"
    $env:PATH = "$UsbRoot\bin;$UsbRoot\nodejs;$UsbRoot\wezterm;$env:PATH"

    # This script shells out to opencode, so it needs the same XDG redirection
    # as launcher.bat - otherwise the export step writes to the host profile.
    $env:XDG_DATA_HOME   = "$UsbRoot\data\xdg\data"
    $env:XDG_CONFIG_HOME = "$UsbRoot\data\xdg\config"
    $env:XDG_CACHE_HOME  = "$UsbRoot\data\xdg\cache"
    $env:XDG_STATE_HOME  = "$UsbRoot\data\xdg\state"

    $sessionId = $null
    $listOutput = & $OpenCodeBin session list 2>&1
    foreach ($line in $listOutput) {
        if ($line -match '\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b') {
            $sessionId = $matches[1]; break
        }
    }

    if ($sessionId) {
        $sessionId | Set-Content $idFile -Encoding UTF8

        $exportJson = Join-Path $SessionDir "export.json"
        & $OpenCodeBin export $sessionId 2>$null | Out-File $exportJson -Encoding UTF8

        if ((Test-Path $exportJson) -and ((Get-Item $exportJson).Length -gt 10)) {
            $session = Get-Content $exportJson -Raw -Encoding UTF8 | ConvertFrom-Json
            $messages = if ($session.messages) { $session.messages } elseif ($session.transcript) { $session.transcript } else { @() }

            Add-Body ""
            Add-Body "## Conversation"
            Add-Body ""

            foreach ($msg in $messages) {
                $role = if ($msg.role) { $msg.role } else { "unknown" }
                $content = ""
                if ($msg.content -is [string]) { $content = $msg.content }
                elseif ($msg.content -is [array]) {
                    foreach ($part in $msg.content) {
                        if ($part.text) { $content += $part.text + "`n" }
                        if ($part.type -eq "tool_use") { $content += "[Tool: $($part.name)]`n" }
                    }
                }
                $icon = switch ($role) { "user" { "👤" } "assistant" { "🤖" } default { "⚙️" } }
                Add-Body "### $icon $role"
                Add-Body ""
                if ($content.Trim()) {
                    $content.Trim() -split "`n" | ForEach-Object { Add-Body "  $_" }
                    Add-Body ""
                }
                if ($msg.tool_calls -or $msg.toolCalls) {
                    $calls = $msg.tool_calls -or $msg.toolCalls
                    foreach ($call in $calls) {
                        $name = $call.name -or $call.function -or $call.tool_name -or "tool"
                        Add-Body "  _Tool: **$name**_"
                        Add-Body ""
                    }
                }
            }
        }
    }
}
catch {
    Add-Body ""; Add-Body "_Error: $_"; Add-Body ""
}

# Write the complete file
$endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fullContent = @(
    $header.TrimEnd()
    ""
    $bodyLines -join "`r`n"
    ""
    "---"
    ""
    "**End Time:** $endTime"
) -join "`r`n"

$fullContent | Set-Content $mdFile -Encoding UTF8 -Force

# Create resume.bat if we have a session ID
$savedId = if ($sessionId) { $sessionId } elseif (Test-Path $idFile) { (Get-Content $idFile -Raw -Encoding UTF8).Trim() } else { $null }
if ($savedId) {
    $resumeContent = @"
@echo off
title Resume OpenCode Session
setlocal enabledelayedexpansion

set "SESSION_FOLDER=%~dp0"
if "%SESSION_FOLDER:~-1%"=="\" set "SESSION_FOLDER=%SESSION_FOLDER:~0,-1%"

:: Auto-detect USB drive (check current drive first, then scan others)
set "CURRENT_DRIVE=%~d0"
if exist "%CURRENT_DRIVE%\bin\opencode.exe" (
    set "USB_ROOT=%CURRENT_DRIVE%\"
) else (
    for %%D in (D E F G H I J K L M N) do if exist "%%D:\bin\opencode.exe" set "USB_ROOT=%%D:\"
)
if "%USB_ROOT%"=="" (
    echo Error: Could not find USB drive with opencode.
    echo Make sure the USB is inserted and try again.
    pause
    exit /b 1
)

set "PATH=%USB_ROOT%\bin;%USB_ROOT%\nodejs;%USB_ROOT%\wezterm;%PATH%"
:: Keep credentials and state on the USB, not the host profile (see launcher.bat)
set "XDG_DATA_HOME=%USB_ROOT%\data\xdg\data"
set "XDG_CONFIG_HOME=%USB_ROOT%\data\xdg\config"
set "XDG_CACHE_HOME=%USB_ROOT%\data\xdg\cache"
set "XDG_STATE_HOME=%USB_ROOT%\data\xdg\state"
set "OPENCODE_CONFIG_DIR=%USB_ROOT%\data\config"
set "OPENCODE_DATA_DIR=%SESSION_FOLDER%\opencode-data"
set "OPENCODE_CACHE_DIR=%SESSION_FOLDER%\cache"
set "OPENCODE_LOG_DIR=%SESSION_FOLDER%\logs"
set "OPENCODE_STATE_DIR=%SESSION_FOLDER%\state"
set "NODE_PATH=%USB_ROOT%\nodejs\node_modules"
set "NODE_SKIP_PLATFORM_CHECK=1"

set /p SESSION_ID=<"%SESSION_FOLDER%\session.id"

cls
echo.
echo  ===============================================
echo    Resuming OpenCode Session
echo    ID: %SESSION_ID%
echo    Folder: %SESSION_FOLDER%
echo  ===============================================
echo.
echo  The AI remembers the full conversation.
echo  Exit when done to save the updated log.
echo.

:: --config-file is a GLOBAL option and must precede 'start'. Also --cwd, not -c.
"%USB_ROOT%\wezterm\wezterm.exe" --config-file "%USB_ROOT%\config\wezterm.lua" start --always-new-process --cwd "%SESSION_FOLDER%" opencode.exe -s %SESSION_ID%

echo.
echo  Updating session log...
powershell.exe -ExecutionPolicy Bypass -File "%USB_ROOT%\bin\session-to-md.ps1" -SessionDir "%SESSION_FOLDER%" -OpenCodeDataDir "%SESSION_FOLDER%\opencode-data" -OpenCodeBin "%USB_ROOT%\bin\opencode.exe"

echo.
echo  Session log updated: %SESSION_FOLDER%\session.md
echo.
pause
"@
    $resumeContent | Set-Content $resumeFile -Encoding ASCII -Force
}
