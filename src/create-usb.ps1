<#
.SYNOPSIS
  Portable OpenCode AI USB Creator
  Creates a fully-configured portable OpenCode AI USB drive.
.DESCRIPTION
  Detects source OpenCode files (from EXE's folder, template\ subfolder,
  or an existing OpenCode USB), prompts user to select a target USB drive,
  optionally partitions it, then copies and configures everything.
.PARAMETER Source
  Optional path to the source OpenCode files. If omitted, auto-detects.
#>

param(
    [string]$Source = ""
)

$Host.UI.RawUI.WindowTitle = "Portable OpenCode AI - USB Creator"

# ===== ADMIN CHECK =====
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "  ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "This tool needs to run as Administrator to:" -ForegroundColor Yellow
    Write-Host "  - Access USB drives via WMI"
    Write-Host "  - Partition and format drives (diskpart)"
    Write-Host "  - Set file attributes"
    Write-Host ""
    Write-Host "Please restart this tool 'As Administrator'." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

# ===== CONSOLE HELPERS =====
function Write-Step($text) {
    Write-Host ""
    Write-Host ">> $text" -ForegroundColor Cyan
}
function Write-OK($text) {
    Write-Host "   [OK] $text" -ForegroundColor DarkGreen
}
function Write-Warn($text) {
    Write-Host "   [!] $text" -ForegroundColor DarkYellow
}
function Write-Error($text) {
    Write-Host "   [ERROR] $text" -ForegroundColor Red
}

# ===== PHASE 0: SOURCE DETECTION =====
Write-Step "Detecting OpenCode source files..."

function Find-Source {
    $scriptDir = Split-Path $MyInvocation.ScriptName -Parent
    $candidates = @()

    # 1. Explicit -Source parameter
    if ($Source -and (Test-Path "$Source\bin\opencode.exe")) {
        return (Resolve-Path $Source).Path
    }

    # 2. Script's own directory
    if (Test-Path "$scriptDir\bin\opencode.exe") {
        return $scriptDir
    }

    # 3. Parent of script directory
    $parentDir = (Get-Item $scriptDir).Parent.FullName
    if (Test-Path "$parentDir\bin\opencode.exe") {
        return $parentDir
    }

    # 4. D: drive (common master USB)
    if (Test-Path "D:\bin\opencode.exe") {
        return "D:\"
    }

    # 5. Any removable drive
    $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
    foreach ($d in $drives) {
        $root = $d.DeviceID
        if (Test-Path "$root\bin\opencode.exe") {
            return $root
        }
    }

    return $null
}

$SourceRoot = Find-Source
if (-not $SourceRoot) {
    Write-Error "Could not find OpenCode source files."
    Write-Host "Make sure this script is in the same directory as bin\opencode.exe"
    Write-Host "or on an existing OpenCode USB drive."
    Write-Host ""
    Write-Host "You can also specify source with: -Source D:\"
    pause
    exit 1
}

Write-OK "Source: $SourceRoot"
Write-Host "       (found: bin\opencode.exe, nodejs, wezterm, config, ...)"

# Verify key directories exist
$requiredDirs = @("bin", "config", "data", "nodejs", "wezterm")
foreach ($dir in $requiredDirs) {
    if (-not (Test-Path "$SourceRoot\$dir")) {
        Write-Error "Missing required directory: $SourceRoot\$dir"
        Write-Host "This doesn't appear to be a complete OpenCode USB."
        pause
        exit 1
    }
}

# ===== PHASE 1: SELECT TARGET USB =====
Write-Step "Select target USB drive..."

Write-Host ""
Write-Host "Searching for USB drives..."
Write-Host ""

$usbDisks = Get-CimInstance Win32_DiskDrive | Where-Object { $_.InterfaceType -eq "USB" }
if (-not $usbDisks) {
    Write-Error "No USB drives detected."
    Write-Host "Please insert a USB drive and run this tool again."
    pause
    exit 1
}

$diskMap = @{}
$index = 0
$selectedDisk = $null

