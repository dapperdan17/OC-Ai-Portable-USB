param(
    [string]$SourcePath = "D:\",
    [string]$OutputDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== OpenCode AI - Self-Contained USB Installer Builder ===" -ForegroundColor Cyan
Write-Host ""

# ─── Sanity check ───
if (-not (Test-Path "$SourcePath\bin\opencode.exe")) {
    Write-Error "Source path does not contain bin\opencode.exe"
    exit 1
}

# ─── Create ZIP of source files ───
$zipPath = Join-Path $OutputDir "opencode-source.zip"
Write-Host "Zipping source files from $SourcePath ..." -ForegroundColor Yellow
Write-Host "  (this may take a minute)"

# Remove old ZIP if present
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# Get all items, excluding user-data folders
$items = Get-ChildItem $SourcePath -Force | Where-Object {
    $_.Name -notin @('sessions','Sessions','System Volume Information','$RECYCLE.BIN')
}

# Use .NET ZipFile for reliable compression (handles hidden files)
Add-Type -AssemblyName "System.IO.Compression"
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

$totalItems = 0
$totalSize = 0L

foreach ($item in $items) {
    $totalItems++
    if (-not $item.PSIsContainer) {
        $totalSize += $item.Length
    } else {
        # Count files in directories
        $files = Get-ChildItem $item.FullName -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        $totalItems += $files.Count
        $totalSize += ($files | Measure-Object -Property Length -Sum).Sum
    }
}

$excludeDirs = @('sessions','Sessions','System Volume Information','$RECYCLE.BIN')

# Exclusions by exact relative path, for cases where a bare name match would be
# too broad. 'node_modules' cannot go in $excludeDirs because nodejs/node_modules
# is the ~108MB npm runtime we must ship. data/config/node_modules, by contrast,
# is plugin state OpenCode installs at runtime and regenerates on first launch -
# shipping it just bloats the installer and risks baking in a half-written tree.
#
# SECURITY: data/xdg holds opencode's credentials (auth.json = live API keys),
# its session database and logs. This zip is embedded verbatim into
# create-usb.exe, which is intended for public distribution - shipping it would
# publish the builder's own API keys inside the installer. Never remove this.
#
$excludePaths = @('data/config/node_modules', 'data/xdg', 'data/tmp')
[System.IO.Compression.ZipFile]::CreateFromDirectory($SourcePath, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

# The CreateFromDirectory doesn't support exclusions, so we need to rebuild
# Remove the ZIP and create a custom one
Remove-Item $zipPath -Force

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)

function Add-FilesToZip($zip, $sourceDir, $baseRelPath = "") {
    $dirItems = Get-ChildItem $sourceDir -Force
    foreach ($item in $dirItems) {
        if ($item.Name -in $excludeDirs) { continue }
        $relPath = if ($baseRelPath) { "$baseRelPath/$($item.Name)" } else { $item.Name }
        if ($excludePaths -contains $relPath) {
            Write-Host "  excluding: $relPath" -ForegroundColor DarkGray
            continue
        }
        if ($item.PSIsContainer) {
            $zip.CreateEntry("$relPath/") | Out-Null
            Add-FilesToZip $zip $item.FullName $relPath
        } else {
            $entry = $zip.CreateEntry($relPath, [System.IO.Compression.CompressionLevel]::Optimal)
            $stream = $entry.Open()
            try {
                $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
                $stream.Write($bytes, 0, $bytes.Length)
            } finally {
                $stream.Close()
            }
        }
    }
}

Add-FilesToZip $zip $SourcePath ""
$zip.Dispose()

$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "  Zipped ~$totalItems items ($([math]::Round($totalSize/1MB,1)) MB -> ${zipSize}MB)" -ForegroundColor Green

# ─── Compile with embedded resource ───
Write-Host ""
Write-Host "Compiling create-usb.exe with embedded source..." -ForegroundColor Yellow

$csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
$csFile = Join-Path $OutputDir "create-usb.cs"
$icoFile = Join-Path $OutputDir "opencode-usb-creator.ico"
$outFile = Join-Path $OutputDir "create-usb.exe"

$launcherDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherCs = Join-Path $launcherDir "launcher.cs"
$launcherExe = Join-Path $launcherDir "launcher.exe"

# Splash artwork, embedded so a standalone create-usb.exe still shows it
$splashFile = Join-Path $OutputDir "7bf66f2c-a3a5-4b4b-8c78-0f019bf0d339.png"
if (-not (Test-Path $splashFile)) {
    Write-Error "Splash image not found: $splashFile"
    exit 1
}

# Compile launcher.exe if needed
if (-not (Test-Path $launcherExe)) {
    Write-Host "  Compiling launcher.exe..." -ForegroundColor Yellow
    & "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe" -target:winexe -out:$launcherExe -win32icon:$icoFile $launcherCs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Launcher compilation failed"
        exit 1
    }
}

& $csc -target:winexe `
    -reference:System.Management.dll `
    -reference:System.Drawing.dll `
    -reference:System.Windows.Forms.dll `
    -reference:System.IO.Compression.dll `
    -reference:System.IO.Compression.FileSystem.dll `
    -resource:$zipPath,opencode-source.zip `
    -resource:$launcherExe,launcher.exe `
    -resource:$splashFile,splash.png `
    -out:$outFile `
    -win32icon:$icoFile `
    $csFile

if ($LASTEXITCODE -ne 0) {
    Write-Error "Compilation failed"
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    exit 1
}

# ─── Clean up ───
Remove-Item $zipPath -Force
Write-Host ""
Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Cyan
Write-Host "Output: $outFile" -ForegroundColor Green
$exeSize = [math]::Round((Get-Item $outFile).Length / 1MB, 1)
Write-Host "Size:   ${exeSize}MB (self-contained)" -ForegroundColor Green
