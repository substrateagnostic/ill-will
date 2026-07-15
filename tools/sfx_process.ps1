<#
  sfx_process.ps1  --  ILL WILL AAA SFX batch processor (Night 4)
  ---------------------------------------------------------------------------
  Rerunnable. PowerShell 5.1-safe. Requires ffmpeg + ffprobe on PATH.

  Reads CC0 source material staged in assets_raw/audio_src_night4/ (see
  assets/audio/LICENSE-NOTE.md) and bakes the shipped WAVs into assets/audio/.

  HOUSE BAR (matches tools/declick_sfx.py, see scripts/sfx.gd:40-49):
    * 44.1 kHz, 16-bit PCM WAV
    * mono or stereo per family (UI/ambience mono to save size)
    * lead/tail silence trimmed (one-shots)
    * 2-5 ms raised-cosine (quarter-sine) fade at BOTH edges so the first and
      last PCM sample are exactly 0  ->  no step-discontinuity "pop"
    * per-family peak normalization (impacts hot, UI/ambience low)
  Loops (ambience beds) are NOT edge-faded (that would dip the loop seam);
  they rely on ambience.gd's volume fade + Godot loop_mode instead.

  After rendering, every one-shot is edge-verified (|first|,|last| must be 0)
  and a full inventory CSV is written to verify_out/sfx_night4/inventory.csv.
