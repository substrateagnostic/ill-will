#requires -Version 5.1
<#
.SYNOPSIS
  Executor idle CANDIDATE WAVE: N calm preset idles on the butler's rig.

.DESCRIPTION
  Eleventh watch (2026-07-20). The exec_lineup receipt proved the S-curve
  scoliosis is the preset Idle ANIMATION (action_id 0 hip-swagger), not the
  generation and not the rig bind. This wave re-animates the SAME rig with
  calmer catalog clips (3cr each) so the director can pick a dignified idle
  from a rendered lineup instead of guessing blind.

  The saved rig task (meshy_rig_trial_report.json, 2026-07-16) may be purged
  server-side (3-day expiry) — the script probes it and re-rigs from the
  static GLB (5cr) if needed.

  Output: assets/models/meshy/executor_butler_idle_c<ID>.glb per candidate
          tools/meshy_exec_idle_wave_report.json

  API key: read at runtime from the Dead_Attestation .env, never logged.
#>
[CmdletBinding()]
param(
    [string]$EnvPath = 'C:\Users\agall\projects\Dead_Attestation\.env',
    [string]$RigTaskId = '019f69f6-57be-73ea-8f36-53f6561428ea',
    [int[]]$ActionIds = @(243, 245, 249, 253, 47),
    [double]$HeightMeters = 1.9,
    [int]$PollIntervalSec = 6,
    [int]$TaskTimeoutMin = 20
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Split-Path -Parent $ScriptDir
$InputGlb = Join-Path $Root 'assets\models\meshy\executor_butler.glb'
$ReportPath = Join-Path $ScriptDir 'meshy_exec_idle_wave_report.json'

$ActionNames = @{ 243 = 'Idle 3'; 245 = 'Idle 5'; 249 = 'Idle 9'; 253 = 'Idle 13'; 47 = 'Listening Gesture' }

function Get-MeshyApiKey {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Meshy env file not found: $Path" }
    foreach ($line in (Get-Content -Path $Path)) {
        if ($line -match '^\s*MESHY_API_KEY\s*=\s*(.+?)\s*$') { return $Matches[1] }
    }
    throw "MESHY_API_KEY not found in $Path"
}

Write-Host 'Exec idle wave — reading API key (never printed)...'
$ApiKey = Get-MeshyApiKey -Path $EnvPath
$Headers = @{ Authorization = ('Bearer ' + $ApiKey) }

# --- phase 0: is the saved rig still alive? -----------------------------------
$rigId = $RigTaskId
$rigOk = $false
$rigCredits = 0
try {
    $probe = Invoke-RestMethod -Method Get -Uri ('https://api.meshy.ai/openapi/v1/rigging/' + $rigId) -Headers $Headers -TimeoutSec 60
    if ($probe.status -eq 'SUCCEEDED') { $rigOk = $true }
    Write-Host ('Saved rig probe: status=' + $probe.status)
} catch {
    Write-Host ('Saved rig probe failed (likely purged): ' + $_.Exception.Message)
}
if (-not $rigOk) {
    Write-Host 'Re-rigging from the static GLB (5cr)...'
    $bytes = [System.IO.File]::ReadAllBytes($InputGlb)
    $dataUri = 'data:model/gltf-binary;base64,' + [Convert]::ToBase64String($bytes)
    $rigBody = @{ model_url = $dataUri; height_meters = $HeightMeters } | ConvertTo-Json -Compress
    $rigResp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/rigging' -Headers $Headers -ContentType 'application/json' -Body $rigBody -TimeoutSec 300
    $rigId = $rigResp.result
    Write-Host ('  new rigging task id: ' + $rigId)
    $deadline = (Get-Date).AddMinutes($TaskTimeoutMin)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $PollIntervalSec
        $t = $null
        try { $t = Invoke-RestMethod -Method Get -Uri ('https://api.meshy.ai/openapi/v1/rigging/' + $rigId) -Headers $Headers -TimeoutSec 60 } catch { continue }
        Write-Host ('  [rig] status=' + $t.status + ' progress=' + $t.progress)
        if ($t.status -eq 'SUCCEEDED') { $rigCredits = [int]$t.consumed_credits; $rigOk = $true; break }
        if ($t.status -eq 'FAILED' -or $t.status -eq 'CANCELED') { throw ('re-rig ' + $t.status) }
    }
    if (-not $rigOk) { throw 're-rig timed out' }
}

# --- phase 1: submit ALL candidate animations concurrently --------------------
$tasks = @()
foreach ($aid in $ActionIds) {
    $body = @{ rig_task_id = $rigId; action_id = $aid } | ConvertTo-Json -Compress
    $resp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/animations' -Headers $Headers -ContentType 'application/json' -Body $body -TimeoutSec 120
    $name = $ActionNames[$aid]
    if (-not $name) { $name = ('action ' + $aid) }
    Write-Host ('Submitted action_id=' + $aid + ' (' + $name + ') task=' + $resp.result)
    $tasks += [PSCustomObject]@{ action_id = $aid; name = $name; task_id = $resp.result; status = 'PENDING'; glb = ''; credits = 0 }
}

# --- phase 2: poll all until done ---------------------------------------------
$deadline = (Get-Date).AddMinutes($TaskTimeoutMin)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $PollIntervalSec
    $pending = @($tasks | Where-Object { $_.status -ne 'SUCCEEDED' -and $_.status -ne 'FAILED' })
    if ($pending.Count -eq 0) { break }
    foreach ($tk in $pending) {
        $t = $null
        try { $t = Invoke-RestMethod -Method Get -Uri ('https://api.meshy.ai/openapi/v1/animations/' + $tk.task_id) -Headers $Headers -TimeoutSec 60 } catch { continue }
        $tk.status = $t.status
        if ($t.status -eq 'SUCCEEDED') {
            $tk.credits = [int]$t.consumed_credits
            $out = Join-Path $Root ('assets\models\meshy\executor_butler_idle_c' + $tk.action_id + '.glb')
            Invoke-WebRequest -Uri $t.result.animation_glb_url -OutFile $out -TimeoutSec 300 -UseBasicParsing
            $tk.glb = ('assets/models/meshy/executor_butler_idle_c' + $tk.action_id + '.glb')
            Write-Host ('  DONE action_id=' + $tk.action_id + ' (' + $tk.name + ') -> ' + $tk.glb)
        } elseif ($t.status -eq 'FAILED' -or $t.status -eq 'CANCELED') {
            Write-Host ('  FAILED action_id=' + $tk.action_id + ' (' + $tk.name + ')')
        }
    }
}

$done = @($tasks | Where-Object { $_.status -eq 'SUCCEEDED' })
$animTotal = 0
foreach ($tk in $done) { $animTotal += $tk.credits }
$report = [PSCustomObject]@{
    generated_at  = (Get-Date).ToString('o')
    experiment    = 'executor idle candidate wave (S-curve fix: calmer presets on the same rig)'
    rig_task_id   = $rigId
    rig_reused    = ($rigCredits -eq 0)
    rig_credits   = $rigCredits
    candidates    = $tasks
    total_credits = ($rigCredits + $animTotal)
}
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ReportPath, ($report | ConvertTo-Json -Depth 5), $enc)
Write-Host ''
Write-Host ('EXEC IDLE WAVE DONE: ' + $done.Count + '/' + $tasks.Count + ' candidates, ' + ($rigCredits + $animTotal) + 'cr total')
Write-Host ('Report: ' + $ReportPath)