foreach ($disk in $usbDisks) {
    $index++
    $sizeGB = [math]::Round($disk.Size / 1GB, 1)
    $model = $disk.Model
    $diskNum = $disk.Index

    # Get partitions and volumes for this disk
    $partitions = Get-CimInstance Win32_DiskDriveToDiskPartition | Where-Object { $_.Antecedent -match "Disk #$diskNum" }
    $volInfo = @()
    foreach ($part in $partitions) {
        $partNum = ($part.Dependent -replace '.*Disk #\d+, Partition #(\d+).*', '$1')
        $ld = Get-CimInstance Win32_LogicalDiskToPartition | Where-Object { $_.Antecedent -match "Disk #$diskNum, Partition #$partNum" }
        foreach ($l in $ld) {
            $letter = ($l.Dependent -replace '.*DeviceID="(\w):".*', '$1')
            $volInfo += "$letter`:"
        }
    }

    $volStr = if ($volInfo) { "$($volInfo -join ', ') - " } else { "No volumes - " }

    Write-Host "[$index] $model" -ForegroundColor Yellow
    Write-Host "     Size: ${sizeGB}GB  |  $volStr" + "Disk #$diskNum"

    $diskMap[$index] = $disk
}

Write-Host ""
$selection = Read-Host "Select drive number (or 0 to cancel)"
if ($selection -eq "0" -or $selection -eq "") {
    Write-Host "Cancelled."
    exit 0
}

$selectedDisk = $diskMap[[int]$selection]
if (-not $selectedDisk) {
    Write-Error "Invalid selection."
    pause
    exit 1
}

$diskNum = $selectedDisk.Index
$diskSizeGB = [math]::Round($selectedDisk.Size / 1GB, 1)
Write-OK "Selected: $($selectedDisk.Model) (Disk #$diskNum, ${diskSizeGB}GB)"

# ===== PHASE 2: WARNING =====
Write-Step "WARNING!"

Write-Host ""
Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
Write-Host "  ALL DATA ON DISK #$diskNum WILL BE DESTROYED!" -ForegroundColor Red
Write-Host "  ($($selectedDisk.Model) - ${diskSizeGB}GB)" -ForegroundColor Red
Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
Write-Host ""
Write-Host "Make sure you have backed up any important files."
Write-Host ""

$confirm = Read-Host "Type DESTROY to continue (anything else cancels)"
if ($confirm -ne "DESTROY") {
    Write-Host "Cancelled."
    exit 0
}

# ===== PHASE 3: PARTITION =====
Write-Step "Partitioning USB drive..."

Write-Host ""
Write-Host "How would you like to partition this drive (${diskSizeGB}GB)?"
Write-Host "  [1] Single partition (everything in one drive)"
if ($diskSizeGB -ge 50) {
    Write-Host "  [2] Two partitions: Tools (50% of drive) + Storage (remaining)"
    Write-Host "  [3] Custom two-partition layout"
}
Write-Host "  [4] Skip (drive already partitioned)"
Write-Host ""
$partChoice = Read-Host "Choose (1/2/3/4)"

$partitionCount = 0
$partitions = @()

switch ($partChoice) {
    "1" {
        $partitionCount = 1
        $partitions = @(@{Size = 0; Label = "OpenCode AI"; EntireDisk = $true})
        Write-OK "Will create single partition using entire drive"
    }
    "2" {
        $toolsSize = [math]::Max(10, [math]::Floor($diskSizeGB / 2))
        $storageSize = $diskSizeGB - $toolsSize
        $partitionCount = 2
        $partitions = @(
            @{Size = $toolsSize; Label = "OpenCode AI"},
            @{Size = 0; Label = "Storage"; Remainder = $true}
        )
        Write-OK "Partition 1: ${toolsSize}GB - Tools (label: OpenCode AI)"
        Write-OK "Partition 2: ${storageSize}GB - Storage (label: Storage)"
    }
    "3" {
        Write-Host ""
        $toolsSizeStr = Read-Host "Size for Tools partition in GB (e.g. 37)"
        $toolsSize = [int]$toolsSizeStr
        if ($toolsSize -lt 10 -or $toolsSize -ge $diskSizeGB) {
            Write-Error "Invalid size. Must be between 10 and $($diskSizeGB - 1) GB."
            pause
            exit 1
        }
        $toolsLabel = Read-Host "Label for Tools partition (default: OpenCode AI)"
        if (-not $toolsLabel) { $toolsLabel = "OpenCode AI" }
        $storageLabel = Read-Host "Label for Storage partition (default: Storage)"
        if (-not $storageLabel) { $storageLabel = "Storage" }
        $partitionCount = 2
        $partitions = @(
            @{Size = $toolsSize; Label = $toolsLabel},
            @{Size = 0; Label = $storageLabel; Remainder = $true}
        )
        $storageSize = $diskSizeGB - $toolsSize
        Write-OK "Partition 1: ${toolsSize}GB - Tools (label: $toolsLabel)"
        Write-OK "Partition 2: ${storageSize}GB - Storage (label: $storageLabel)"
    }
    "4" {
        Write-OK "Skipping partitioning. Using existing partitions."
        $partitionCount = -1
    }
    default {
        Write-Error "Invalid choice."
        pause
        exit 1
    }
}

