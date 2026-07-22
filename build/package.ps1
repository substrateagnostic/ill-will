#requires -Version 5.1
<#
.SYNOPSIS
  Build ILL WILL and assemble the distributable zip.

.DESCRIPTION
  1. (optional) regenerates the Windows icon if it is missing
  2. imports the project headless
  3. exports a release Windows Desktop build (single embedded-pck exe)
  4. writes README-FOR-PLAYERS.txt
  5. zips  exe + README-FOR-PLAYERS.txt + STORE-BLURB.md  ->  build/illwill-<version>.zip

  Windows PowerShell 5.1. No && / || / ternary; native-exe exit codes are
  checked via $LASTEXITCODE (they do not trip $ErrorActionPreference).

.PARAMETER Godot
  Path to the Godot 4.6 executable. Falls back to $env:GODOT, then `godot` on PATH.

.PARAMETER SkipIcon
  Do not attempt to regenerate the icon even if it is missing.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File build\package.ps1
  powershell -File build\package.ps1 -Godot 'C:\tools\godot.exe'
#>
[CmdletBinding()]
param(
    [string]$Godot = $env:GODOT,
    [switch]$SkipIcon
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDir    = Join-Path $ProjectRoot 'build'
$Preset      = 'Windows Desktop'

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
    # Prefer the *_console.exe build: the plain Windows editor exe relaunches
    # itself detached and returns immediately, so `&` would not wait for the
    # export to finish. The console build stays attached and blocks.
    $console = Join-Path $item.DirectoryName ($item.BaseName + '_console.exe')
    if (Test-Path $console) { return $console }
    return $p
}

$Godot = Resolve-Godot -Hint $Godot
if (-not $Godot) {
    throw 'Godot 4.6 not found. Pass -Godot <path> or set $env:GODOT, or add godot to PATH.'
}
Write-Host ('Godot:    ' + $Godot)

