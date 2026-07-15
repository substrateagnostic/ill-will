#requires -Version 5.1
<#
.SYNOPSIS
  Manifest-driven Meshy.ai text-to-3D batch generator for ILL WILL props.

.DESCRIPTION
  Reads tools/meshy_manifest.json (array of {id, prompt, target_height_hint,
  category}), submits a text-to-3D PREVIEW per prop (model meshy-6, low-poly,
  house style suffix appended), polls to completion, submits a REFINE for
  every prop whose preview succeeded (PBR off — house style is flat-color),
  polls those, and downloads the finished GLBs to
  assets/models/meshy/generated/<id>.glb.

  Writes tools/meshy_forge_report.json: one entry per manifest id with task
  ids, consumed_credits, and status, plus a summary block.

  Full API research / parameter rationale: docs/design/15-meshy-pipeline.md

  Windows PowerShell 5.1. No && / || / ternary. Never writes the API key to
  any file; it is read from the .env at runtime into a process variable only.

.PARAMETER PreviewOnly
  Stop after preview (download the untextured preview GLB instead of
  refining). Useful for a fast geometry-only sanity pass.

.PARAMETER Resume
  Skip any id whose GLB already exists in the output directory. Prior
  report entries for skipped ids are carried forward into the new report.

.PARAMETER Only
  Comma-separated list of manifest ids to process (everything else is
  skipped as if -Resume had already downloaded it). Used for pilot runs and
  targeted re-generation after a contact-sheet review.

.PARAMETER BatchSize
  Max tasks in flight at once per phase (preview phase, then refine phase).
  Kept well under the paid-tier queued-task cap (10-20) — see doc 15.

.EXAMPLE
  powershell -File tools\meshy_forge.ps1 -Only grave_headstone_plain,grave_headstone_cracked,award_workhorse
  powershell -File tools\meshy_forge.ps1 -Resume
  powershell -File tools\meshy_forge.ps1 -PreviewOnly -Only board_planchette
#>
[CmdletBinding()]
param(
    [string]$ManifestPath = '',
    [string]$OutDir       = '',
    [string]$ReportPath   = '',
    [string]$EnvPath      = 'C:\Users\agall\projects\Dead_Attestation\.env',
    [switch]$PreviewOnly,
    [switch]$Resume,
    [string]$Only = '',
    [int]$BatchSize = 5,
    [int]$PollIntervalSec = 5,
    [int]$TaskTimeoutMin = 15
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# $PSScriptRoot can come back empty depending on how the script was invoked
# (e.g. nested inside another PowerShell host); fall back to the invocation
# path so relative default paths always resolve.
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent (Resolve-Path '.\tools\meshy_forge.ps1' -ErrorAction SilentlyContinue) }
if (-not $ScriptDir) { throw 'Could not resolve tools/ script directory; run from the project root or pass -ManifestPath/-OutDir/-ReportPath explicitly.' }
if (-not $ManifestPath) { $ManifestPath = Join-Path $ScriptDir 'meshy_manifest.json' }
if (-not $OutDir)       { $OutDir       = Join-Path (Split-Path -Parent $ScriptDir) 'assets\models\meshy\generated' }
if (-not $ReportPath)   { $ReportPath   = Join-Path $ScriptDir 'meshy_forge_report.json' }

$BaseUri = 'https://api.meshy.ai/openapi/v2/text-to-3d'

# Proven house style suffix — reused verbatim from docs/verify/meshy-assets-VERIFY.md
# and docs/verify/visual-polish-VERIFY.md (18/18 KEEP across three prior batches).
$HouseStyleSuffix = 'low poly, chunky toy-like proportions, flat colors, no textures needed, game asset, clean silhouette, single object, Kenney/KayKit style'

# --- helpers -------------------------------------------------------------

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

