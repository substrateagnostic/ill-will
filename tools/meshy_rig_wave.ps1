#requires -Version 5.1
<#
.SYNOPSIS
  THE RIGGING WAVE (night 5, lane E3): give the graveyard troupe real bones.
  Rig three humanoids once each, then apply one or two preset animations to each.

.DESCRIPTION
  Generalizes the sanctioned rig trial (tools/meshy_rig_trial.ps1) into a small,
  resumable, manifest-driven wave. For each model it:
    1. RIGS the static GLB via POST /openapi/v1/rigging (Meshy humanoid auto-rig),
       passing the model's real-world `height_meters` (recorded in the report —
       MeshyProp.instance_rigged needs it as `native_height`).
    2. ANIMATES it via POST /openapi/v1/animations for each requested action_id,
       downloading each result to <name>_<label>.glb IMMEDIATELY (Meshy purges
       server assets after 3 days).

  Inputs : assets/models/meshy/generated/<name>.glb  (static, sent as a base64
           Data URI — original text-to-3d task ids are purged).
  Outputs: assets/models/meshy/generated/<name>_<label>.glb  (animated; statics
           are NOT replaced) + tools/meshy_rig_wave_report.json (task ids,
           credits, native heights per model).

  RESUMABLE: an existing report is read back; a model with a stored rig_task_id
  is not re-rigged, and an animation whose output GLB already exists is skipped.
  A single FAILED animation is logged and the wave continues (does not abort).

  API key: read at runtime from the .env (never logged, never written). Same
  conventions as tools/meshy_forge.ps1 / tools/meshy_rig_trial.ps1.
#>
[CmdletBinding()]
param(
    [string]$EnvPath = 'C:\Users\agall\projects\un_party_game\.env',
    [string]$Root = '',
    [string]$GenDir = '',
    [string]$ReportPath = '',
    [string]$ManifestPath = '',
    [int]$PollIntervalSec = 5,
    [int]$TaskTimeoutMin = 15
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $Root)       { $Root       = Split-Path -Parent $ScriptDir }
if (-not $GenDir)     { $GenDir     = Join-Path $Root 'assets\models\meshy\generated' }
if (-not $ReportPath) { $ReportPath = Join-Path $ScriptDir 'meshy_rig_wave_report.json' }
if (-not (Test-Path $EnvPath)) { $EnvPath = 'C:\Users\agall\projects\Dead_Attestation\.env' }

# ---------------------------------------------------------------- the manifest
# Each model is rigged ONCE at height_meters; then each anim is applied by id.
# action_id 0 (Idle, rigType style_01) is the proven-safe preset from the trial.
# Gentlemans Bow (42, rigType style_02) is the funeral "pay respects" pose and
# also probes whether the auto-rig retargets the big style_02 catalog.
$Manifest = @(
    [PSCustomObject]@{
        name = 'npc_groundskeeper'; height_meters = 1.8
        anims = @( [PSCustomObject]@{ label = 'idle'; action = 0; action_name = 'Idle' } )
    },
    [PSCustomObject]@{
        name = 'npc_mourner_elderly'; height_meters = 1.65
        anims = @( [PSCustomObject]@{ label = 'idle'; action = 0; action_name = 'Idle' } )
    },
    [PSCustomObject]@{
        name = 'npc_mourner_hooded'; height_meters = 1.75
        anims = @(
            [PSCustomObject]@{ label = 'idle'; action = 0;  action_name = 'Idle' },
            [PSCustomObject]@{ label = 'bow';  action = 42; action_name = 'Gentlemans Bow' }
        )
    }
)

# Optional external manifest override (additive; the built-in default above is
# the original night-5 troupe). A -ManifestPath JSON is an array of objects
# shaped exactly like the built-in entries: {name, height_meters, anims:[{label,
# action, action_name}]}. Used by later waves (e.g. the PROCESSION heroes) so we
# never mutate the record of what a prior wave rigged.
if ($ManifestPath -and (Test-Path $ManifestPath)) {
    $loaded = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    $Manifest = @($loaded)
    Write-Host ("Manifest overridden from {0}: {1} model(s)." -f $ManifestPath, $Manifest.Count)
}

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

function Save-Report {
    param($Models, [string]$Path)
    $rigCr = 0; $animCr = 0
    foreach ($m in $Models) {
        if ($m.rig_credits) { $rigCr += [int]$m.rig_credits }
        foreach ($a in $m.animations) { if ($a.anim_credits) { $animCr += [int]$a.anim_credits } }
    }
    $report = [PSCustomObject]@{
        generated_at = (Get-Date).ToString('o')
        experiment   = 'RIGGING WAVE: rig graveyard troupe + apply preset animations'
        gen_dir      = 'assets/models/meshy/generated/'
        models       = $Models
        totals       = [PSCustomObject]@{ rig_credits = $rigCr; anim_credits = $animCr; total_credits = ($rigCr + $animCr) }
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($report | ConvertTo-Json -Depth 8), $enc)
}

Write-Host 'RIGGING WAVE — reading API key (never printed)...'
$ApiKey = Get-MeshyApiKey -Path $EnvPath
$Headers = @{ Authorization = ('Bearer ' + $ApiKey) }

# ---- resume state: index prior report by model name -------------------------
$prior = @{}
if (Test-Path $ReportPath) {
    try {
        $old = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json
        foreach ($m in $old.models) { $prior[$m.name] = $m }
        Write-Host ("Resuming: prior report has {0} model(s)." -f $prior.Count)
    } catch { Write-Host 'Prior report unreadable — starting fresh.' }
}