# --- version from export_presets.cfg (application/file_version="x.y.z") --------
$Version = '0.0.0'
$verHit = Select-String -Path (Join-Path $ProjectRoot 'export_presets.cfg') `
    -Pattern 'application/file_version="([^"]+)"' | Select-Object -First 1
if ($verHit) { $Version = $verHit.Matches[0].Groups[1].Value }
Write-Host ('Version:  ' + $Version)

if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }

# --- icon (regenerate only if missing) ----------------------------------------
$Ico = Join-Path $ProjectRoot 'assets\ui\illwill.ico'
if (-not $SkipIcon -and -not (Test-Path $Ico)) {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        Write-Host 'Icon:     regenerating (assets/ui/illwill.ico missing)'
        & $py.Source (Join-Path $BuildDir 'generate_icon.py')
    } else {
        Write-Warning 'Icon missing and python not found; exporting without a fresh icon.'
    }
} elseif (Test-Path $Ico) {
    Write-Host 'Icon:     assets/ui/illwill.ico'
}

Push-Location $ProjectRoot
try {
    # --- import (idempotent; primes .godot cache so export has all resources) --
    Write-Host 'Import:   headless reimport...'
    & $Godot --headless --path . --import --quit
    # first-run import can surface asset warnings; export is the real gate.

    # --- export release --------------------------------------------------------
    $Exe = Join-Path $BuildDir 'illwill.exe'
    if (Test-Path $Exe) { Remove-Item $Exe -Force }
    Write-Host ('Export:   ' + $Preset + ' -> ' + $Exe)
    & $Godot --headless --path . --export-release $Preset $Exe
    $exitCode = $LASTEXITCODE
    # Wait for the exe to exist AND stop growing (a detaching editor build or a
    # real-time AV scan of a ~290 MB write can lag behind the process exit).
    $deadline = (Get-Date).AddSeconds(180)
    $lastLen = -1
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $Exe) {
            $len = (Get-Item $Exe).Length
            if ($len -gt 0 -and $len -eq $lastLen) { break }
            $lastLen = $len
        }
        Start-Sleep -Milliseconds 750
    }
    if (-not (Test-Path $Exe) -or (Get-Item $Exe).Length -le 0) {
        throw ('Export failed: ' + $Exe + ' was not produced (exit=' + $exitCode + ').')
    }
}
finally {
    Pop-Location
}

# --- README-FOR-PLAYERS.txt (literal here-string: no interpolation) -----------
$Readme = Join-Path $BuildDir 'README-FOR-PLAYERS.txt'
$readmeText = @'
============================================================
  ILL WILL  -  a party game about inheritance and betrayal
============================================================

Thank you for opening the estate. The Executor has been expecting someone;
it was not, in candour, you.

------------------------------------------------------------
QUICK START
------------------------------------------------------------
1. Unzip everything to a folder and run  illwill.exe.
   (Windows SmartScreen may warn about an unknown publisher on an unsigned
   build - click "More info" then "Run anyway".)
2. On the couch, each player presses their button to take a seat:
     - Gamepad:  press A
     - Keyboard: Space (left half) or Enter (right half)
   Empty seats are filled by bots. Up to FOUR play at once.
3. Press PLAY and choose how the estate settles its debts tonight:
     - THE PROCESSION (the main event): a full board night. Stop THE LAST
       BREATH meter to move - the needle IS the dice. Gather wreaths, hoard
       pennies, shop the peddler's cart, survive the estate's stirs and the
       seance wheel, endure the Executor's commentary. When THE FINAL BELL
       tolls, the most wreaths inherits the estate.
     - Or pull any single game off the shelf for a quick match.
   Left alone for 45 seconds, the house rehearses without you (any button
   interrupts).

------------------------------------------------------------
CONTROLS  -  the game always shows you your own keys
------------------------------------------------------------
Every game prints YOUR exact controls on its GET READY card, live from your
settings, before it starts - you never have to guess or memorise a manual.

Defaults:
  - MOVE:   keyboard WASD / arrow keys, or the left stick on a gamepad
  - A / B:  each game names what A and B do on the card (shove, throw, dash...)
  - PAR FOR THE CURSE is mouse-driven (aim, hold, release to putt) and passes
    the mouse around the couch, hotseat style.
  - ESC (or START on a gamepad) opens PLAYERS & CONTROLS - reassign
    devices, remap any key, and reach SETTINGS (volume, colorblind
    palettes, text size, screen shake) from there.

------------------------------------------------------------
PLAYING TOGETHER
------------------------------------------------------------
COUCH (recommended): up to 4 players, one screen. Plug in gamepads or share
the keyboard halves (Space-side and Enter-side). Missing players become bots.

ONLINE (host / join):
  - HOST NIGHT gives you a short invite CODE (and an IP:PORT). Share it.
  - JOIN NIGHT accepts that code, or a plain  IP:PORT  address.
  - The estate itself is the shared lobby; guests drive their own seat.
  - Network transport is ENet over UDP port 8910.
    * Same house / LAN: works out of the box.
    * Over the internet: the HOST must port-forward UDP 8910 to their PC
      (and share their public IP:PORT, since the short code only encodes
      LAN addresses). Guests need nothing forwarded.

PLAYING ONLINE WITHOUT PORT FORWARDING (the easy way):
  Install Tailscale (free, tailscale.com) - everyone in your group installs
  it once and joins the same "tailnet" (one of you makes it, invites the
  rest). After that your PCs can see each other like one big house LAN, from
  anywhere. The host presses HOST NIGHT and shares the code or the address
  the game shows; friends JOIN NIGHT with it. No router settings, ever.
  Five minutes of setup the first time, zero after that.

STEAM REMOTE PLAY: because ILL WILL is true couch co-op, the host can use
Steam's "Remote Play Together" to invite far-away friends into the same
session - they stream the host's screen and play with their own controller,
no port-forwarding required. One copy hosts; friends need no purchase.

------------------------------------------------------------
The estate remembers. Nights of games until someone reaches the manor and
inherits it. Grudge is a currency. Your traps pay you. Nobody is flattered.

над. нашу. присутствие. память.
'@
Set-Content -Path $Readme -Value $readmeText -Encoding utf8
Write-Host ('README:   ' + $Readme)

# --- assemble the zip ---------------------------------------------------------
$Blurb = Join-Path $ProjectRoot 'STORE-BLURB.md'
$Zip   = Join-Path $BuildDir ('illwill-' + $Version + '.zip')
if (Test-Path $Zip) { Remove-Item $Zip -Force }

$payload = @((Join-Path $BuildDir 'illwill.exe'), $Readme)
if (Test-Path $Blurb) { $payload += $Blurb }
Compress-Archive -Path $payload -DestinationPath $Zip -Force

# --- receipt ------------------------------------------------------------------
$zi = Get-Item $Zip
Write-Host ''
Write-Host '============================================================'
Write-Host ('  PACKAGED  ' + $zi.Name)
Write-Host ('  path      ' + $zi.FullName)
Write-Host ('  size      ' + [math]::Round($zi.Length / 1MB, 2) + ' MB')
Write-Host '  contents  illwill.exe  +  README-FOR-PLAYERS.txt  +  STORE-BLURB.md'
Write-Host '============================================================'