if ($partitionCount -ne -1) {
    Write-Host ""
    $partStyleChoice = Read-Host "Partition style (MBR/GPT, default MBR)"
    if ($partStyleChoice -eq '' -or $partStyleChoice -eq 'MBR') { $partStyle = 'MBR' } else { $partStyle = 'GPT' }
    Write-OK "Using $partStyle partition style"

    Write-Host ""
    Write-Host "Creating partitions... (this may take a moment)" -ForegroundColor Yellow

    # ─── Try PowerShell Storage cmdlets first (more reliable) ───
    $psSuccess = $false
    try {
        $partitionArgs = @()

        $dpStyle = if ($partStyle -eq 'GPT') { 'gpt' } else { 'mbr' }
        $dpScript = "@`"``r``nselect disk $diskNum``r``nclean``r``nconvert $dpStyle``r``nexit``r``n`"@"
        if ($partitions.Count -eq 1) {
            $psCmd = "$dpScript | diskpart; " +
                     "if (`$LASTEXITCODE -ne 0) { throw 'diskpart failed' }; " +
                     "Start-Sleep -Seconds 2; " +
                     "`$p = New-Partition -DiskNumber $diskNum -UseMaximumSize -AssignDriveLetter -ErrorAction Stop; " +
                     "Start-Sleep -Seconds 2; " +
                     "`$v = `$p | Get-Volume; " +
                     "Format-Volume -DriveLetter `$v.DriveLetter -FileSystem EXFAT -NewFileSystemLabel '$($partitions[0].Label)' -Confirm:`$false -ErrorAction Stop; " +
                     "Write-Host 'PS-OK'"
        } else {
            $psCmd = "$dpScript | diskpart; " +
                     "if (`$LASTEXITCODE -ne 0) { throw 'diskpart failed' }; " +
                     "Start-Sleep -Seconds 2; " +
                     "`$p1 = New-Partition -DiskNumber $diskNum -Size $($partitions[0].Size)GB -AssignDriveLetter -ErrorAction Stop; " +
                     "Start-Sleep -Seconds 1; " +
                     "`$v1 = `$p1 | Get-Volume; " +
                     "Format-Volume -DriveLetter `$v1.DriveLetter -FileSystem EXFAT -NewFileSystemLabel '$($partitions[0].Label)' -Confirm:`$false -ErrorAction Stop; " +
                     "Write-Host 'PS-P1-OK'; " +
                     "`$p2 = New-Partition -DiskNumber $diskNum -UseMaximumSize -AssignDriveLetter -ErrorAction Stop; " +
                     "Start-Sleep -Seconds 1; " +
                     "`$v2 = `$p2 | Get-Volume; " +
                     "Format-Volume -DriveLetter `$v2.DriveLetter -FileSystem EXFAT -NewFileSystemLabel '$($partitions[1].Label)' -Confirm:`$false -ErrorAction Stop; " +
                     "Write-Host 'PS-P2-OK'"
        }

        $psScript = [System.IO.Path]::GetTempFileName() + ".ps1"
        $psCmd | Set-Content $psScript -Encoding Unicode -Force

        Write-Host "  Trying PowerShell Storage cmdlets..." -ForegroundColor DarkGray
        $psResult = powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $psScript 2>&1
        $psExit = $LASTEXITCODE

        Remove-Item $psScript -Force -ErrorAction SilentlyContinue

        if ($psExit -eq 0 -and ($psResult -match 'PS-OK' -or $psResult -match 'PS-P2-OK')) {
            Write-OK "PowerShell partitioning succeeded"
            $psSuccess = $true
        } else {
            Write-Warn "PowerShell partitioning failed, falling back to diskpart..."
            if ($psResult) { $psResult | ForEach-Object { Write-Warn "  $_" } }
        }
    } catch {
        Write-Warn "PowerShell approach not available, falling back to diskpart..."
        Write-Warn "  $_"
    }

    if (-not $psSuccess) {
        # ─── Fall back to diskpart ───
        $convertCmd = if ($partStyle -eq 'GPT') { 'convert gpt' } else { 'convert mbr' }
        $diskpartScript = @"
select disk $diskNum
rescan
clean
$convertCmd
rescan
"@

        foreach ($part in $partitions) {
            if ($part.EntireDisk) {
                $diskpartScript += @"

create partition primary
format fs=exFAT quick override label="$($part.Label)"
assign
"@
            } elseif ($part.Remainder) {
                $diskpartScript += @"

create partition primary
format fs=exFAT quick override label="$($part.Label)"
assign
"@
            } else {
                $diskpartScript += @"

create partition primary size=$($part.Size * 1024)
format fs=exFAT quick override label="$($part.Label)"
assign
"@
            }
        }

        $diskpartScript += @"
exit
"@

        $dpScriptPath = [System.IO.Path]::GetTempFileName() + ".txt"
        $diskpartScript | Set-Content $dpScriptPath -Encoding ASCII -Force

        Write-Host "  Running diskpart (fallback)..." -ForegroundColor Yellow
        Write-Host "  (Script: $dpScriptPath)" -ForegroundColor DarkGray

        $result = diskpart /s $dpScriptPath 2>&1
        if ($LASTEXITCODE -ne 0 -or $result -match 'DiskPart has encountered an error' -or $result -match 'failed') {
            Write-Error "diskpart failed. Output:"
            $result | ForEach-Object { Write-Warn $_ }
            Remove-Item $dpScriptPath -Force -ErrorAction SilentlyContinue
            Write-Host ""
            Write-Host "Possible fixes:" -ForegroundColor Yellow
            Write-Host "  1. Close all Explorer/file manager windows showing the USB" -ForegroundColor Yellow
            Write-Host "  2. Make sure the USB isn't write-protected" -ForegroundColor Yellow
            Write-Host "  3. Run this tool as Administrator" -ForegroundColor Yellow
            pause
            exit 1
        }

        Remove-Item $dpScriptPath -Force -ErrorAction SilentlyContinue
        Write-OK "diskpart partitioning complete"
    }

    # Wait for volumes to appear
    Write-Host "Waiting for volumes to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

