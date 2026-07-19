#requires -Version 5.1
<#
.SYNOPSIS
  Lane ZR (THE FINISH WAVE): re-skin the 6 PLASTIC-verdict flat assets from
  docs/design/30-asset-finish-audit.md via Meshy's /retexture endpoint.

.DESCRIPTION
  Text-driven retexture on EXISTING geometry (no re-forge): for each manifest
  entry, uploads the current committed GLB (base64 data URI - the original
  text-to-3d task ids are past Meshy's 3-day asset retention window), submits
  a /openapi/v1/retexture task with a per-asset weathering prompt, polls to a
  terminal state, and downloads the result to
  assets/models/meshy/generated/<id>_retex_v1.glb -- a CANDIDATE, sitting
  alongside the original <id>.glb, never overwriting it. The calling agent
  judges each candidate (technical stddev pass + contact-sheet screenshots)
  and only promotes it (rename over the original) by hand after review; this
  script never deletes or replaces a shipped asset itself.

  RESUMABLE: an existing report is read back; an id whose candidate GLB
  already exists on disk with a prior SUCCEEDED status is skipped (use -Only
  to force a specific id, e.g. for a v2 re-attempt after prompt tuning).

  API key: read at runtime from the .env (never logged, never written). Same
  conventions as tools/meshy_forge.ps1 / tools/meshy_rig_wave.ps1.

.PARAMETER Only
  Comma-separated list of manifest ids to process (default: all 6 in-script).

.PARAMETER Suffix
  Candidate filename suffix (default retex_v1; pass retex_v2 for a second
  attempt on an id after keeping the v1 candidate for reference/comparison).
#>
[CmdletBinding()]
param(
    [string]$EnvPath     = 'C:\Users\agall\projects\un_party_game\.env',
    [string]$GenDir      = '',
    [string]$ReportPath  = '',
    [string]$Only        = '',
    [string]$Suffix      = 'retex_v1',
    [int]$PollIntervalSec = 5,
    [int]$TaskTimeoutMin  = 15
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Split-Path -Parent $ScriptDir
if (-not $GenDir)     { $GenDir     = Join-Path $Root 'assets\models\meshy\generated' }
if (-not $ReportPath) { $ReportPath = Join-Path $ScriptDir 'meshy_retexture_report.json' }

$RetexUri = 'https://api.meshy.ai/openapi/v1/retexture'

# House-style weathering suffix -- echoes the proven flat/matte/toy suffix from
# docs/design/15-meshy-pipeline.md, minus the text-to-3d-only "no textures
# needed"/"single object" clauses (contradictory for a texture-generation call).
$StyleSuffix = 'Flat toy-style painted look, low poly game asset, matte colors, no shiny highlights, Kenney/KayKit style.'

# Per-asset weathering prompts -- from doc 30's "Recommended fix" column,
# matched against each item's sibling/neighbor already reading PAINTED.
$Manifest = @(
    [PSCustomObject]@{ id = 'grave_headstone_plain'; prompt = "Weathered mournful grey stone headstone texture: fine crack lines, patches of pale green moss, subtle grime streaks, worn rounded edges. $StyleSuffix" },
    [PSCustomObject]@{ id = 'grave_small_obelisk';    prompt = "Weathered aged grey stone obelisk texture: visible stone-block grain, subtle mottled shading, faint moss at the base, worn weathered surface. $StyleSuffix" },
    [PSCustomObject]@{ id = 'board_grim_signpost';    prompt = "Weathered aged wood signpost texture: visible wood grain, faded hand-painted lettering, worn splintered edges, subtle dirt and moss streaks. $StyleSuffix" },
    [PSCustomObject]@{ id = 'estate_broken_angel';    prompt = "Weathered mournful white marble statue texture: fine crack lines across the broken angel figure, patches of pale green moss, grey grime streaks, worn aged stone shading. $StyleSuffix" },
    [PSCustomObject]@{ id = 'monument_obelisk_small'; prompt = "Aged weathered grey stone obelisk texture with subtle shading and stone-block grain, faint weathering streaks, worn surface detail. $StyleSuffix" },
    [PSCustomObject]@{ id = 'lychgate';               prompt = "Aged oak timber gate texture: rich brown wood grain on beams and posts, patches of lichen and moss on the roof shakes, weathered stone footing texture, subtle age wear. $StyleSuffix" }
)

function Get-MeshyApiKey {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Meshy env file not found: $Path" }
    foreach ($line in (Get-Content -Path $Path)) {
        if ($line -match '^\s*MESHY_API_KEY\s*=\s*(.+?)\s*$') { return $Matches[1] }
    }
    throw "MESHY_API_KEY not found in $Path"
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Save-Report {
    param($Items, [string]$Path)
    $cr = 0
    foreach ($it in $Items) { if ($it.consumed_credits) { $cr += [int]$it.consumed_credits } }
    $report = [PSCustomObject]@{
        generated_at   = (Get-Date).ToString('o')
        experiment     = 'THE FINISH WAVE (lane ZR): /retexture on the 6 PLASTIC-verdict flat assets'
        endpoint       = 'POST /openapi/v1/retexture'
        items          = $Items
        total_credits  = $cr
    }
    Write-Utf8NoBom -Path $Path -Text ($report | ConvertTo-Json -Depth 8)
}

Write-Host 'RETEXTURE WAVE -- reading API key (never printed)...'
$ApiKey = Get-MeshyApiKey -Path $EnvPath
$Headers = @{ Authorization = ('Bearer ' + $ApiKey) }

$prior = @{}
if (Test-Path $ReportPath) {
    try {
        $old = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json
        foreach ($it in @($old.items)) { $prior[$it.id] = $it }
    } catch { Write-Host 'Prior report unreadable -- starting fresh.' }
}

$OnlyList = @()
if ($Only.Trim().Length -gt 0) {
    $OnlyList = @($Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

$toProcess = @()
foreach ($m in $Manifest) {
    if ($OnlyList.Count -gt 0 -and ($OnlyList -notcontains $m.id)) { continue }
    $toProcess += $m
}
Write-Host ("Processing {0} id(s), suffix={1}." -f $toProcess.Count, $Suffix)

$Items = @()
foreach ($m in $toProcess) {
    $id = $m.id
    Write-Host ''
    Write-Host ("=== $id ===")
    $srcGlb = Join-Path $GenDir ($id + '.glb')
    $candGlb = Join-Path $GenDir ($id + '_' + $Suffix + '.glb')
    $rec = [PSCustomObject]@{
        id = $id; prompt = $m.prompt; candidate_glb = ('assets/models/meshy/generated/' + $id + '_' + $Suffix + '.glb')
        task_id = ''; status = ''; consumed_credits = 0; error = ''
    }

    if (-not (Test-Path $srcGlb)) {
        $rec.status = 'failed'; $rec.error = "source missing: $srcGlb"
        Write-Host ("  SKIP -- source missing: $srcGlb")
        $Items += $rec
        Save-Report -Items $Items -Path $ReportPath
        continue
    }

    if ($prior.ContainsKey($id + '_' + $Suffix) -and (Test-Path $candGlb)) {
        $p = $prior[$id + '_' + $Suffix]
        if ($p.status -eq 'ok') {
            Write-Host ("  candidate already present + SUCCEEDED -- skip (resume)")
            $Items += $p
            continue
        }
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($srcGlb)
        $dataUri = 'data:model/gltf-binary;base64,' + [Convert]::ToBase64String($bytes)
        Write-Host ("  uploading " + (Split-Path -Leaf $srcGlb) + (' ({0:n0} bytes)...' -f $bytes.Length))
        $body = [ordered]@{
            model_url        = $dataUri
            text_style_prompt = $m.prompt
            ai_model         = 'meshy-6'
            enable_pbr       = $false
            target_formats   = @('glb')
        }
        $json = $body | ConvertTo-Json -Depth 6 -Compress
        $resp = Invoke-RestMethod -Method Post -Uri $RetexUri -Headers $Headers -ContentType 'application/json' -Body $json -TimeoutSec 300
        $taskId = $resp.result
        $rec.task_id = $taskId
        Write-Host ("  task id: $taskId")

        $deadline = (Get-Date).AddMinutes($TaskTimeoutMin)
        $task = $null
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds $PollIntervalSec
            $task = Invoke-RestMethod -Method Get -Uri ($RetexUri + '/' + $taskId) -Headers $Headers -TimeoutSec 60
            Write-Host ("  status=" + $task.status + " progress=" + $task.progress)
            if ($task.status -eq 'SUCCEEDED' -or $task.status -eq 'FAILED' -or $task.status -eq 'CANCELED') { break }
            $task = $null
        }
        if ($null -eq $task) { throw "timed out after $TaskTimeoutMin min" }

        if ($task.status -eq 'SUCCEEDED') {
            $rec.consumed_credits = [int]$task.consumed_credits
            Invoke-WebRequest -Uri $task.model_urls.glb -OutFile $candGlb -TimeoutSec 300 -UseBasicParsing
            $rec.status = 'ok'
            Write-Host ("  SUCCEEDED + downloaded, credits=" + $rec.consumed_credits + " -> " + (Split-Path -Leaf $candGlb))
        } else {
            $errMsg = ''
            if ($task.task_error -and $task.task_error.message) { $errMsg = $task.task_error.message }
            $rec.status = 'failed'
            $rec.error = $task.status + ': ' + $errMsg
            Write-Host ("  " + $task.status + ": " + $errMsg)
        }
    } catch {
        $rec.status = 'failed'
        $rec.error = $_.Exception.Message
        Write-Host ("  FAILED: " + $_.Exception.Message)
    }
    $Items += $rec
    Save-Report -Items $Items -Path $ReportPath
}

Save-Report -Items $Items -Path $ReportPath
$totCr = 0
foreach ($it in $Items) { if ($it.consumed_credits) { $totCr += [int]$it.consumed_credits } }
Write-Host ''
Write-Host ("RETEXTURE WAVE DONE: {0} item(s), credits={1}" -f $Items.Count, $totCr)
Write-Host ("Report: " + $ReportPath)
