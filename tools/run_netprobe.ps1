#requires -Version 5.1
<#
.SYNOPSIS
  ILL WILL two-process ONLINE NETPROBE (ONLINE ERA, task #91).

.DESCRIPTION
  Launches a HOST estate and a GUEST estate as two real headless processes on
  this machine, connected over loopback ENet, and lets the frozen sim play a
  full bot match while the guest mirrors THE PROCESSION from 20 Hz snapshots.
  Both sides print PROCESSION_NETPROBE_{HOST,CLIENT} fact hashes keyed by the
  pump's snapshot seq; this runner pairs them and rules a single verdict line:

      NETPROBE VERDICT: PASS | FAIL

  What a PASS certifies (see docs/verify/VERIFY-BOARD.md "4-NET"):
    - host night opens, guest joins, seat granted over the wire
    - the guest boots the procession MIRROR (the stirnettest shell, live)
    - every paired snapshot hash matches: positions, moved, pennies (grudge),
      WREATHS, arrivals, bell, pre-commit plan fields, and the LIVE graph
      adjacency (Estate Stirs mutations replayed on the guest)
    - the mirror held across nights (night >= 2 seen by the guest)
    - the match ran to its natural PROCESSION_HEIR finale

  PRECONDITION (not run here): the import gate —
      godot --headless --editor --import --quit --path .   (exit 0; run
      twice on a stone-cold checkout).

  Save safety: user://* (party_setup.json, prefs.json, saves/slot_1.json,
  saves/slot_3.json) is externally backed up before launch and restored
  after, on top of the in-game .npbak rig. The probe itself plays on scratch
  --slot=3; a slot_3.json that did not exist before the run is deleted.

  Exit 139 / -1073741819 after quit() is the known harmless shutdown crash;
  PASS/FAIL is decided by log content only.

.PARAMETER Seed
  Host --seed (EstateState stream; keeps reruns comparable). Default 7.

.PARAMETER Port
  Loopback ENet port. Default 8917 (clear of the 8910 default so a live
  session elsewhere on this machine cannot collide with the probe).

.PARAMETER TimeoutSec
  Whole-session budget before both processes are killed. Default 1800 —
  the certified run plays at COUCH PACE (--slowsim): compressing the match
  (plain --autoplay blitzes 3 nights in ~2 s of wall time) makes the whole
  match fit inside the guest's ~3 s world build, which is a probe artifact,
  not a transport truth. Real pace is what four friends actually get.

.PARAMETER MinPairs
  Minimum number of paired (host,client) hash seqs for a PASS. Default 300.

.EXAMPLE
  powershell -File tools\run_netprobe.ps1
  powershell -File tools\run_netprobe.ps1 -Seed 11 -Port 8919
#>
[CmdletBinding()]
param(
    [int]$Seed = 7,
    [int]$Port = 8917,
    [int]$TimeoutSec = 1800,
    [int]$MinPairs = 300,
    [string]$Godot = $env:GODOT
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot 'verify_out\netprobe'
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
    $item = Get-Item $p
    if ($item.Target) { $p = @($item.Target)[0]; $item = Get-Item $p }
    $console = Join-Path $item.DirectoryName ($item.BaseName + '_console.exe')
    if (Test-Path $console) { return $console }
    return $p
}

$Godot = Resolve-Godot -Hint $Godot
if (-not $Godot) {
    throw 'Godot 4.6 not found. Pass -Godot <path>, set $env:GODOT, or add godot to PATH.'
}
Write-Host "Godot:   $Godot"
Write-Host "Seed:    $Seed   Port: $Port   Timeout: ${TimeoutSec}s"

