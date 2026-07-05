# Export VERIFY — Windows Desktop double-clickable build

Goal: make the game double-clickable so the owner can hand friends a build.
Result: **PASS.** A single-file `unparty.exe` (embedded PCK) builds, launches on
the GPU, renders the lobby, and self-quits cleanly.

## Engine / templates

- Godot: `4.6.2.stable.official` (on PATH as `godot`).
- Export templates: already installed at
  `%APPDATA%\Godot\export_templates\4.6.2.stable\`
  (`C:\Users\<user>\AppData\Roaming\Godot\export_templates\4.6.2.stable\`).
  `version.txt` = `4.6.2.stable`; `windows_release_x86_64.exe` present.
  No download was needed.

## Export preset

`export_presets.cfg` (project root), preset `[preset.0]` "Windows Desktop":

- `platform="Windows Desktop"`, `binary_format/architecture="x86_64"`
- `binary_format/embed_pck=true`  → single self-contained `.exe`
- `application/modify_resources=true`
- `application/product_name="The Un-Party"`
- `application/file_version="0.1.0"`, `application/product_version="0.1.0"`
- `application/company_name="un-party"`, `application/file_description="The Un-Party"`
- `codesign/enable=false` (no code signing)
- icon left default (`application/icon=""`)
- `export_path="build/unparty.exe"`

Embedded metadata verified on the built exe (PowerShell `(Get-Item ...).VersionInfo`):
`ProductName=The Un-Party`, `FileVersion=0.1.0`, `CompanyName=un-party`,
`FileDescription=The Un-Party`.

## Build output

- Path: `build/unparty.exe`
- Size: **218,829,984 bytes (~209 MiB)** — Windows release template + embedded PCK.
- `build/` is git-ignored (already present in `.gitignore`, alongside `verify_out/`),
  so the exe is not committed.

## One-command rebuild

```
godot --headless --export-release "Windows Desktop" build/unparty.exe --path .
```

Run from the project root. `build/` must exist (`mkdir build` once). On a fresh
checkout with no `.godot/` cache, run `godot --headless --path . --import` once
first to import assets (the export will otherwise import on the fly).

## Verification evidence

Ran the exported exe against the in-game verify harness (`VerifyCapture`,
`scripts/verify_capture.gd`) so it captures a frame and quits on its own:

```
build/unparty.exe -- --shots=200 --outdir=verify_out/exportcheck --quitafter=300
```

Console output:

```
Godot Engine v4.6.2.stable.official.71f334935
Vulkan 1.4.303 - Forward+ - Using Device #0: NVIDIA GeForce RTX 4050 Laptop GPU
VERIFY_SHOT res://verify_out/exportcheck/shot_0200.png
VERIFY_DONE
```

Exit code 0. The packed exe **could** write into `res://` — when packed, `res://`
globalizes to the executable's own directory, so the PNG landed at
`build/verify_out/exportcheck/shot_0200.png`. That capture was read back and
confirms the game rendered the lobby: the yellow **"THE UN-PARTY"** title over the
green estate hill, with the "who's on the couch?" player-setup panel
(RED/BLUE/GOLD/MINT rows, HUMAN/BOT toggles, START THE NIGHT / MINIGAMES buttons).

Committed copy of that frame: `docs/verify/shots/export_lobby.png`.

Verdict: **the build is double-clickable and runs correctly.**