$Models = @()
foreach ($entry in $Manifest) {
    $name = $entry.name
    Write-Host ''
    Write-Host ('=== ' + $name + ' (rig height ' + $entry.height_meters + ' m) ===')
    $inputGlb = Join-Path $GenDir ($name + '.glb')
    if (-not (Test-Path $inputGlb)) { Write-Host ('  SKIP — input missing: ' + $inputGlb); continue }

    # carry forward prior record (so we can reuse a rig and skip finished anims)
    $rec = [PSCustomObject]@{
        name = $name; native_height_meters = $entry.height_meters
        rig_task_id = ''; rig_credits = 0; rig_reused = $false; animations = @()
    }
    $p = $null
    if ($prior.ContainsKey($name)) { $p = $prior[$name] }

    # ---- phase 1: rigging (reuse a stored rig id if present) ----------------
    try {
        if ($p -and $p.rig_task_id) {
            $rec.rig_task_id = [string]$p.rig_task_id
            $rec.rig_credits = [int]$p.rig_credits
            $rec.rig_reused  = $true
            Write-Host ('  rig reused: ' + $rec.rig_task_id + ' (' + $rec.rig_credits + 'cr, no new charge)')
        } else {
            $bytes = [System.IO.File]::ReadAllBytes($inputGlb)
            $dataUri = 'data:model/gltf-binary;base64,' + [Convert]::ToBase64String($bytes)
            Write-Host ('  rigging ' + (Split-Path -Leaf $inputGlb) + (' ({0:n0} bytes)...' -f $bytes.Length))
            $rigBody = @{ model_url = $dataUri; height_meters = $entry.height_meters } | ConvertTo-Json -Compress
            $rigResp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/rigging' -Headers $Headers -ContentType 'application/json' -Body $rigBody -TimeoutSec 300
            $rigId = $rigResp.result
            Write-Host ('  rig task id: ' + $rigId)
            $rigTask = Wait-MeshyTask -Uri ('https://api.meshy.ai/openapi/v1/rigging/' + $rigId) -Headers $Headers -Tag 'rig' -IntervalSec $PollIntervalSec -TimeoutMin $TaskTimeoutMin
            $rec.rig_task_id = $rigId
            $rec.rig_credits = [int]$rigTask.consumed_credits
            Write-Host ('  rig SUCCEEDED, credits=' + $rec.rig_credits)
        }
    } catch {
        Write-Host ('  RIG FAILED: ' + $_.Exception.Message)
        $Models += $rec
        Save-Report -Models $Models -Path $ReportPath
        continue
    }

    # ---- phase 2: animations (one at a time; failures logged, not fatal) -----
    $animList = @()
    foreach ($an in $entry.anims) {
        $label = $an.label
        $outGlb = Join-Path $GenDir ($name + '_' + $label + '.glb')
        # resume: if the output already exists and prior recorded success, skip
        $priorAnim = $null
        if ($p) { foreach ($pa in $p.animations) { if ($pa.label -eq $label) { $priorAnim = $pa } } }
        if ((Test-Path $outGlb) -and $priorAnim -and $priorAnim.status -eq 'SUCCEEDED') {
            Write-Host ('  anim [' + $label + '] already present — skip')
            $animList += $priorAnim
            continue
        }
        $arec = [PSCustomObject]@{
            label = $label; action_id = $an.action; action_name = $an.action_name
            status = ''; anim_credits = 0; output_glb = ('assets/models/meshy/generated/' + $name + '_' + $label + '.glb'); error = ''
        }
        try {
            Write-Host ('  animating [' + $label + '] action_id=' + $an.action + ' (' + $an.action_name + ')...')
            $animBody = @{ rig_task_id = $rec.rig_task_id; action_id = $an.action } | ConvertTo-Json -Compress
            $animResp = Invoke-RestMethod -Method Post -Uri 'https://api.meshy.ai/openapi/v1/animations' -Headers $Headers -ContentType 'application/json' -Body $animBody -TimeoutSec 120
            $animId = $animResp.result
            Write-Host ('    anim task id: ' + $animId)
            $animTask = Wait-MeshyTask -Uri ('https://api.meshy.ai/openapi/v1/animations/' + $animId) -Headers $Headers -Tag ('anim:' + $label) -IntervalSec $PollIntervalSec -TimeoutMin $TaskTimeoutMin
            $glbUrl = $animTask.result.animation_glb_url
            if (-not $glbUrl) { throw 'succeeded but no animation_glb_url' }
            Invoke-WebRequest -Uri $glbUrl -OutFile $outGlb -TimeoutSec 300 -UseBasicParsing
            $arec.status = 'SUCCEEDED'
            $arec.anim_credits = [int]$animTask.consumed_credits
            Write-Host ('    SUCCEEDED, credits=' + $arec.anim_credits + ' -> ' + (Split-Path -Leaf $outGlb))
        } catch {
            $arec.status = 'FAILED'
            $arec.error = $_.Exception.Message
            Write-Host ('    FAILED: ' + $_.Exception.Message)
        }
        $animList += $arec
    }
    $rec.animations = $animList
    $Models += $rec
    Save-Report -Models $Models -Path $ReportPath   # incremental save per model
}

Save-Report -Models $Models -Path $ReportPath
$rigTot = 0; $animTot = 0
foreach ($m in $Models) {
    if ($m.rig_credits -and -not $m.rig_reused) { $rigTot += [int]$m.rig_credits }
    foreach ($a in $m.animations) { if ($a.anim_credits) { $animTot += [int]$a.anim_credits } }
}
Write-Host ''
Write-Host ('WAVE DONE: new rig credits=' + $rigTot + ' anim credits=' + $animTot + ' NEW total=' + ($rigTot + $animTot) + 'cr')
Write-Host ('Report: ' + $ReportPath)