# ---- user:// save safety (external backup, belt over the in-game .npbak rig)
$UserDir = Join-Path $env:APPDATA 'Godot\app_userdata\ILL WILL'
$BackupDir = Join-Path $LogDir 'userbackup'
$Guarded = @('party_setup.json', 'prefs.json', 'saves\slot_1.json', 'saves\slot_3.json')
$HadSlot3 = Test-Path (Join-Path $UserDir 'saves\slot_3.json')
if (Test-Path $BackupDir) { Remove-Item $BackupDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir 'saves') | Out-Null
foreach ($rel in $Guarded) {
    $src = Join-Path $UserDir $rel
    if (Test-Path $src) { Copy-Item $src (Join-Path $BackupDir $rel) -Force }
}
# stale .npbak from a killed earlier session must not poison the in-game rig
foreach ($bak in @('party_setup.json.npbak', 'prefs.json.npbak')) {
    $p = Join-Path $UserDir $bak
    if (Test-Path $p) { Remove-Item $p -Force }
}

function Restore-UserFiles {
    foreach ($rel in $Guarded) {
        $bak = Join-Path $BackupDir $rel
        $dst = Join-Path $UserDir $rel
        if (Test-Path $bak) {
            Copy-Item $bak $dst -Force
        }
    }
    foreach ($bak in @('party_setup.json.npbak', 'prefs.json.npbak')) {
        $p = Join-Path $UserDir $bak
        if (Test-Path $p) { Remove-Item $p -Force }
    }
    if (-not $HadSlot3) {
        $s3 = Join-Path $UserDir 'saves\slot_3.json'
        if (Test-Path $s3) { Remove-Item $s3 -Force }
    }
}

$HostLog = Join-Path $LogDir 'netprobe_host.log'
$GuestLog = Join-Path $LogDir 'netprobe_guest.log'
foreach ($f in @($HostLog, $GuestLog)) { if (Test-Path $f) { Remove-Item $f -Force } }

$HostArgs = @('--headless', '--path', '.', '--',
    '--net=host', "--port=$Port", '--netprobe=hostmatch',
    '--autoplay=bots', '--slowsim', "--seed=$Seed", '--slot=3')
$GuestArgs = @('--headless', '--path', '.', '--',
    "--net=join=127.0.0.1:$Port", '--netprobe=joinmatch', '--slot=3')

