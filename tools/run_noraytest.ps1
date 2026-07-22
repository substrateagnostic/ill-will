#requires -Version 5.1
<#
.SYNOPSIS
  ILL WILL noray transport certification against the MOCK relay (task #91).

.DESCRIPTION
  Runs tools/noray_mock.gd (a faithful loopback mock of foxssake/noray's
  protocol slice: register-host / set-oid / set-pid / UDP registrar / connect
  / connect-relay + a real UDP forwarder) and then drives TWO full estate
  processes through core/net_session.gd's "noray" transport:

    Path 1 (NAT):    host --transport=noray, guest joins  noray:MOCKA
                     (registrar + punchthrough handshake + stock ENet)
    Path 2 (RELAY):  fresh mock, guest joins  norayrelay:MOCKA
                     (whole ENet session forwarded through the mock's relay port)

  Both paths ride the SAME hostmatch/joinmatch probe rig as run_netprobe.ps1,
  so the procession mirror hash law applies over the new transport too. The
  match runs at blitz pace here — transport certification wants the wire
  opened correctly and byte-identical facts, not couch pacing (that is
  run_netprobe.ps1's job); the blitz truncates pairing at the guest's world
  build, so MinPairs is lower.

  What this does NOT certify (live-relay work, pending the producer's deploy
  per docs/design/39-noray-deploy.md): a real noray instance, real NAT
  traversal across routers, Bun/Docker runtime behavior.

  One verdict line per path and overall:  NORAYTEST VERDICT: PASS | FAIL

.EXAMPLE
  powershell -File tools\run_noraytest.ps1
  powershell -File tools\run_noraytest.ps1 -SkipRelay
#>
[CmdletBinding()]
param(
    [int]$Seed = 7,
    [int]$TcpPort = 8890,
    [int]$RegPort = 8809,
    [int]$TimeoutSec = 300,
    [int]$MinPairs = 10,
    [switch]$SkipRelay,
    [string]$Godot = $env:GODOT
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot 'verify_out\noraytest'
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
Write-Host "Godot: $Godot"

# ---- user:// save safety (same guard as run_netprobe.ps1)
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
foreach ($bak in @('party_setup.json.npbak', 'prefs.json.npbak')) {
    $p = Join-Path $UserDir $bak
    if (Test-Path $p) { Remove-Item $p -Force }
}
function Restore-UserFiles {
    foreach ($rel in $Guarded) {
        $bak = Join-Path $BackupDir $rel
        if (Test-Path $bak) { Copy-Item $bak (Join-Path $UserDir $rel) -Force }
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

function Invoke-NorayPath {
    param([string]$Name, [string]$JoinTarget)
    $mockLog = Join-Path $LogDir "mock_$Name.log"
    $hostLog = Join-Path $LogDir "host_$Name.log"
    $guestLog = Join-Path $LogDir "guest_$Name.log"
    foreach ($f in @($mockLog, $hostLog, $guestLog)) { if (Test-Path $f) { Remove-Item $f -Force } }
    $relay = "127.0.0.1:$TcpPort"
    $mock = $null; $hostP = $null; $guest = $null
    try {
        Write-Host "`n== [$Name] mock relay up"
        $mock = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', '.',
            '--script', 'res://tools/noray_mock.gd') -NoNewWindow -PassThru `
            -RedirectStandardOutput $mockLog -WorkingDirectory $ProjectRoot
        Start-Sleep -Seconds 3
        Write-Host "== [$Name] host up (noray transport)"
        $hostP = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', '.', '--',
            '--transport=noray', "--relay=$relay", '--net=host', '--netprobe=hostmatch',
            '--autoplay=bots', "--seed=$Seed", '--slot=3') -NoNewWindow -PassThru `
            -RedirectStandardOutput $hostLog -WorkingDirectory $ProjectRoot
        Start-Sleep -Seconds 6
        Write-Host "== [$Name] guest joining $JoinTarget"
        $guest = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', '.', '--',
            "--relay=$relay", "--net=join=$JoinTarget", '--netprobe=joinmatch', '--slot=3') `
            -NoNewWindow -PassThru -RedirectStandardOutput $guestLog -WorkingDirectory $ProjectRoot
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
            if ($hostP.HasExited -and $guest.HasExited) { break }
            Start-Sleep -Milliseconds 500
        }
        $timedOut = (-not $hostP.HasExited) -or (-not $guest.HasExited)
        if ($timedOut) { Write-Host "[$Name] TIMEOUT - killing survivors" }
    }
    finally {
        foreach ($p in @($hostP, $guest, $mock)) {
            if ($p -and -not $p.HasExited) { try { $p.Kill() } catch { } }
        }
    }
    # ---- parse
    $rxHost = 'PROCESSION_NETPROBE_HOST seq=(\d+) round=(\d+) night=(\d+) hash=([0-9a-f]{8})'
    $rxClient = 'PROCESSION_NETPROBE_CLIENT seq=(\d+) round=(\d+) night=(\d+) hash=([0-9a-f]{8})'
    $hostHash = @{}
    $clientHash = @{}
    foreach ($m in (Select-String -Path $hostLog -Pattern $rxHost -ErrorAction SilentlyContinue)) {
        $g = $m.Matches[0].Groups; $hostHash[[int]$g[1].Value] = $g[4].Value
    }
    foreach ($m in (Select-String -Path $guestLog -Pattern $rxClient -ErrorAction SilentlyContinue)) {
        $g = $m.Matches[0].Groups; $clientHash[[int]$g[1].Value] = $g[4].Value
    }
    $pairs = 0
    $mismatches = 0
    foreach ($seq in $clientHash.Keys) {
        if ($hostHash.ContainsKey($seq)) {
            $pairs++
            if ($hostHash[$seq] -ne $clientHash[$seq]) { $mismatches++ }
        }
    }
    $norayUp = [bool](Select-String -Path $hostLog -Pattern 'NET noray host up' -Quiet -ErrorAction SilentlyContinue)
    $expectWire = 'NET noray: punchthrough OK'
    if ($JoinTarget.StartsWith('norayrelay:')) { $expectWire = 'NET noray: relay endpoint' }
    $wire = [bool](Select-String -Path $guestLog -Pattern ([regex]::Escape($expectWire)) -Quiet -ErrorAction SilentlyContinue)
    $seated = [bool](Select-String -Path $guestLog -Pattern 'NETPROBE granted seat' -Quiet -ErrorAction SilentlyContinue)
    $mirror = [bool](Select-String -Path $guestLog -Pattern 'NET mirror boot: procession' -Quiet -ErrorAction SilentlyContinue)
    $heir = [bool](Select-String -Path $hostLog -Pattern 'PROCESSION_HEIR' -Quiet -ErrorAction SilentlyContinue)
    Write-Host "[$Name] noray-host-up=$norayUp wire[$expectWire]=$wire seated=$seated mirror=$mirror pairs=$pairs mism=$mismatches heir=$heir"
    $pass = $norayUp -and $wire -and $seated -and $mirror -and $heir -and `
        ($pairs -ge $MinPairs) -and ($mismatches -eq 0)
    $tag = 'FAIL'; if ($pass) { $tag = 'PASS' }
    Write-Host "[$Name] $tag  (logs: $hostLog | $guestLog | $mockLog)"
    return $pass
}

$ok = $true
try {
    if (-not (Invoke-NorayPath -Name 'nat' -JoinTarget 'noray:MOCKA')) { $ok = $false }
    if (-not $SkipRelay) {
        if (-not (Invoke-NorayPath -Name 'relay' -JoinTarget 'norayrelay:MOCKA')) { $ok = $false }
    }
}
finally {
    Restore-UserFiles
    Write-Host "user:// saves restored (external backup)"
}

$verdict = 'FAIL'
if ($ok) { $verdict = 'PASS' }
Write-Host "`nNORAYTEST VERDICT: $verdict"
if ($ok) { exit 0 } else { exit 1 }
