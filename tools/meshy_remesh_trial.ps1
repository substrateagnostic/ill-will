#requires -Version 5.1
<#
.SYNOPSIS
  REMESH TRIAL: does uniform quad-dominant topology cure the candy-wrapper
  waist ballooning on rigged/animating Meshy NPCs?

.DESCRIPTION
  Producer-authorized experiment (~15cr, 2026-07-20 follow-up to rig_audit2).
  Hypothesis: the S-curve/candy-wrapper midsection ballooning seen on
  executor_butler_v2_idle_c243 (and siblings) comes from sparse/irregular
  waist topology giving the auto-rigger bad weight targets. A REMESH to
  uniform quad-dominant topology before rigging should cure or reduce it.

  Pipeline: remesh (topology=quad) -> rig (height_meters) -> animate
  (action_id, same clip as the shipped ballooning candidate) -> download.

  Remesh input: prefers the fresh refine_task_id from this session's
  rigging-batch regen (input_task_id, free of upload cost / data-URI size);
  falls back to a base64 data URI of the local static GLB if the task id
  has purged server-side (3-day expiry).

  API key: read at runtime from the repo-root .env, never logged, never
  written. Same conventions as tools/meshy_rig_trial.ps1.
#>
[CmdletBinding()]
param(
    [string]$EnvPath = 'C:\Users\agall\projects\un_party_game\.env',
    [Parameter(Mandatory=$true)][string]$InputGlb,
    [string]$InputTaskId = '',
    [Parameter(Mandatory=$true)][string]$OutRemeshGlb,
    [Parameter(Mandatory=$true)][string]$OutRiggedIdleGlb,
    [int]$TargetPolycount = 30000,
    [string]$Topology = 'quad',
    [double]$HeightMeters = 1.9,
    [int]$ActionId = 243,
    [int]$PollIntervalSec = 6,
    [int]$TaskTimeoutMin = 20,
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ReportPath) { $ReportPath = Join-Path $ScriptDir ('meshy_remesh_trial_report_' + [IO.Path]::GetFileNameWithoutExtension($OutRiggedIdleGlb) + '.json') }

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

Write-Host 'Remesh trial — reading API key (never printed)...'
$ApiKey = Get-MeshyApiKey -Path $EnvPath
$Headers = @{ Authorization = ('Bearer ' + $ApiKey) }

# --- phase 1: remesh ----------------------------------------------------------
$remeshBodyObj = @{ target_formats = @('glb'); topology = $Topology; target_polycount = $TargetPolycount }
$usedInputMode = ''
if ($InputTaskId) {
    Write-Host ("Probing input_task_id {0} (may be purged)..." -f $InputTaskId)
    $probeOk = $false
    try {
        # We can't GET a rigging-batch refine task directly to confirm liveness
        # without knowing its origin endpoint; just try remesh with it and
        # fall back to data URI on failure.
        $remeshBodyObj['input_task_id'] = $InputTaskId
        $usedInputMode = 'input_task_id'
    } catch { }
}
if (-not (Test-Path $InputGlb)) { throw "Input GLB not found: $InputGlb" }

function Submit-Remesh {
    param([hashtable]$BodyObj)
    $body = $BodyObj | ConvertTo-Json -Compress
    return Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/remesh' -Headers $Headers -ContentType 'application/json' -Body $body -TimeoutSec 300
}

$remeshResp = $null
if ($usedInputMode -eq 'input_task_id') {
    try {
        Write-Host 'Submitting remesh task (input_task_id mode)...'
        $remeshResp = Submit-Remesh -BodyObj $remeshBodyObj
    } catch {
        Write-Host ('  input_task_id remesh failed (' + $_.Exception.Message + '); falling back to data URI upload...')
        $remeshResp = $null
        $usedInputMode = ''
    }
}
if (-not $remeshResp) {
    $bytes = [System.IO.File]::ReadAllBytes($InputGlb)
    $dataUri = 'data:model/gltf-binary;base64,' + [Convert]::ToBase64String($bytes)
    Write-Host ("Input {0} ({1:n0} bytes, data URI {2:n0} chars)" -f (Split-Path -Leaf $InputGlb), $bytes.Length, $dataUri.Length)
    $remeshBodyObj.Remove('input_task_id') | Out-Null
    $remeshBodyObj['model_url'] = $dataUri
    $usedInputMode = 'model_url_data_uri'
    Write-Host 'Submitting remesh task (model_url data URI mode)...'
    $remeshResp = Submit-Remesh -BodyObj $remeshBodyObj
}
$remeshId = $remeshResp.result
Write-Host ('  remesh task id: ' + $remeshId + ' (input mode: ' + $usedInputMode + ')')
$remeshTask = Wait-MeshyTask -Uri ('https://api.meshy.ai/openapi/v1/remesh/' + $remeshId) -Headers $Headers -Tag 'remesh' -IntervalSec $PollIntervalSec -TimeoutMin $TaskTimeoutMin
$remeshCredits = [int]$remeshTask.consumed_credits
Write-Host ('  remesh SUCCEEDED, credits=' + $remeshCredits)