$hostProc = $null
$guestProc = $null
$verdict = 'FAIL'
try {
    Write-Host "`n== launching HOST  (log: $HostLog)"
    $hostProc = Start-Process -FilePath $Godot -ArgumentList $HostArgs -NoNewWindow -PassThru `
        -RedirectStandardOutput $HostLog -WorkingDirectory $ProjectRoot
    Start-Sleep -Seconds 4
    Write-Host "== launching GUEST (log: $GuestLog)"
    $guestProc = Start-Process -FilePath $Godot -ArgumentList $GuestArgs -NoNewWindow -PassThru `
        -RedirectStandardOutput $GuestLog -WorkingDirectory $ProjectRoot

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $beat = 0
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
        if ($hostProc.HasExited -and $guestProc.HasExited) { break }
        Start-Sleep -Milliseconds 500
        $beat++
        if ($beat % 30 -eq 0) {
            $hLines = 0; $cLines = 0
            if (Test-Path $HostLog) { $hLines = @(Select-String -Path $HostLog -Pattern 'PROCESSION_NETPROBE_HOST').Count }
            if (Test-Path $GuestLog) { $cLines = @(Select-String -Path $GuestLog -Pattern 'PROCESSION_NETPROBE_CLIENT').Count }
            Write-Host ("  ... {0:n0}s  host hashes={1}  guest hashes={2}" -f $sw.Elapsed.TotalSeconds, $hLines, $cLines)
        }
    }
    $timedOut = (-not $hostProc.HasExited) -or (-not $guestProc.HasExited)
    if ($timedOut) { Write-Host "TIMEOUT after $([math]::Round($sw.Elapsed.TotalSeconds,1))s - killing survivors" }
    foreach ($p in @($hostProc, $guestProc)) {
        if ($p -and -not $p.HasExited) { try { $p.Kill() } catch { } }
    }

    # ---- parse + pair --------------------------------------------------------
    $rxHost = 'PROCESSION_NETPROBE_HOST seq=(\d+) round=(\d+) night=(\d+) hash=([0-9a-f]{8})'
    $rxClient = 'PROCESSION_NETPROBE_CLIENT seq=(\d+) round=(\d+) night=(\d+) hash=([0-9a-f]{8})'
    $hostHash = @{}
    $clientHash = @{}
    $clientMaxNight = 0
    $clientMaxRound = 0
    foreach ($m in (Select-String -Path $HostLog -Pattern $rxHost -ErrorAction SilentlyContinue)) {
        $g = $m.Matches[0].Groups
        $hostHash[[int]$g[1].Value] = $g[4].Value
    }
    foreach ($m in (Select-String -Path $GuestLog -Pattern $rxClient -ErrorAction SilentlyContinue)) {
        $g = $m.Matches[0].Groups
        $seq = [int]$g[1].Value
        $clientHash[$seq] = $g[4].Value
        $n = [int]$g[3].Value
        $r = [int]$g[2].Value
        if ($n -gt $clientMaxNight) { $clientMaxNight = $n }
        if ($r -gt $clientMaxRound) { $clientMaxRound = $r }
    }
    $pairs = 0
    $mismatches = @()
    foreach ($seq in $clientHash.Keys) {
        if ($hostHash.ContainsKey($seq)) {
            $pairs++
            if ($hostHash[$seq] -ne $clientHash[$seq]) { $mismatches += $seq }
        }
    }
    $mismatches = @($mismatches | Sort-Object)
    $mirrorBooted = [bool](Select-String -Path $GuestLog -Pattern 'NET mirror boot: procession' -Quiet -ErrorAction SilentlyContinue)
    $clientDone = [bool](Select-String -Path $GuestLog -Pattern 'NETPROBE_CLIENT_DONE' -Quiet -ErrorAction SilentlyContinue)
    $hostDone = [bool](Select-String -Path $HostLog -Pattern 'NETPROBE_DONE' -Quiet -ErrorAction SilentlyContinue)
    $heir = [bool](Select-String -Path $HostLog -Pattern 'PROCESSION_HEIR' -Quiet -ErrorAction SilentlyContinue)
    $anyFail = [bool](Select-String -Path $HostLog, $GuestLog -Pattern 'NETPROBE FAIL' -Quiet -ErrorAction SilentlyContinue)

    Write-Host "`n== results"
    Write-Host "  mirror booted on guest : $mirrorBooted"
    Write-Host "  paired hash seqs       : $pairs (min $MinPairs)"
    Write-Host "  hash mismatches        : $($mismatches.Count)"
    Write-Host "  guest reached night    : $clientMaxNight (round $clientMaxRound)"
    Write-Host "  host finale (HEIR)     : $heir"
    Write-Host "  host clean exit        : $hostDone"
    Write-Host "  guest clean exit       : $clientDone"
    Write-Host "  in-flow FAIL lines     : $anyFail"
    if ($mismatches.Count -gt 0) {
        $first = $mismatches[0]
        Write-Host "  first mismatch seq=$first host=$($hostHash[$first]) client=$($clientHash[$first])"
        $show = @($mismatches | Select-Object -First 10) -join ', '
        Write-Host "  mismatched seqs (first 10): $show"
    }

    $pass = $mirrorBooted -and ($pairs -ge $MinPairs) -and ($mismatches.Count -eq 0) `
        -and ($clientMaxNight -ge 2) -and $heir -and $hostDone -and $clientDone `
        -and (-not $anyFail) -and (-not $timedOut)
    if ($pass) { $verdict = 'PASS' }
}
finally {
    foreach ($p in @($hostProc, $guestProc)) {
        if ($p -and -not $p.HasExited) { try { $p.Kill() } catch { } }
    }
    Restore-UserFiles
    Write-Host "user:// saves restored (external backup)"
}

Write-Host "`nNETPROBE VERDICT: $verdict"
if ($verdict -eq 'PASS') { exit 0 } else { exit 1 }
