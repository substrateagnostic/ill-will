#requires -Version 5.1
<#
.SYNOPSIS
  ONE bounded rigging+animation trial: executor_butler -> auto-rig -> preset idle.

.DESCRIPTION
  Director-sanctioned experiment (2026-07-16): can Meshy's /openapi/v1/rigging
  (auto humanoid skeleton) + /openapi/v1/animations (preset library, action_id 0
  = Idle) turn a shipped static Meshy figure into a usable idle-animated GLB?
  If yes, future nights replace puppet-tweens with real idles.

  Input : assets/models/meshy/executor_butler.glb (static, 3.85 MB — sent as a
          base64 Data URI because its original text-to-3d task id is long
          purged; Meshy assets expire server-side after 3 days).
  Output: assets/models/meshy/executor_butler_idle.glb  (animated — the static
          GLB is NOT replaced; both ship side by side)
          tools/meshy_rig_trial_report.json             (task ids + credits)

  API key: read at runtime from the Dead_Attestation .env, never logged,
  never written. Same conventions as tools/meshy_forge.ps1.
#>
[CmdletBinding()]
param(
    [string]$EnvPath = 'C:\Users\agall\projects\Dead_Attestation\.env',
    [string]$InputGlb = '',
    [string]$OutGlb = '',
    [string]$ReportPath = '',
    [double]$HeightMeters = 1.9,
    [int]$ActionId = 0,
    [int]$PollIntervalSec = 5,
    [int]$TaskTimeoutMin = 15
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Split-Path -Parent $ScriptDir
if (-not $InputGlb)   { $InputGlb   = Join-Path $Root 'assets\models\meshy\executor_butler.glb' }
if (-not $OutGlb)     { $OutGlb     = Join-Path $Root 'assets\models\meshy\executor_butler_idle.glb' }
if (-not $ReportPath) { $ReportPath = Join-Path $ScriptDir 'meshy_rig_trial_report.json' }

function Get-MeshyApiKey {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Meshy env file not found: $Path" }
    foreach ($line in (Get-Content -Path $Path)) {
        if ($line -match '^\s*MESHY_API_KEY\s*=\s*(.+?)\s*$') { return $Matches[1] }
    }
    throw "MESHY_API_KEY not found in $Path"
}

function Wait-MeshyTask {
    param([string]$Uri, [hashtable]$Headers, [string]$Tag, [int]$IntervalSec, [int]$TimeoutMin)
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $IntervalSec
        $task = $null
        try {
            $task = Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers -TimeoutSec 60
        } catch {
            Write-Host ("  [{0}] poll error: {1}" -f $Tag, $_.Exception.Message)
            continue
        }
        Write-Host ("  [{0}] status={1} progress={2}" -f $Tag, $task.status, $task.progress)
        if ($task.status -eq 'SUCCEEDED') { return $task }
        if ($task.status -eq 'FAILED' -or $task.status -eq 'CANCELED') {
            $msg = ''
            if ($task.task_error -and $task.task_error.message) { $msg = $task.task_error.message }
            throw ("{0} {1}: {2}" -f $Tag, $task.status, $msg)
        }
    }
    throw ("{0} timed out after {1} min" -f $Tag, $TimeoutMin)
}

Write-Host 'Rig trial — reading API key (never printed)...'
$ApiKey = Get-MeshyApiKey -Path $EnvPath
$Headers = @{ Authorization = ('Bearer ' + $ApiKey) }

if (-not (Test-Path $InputGlb)) { throw "Input GLB not found: $InputGlb" }
$bytes = [System.IO.File]::ReadAllBytes($InputGlb)
$dataUri = 'data:model/gltf-binary;base64,' + [Convert]::ToBase64String($bytes)
Write-Host ("Input {0} ({1:n0} bytes, data URI {2:n0} chars)" -f (Split-Path -Leaf $InputGlb), $bytes.Length, $dataUri.Length)

# --- phase 1: rigging --------------------------------------------------------
$rigBody = @{ model_url = $dataUri; height_meters = $HeightMeters } | ConvertTo-Json -Compress
Write-Host 'Submitting rigging task...'
$rigResp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/rigging' -Headers $Headers -ContentType 'application/json' -Body $rigBody -TimeoutSec 300
$rigId = $rigResp.result
Write-Host ('  rigging task id: ' + $rigId)
$rigTask = Wait-MeshyTask -Uri ('https://api.meshy.ai/openapi/v1/rigging/' + $rigId) -Headers $Headers -Tag 'rig' -IntervalSec $PollIntervalSec -TimeoutMin $TaskTimeoutMin
$rigCredits = [int]$rigTask.consumed_credits
Write-Host ('  rigging SUCCEEDED, credits=' + $rigCredits)

# --- phase 2: preset idle animation ------------------------------------------
$animBody = @{ rig_task_id = $rigId; action_id = $ActionId } | ConvertTo-Json -Compress
Write-Host ('Submitting animation task (action_id=' + $ActionId + ' Idle)...')
$animResp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/animations' -Headers $Headers -ContentType 'application/json' -Body $animBody -TimeoutSec 120
$animId = $animResp.result
Write-Host ('  animation task id: ' + $animId)
$animTask = Wait-MeshyTask -Uri ('https://api.meshy.ai/openapi/v1/animations/' + $animId) -Headers $Headers -Tag 'anim' -IntervalSec $PollIntervalSec -TimeoutMin $TaskTimeoutMin
$animCredits = [int]$animTask.consumed_credits
Write-Host ('  animation SUCCEEDED, credits=' + $animCredits)

# --- download (immediately; assets purge in 3 days) ---------------------------
$glbUrl = $animTask.result.animation_glb_url
if (-not $glbUrl) { throw 'animation task succeeded but no animation_glb_url in result' }
Invoke-WebRequest -Uri $glbUrl -OutFile $OutGlb -TimeoutSec 300 -UseBasicParsing
Write-Host ('Downloaded animated GLB -> ' + $OutGlb)

$report = [PSCustomObject]@{
    generated_at   = (Get-Date).ToString('o')
    experiment     = 'rigging+animation trial: executor_butler -> preset Idle (action_id 0)'
    input_glb      = 'assets/models/meshy/executor_butler.glb'
    output_glb     = 'assets/models/meshy/executor_butler_idle.glb'
    height_meters  = $HeightMeters
    rig_task_id    = $rigId
    rig_credits    = $rigCredits
    anim_task_id   = $animId
    action_id      = $ActionId
    anim_credits   = $animCredits
    total_credits  = ($rigCredits + $animCredits)
}
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ReportPath, ($report | ConvertTo-Json -Depth 4), $enc)
Write-Host ''
Write-Host ('RIG TRIAL DONE: rig=' + $rigCredits + 'cr anim=' + $animCredits + 'cr total=' + ($rigCredits + $animCredits) + 'cr')
Write-Host ('Report: ' + $ReportPath)
