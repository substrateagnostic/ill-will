#requires -Version 5.1
<#
.SYNOPSIS
  ILL WILL frozen board receipt runner (docs/verify/VERIFY-BOARD.md).

.DESCRIPTION
  One command that replays the frozen THE PROCESSION board receipts and
  greps their frozen output lines, printing PASS/FAIL per gate plus a final
  verdict. Exits nonzero if any gate fails. This is the suite runner called
  for by docs/design/research-night7/RC-rework-audit.md §5 step 4 (no such
  runner existed before).

  Gates (VERIFY-BOARD.md is the source of truth for all frozen values):
    1. topology        --boardgraphtest              (§2)
    2. canonical-match  seed=7, turncap=12, nights=3   (§4, md5-verified)
    3. single-night      seed=7, turncap=12, nights=1   (§5)
    4. sweep-seed1/11   seed=1 / seed=11, nights=3      (§4 secondaries, -Sweeps only)

  PRECONDITION (assumed already satisfied — NOT re-run here, it is slow and
  belongs to import/asset changes, not receipt gates):
    godot --headless --editor --import --quit --path .    (must exit 0)
  On a stone-cold checkout (no .godot/ cache yet) this can need TWO runs:
  the first pass builds the cache and may crash mid font-reimport; the
  second pass is clean. Re-run it if gates below fail to boot at all.

  PASS/FAIL is decided by matching frozen output text, not by the raw exit
  code: THE PROCESSION's headless runs end in the known harmless shutdown
  segfault / access violation after quit() (Windows: -1073741819, POSIX
  shells: 139) — treated as harmless whenever the expected lines printed
  first. The exit code is captured best-effort and shown for information
  only.

  Windows PowerShell 5.1. No && / || / ternary. Godot output is always
  captured to a log file first and parsed after — never piped through
  Select-Object directly (godot's own stdout/stderr framing does not mix
  well with the pipeline).

.PARAMETER Quick
  Gates 1+2 only (topology + canonical 3-night match). Skips gate 3 and
  never runs -Sweeps regardless of that switch.

.PARAMETER Sweeps
  Also run the OPTIONAL seed-sweep secondaries (seed 1 & seed 11, 3-night;
  VERIFY-BOARD.md §4 "Seed-sweep secondaries"). Off by default: slow, and
  these are single-run records, not md5-verified x3 like the seed-7 line.

