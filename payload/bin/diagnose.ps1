# Collects everything needed to work out why opencode fails on a given PC.
# Writes a single report to the USB root. Nothing is written to the host.
param([string]$UsbRoot)

if (-not $UsbRoot) { $UsbRoot = Split-Path $PSScriptRoot -Parent }
$report = Join-Path $UsbRoot "diagnostic-report.txt"

$env:PATH = "$UsbRoot\bin;$UsbRoot\nodejs;$UsbRoot\wezterm;$env:PATH"
$env:XDG_DATA_HOME   = "$UsbRoot\data\xdg\data"
$env:XDG_CONFIG_HOME = "$UsbRoot\data\xdg\config"
$env:XDG_CACHE_HOME  = "$UsbRoot\data\xdg\cache"
$env:XDG_STATE_HOME  = "$UsbRoot\data\xdg\state"
$env:OPENCODE_CONFIG_DIR = "$UsbRoot\data\config"
$env:TEMP = "$UsbRoot\data\tmp"; $env:TMP = "$UsbRoot\data\tmp"
New-Item -ItemType Directory -Force -Path "$UsbRoot\data\tmp" | Out-Null

$out = New-Object System.Collections.ArrayList
function W($t) { [void]$out.Add($t); Write-Host $t }

W "OpenCode Portable USB - diagnostic report"
W "generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
W "USB root:  $UsbRoot"
W ""

W "=== MACHINE ==="
W "computer:  $env:COMPUTERNAME"
$os = Get-CimInstance Win32_OperatingSystem
W "windows:   $($os.Caption) build $($os.BuildNumber) ($($os.OSArchitecture))"
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
W "cpu:       $($cpu.Name)"
W "cores:     $($cpu.NumberOfCores) physical / $($cpu.NumberOfLogicalProcessors) logical"
W "arch:      $env:PROCESSOR_ARCHITECTURE (level $env:PROCESSOR_LEVEL, rev $env:PROCESSOR_REVISION)"
W ""

# AVX2 matters: opencode ships as a Bun binary and Bun's standard x64 build
# requires AVX2. CPUs older than Intel Haswell / AMD Excavator lack it and the
# process dies immediately with a bare exit code.
W "=== AVX2 SUPPORT (opencode is a Bun binary; Bun x64 needs AVX2) ==="
$avx = "unknown"
try {
    # PowerShell 7+ / .NET 5+ exposes CPU intrinsics directly — no compilation.
    $avx = [System.Runtime.Intrinsics.X86.Avx2]::IsSupported
} catch {
    # Windows PowerShell 5.1 lacks System.Runtime.Intrinsics.
    # Fall back to a CPU-name heuristic via WMI (no C# Add-Type needed).
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cpuName = if ($cpu) { $cpu.Name } else { "unknown" }
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        $avx = "N/A (ARM64 — AVX2 is x86-only)"
    } elseif ($cpuName -match "Intel.*(Core.*[4-9]\d{3}|Core.*[1-9]\d{3,}i|Haswell|Broadwell|Skylake|Kaby|Coffee|Comet|Rocket|Alder|Raptor|Meteor|Lunar|Arrow)" -or
              $cpuName -match "AMD.*(Ryzen|EPYC|Zen|FX-[89])") {
        $avx = "likely yes (CPU: $cpuName)"
    } else {
        $avx = "undetermined (CPU: $cpuName) — manual check recommended"
    }
}
W "AVX2 available: $avx"
if ($avx -eq $false) {
    W "*** THIS IS ALMOST CERTAINLY THE PROBLEM ***"
    W "    This CPU lacks AVX2. Bun-compiled binaries cannot run on it."
    W "    A 'baseline' build of opencode is required for this machine."
}
W ""

W "=== FILES PRESENT ==="
foreach ($f in @("bin\opencode.exe","nodejs\node.exe","wezterm\wezterm.exe","wezterm\wezterm-gui.exe",
                 "config\wezterm.lua","data\config\opencode.json","launcher.bat","OpenCode AI.exe")) {
    $p = Join-Path $UsbRoot $f
    # -Force: several of these are deliberately hidden on the stick
    $sz = if (Test-Path $p) { "{0:N1} MB" -f ((Get-Item $p -Force).Length/1MB) } else { "MISSING" }
    W ("  {0,-30} {1}" -f $f, $sz)
}
W ""

W "=== opencode.json ==="
$cfgPath = Join-Path $UsbRoot "data\config\opencode.json"
if (Test-Path $cfgPath) { W (Get-Content $cfgPath -Raw) } else { W "  MISSING" }
W ""

function TryRun($label, $argList, $timeoutSec) {
    W "=== $label ==="
    # Use System.Diagnostics.Process directly rather than Start-Process: the
    # latter does not reliably populate ExitCode when used with -PassThru, and
    # the exit code is the single most important thing this report captures.
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "$UsbRoot\bin\opencode.exe"
        $psi.Arguments = ($argList -join ' ')
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)

        $stdout = $proc.StandardOutput.ReadToEndAsync()
        $stderr = $proc.StandardError.ReadToEndAsync()

        if (-not $proc.WaitForExit($timeoutSec * 1000)) {
            W "  still running after ${timeoutSec}s (that is GOOD - it did not crash)"
            try { $proc.Kill() } catch { }
        } else {
            W "  exit code: $($proc.ExitCode)"
            if ($proc.ExitCode -ne 0) { W "  *** NON-ZERO EXIT - this is the failure ***" }
        }
        foreach ($pair in @(@("stdout",$stdout), @("stderr",$stderr))) {
            $t = ""
            try { $t = $pair[1].Result } catch { }
            if ($t -and $t.Trim()) { W "  --- $($pair[0]) ---"; W ($t.Trim()) }
        }
    } catch { W "  LAUNCH FAILED: $($_.Exception.Message)" }
    W ""
}

TryRun "opencode --version"                    @("--version") 30
TryRun "opencode auth list"                    @("auth","list") 30
TryRun "opencode --print-logs (debug startup)" @("--print-logs","--log-level","DEBUG","--version") 30

# THE IMPORTANT ONE. The checks above all use CLI subcommands that exit
# straight away; none of them start the TUI, which is the path that actually
# fails. Launching bare 'opencode' reproduces the real failure and captures
# whatever it prints on the way down.
TryRun "opencode TUI (bare launch - THE FAILING PATH)" @("--print-logs","--log-level","DEBUG") 25

W "=== SESSION FOLDERS (a launch that dies early leaves only session.md) ==="
$sess = Get-ChildItem "$UsbRoot\sessions" -Directory -Force -ErrorAction SilentlyContinue |
        Sort-Object CreationTime -Descending | Select-Object -First 5
foreach ($s in $sess) {
    $hasData = Test-Path (Join-Path $s.FullName "opencode-data")
    W ("  {0}  created {1}  opencode-data: {2}" -f $s.Name, $s.CreationTime.ToString('HH:mm:ss'), $hasData)
}
W ""

W "=== opencode log files on the USB ==="
$logDir = "$UsbRoot\data\xdg\data\opencode\log"
if (Test-Path $logDir) {
    Get-ChildItem $logDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 2 | ForEach-Object {
        W "  --- $($_.Name) (last 40 lines) ---"
        Get-Content $_.FullName -Tail 40 | ForEach-Object { W "    $_" }
    }
} else { W "  none" }

$out | Set-Content $report -Encoding UTF8
Write-Host ""
Write-Host "Report written to: $report" -ForegroundColor Green