# ===== PHASE 4: FIND TARGET DRIVE LETTER =====
Write-Step "Locating target drive..."

# After partitioning, we need to find which drive letter was assigned
# Wait a bit more for Windows to assign letters
Start-Sleep -Seconds 2

$targetRoot = $null
$storageRoot = $null

# Try to find the newly created OpenCode AI volume
$volumes = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
foreach ($v in $volumes) {
    $volDisk = Get-CimInstance Win32_LogicalDiskToPartition | Where-Object { $_.Dependent -match "DeviceID=`"$($v.DeviceID)`"" }
    foreach ($vd in $volDisk) {
        if ($vd.Antecedent -match "Disk #$diskNum") {
            if ($v.VolumeName -eq "OpenCode AI" -or -not $targetRoot) {
                $targetRoot = $v.DeviceID
            } else {
                $storageRoot = $v.DeviceID
            }
        }
    }
}

if (-not $targetRoot) {
    # Fallback: just pick the first volume on the target disk
    $allParts = Get-CimInstance Win32_LogicalDiskToPartition
    foreach ($p in $allParts) {
        if ($p.Antecedent -match "Disk #$diskNum") {
            $deviceId = $p.Dependent -replace '.*DeviceID="(\w:)".*', '$1'
            if (Test-Path $deviceId) {
                $targetRoot = $deviceId
                break
            }
        }
    }
}

if (-not $targetRoot) {
    Write-Error "Could not find the target drive letter."
    Write-Host "Please check if the USB was partitioned correctly."
    Write-Host "You may need to assign a drive letter manually in Disk Management."
    pause
    exit 1
}

# Ensure trailing backslash
if (-not $targetRoot.EndsWith("\")) { $targetRoot += "\" }
if ($storageRoot -and -not $storageRoot.EndsWith("\")) { $storageRoot += "\" }

Write-OK "Target tools drive: $targetRoot"
if ($storageRoot) {
    Write-OK "Storage drive:      $storageRoot"
}

# ===== PHASE 5: COPY FILES =====
Write-Step "Copying files to USB..."

Write-Host "  This may take several minutes..." -ForegroundColor Yellow
Write-Host ""

$sourceItems = Get-ChildItem "$SourceRoot" -Force | Where-Object {
    $_.Name -notin @("sessions", "Sessions", "System Volume Information", "$RECYCLE.BIN")
}

$totalItems = 0
$totalSize = 0
foreach ($item in $sourceItems) {
    if ($item.PSIsContainer) {
        $size = (Get-ChildItem $item.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $totalSize += $size
        $totalItems++
    } else {
        $totalSize += $item.Length
        $totalItems++
    }
}
$totalSizeMB = [math]::Round($totalSize / 1MB, 1)
Write-Host "  Found $totalItems items (${totalSizeMB}MB) to copy"
Write-Host ""

$copied = 0
$errors = 0

foreach ($item in $sourceItems) {
    $name = $item.Name
    $destPath = "$targetRoot$name"
    $progress = [math]::Round(($copied / $totalItems) * 100, 0)
    Write-Progress -Activity "Copying to USB" -Status "$progress% - $name" -PercentComplete $progress

    try {
        if ($item.PSIsContainer) {
            # Use robocopy for directories (faster, handles deep paths)
            $robolog = [System.IO.Path]::GetTempFileName()
            $robocopyArgs = @(
                $item.FullName, $destPath, "/MIR", "/NP", "/NDL", "/NJH", "/NJS",
                "/XD", "node_modules", ".git", "__pycache__",
                "/R:2", "/W:2"
            )
            $proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -ge 8) {
                Write-Warn "Robocopy had warnings for '$name' (exit code: $($proc.ExitCode))"
            }
        } else {
            Copy-Item $item.FullName $destPath -Force -ErrorAction Stop
        }
        $copied++
    } catch {
        Write-Warn "Failed to copy '$name': $_"
        $errors++
    }
}

Write-Progress -Activity "Copying to USB" -Completed
Write-OK "Copied $copied items ($errors errors)"

# ===== PHASE 6: CONFIGURE =====
Write-Step "Configuring USB..."

# Rename the launcher to its visible, double-click name. A .exe resolves its own folder
# at runtime, so it keeps working no matter what drive letter Windows assigns this stick on
# a given PC. A .lnk shortcut instead bakes in an absolute "D:\..." path at creation time,
# which breaks the moment the same USB mounts under a different letter on another computer.
$oldLauncherExe = "$targetRoot\OpenCode AI Launcher.exe"
$exePath = "$targetRoot\OpenCode AI.exe"
if ((Test-Path $oldLauncherExe) -and -not (Test-Path $exePath)) {
    Rename-Item -Path $oldLauncherExe -NewName "OpenCode AI.exe" -Force -ErrorAction SilentlyContinue
}

# Remove stale artifacts from older versions of this tool (previous runs on this stick)
foreach ($old in @("OpenCode AI Launcher.exe", "OpenCode AI.lnk", "Session Logs.lnk", "Check for Updates.lnk", "launcher.vbs")) {
    $path = "$targetRoot\$old"
    if (Test-Path $path) { Remove-Item -Path $path -Force -ErrorAction SilentlyContinue }
}

# Hide internal folders
$hiddenItems = @(
    "bin", "config", "data", "nodejs", "wezterm", "sessions",
    "launcher.bat", "launcher-no-wezterm.bat", "opencode-usb-creator.ico"
)
foreach ($item in $hiddenItems) {
    $path = "$targetRoot$item"
    if (Test-Path $path) {
        Set-ItemProperty -Path $path -Name Attributes -Value ([System.IO.FileAttributes]::Hidden) -ErrorAction SilentlyContinue
    }
}

# Ensure README and shortcuts are visible
$visibleItems = @("README.txt", "OpenCode AI.exe", "Session Logs.bat", "Check for Updates.bat")
foreach ($item in $visibleItems) {
    $path = "$targetRoot$item"
    if (Test-Path $path) {
        $current = (Get-Item $path -Force).Attributes
        if ($current -band [System.IO.FileAttributes]::Hidden) {
            Set-ItemProperty -Path $path -Name Attributes -Value ($current -bxor [System.IO.FileAttributes]::Hidden) -ErrorAction SilentlyContinue
        }
    }
}

# Session Logs / Check for Updates: self-locating batch files (via %~dp0) instead of
# .lnk shortcuts, so these also survive a drive-letter change on another PC.
try {
    Set-Content -Path "$targetRoot\Session Logs.bat" -Encoding ASCII -Value @(
        '@echo off'
        'start "" explorer.exe "%~dp0sessions"'
    )
    Write-OK "Created: Session Logs.bat"
} catch {
    Write-Warn "Could not create Session Logs.bat: $_"
}

try {
    Set-Content -Path "$targetRoot\Check for Updates.bat" -Encoding ASCII -Value @(
        '@echo off'
        'cd /d "%~dp0bin"'
        'powershell.exe -NoLogo -ExecutionPolicy Bypass -NoProfile -File "%~dp0bin\check-updates.ps1"'
        'pause'
    )
    Write-OK "Created: Check for Updates.bat"
} catch {
    Write-Warn "Could not create Check for Updates.bat: $_"
}

# Create initial sessions folder
if (-not (Test-Path "$targetRoot\sessions")) {
    New-Item -ItemType Directory -Path "$targetRoot\sessions" -Force | Out-Null
    Set-ItemProperty -Path "$targetRoot\sessions" -Name Attributes -Value ([System.IO.FileAttributes]::Hidden) -ErrorAction SilentlyContinue
    Write-OK "Created: sessions\ folder"
}

# ===== PHASE 7: WRITE CONFIG =====
Write-Step "Writing drive-specific config..."

# Update opencode.json with correct drive-letter-agnostic paths
$configPath = "$targetRoot\data\config\opencode.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        # The config should already be drive-letter agnostic (using short names)
        # But let's make sure the MCP commands use the correct paths
        if ($config.mcp) {
            foreach ($mcpKey in $config.mcp.PSObject.Properties.Name) {
                $cmd = $config.mcp.$mcpKey.command
                if ($cmd -is [array]) {
                    $cmd[0] = $cmd[0]  # Keep as-is (should be relative name, not full path)
                }
            }
        }
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8 -Force
        Write-OK "Updated: data\config\opencode.json"
    } catch {
        Write-Warn "Could not update opencode.json: $_"
    }
}

# ===== PHASE 8: SUCCESS =====
Write-Step "Done!"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  USB CREATION COMPLETE!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Target drive: $targetRoot"
if ($storageRoot) {
    Write-Host "  Storage drive: $storageRoot"
}
Write-Host ""
Write-Host "  To use:"
Write-Host "    1. Safely eject the USB"
Write-Host "    2. Plug it into any Windows 10/11 PC"
Write-Host "    3. Open the USB in File Explorer"
Write-Host "    4. Double-click 'OpenCode AI.exe'"
Write-Host ""
Write-Host "  Features:"
Write-Host "    - Only the WezTerm (opencode) window appears"
Write-Host "    - Session logs saved automatically"
Write-Host "    - 5 built-in skills, 3 MCP servers"
Write-Host "    - 'Check for Updates.bat' to stay current"
Write-Host ""
Write-Host "  Note: If you made two partitions, the storage"
Write-Host "  drive ($storageRoot) is for your project files."
Write-Host "==============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Press any key to exit."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
