# check-updates.ps1  -  Portable OpenCode AI USB
#
# Reports whether a newer OpenCode release exists. It only CHECKS - it never
# changes anything and never touches the host PC.
#
# It deliberately does NOT run 'opencode upgrade': that command installs via
# curl/npm/brew/etc into a host/system location, which would both fail for this
# copied-binary layout and write OpenCode onto the host machine - the exact
# thing this portable stick is built to avoid. Updating the stick means
# replacing bin\opencode.exe, so this script just tells you when to.

$ErrorActionPreference = 'Stop'

# USB root = parent of the bin\ folder this script lives in. Never a fixed drive
# letter - the stick mounts under whatever letter the host happens to assign.
$UsbRoot = (Split-Path $PSScriptRoot -Parent).TrimEnd('\')
$OpenCodeBin = Join-Path $PSScriptRoot 'opencode.exe'

Write-Host ''
Write-Host '  ===============================================' -ForegroundColor Cyan
Write-Host '    OpenCode AI  -  Check for Updates' -ForegroundColor Cyan
Write-Host '  ===============================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $OpenCodeBin)) {
    Write-Host "  Could not find opencode.exe at $OpenCodeBin" -ForegroundColor Red
    return
}

# Keep any opencode invocation on the stick, not the host profile.
$env:PATH = "$UsbRoot\bin;$UsbRoot\nodejs;$UsbRoot\wezterm;$env:PATH"
$env:XDG_DATA_HOME   = "$UsbRoot\data\xdg\data"
$env:XDG_CONFIG_HOME = "$UsbRoot\data\xdg\config"
$env:XDG_CACHE_HOME  = "$UsbRoot\data\xdg\cache"
$env:XDG_STATE_HOME  = "$UsbRoot\data\xdg\state"
$env:TEMP = "$UsbRoot\data\tmp"
$env:TMP  = "$UsbRoot\data\tmp"

$current = (& $OpenCodeBin --version 2>$null | Select-Object -First 1)
if ($current) { $current = $current.Trim() }
Write-Host "  Installed version: $current" -ForegroundColor White

$latest = $null
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $latest = (Invoke-RestMethod -Uri 'https://registry.npmjs.org/opencode-ai/latest' -TimeoutSec 15).version
} catch {
    Write-Host ''
    Write-Host '  Could not reach the update server (no internet, or it is down).' -ForegroundColor Yellow
    Write-Host "  Details: $($_.Exception.Message)" -ForegroundColor DarkGray
    return
}
Write-Host "  Latest release:    $latest" -ForegroundColor White
Write-Host ''

$newer = $false
try {
    $cv = [version]($current -replace '[^0-9.]', '')
    $lv = [version]($latest  -replace '[^0-9.]', '')
    $newer = $lv -gt $cv
} catch {
    $newer = ($latest -and $current -and ($latest -ne $current))
}

if ($newer) {
    Write-Host "  A newer version of OpenCode is available: $latest" -ForegroundColor Green
    Write-Host ''
    Write-Host '  To update this portable stick (everything stays on the USB):' -ForegroundColor White
    Write-Host '    1. Download the latest OpenCode for Windows from https://opencode.ai' -ForegroundColor Gray
    Write-Host "    2. Replace  $UsbRoot\bin\opencode.exe  with the new opencode.exe" -ForegroundColor Gray
    Write-Host ''
    Write-Host "  (Do NOT run 'opencode upgrade' - it installs onto the host PC, which" -ForegroundColor DarkGray
    Write-Host '   this portable stick is designed to avoid.)' -ForegroundColor DarkGray
} else {
    Write-Host '  You are up to date.' -ForegroundColor Green
}
Write-Host ''