.PARAMETER Godot
  Path to the Godot 4.6 executable. Falls back to $env:GODOT, then `godot`
  on PATH. Automatically prefers the sibling *_console.exe build — the
  plain editor exe is a GUI-subsystem binary that relaunches itself
  detached under output redirection, so the parent process returns before
  the run actually finishes and nothing lands in the log (same fix already
  used by build/package.ps1's Resolve-Godot).

.EXAMPLE
  powershell -File tools\run_receipts.ps1
  powershell -File tools\run_receipts.ps1 -Quick
  powershell -File tools\run_receipts.ps1 -Sweeps
#>
[CmdletBinding()]
param(
    [switch]$Quick,
    [switch]$Sweeps,
    [string]$Godot = $env:GODOT
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot 'verify_out\run_receipts'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Resolve-Godot {
    param([string]$Hint)
    $p = $null
    if ($Hint -and (Test-Path $Hint)) { $p = (Resolve-Path $Hint).Path }
    if (-not $p) {
        $cmd = Get-Command godot -ErrorAction SilentlyContinue
        if ($cmd) { $p = $cmd.Source }
    }
    if (-not $p) { return $null }
    # Follow a symlink / WinGet reparse point to the real editor exe.
    $item = Get-Item $p
    if ($item.Target) { $p = @($item.Target)[0]; $item = Get-Item $p }
    # Prefer the *_console.exe build — see .PARAMETER Godot above.
    $console = Join-Path $item.DirectoryName ($item.BaseName + '_console.exe')
    if (Test-Path $console) { return $console }
    return $p
}

$Godot = Resolve-Godot -Hint $Godot
if (-not $Godot) {
    throw 'Godot 4.6 not found. Pass -Godot <path>, set $env:GODOT, or add godot to PATH.'
}
Write-Host "Godot:   $Godot"
Write-Host "Precondition assumed: godot --headless --editor --import --quit --path . (exit 0)"

# The known harmless post-quit() shutdown crash. Informational only — PASS
# is decided by content match, never by this list.
$HarmlessExit = @('0', '139', '-1073741819')

function Invoke-Receipt {
    param(
        [string[]]$GameArgs,
        [string]$LogName,
        [int]$TimeoutSec = 240
    )
    $logPath = Join-Path $LogDir $LogName
    if (Test-Path $logPath) { Remove-Item $logPath -Force }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath $Godot -ArgumentList $GameArgs -NoNewWindow -PassThru `
        -RedirectStandardOutput $logPath -WorkingDirectory $ProjectRoot
    while ((-not $proc.HasExited) -and ($sw.Elapsed.TotalSeconds -lt $TimeoutSec)) {
        Start-Sleep -Milliseconds 300
    }
    $timedOut = -not $proc.HasExited
    if ($timedOut) {
        try { $proc.Kill() } catch { }
    }
    $exitDisplay = 'n/a'
    try { $exitDisplay = [string]$proc.ExitCode } catch { }
    return [pscustomobject]@{
        LogPath  = $logPath
        TimedOut = $timedOut
        Seconds  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        Exit     = $exitDisplay
    }
}

function Get-MatchedLines {
    param([string]$LogPath, [string]$Pattern)
    if (-not (Test-Path $LogPath)) { return @() }
    return @(Get-Content -LiteralPath $LogPath | Where-Object { $_ -match $Pattern })
}

function Get-LineSetMd5 {
    param([string[]]$Lines)
    $joined = ($Lines -join "`n") + "`n"
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $hashBytes = $md5.ComputeHash($bytes)
    return -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
}

function Format-ExitNote {
    param([string]$Exit)
    if ($HarmlessExit -contains $Exit) { return "exit=$Exit (harmless)" }
    return "exit=$Exit"
}

$script:results = @()

function Report-Gate {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $script:results += [pscustomobject]@{ Name = $Name; Pass = $Pass }
    $tag = 'FAIL'
    if ($Pass) { $tag = 'PASS' }
    Write-Host ("[{0}] {1} - {2}" -f $tag, $Name, $Detail)
}

# --- Gate 1: topology (VERIFY-BOARD.md §2) ---------------------------------
Write-Host "`n== Gate 1: topology (--boardgraphtest) =="
$r1 = Invoke-Receipt -GameArgs @('--headless', '--path', '.', '--', '--procession', '--boardgraphtest') `
    -LogName 'gate1_topology.log' -TimeoutSec 180
if ($r1.TimedOut) {
    Report-Gate 'topology' $false "TIMEOUT after $($r1.Seconds)s ($(Format-ExitNote $r1.Exit)); log: $($r1.LogPath))"
} else {
    $hasChecksum = [bool](Select-String -Path $r1.LogPath -Pattern '^BOARDGRAPH checksum=b269c570$' -Quiet)
    $hasOk = [bool](Select-String -Path $r1.LogPath -Pattern '^BOARDGRAPH_OK$' -Quiet)
    $pass = $hasChecksum -and $hasOk
    Report-Gate 'topology' $pass "checksum=b269c570:$hasChecksum BOARDGRAPH_OK:$hasOk ($($r1.Seconds)s, $(Format-ExitNote $r1.Exit); log: $($r1.LogPath))"
}

# --- Gate 2: canonical 3-night match (VERIFY-BOARD.md §4) ------------------
Write-Host "`n== Gate 2: canonical 3-night match (seed=7) =="
$r2 = Invoke-Receipt -GameArgs @('--headless', '--path', '.', '--', '--procession', '--seed=7', '--turncap=12', '--nights=3', '--autoplay=bots') `
    -LogName 'gate2_match.log' -TimeoutSec 240
if ($r2.TimedOut) {
    Report-Gate 'canonical-match' $false "TIMEOUT after $($r2.Seconds)s ($(Format-ExitNote $r2.Exit)); log: $($r2.LogPath))"
} else {
    $lines = Get-MatchedLines -LogPath $r2.LogPath -Pattern '^PROCESSION_(NIGHT|MATCH|HEIR)'
    $md5 = ''
    if ($lines.Count -gt 0) { $md5 = Get-LineSetMd5 -Lines $lines }
    $expectMd5 = 'da76f7c9d42a6568980ecb55fcaef3e9'
    $heirLine = $lines | Select-Object -Last 1
    $expectHeir = 'PROCESSION_HEIR RED (seed 7, 3 nights)'
    $pass = ($md5 -eq $expectMd5) -and ($heirLine -eq $expectHeir)
    Report-Gate 'canonical-match' $pass "md5=$md5 (expect $expectMd5); heir=[$heirLine] ($($r2.Seconds)s, $(Format-ExitNote $r2.Exit); log: $($r2.LogPath))"
}

# --- Gate 3: single-night record (VERIFY-BOARD.md §5) ----------------------
if (-not $Quick) {
    Write-Host "`n== Gate 3: single-night record (seed=7, nights=1) =="
    $r3 = Invoke-Receipt -GameArgs @('--headless', '--path', '.', '--', '--procession', '--seed=7', '--turncap=12', '--nights=1', '--autoplay=bots') `
        -LogName 'gate3_single.log' -TimeoutSec 180
    if ($r3.TimedOut) {
        Report-Gate 'single-night' $false "TIMEOUT after $($r3.Seconds)s ($(Format-ExitNote $r3.Exit)); log: $($r3.LogPath))"
    } else {
        $lines = Get-MatchedLines -LogPath $r3.LogPath -Pattern '^PROCESSION_(NIGHT|MATCH|HEIR)'
        $heirLine = $lines | Select-Object -Last 1
        $expectHeir = 'PROCESSION_HEIR GOLD (seed 7, 1 nights)'
        $matchLine = $lines | Where-Object { $_ -match '^PROCESSION_MATCH' } | Select-Object -First 1
        $hasWreaths = [bool]($matchLine -match '"wreaths":\[14,7,16,9\]')
        $pass = ($heirLine -eq $expectHeir) -and $hasWreaths
        Report-Gate 'single-night' $pass "heir=[$heirLine]; wreaths=[14,7,16,9]:$hasWreaths ($($r3.Seconds)s, $(Format-ExitNote $r3.Exit); log: $($r3.LogPath))"
    }
}

# --- Gate 4 (OPTIONAL): seed sweeps, 3-night (VERIFY-BOARD.md §4 secondaries) --
if ($Sweeps) {
    $sweepSeeds = @(
        [pscustomobject]@{ Seed = 1;  Heir = 'BLUE'; Wreaths = '[43,63,37,46]' },
        [pscustomobject]@{ Seed = 11; Heir = 'BLUE'; Wreaths = '[55,60,37,37]' }
    )
    foreach ($sweep in $sweepSeeds) {
        $seed = $sweep.Seed
        Write-Host "`n== Gate 4 (sweep): seed=$seed, 3-night =="
        $r = Invoke-Receipt -GameArgs @('--headless', '--path', '.', '--', '--procession', "--seed=$seed", '--turncap=12', '--nights=3', '--autoplay=bots') `
            -LogName "gate4_sweep_seed$seed.log" -TimeoutSec 240
        $gateName = "sweep-seed$seed"
        if ($r.TimedOut) {
            Report-Gate $gateName $false "TIMEOUT after $($r.Seconds)s ($(Format-ExitNote $r.Exit)); log: $($r.LogPath))"
        } else {
            $lines = Get-MatchedLines -LogPath $r.LogPath -Pattern '^PROCESSION_(NIGHT|MATCH|HEIR)'
            $heirLine = $lines | Select-Object -Last 1
            $expectHeir = "PROCESSION_HEIR $($sweep.Heir) (seed $seed, 3 nights)"
            $matchLine = $lines | Where-Object { $_ -match '^PROCESSION_MATCH' } | Select-Object -First 1
            $wreathsPattern = [regex]::Escape('"wreaths":' + $sweep.Wreaths)
            $hasWreaths = [bool]($matchLine -match $wreathsPattern)
            $pass = ($heirLine -eq $expectHeir) -and $hasWreaths
            Report-Gate $gateName $pass "heir=[$heirLine]; wreaths=$($sweep.Wreaths):$hasWreaths ($($r.Seconds)s, $(Format-ExitNote $r.Exit); log: $($r.LogPath))"
        }
    }
}

# --- Verdict ----------------------------------------------------------------
Write-Host "`n===================="
$failed = @($script:results | Where-Object { -not $_.Pass })
if ($failed.Count -eq 0) {
    Write-Host "VERDICT: PASS ($($script:results.Count)/$($script:results.Count) gates)"
    exit 0
} else {
    $failNames = ($failed | ForEach-Object { $_.Name }) -join ', '
    Write-Host "VERDICT: FAIL ($($failed.Count)/$($script:results.Count) gates failed: $failNames)"
    exit 1
}