$remeshGlbUrl = $remeshTask.model_urls.glb
if (-not $remeshGlbUrl) { throw 'remesh task succeeded but no model_urls.glb in result' }
Invoke-WebRequest -Uri $remeshGlbUrl -OutFile $OutRemeshGlb -TimeoutSec 300 -UseBasicParsing
Write-Host ('Downloaded remeshed GLB -> ' + $OutRemeshGlb)

# --- phase 2: rig the remeshed GLB ---------------------------------------------
$remeshBytes = [System.IO.File]::ReadAllBytes($OutRemeshGlb)
$remeshDataUri = 'data:model/gltf-binary;base64,' + [Convert]::ToBase64String($remeshBytes)
$rigBody = @{ model_url = $remeshDataUri; height_meters = $HeightMeters } | ConvertTo-Json -Compress
Write-Host 'Submitting rigging task on remeshed GLB...'
$rigResp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/rigging' -Headers $Headers -ContentType 'application/json' -Body $rigBody -TimeoutSec 300
$rigId = $rigResp.result
Write-Host ('  rigging task id: ' + $rigId)
$rigTask = Wait-MeshyTask -Uri ('https://api.meshy.ai/openapi/v1/rigging/' + $rigId) -Headers $Headers -Tag 'rig' -IntervalSec $PollIntervalSec -TimeoutMin $TaskTimeoutMin
$rigCredits = [int]$rigTask.consumed_credits
Write-Host ('  rigging SUCCEEDED, credits=' + $rigCredits)

# --- phase 3: preset idle animation (same clip as the ballooning candidate) ---
$animBody = @{ rig_task_id = $rigId; action_id = $ActionId } | ConvertTo-Json -Compress
Write-Host ('Submitting animation task (action_id=' + $ActionId + ')...')
$animResp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/animations' -Headers $Headers -ContentType 'application/json' -Body $animBody -TimeoutSec 120
$animId = $animResp.result
Write-Host ('  animation task id: ' + $animId)
$animTask = Wait-MeshyTask -Uri ('https://api.meshy.ai/openapi/v1/animations/' + $animId) -Headers $Headers -Tag 'anim' -IntervalSec $PollIntervalSec -TimeoutMin $TaskTimeoutMin
$animCredits = [int]$animTask.consumed_credits
Write-Host ('  animation SUCCEEDED, credits=' + $animCredits)

$glbUrl = $animTask.result.animation_glb_url
if (-not $glbUrl) { throw 'animation task succeeded but no animation_glb_url in result' }
Invoke-WebRequest -Uri $glbUrl -OutFile $OutRiggedIdleGlb -TimeoutSec 300 -UseBasicParsing
Write-Host ('Downloaded animated GLB -> ' + $OutRiggedIdleGlb)

$totalCredits = $remeshCredits + $rigCredits + $animCredits
$report = [PSCustomObject]@{
    generated_at        = (Get-Date).ToString('o')
    experiment          = 'remesh trial: uniform topology before rig, cure for candy-wrapper waist ballooning'
    input_glb           = $InputGlb
    input_task_id_tried = $InputTaskId
    remesh_input_mode   = $usedInputMode
    topology            = $Topology
    target_polycount    = $TargetPolycount
    remesh_task_id      = $remeshId
    remesh_credits      = $remeshCredits
    remesh_glb          = $OutRemeshGlb
    height_meters       = $HeightMeters
    rig_task_id         = $rigId
    rig_credits         = $rigCredits
    action_id           = $ActionId
    anim_task_id        = $animId
    anim_credits        = $animCredits
    output_glb          = $OutRiggedIdleGlb
    total_credits       = $totalCredits
}
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ReportPath, ($report | ConvertTo-Json -Depth 5), $enc)
Write-Host ''
Write-Host ('REMESH TRIAL DONE: remesh=' + $remeshCredits + 'cr rig=' + $rigCredits + 'cr anim=' + $animCredits + 'cr total=' + $totalCredits + 'cr')
Write-Host ('Report: ' + $ReportPath)