# Retrying wrapper. Never logs $Headers (would leak the bearer token).
function Invoke-MeshyRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        $BodyObj = $null
    )
    $delays = @(5, 10, 20)
    $attempt = 0
    while ($true) {
        try {
            if ($null -ne $BodyObj) {
                $json = $BodyObj | ConvertTo-Json -Depth 6 -Compress
                return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body $json -TimeoutSec 60
            } else {
                return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -TimeoutSec 60
            }
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = $null }
            }
            $isRetryable = $false
            if ($null -eq $statusCode) { $isRetryable = $true }
            elseif ($statusCode -eq 429) { $isRetryable = $true }
            elseif ($statusCode -ge 500) { $isRetryable = $true }

            if (-not $isRetryable -or $attempt -ge $delays.Count) {
                $bodyText = ''
                if ($_.Exception.Response) {
                    try {
                        $stream = $_.Exception.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $bodyText = $reader.ReadToEnd()
                    } catch {}
                }
                throw ("Meshy API error (status=$statusCode): " + $_.Exception.Message + ' body=' + $bodyText)
            }
            $delay = $delays[$attempt]
            Write-Host ('    [retry] status=' + $statusCode + ", waiting ${delay}s...")
            Start-Sleep -Seconds $delay
            $attempt += 1
        }
    }
}

function Submit-Preview {
    param([string]$Prompt, [hashtable]$Headers)
    $body = [ordered]@{
        mode              = 'preview'
        prompt            = $Prompt
        ai_model          = 'meshy-6'
        model_type        = 'lowpoly'
        topology          = 'triangle'
        target_polycount  = 8000
        should_remesh     = $true
        moderation        = $false
        target_formats    = @('glb')
        origin_at         = 'bottom'
    }
    $resp = Invoke-MeshyRequest -Method Post -Uri $BaseUri -Headers $Headers -BodyObj $body
    return $resp.result
}

function Submit-Refine {
    param([string]$PreviewTaskId, [hashtable]$Headers)
    $body = [ordered]@{
        mode            = 'refine'
        preview_task_id = $PreviewTaskId
        ai_model        = 'meshy-6'
        enable_pbr      = $false
        moderation      = $false
        target_formats  = @('glb')
        origin_at       = 'bottom'
    }
    $resp = Invoke-MeshyRequest -Method Post -Uri $BaseUri -Headers $Headers -BodyObj $body
    return $resp.result
}

function Get-Batches {
    param([array]$Items, [int]$Size)
    $batches = @()
    # NOTE: `return $batches` (no leading comma) would let PowerShell enumerate
    # the outer array onto the output pipeline and re-collect it one level
    # flattened, silently turning "N batches of up to $Size" into "N*Size
    # batches of 1". The unary comma suppresses that one level of unrolling.
    if (-not $Items -or $Items.Count -eq 0) { return , $batches }
    for ($i = 0; $i -lt $Items.Count; $i += $Size) {
        $end = [Math]::Min($i + $Size, $Items.Count) - 1
        $batches += ,@($Items[$i..$end])
    }
    return , $batches
}

function Save-Report {
    param($StateMap, [array]$OrderedIds, [string]$Path, [bool]$PreviewOnlyMode)
    $items = @()
    foreach ($id in $OrderedIds) {
        $st = $StateMap[$id]
        $consumed = 0
        if ($st.preview_credits) { $consumed += [int]$st.preview_credits }
        if ($st.refine_credits)  { $consumed += [int]$st.refine_credits }
        if ($st.PSObject.Properties.Match('carried_credits').Count -gt 0 -and $st.carried_credits) {
            $consumed = [int]$st.carried_credits
        }
        $items += [PSCustomObject]@{
            id                 = $st.id
            category           = $st.category
            status             = $st.status
            preview_task_id    = $st.preview_task_id
            preview_status     = $st.preview_status
            preview_credits    = $st.preview_credits
            refine_task_id     = $st.refine_task_id
            refine_status      = $st.refine_status
            refine_credits     = $st.refine_credits
            consumed_credits   = $consumed
            glb_path           = $st.glb_path
            error              = $st.error
        }
    }
    # @() wraps every Where-Object result below: a filter that matches exactly
    # one item returns a bare scalar (no .Count property) instead of a
    # 1-element array — the same footgun documented on Get-Batches above.
    $summary = [PSCustomObject]@{
        total            = $items.Count
        ok               = (@($items | Where-Object { $_.status -eq 'ok' })).Count
        preview_only     = (@($items | Where-Object { $_.status -eq 'preview_only' })).Count
        failed           = (@($items | Where-Object { $_.status -eq 'failed' })).Count
        resumed_skip     = (@($items | Where-Object { $_.status -eq 'resumed_skip' })).Count
        total_credits    = ($items | Measure-Object -Property consumed_credits -Sum).Sum
    }
    $report = [PSCustomObject]@{
        generated_at = (Get-Date).ToString('o')
        model        = 'meshy-6'
        preview_only = $PreviewOnlyMode
        batch_size   = $BatchSize
        items        = $items
        summary      = $summary
    }
    $json = $report | ConvertTo-Json -Depth 8
    Write-Utf8NoBom -Path $Path -Text $json
}