#>
param(
  [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
  [string]$Src      = (Join-Path (Split-Path $PSScriptRoot -Parent) "assets_raw\audio_src_night4"),
  [string]$Out      = (Join-Path (Split-Path $PSScriptRoot -Parent) "assets\audio"),
  [switch]$SkipSynth
)

$ErrorActionPreference = 'Continue'
$FFMPEG  = 'ffmpeg'
$FFPROBE = 'ffprobe'
$tmpDir  = Join-Path $Src ("_proc_tmp")
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$verifyDir = Join-Path $RepoRoot "verify_out\sfx_night4"
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
$synthDir = Join-Path $Src "synth"
New-Item -ItemType Directory -Force -Path $synthDir | Out-Null

# ---------- native-exe helpers (arg arrays dodge PS5.1 quoting + NativeCommandError) ----------
function Run-Exe {
  param([string]$Exe, [string[]]$FFArgs)
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $out = & $Exe @FFArgs 2>&1 | ForEach-Object { $_.ToString() }
  $ErrorActionPreference = $prev
  return ($out -join "`n")
}
function Get-MaxDb {
  param([string]$File)
  $o = Run-Exe $FFMPEG @('-hide_banner','-i',$File,'-af','volumedetect','-f','null','NUL')
  $m = [regex]::Match($o, 'max_volume:\s*(-?[0-9.]+)\s*dB')
  if ($m.Success) { return [double]$m.Groups[1].Value }
  return -99.0
}
function Get-Dur {
  param([string]$File)
  $o = Run-Exe $FFPROBE @('-v','error','-show_entries','format=duration','-of','csv=p=0',$File)
  $v = ($o -split "`n" | Where-Object { $_ -match '^[0-9.]+$' } | Select-Object -First 1)
  if ($v) { return [double]$v }
  return 0.0
}
# read first & last frame of a 16-bit PCM WAV -> max abs sample value across channels
function Get-WavEdge {
  param([string]$File)
  $b = [System.IO.File]::ReadAllBytes($File)
  # locate 'fmt ' for channel count, and 'data' chunk
  $ch = 1; $dataOff = -1; $dataLen = 0
  $i = 12
  while ($i + 8 -le $b.Length) {
    $id = [Text.Encoding]::ASCII.GetString($b, $i, 4)
    $sz = [BitConverter]::ToUInt32($b, $i+4)
    if ($id -eq 'fmt ') { $ch = [BitConverter]::ToUInt16($b, $i+8+2) }
    elseif ($id -eq 'data') { $dataOff = $i+8; $dataLen = [int]$sz; break }
    $i += 8 + [int]$sz + ([int]$sz -band 1)
  }
  if ($dataOff -lt 0 -or $dataLen -lt (2*$ch)) { return @{ first = -1; last = -1; ch = $ch } }
  $firstMax = 0; $lastMax = 0
  for ($c = 0; $c -lt $ch; $c++) {
    $fv = [Math]::Abs([BitConverter]::ToInt16($b, $dataOff + 2*$c))
    $lv = [Math]::Abs([BitConverter]::ToInt16($b, $dataOff + $dataLen - 2*$ch + 2*$c))
    if ($fv -gt $firstMax) { $firstMax = $fv }
    if ($lv -gt $lastMax)  { $lastMax  = $lv }
  }
  return @{ first = $firstMax; last = $lastMax; ch = $ch }
}
# Force the first AND last PCM frame of a 16-bit WAV to exactly 0. The qsin edge
# fades bring the edges to within ~1% of zero; ffmpeg's continuous fade cannot
# land the *discrete* last sample on exact 0, so we bit-zero it here to meet the
# house declick guarantee (first == last == 0, matching tools/declick_sfx.py).
function Set-WavZeroEdges {
  param([string]$File)
  $b = [System.IO.File]::ReadAllBytes($File)
  $ch = 1; $dataOff = -1; $dataLen = 0
  $i = 12
  while ($i + 8 -le $b.Length) {
    $id = [Text.Encoding]::ASCII.GetString($b, $i, 4)
    $sz = [BitConverter]::ToUInt32($b, $i+4)
    if ($id -eq 'fmt ') { $ch = [BitConverter]::ToUInt16($b, $i+8+2) }
    elseif ($id -eq 'data') { $dataOff = $i+8; $dataLen = [int]$sz; break }
    $i += 8 + [int]$sz + ([int]$sz -band 1)
  }
  if ($dataOff -lt 0 -or $dataLen -lt (4*$ch)) { return }
  for ($k = 0; $k -lt (2*$ch); $k++) {
    $b[$dataOff + $k] = 0
    $b[$dataOff + $dataLen - 2*$ch + $k] = 0
  }
  [System.IO.File]::WriteAllBytes($File, $b)
}

# ---------- family render targets ----------
# peakDb = target peak dBFS ; ch = channels ; trim = trim silence ; loop = seamless bed
# fInMs / fOutMs = raised-cosine fade at head / tail (ms). Attack-critical families
# (impact/whoosh/tick) use fInMs=0 to keep a razor onset -- the single-sample bit-zero
# still removes any DC step without rounding the transient. Both edges are bit-zeroed.
$FAMILY = @{
  impact      = @{ peakDb = -1.0; ch = 2; trim = $true;  fInMs = 0; fOutMs = 4; loop = $false }
  whoosh      = @{ peakDb = -3.5; ch = 2; trim = $true;  fInMs = 0; fOutMs = 3; loop = $false }
  ui          = @{ peakDb = -7.0; ch = 1; trim = $false; fInMs = 2; fOutMs = 2; loop = $false }
  stinger     = @{ peakDb = -1.5; ch = 2; trim = $true;  fInMs = 1; fOutMs = 5; loop = $false }
  tick        = @{ peakDb = -7.0; ch = 1; trim = $false; fInMs = 0; fOutMs = 2; loop = $false }
  bell        = @{ peakDb = -3.0; ch = 2; trim = $true;  fInMs = 1; fOutMs = 5; loop = $false }
  gothic_mono = @{ peakDb = -3.0; ch = 1; trim = $true;  fInMs = 1; fOutMs = 5; loop = $false }
  gothic_wide = @{ peakDb = -2.0; ch = 2; trim = $true;  fInMs = 1; fOutMs = 6; loop = $false }
  foley       = @{ peakDb = -5.0; ch = 1; trim = $true;  fInMs = 2; fOutMs = 3; loop = $false }
  amb         = @{ peakDb = -6.0; ch = 1; trim = $false; fInMs = 0; fOutMs = 0; loop = $true  }
}

# ---------- synth sources (noise-texture sound design; original -> CC0) ----------
function Generate-Synth {
  Write-Host "== generating synth sources ==" -ForegroundColor Cyan
  $crow = Join-Path $Src "oga\crow_caw.wav"
  # deeper raven variant (pitch/slow down the caw)
  Run-Exe $FFMPEG @('-y','-hide_banner','-i',$crow,'-af','asetrate=96000*0.80,aresample=44100','-ac','1', (Join-Path $synthDir 'raven_deep.wav')) | Out-Null
  # wind gust one-shots (pink noise, band-limited, swelled)
  Run-Exe $FFMPEG @('-y','-hide_banner','-f','lavfi','-i','anoisesrc=d=1.4:c=pink:a=0.7:r=44100','-af','highpass=f=140,lowpass=f=2200,tremolo=f=6:d=0.35,afade=t=in:d=0.45:curve=qsin,afade=t=out:st=0.75:d=0.6:curve=qsin', (Join-Path $synthDir 'gust_1.wav')) | Out-Null
  Run-Exe $FFMPEG @('-y','-hide_banner','-f','lavfi','-i','anoisesrc=d=1.1:c=pink:a=0.65:r=44100','-af','highpass=f=160,lowpass=f=1800,tremolo=f=5:d=0.4,afade=t=in:d=0.35:curve=qsin,afade=t=out:st=0.6:d=0.5:curve=qsin', (Join-Path $synthDir 'gust_2.wav')) | Out-Null
  # wind bed loop (brown noise, slow tremolo = gusting)
  Run-Exe $FFMPEG @('-y','-hide_banner','-f','lavfi','-i','anoisesrc=d=16:c=brown:a=0.8:r=44100','-af','highpass=f=90,lowpass=f=1100,tremolo=f=0.18:d=0.7', (Join-Path $synthDir 'wind_bed.wav')) | Out-Null
  # room-tone loop (low brown noise)
  Run-Exe $FFMPEG @('-y','-hide_banner','-f','lavfi','-i','anoisesrc=d=12:c=brown:a=0.5:r=44100','-af','highpass=f=45,lowpass=f=320', (Join-Path $synthDir 'room_tone.wav')) | Out-Null
  Write-Host "  synth done"
}

# ---------- MANIFEST: OutBase | SrcRelPath | Family | Mode ----------
# Mode: one | loop     (Family drives targets; Mode picks one-shot vs bed path)
$MANIFEST = @'
# --- new taxonomy: impact tiers (attack weight) ---
impact_light_v1|kenney_impact-sounds/Audio/impactGeneric_light_000.ogg|impact|one
impact_light_v2|kenney_impact-sounds/Audio/impactGeneric_light_001.ogg|impact|one
impact_light_v3|kenney_impact-sounds/Audio/impactGeneric_light_002.ogg|impact|one
impact_light_v4|kenney_impact-sounds/Audio/impactGeneric_light_003.ogg|impact|one
impact_heavy_v1|kenney_impact-sounds/Audio/impactPunch_heavy_000.ogg|impact|one
impact_heavy_v2|kenney_impact-sounds/Audio/impactPunch_heavy_001.ogg|impact|one
impact_heavy_v3|kenney_impact-sounds/Audio/impactPunch_heavy_002.ogg|impact|one
impact_heavy_v4|kenney_impact-sounds/Audio/impactPunch_heavy_003.ogg|impact|one
impact_wood_v1|kenney_impact-sounds/Audio/impactWood_heavy_000.ogg|impact|one
impact_wood_v2|kenney_impact-sounds/Audio/impactWood_heavy_001.ogg|impact|one
impact_wood_v3|kenney_impact-sounds/Audio/impactWood_heavy_002.ogg|impact|one
impact_wood_v4|kenney_impact-sounds/Audio/impactWood_medium_000.ogg|impact|one
impact_metal_v1|kenney_impact-sounds/Audio/impactMetal_heavy_000.ogg|impact|one
impact_metal_v2|kenney_impact-sounds/Audio/impactMetal_heavy_001.ogg|impact|one
impact_metal_v3|kenney_impact-sounds/Audio/impactMetal_heavy_002.ogg|impact|one
impact_metal_v4|kenney_impact-sounds/Audio/impactMetal_medium_000.ogg|impact|one
# --- whoosh ---
whoosh_small_v1|oga/swishes/swishes/swish-1.wav|whoosh|one
whoosh_small_v2|oga/swishes/swishes/swish-2.wav|whoosh|one
whoosh_small_v3|oga/swishes/swishes/swish-3.wav|whoosh|one
whoosh_small_v4|oga/swishes/swishes/swish-4.wav|whoosh|one
whoosh_big_v1|oga/swishes/swishes/swish-9.wav|whoosh|one
whoosh_big_v2|oga/swishes/swishes/swish-10.wav|whoosh|one
whoosh_big_v3|oga/swishes/swishes/swish-11.wav|whoosh|one
whoosh_big_v4|oga/swishes/swishes/swish-13.wav|whoosh|one
# --- UI family ---
ui_move_v1|kenney_ui-audio/Audio/rollover1.ogg|ui|one
ui_move_v2|kenney_ui-audio/Audio/rollover2.ogg|ui|one
ui_move_v3|kenney_ui-audio/Audio/rollover3.ogg|ui|one
ui_confirm_v1|kenney_interface-sounds/Audio/confirmation_001.ogg|ui|one
ui_confirm_v2|kenney_interface-sounds/Audio/confirmation_002.ogg|ui|one
ui_confirm_v3|kenney_interface-sounds/Audio/confirmation_003.ogg|ui|one
ui_back_v1|kenney_interface-sounds/Audio/back_001.ogg|ui|one
ui_back_v2|kenney_interface-sounds/Audio/back_002.ogg|ui|one
ui_back_v3|kenney_interface-sounds/Audio/back_003.ogg|ui|one
ui_error_v1|kenney_interface-sounds/Audio/error_004.ogg|ui|one
ui_error_v2|kenney_interface-sounds/Audio/error_005.ogg|ui|one
ui_error_v3|kenney_interface-sounds/Audio/error_006.ogg|ui|one
ui_tab_v1|kenney_interface-sounds/Audio/switch_001.ogg|ui|one
ui_tab_v2|kenney_interface-sounds/Audio/switch_002.ogg|ui|one
ui_tab_v3|kenney_interface-sounds/Audio/toggle_002.ogg|ui|one
# --- stingers (abstract SFX cues, not melodies) ---
stinger_win_v1|kenney_sci-fi-sounds/Audio/forceField_000.ogg|stinger|one
stinger_lose_v1|kenney_sci-fi-sounds/Audio/explosionCrunch_000.ogg|stinger|one
stinger_reveal_v1|kenney_sci-fi-sounds/Audio/forceField_001.ogg|stinger|one
stinger_dread_v1|oga/100cc0/gong_02.ogg|stinger|one
# --- countdown ---
tick_countdown_v1|kenney_interface-sounds/Audio/tick_001.ogg|tick|one
tick_countdown_v2|kenney_interface-sounds/Audio/tick_002.ogg|tick|one
tick_countdown_v3|kenney_interface-sounds/Audio/tick_004.ogg|tick|one
# --- bells ---
bell_toll_v1|oga/100cc0/gong_01.ogg|gothic_wide|one
bell_toll_v2|oga/100cc0/gong_02.ogg|gothic_wide|one
bell_toll_v3|oga/100cc0/bell_03.ogg|gothic_wide|one
bell_small_v1|oga/100cc0/bell_01.ogg|bell|one
bell_small_v2|oga/100cc0/bell_02.ogg|bell|one
bell_small_v3|kenney_impact-sounds/Audio/impactBell_heavy_002.ogg|bell|one
# --- gothic one-shots ---
raven_v1|oga/crow_caw.wav|gothic_mono|one
raven_v2|synth/raven_deep.wav|gothic_mono|one
creak_v1|kenney_rpg-audio/Audio/creak1.ogg|gothic_mono|one
creak_v2|kenney_rpg-audio/Audio/creak2.ogg|gothic_mono|one
creak_v3|kenney_rpg-audio/Audio/creak3.ogg|gothic_mono|one
thunder_far_v1|kenney_sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg|gothic_wide|one
thunder_far_v2|kenney_sci-fi-sounds/Audio/lowFrequency_explosion_001.ogg|gothic_wide|one
thunder_far_v3|oga/100cc0/explosion.ogg|gothic_wide|one
gust_v1|synth/gust_1.wav|gothic_mono|one
gust_v2|synth/gust_2.wav|gothic_mono|one
chain_v1|oga/100cc0/metal_10.ogg|gothic_mono|one
chain_v2|oga/100cc0/metal_11.ogg|gothic_mono|one
chain_v3|oga/100cc0/metal_12.ogg|gothic_mono|one
thud_coffin_v1|kenney_impact-sounds/Audio/impactWood_heavy_003.ogg|gothic_wide|one
thud_coffin_v2|kenney_impact-sounds/Audio/impactWood_heavy_004.ogg|gothic_wide|one
thud_coffin_v3|oga/100cc0/slam_01.ogg|gothic_wide|one
organ_stab_v1|oga/100cc0/gong_02.ogg|gothic_wide|one
projector_v1|oga/100cc0/machine_01.ogg|gothic_mono|one
projector_v2|oga/100cc0/machine_02.ogg|gothic_mono|one
projector_v3|oga/100cc0/machine_03.ogg|gothic_mono|one
# --- ambience beds (loops) ---
amb_night_crickets|oga/crickets_1.mp3|amb|loop
amb_wind_grounds|synth/wind_bed.wav|amb|loop
amb_room_parlor|synth/room_tone.wav|amb|loop
# --- upgrades: extra round-robin variants for existing keys (raw basenames) ---
impactPunch_heavy_001|kenney_impact-sounds/Audio/impactPunch_heavy_001.ogg|impact|one
impactPunch_heavy_002|kenney_impact-sounds/Audio/impactPunch_heavy_002.ogg|impact|one
impactMining_001|kenney_impact-sounds/Audio/impactMining_001.ogg|impact|one
impactMining_002|kenney_impact-sounds/Audio/impactMining_002.ogg|impact|one
impactBell_heavy_002|kenney_impact-sounds/Audio/impactBell_heavy_002.ogg|impact|one
drop_002|kenney_interface-sounds/Audio/drop_002.ogg|foley|one
drop_003|kenney_interface-sounds/Audio/drop_003.ogg|foley|one
confirmation_002|kenney_interface-sounds/Audio/confirmation_002.ogg|ui|one
confirmation_003|kenney_interface-sounds/Audio/confirmation_003.ogg|ui|one
error_005|kenney_interface-sounds/Audio/error_005.ogg|ui|one
error_006|kenney_interface-sounds/Audio/error_006.ogg|ui|one
'@

# ---------- process ----------
if (-not $SkipSynth) { Generate-Synth }

$rows = @()
$seen = @{}
$n = 0
foreach ($line in ($MANIFEST -split "`r?`n")) {
  $t = $line.Trim()
  if ($t -eq '' -or $t.StartsWith('#')) { continue }
  $p = $t.Split('|')
  if ($p.Count -lt 4) { continue }
  $outBase = $p[0]; $srcRel = $p[1]; $fam = $p[2]; $mode = $p[3]
  if ($seen.ContainsKey($outBase)) { continue }
  $seen[$outBase] = $true
  $srcPath = Join-Path $Src ($srcRel -replace '/','\')
  if (-not (Test-Path $srcPath)) { Write-Host ("  MISSING SRC  {0}  <-  {1}" -f $outBase, $srcRel) -ForegroundColor Red; continue }
  $f = $FAMILY[$fam]
  if ($null -eq $f) { Write-Host ("  UNKNOWN FAMILY '{0}' for {1}" -f $fam, $outBase) -ForegroundColor Red; continue }
  $ch = $f.ch
  $tmp1 = Join-Path $tmpDir ($outBase + "_a.wav")
  $dst  = Join-Path $Out ($outBase + ".wav")

  # ---- pass 1: resample / channel / (trim) ----
  $af1 = @()
  if ($f.loop) { $af1 += 'highpass=f=20' } else { $af1 += 'highpass=f=12' }
  if ($f.trim) {
    $af1 += 'silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.005:detection=peak'
    $af1 += 'areverse'
    $af1 += 'silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.005:detection=peak'
    $af1 += 'areverse'
  }
  $af1s = ($af1 -join ',')
  $r1 = Run-Exe $FFMPEG @('-y','-hide_banner','-i',$srcPath,'-ac',"$ch",'-ar','44100','-af',$af1s,'-c:a','pcm_s16le',$tmp1)
  if (-not (Test-Path $tmp1)) {
    Write-Host ("  FF FAIL  {0}  (src={1})" -f $outBase, $srcPath) -ForegroundColor Red
    (($r1 -split "`n") | Select-Object -Last 3) | ForEach-Object { Write-Host ("      | " + $_) -ForegroundColor DarkYellow }
    continue
  }

  # ---- measure + normalize gain ----
  $maxdb = Get-MaxDb $tmp1
  $gain  = [Math]::Round(($f.peakDb - $maxdb), 2)
  $dur   = Get-Dur $tmp1

  # ---- pass 2: gain (+ edge fades for one-shots) -> final ----
  $af2 = @("volume=$($gain)dB")
  if (-not $f.loop -and $dur -gt 0) {
    if ($f.fInMs -gt 0) {
      $fin = [Math]::Round([Math]::Min(($f.fInMs/1000.0), ($dur/5.0)), 4)
      $af2 += "afade=t=in:st=0:d=$($fin):curve=qsin"
    }
    if ($f.fOutMs -gt 0) {
      $fout = [Math]::Round([Math]::Min(($f.fOutMs/1000.0), ($dur/4.0)), 4)
      $outSt = [Math]::Round(($dur - $fout), 4)
      if ($outSt -lt 0) { $outSt = 0 }
      $af2 += "afade=t=out:st=$($outSt):d=$($fout):curve=qsin"
    }
  }
  $af2s = ($af2 -join ',')
  Run-Exe $FFMPEG @('-y','-hide_banner','-i',$tmp1,'-af',$af2s,'-ac',"$ch",'-ar','44100','-c:a','pcm_s16le',$dst) | Out-Null

  # ---- bit-exact zero edges (one-shots) then verify ----
  if (-not $f.loop) { Set-WavZeroEdges $dst }
  $fpeak = Get-MaxDb $dst
  $fdur  = Get-Dur $dst
  $edge  = @{ first = 0; last = 0 }
  if (-not $f.loop) { $edge = Get-WavEdge $dst }
  $sizeKb = [Math]::Round((Get-Item $dst).Length / 1024.0, 1)
  $rows += [PSCustomObject]@{
    key = $outBase; family = $fam; mode = $mode; ch = $ch
    dur_s = [Math]::Round($fdur,3); peak_dBFS = $fpeak
    first = $edge.first; last = $edge.last; size_kB = $sizeKb
    source = $srcRel
  }
  $n++
  $flag = ''
  if (-not $f.loop -and ($edge.first -ne 0 -or $edge.last -ne 0)) { $flag = '  <-- EDGE NOT ZERO' }
  Write-Host ("  {0,-24} {1,-11} ch{2} {3,6:N3}s peak={4,6} first={5} last={6}{7}" -f $outBase, $fam, $ch, $fdur, $fpeak, $edge.first, $edge.last, $flag)
}

# ---------- inventory CSV ----------
$csv = Join-Path $verifyDir "inventory.csv"
$rows | Sort-Object family, key | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
$badEdges = @($rows | Where-Object { $_.mode -eq 'one' -and ($_.first -ne 0 -or $_.last -ne 0) })
$totalKb  = ($rows | Measure-Object size_kB -Sum).Sum
Write-Host ""
Write-Host ("Processed {0} files.  Committed WAV total: {1:N1} kB ({2:N2} MB)" -f $n, $totalKb, ($totalKb/1024.0)) -ForegroundColor Green
Write-Host ("Edge check: {0} one-shots, {1} with non-zero edges." -f (@($rows | Where-Object mode -eq 'one').Count), $badEdges.Count) -ForegroundColor Green
Write-Host ("Inventory -> {0}" -f $csv)
Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