# --- setup -----------------------------------------------------------------

Write-Host 'Meshy Forge — reading API key (never printed)...'
$ApiKey = Get-MeshyApiKey -Path $EnvPath
$Headers = @{ Authorization = ('Bearer ' + $ApiKey) }
Write-Host 'Meshy Forge — API key loaded into memory only.'

if (-not (Test-Path $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
# Two-step, NOT `@(... | ConvertFrom-Json)` directly: ConvertFrom-Json writes
# a parsed JSON array to the pipeline with -NoEnumerate semantics (one array
# object, not one emission per element), so wrapping the live pipeline call
# in @() re-collects that single array-object as ONE element of a NEW outer
# array — silently turning a 32-item manifest into a 1-item manifest whose
# sole "item" is the whole array (caught empirically: verified via isolated
# test before landing this). Assigning first captures the array as-is
# (already correct for N>1 elements); @() on the now-plain variable is safe
# and only kicks in to fix the true scalar case (e.g. a hand-authored
# 1-entry -ManifestPath override, or malformed JSON that isn't an array).
$manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
$manifest = @($manifest)
Write-Host ("Manifest: {0} props from {1}" -f $manifest.Count, $ManifestPath)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$OnlyList = @()
if ($Only.Trim().Length -gt 0) {
    $OnlyList = @($Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

$oldMap = @{}
if (Test-Path $ReportPath) {
    try {
        $oldReport = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json
        foreach ($it in @($oldReport.items)) { $oldMap[$it.id] = $it }
    } catch {
        Write-Host ('  (could not parse existing report, ignoring: ' + $_.Exception.Message + ')')
    }
}

$toProcess = @()
foreach ($m in $manifest) {
    if ($OnlyList.Count -gt 0 -and ($OnlyList -notcontains $m.id)) { continue }
    $toProcess += $m
}
$orderedIds = @($toProcess | ForEach-Object { $_.id })

$state = @{}
foreach ($m in $toProcess) {
    $glbPath = Join-Path $OutDir ($m.id + '.glb')
    $alreadyDone = $Resume -and (Test-Path $glbPath)
    $obj = [PSCustomObject]@{
        id                  = $m.id
        category            = $m.category
        prompt              = $m.prompt
        target_height_hint  = $m.target_height_hint
        full_prompt         = ($m.prompt + ', ' + $HouseStyleSuffix)
        preview_task_id     = $null
        preview_status      = $null
        preview_credits     = 0
        preview_glb_url     = $null
        preview_retried     = $false
        refine_task_id      = $null
        refine_status       = $null
        refine_credits      = 0
        status              = $null
        error               = $null
        glb_path            = $null
        carried_credits     = $null
    }
    if ($alreadyDone) {
        $obj.status = 'resumed_skip'
        $obj.glb_path = $glbPath
        if ($oldMap.ContainsKey($m.id)) { $obj.carried_credits = $oldMap[$m.id].consumed_credits }
    }
    $state[$m.id] = $obj
}

$active = @($toProcess | Where-Object { $state[$_.id].status -ne 'resumed_skip' })
Write-Host ("Processing {0} props ({1} resumed-skipped)." -f $active.Count, ($toProcess.Count - $active.Count))

# --- phase 1: preview --------------------------------------------------------

$previewBatches = Get-Batches -Items $active -Size $BatchSize
$batchNum = 0
foreach ($batch in $previewBatches) {
    $batchNum += 1
    Write-Host ("`nPREVIEW batch {0}/{1}: {2}" -f $batchNum, $previewBatches.Count, (($batch | ForEach-Object { $_.id }) -join ', '))
    foreach ($m in $batch) {
        $st = $state[$m.id]
        try {
            $taskId = Submit-Preview -Prompt $st.full_prompt -Headers $Headers
            $st.preview_task_id = $taskId
            Write-Host ('  submitted preview ' + $m.id + ' -> ' + $taskId)
        } catch {
            $st.status = 'failed'
            $st.error = 'preview submit: ' + $_.Exception.Message
            Write-Host ('  SUBMIT FAILED ' + $m.id + ': ' + $_.Exception.Message)
        }
        Start-Sleep -Milliseconds 400
    }

    # @() wrap: a batch where exactly one item still needs polling would
    # otherwise collapse to a bare object with no .Count, silently skipping
    # the poll loop below entirely (this is what happened to the pilot run).
    $pending = @($batch | Where-Object { $state[$_.id].preview_task_id -and -not $state[$_.id].status })
    $deadline = (Get-Date).AddMinutes($TaskTimeoutMin)
    while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $PollIntervalSec
        $stillPending = @()
        foreach ($m in $pending) {
            $st = $state[$m.id]
            try {
                $task = Invoke-MeshyRequest -Method Get -Uri ($BaseUri + '/' + $st.preview_task_id) -Headers $Headers
            } catch {
                Write-Host ('  POLL ERROR ' + $m.id + ': ' + $_.Exception.Message)
                $stillPending += $m
                continue
            }
            $status = $task.status
            if ($status -eq 'SUCCEEDED') {
                $st.preview_status = 'SUCCEEDED'
                $st.preview_credits = [int]$task.consumed_credits
                $st.preview_glb_url = $task.model_urls.glb
                Write-Host ('  preview SUCCEEDED ' + $m.id + ' credits=' + $st.preview_credits)
            } elseif ($status -eq 'FAILED' -or $status -eq 'CANCELED') {
                $errMsg = $null
                if ($task.task_error -and $task.task_error.message) { $errMsg = $task.task_error.message }
                if (-not $st.preview_retried) {
                    Write-Host ('  preview ' + $status + ' ' + $m.id + ' (' + $errMsg + ') -- retrying once with adjusted prompt')
                    $st.preview_retried = $true
                    $retryPrompt = $st.full_prompt + ', simple clean geometry, single distinct object'
                    try {
                        $newTaskId = Submit-Preview -Prompt $retryPrompt -Headers $Headers
                        $st.preview_task_id = $newTaskId
                        $stillPending += $m
                    } catch {
                        $st.status = 'failed'
                        $st.error = 'preview retry submit: ' + $_.Exception.Message
                    }
                } else {
                    $st.preview_status = $status
                    $st.status = 'failed'
                    $st.error = 'preview ' + $status + ': ' + $errMsg
                    Write-Host ('  preview FAILED (final) ' + $m.id + ': ' + $errMsg)
                }
            } else {
                $stillPending += $m
            }
        }
        $pending = $stillPending
    }
    foreach ($m in $pending) {
        $st = $state[$m.id]
        if (-not $st.status) {
            $st.status = 'failed'
            $st.error = 'preview timeout'
            Write-Host ('  PREVIEW TIMEOUT ' + $m.id)
        }
    }
    Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode ([bool]$PreviewOnly)
}

# --- preview-only mode: download preview GLBs and stop ----------------------

if ($PreviewOnly) {
    foreach ($m in $active) {
        $st = $state[$m.id]
        if ($st.preview_status -eq 'SUCCEEDED' -and -not $st.status) {
            $dest = Join-Path $OutDir ($m.id + '.glb')
            try {
                Invoke-WebRequest -Uri $st.preview_glb_url -OutFile $dest -TimeoutSec 120 -UseBasicParsing
                $st.status = 'preview_only'
                $st.glb_path = $dest
                Write-Host ('  downloaded preview-only GLB: ' + $m.id)
            } catch {
                $st.status = 'failed'
                $st.error = 'preview download failed: ' + $_.Exception.Message
            }
        }
    }
    Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode $true
} else {

    # --- phase 2: refine -----------------------------------------------------

    $readyForRefine = @($active | Where-Object { $state[$_.id].preview_status -eq 'SUCCEEDED' -and -not $state[$_.id].status })
    $refineBatches = Get-Batches -Items $readyForRefine -Size $BatchSize
    $batchNum = 0
    foreach ($batch in $refineBatches) {
        $batchNum += 1
        Write-Host ("`nREFINE batch {0}/{1}: {2}" -f $batchNum, $refineBatches.Count, (($batch | ForEach-Object { $_.id }) -join ', '))
        foreach ($m in $batch) {
            $st = $state[$m.id]
            try {
                $taskId = Submit-Refine -PreviewTaskId $st.preview_task_id -Headers $Headers
                $st.refine_task_id = $taskId
                Write-Host ('  submitted refine ' + $m.id + ' -> ' + $taskId)
            } catch {
                $st.status = 'failed'
                $st.error = 'refine submit: ' + $_.Exception.Message
                Write-Host ('  SUBMIT FAILED ' + $m.id + ': ' + $_.Exception.Message)
            }
            Start-Sleep -Milliseconds 400
        }

        $pending = @($batch | Where-Object { $state[$_.id].refine_task_id -and -not $state[$_.id].status })
        $deadline = (Get-Date).AddMinutes($TaskTimeoutMin)
        while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
            Start-Sleep -Seconds $PollIntervalSec
            $stillPending = @()
            foreach ($m in $pending) {
                $st = $state[$m.id]
                try {
                    $task = Invoke-MeshyRequest -Method Get -Uri ($BaseUri + '/' + $st.refine_task_id) -Headers $Headers
                } catch {
                    Write-Host ('  POLL ERROR ' + $m.id + ': ' + $_.Exception.Message)
                    $stillPending += $m
                    continue
                }
                $status = $task.status
                if ($status -eq 'SUCCEEDED') {
                    $st.refine_status = 'SUCCEEDED'
                    $st.refine_credits = [int]$task.consumed_credits
                    $dest = Join-Path $OutDir ($m.id + '.glb')
                    try {
                        Invoke-WebRequest -Uri $task.model_urls.glb -OutFile $dest -TimeoutSec 120 -UseBasicParsing
                        $st.status = 'ok'
                        $st.glb_path = $dest
                        Write-Host ('  refine SUCCEEDED + downloaded ' + $m.id + ' credits=' + $st.refine_credits + ' total=' + ($st.preview_credits + $st.refine_credits))
                    } catch {
                        $st.status = 'failed'
                        $st.error = 'download failed: ' + $_.Exception.Message
                        Write-Host ('  DOWNLOAD FAILED ' + $m.id + ': ' + $_.Exception.Message)
                    }
                } elseif ($status -eq 'FAILED' -or $status -eq 'CANCELED') {
                    $st.refine_status = $status
                    $errMsg = $null
                    if ($task.task_error -and $task.task_error.message) { $errMsg = $task.task_error.message }
                    $st.status = 'failed'
                    $st.error = 'refine ' + $status + ': ' + $errMsg
                    Write-Host ('  refine FAILED ' + $m.id + ': ' + $errMsg)
                } else {
                    $stillPending += $m
                }
            }
            $pending = $stillPending
        }
        foreach ($m in $pending) {
            $st = $state[$m.id]
            if (-not $st.status) {
                $st.status = 'failed'
                $st.error = 'refine timeout'
                Write-Host ('  REFINE TIMEOUT ' + $m.id)
            }
        }
        Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode $false
    }
}

# --- final summary -----------------------------------------------------------

Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode ([bool]$PreviewOnly)
$finalReport = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json

Write-Host ''
Write-Host '================ MESHY FORGE SUMMARY ================'
$byCat = @($finalReport.items) | Group-Object category
foreach ($g in $byCat) {
    $okCount = (@($g.Group | Where-Object { $_.status -eq 'ok' -or $_.status -eq 'preview_only' -or $_.status -eq 'resumed_skip' })).Count
    Write-Host ("[{0}] {1}/{2} ok" -f $g.Name, $okCount, $g.Count)
    foreach ($it in @($g.Group)) {
        Write-Host ("  - {0,-26} {1,-14} credits={2}" -f $it.id, $it.status, $it.consumed_credits)
    }
}
Write-Host ''
Write-Host ('TOTAL: ' + $finalReport.summary.total + '  ok=' + $finalReport.summary.ok + '  preview_only=' + $finalReport.summary.preview_only + '  failed=' + $finalReport.summary.failed + '  resumed_skip=' + $finalReport.summary.resumed_skip)
Write-Host ('TOTAL CREDITS CONSUMED: ' + $finalReport.summary.total_credits)
Write-Host ('Report: ' + $ReportPath)
Write-Host '======================================================='
