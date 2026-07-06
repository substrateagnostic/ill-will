# ACCESS tab — colorblind palettes + UI scale (VERIFY)

Research digest 04 MUST items delivered: **colorblind palettes (3 modes + never-
color-alone)** and **text/UI scale**. Files touched: `scripts/game_state.gd`,
`core/party_setup.gd`, `scripts/dev/test_access.gd`, `docs/verify/`.

## What shipped

- **`GameState.PALETTES`** — four seat palettes (`classic` / `deutan` / `protan`
  / `tritan`). Each alternate is designed so all FOUR seats stay mutually
  distinguishable under that dichromacy.
- **`GameState.apply_palette(id)`** — mutates `PLAYER_COLORS` **in place** (not a
  reassignment) so live readers pick it up. `PLAYER_COLORS` changed `const` →
  `var` because const Arrays are read-only in Godot 4; default value is the
  classic palette, byte-identical to the shipped colors.
- **ACCESS tab** (`core/party_setup.gd`): a `COLOR PALETTE` OptionButton
  (`CLASSIC / DEUTERANOPIA / PROTANOPIA / TRITANOPIA`) bound to pref `"palette"`,
  and a `UI SCALE` slider (1.0–1.3, step 0.05) bound to pref `"ui_scale"` driving
  `get_tree().root.content_scale_factor`. Both apply on boot (from `_ready`, via
  `_apply_access_prefs()` after `_load_prefs`) and live on change.
- Identity always travels as **name + badge SHAPE + color** (RED●/BLUE▲/GOLD■/
  MINT◆). Seat NAMES never change — hue is never the only channel.

## Palette hex tables

Godot `Color()` floats as written in `game_state.gd`, with nearest sRGB hex.

| Seat (shape) | classic | deutan | protan | tritan |
|---|---|---|---|---|
| RED ● | `#EB574D` (0.92,0.34,0.30) | `#C43E00` (0.769,0.243,0.0) | `#B03A00` (0.69,0.227,0.0) | `#CC3311` (0.8,0.2,0.067) |
| BLUE ▲ | `#408CE6` (0.25,0.55,0.90) | `#1552D8` (0.082,0.322,0.847) | `#0072B2` (0.0,0.447,0.698) | `#3B4CC0` (0.231,0.298,0.753) |
| GOLD ■ | `#F2BF33` (0.95,0.75,0.20) | `#F0E442` (0.941,0.894,0.259) | `#F0E442` (0.941,0.894,0.259) | `#ECD400` (0.925,0.831,0.0) |
| MINT ◆ | `#4DD999` (0.30,0.85,0.60) | `#44AA99` (0.267,0.667,0.6) | `#009E73` (0.0,0.62,0.451) | `#00C389` (0.0,0.765,0.537) |

Anchored on the Okabe-Ito CVD-safe palette (`#0072B2` blue, `#F0E442` yellow,
`#009E73` bluish-green, `#D55E00`/`#E69F00` warm reds) and tuned per mode.

## CVD reasoning

Each dichromacy collapses one opponent axis; the fix is to spread the four seats
along the axes that survive.

- **Deuteranopia** (no M-cones, ~6% of males — red↔green confusion). Survives:
  the **blue↔yellow** axis + **lightness**. The palette places the two warm seats
  (RED vermillion, GOLD lemon) far apart in *lightness*, and the two cool seats
  (BLUE vivid, MINT teal) far apart in lightness + chroma; warm vs cool separate
  on blue-yellow.
- **Protanopia** (no L-cones, ~1.5% of males — red↔green, and reds lose
  luminance so they look *darker/dimmer*). Strategy: turn that weakness into the
  signal — push RED to a **dark brick** (`#B03A00`) so it becomes a unique DARK
  anchor (lightness is retained), keeping BLUE/GOLD/MINT bright. A candidate
  search confirmed this beats an orange-red, which collides with the yellow GOLD
  (min ΔE00 27.2 vs 15.2).
- **Tritanopia** (no S-cones, rare — blue↔yellow confusion: blue↔green and
  yellow↔pink). Survives: the **red↔green** axis + lightness. Palette spreads on
  red-green (clean RED, spring-green MINT) and pulls the classic blue↔green
  collision apart with a deep **indigo** BLUE (`#3B4CC0`) plus a bright MINT and a
  lightness gap.

## Numerical validation (Machado-2009 sim + CIEDE2000)

Simulated each palette under full (severity 1.0) dichromacy (Machado et al. 2009
matrices in linear RGB), converted to CIELAB, and took the **minimum CIEDE2000
(ΔE00) over all six seat-pairs** — the worst-case "closest pair". Reference:
ΔE00 ≈ 1 is a just-noticeable difference; > 10 is comfortably distinct.
(Validator: `scratchpad/cvd_check.py`, reproducible.)

| Palette | normal | deutan | protan | tritan |
|---|---|---|---|---|
| classic  | **36.6** | 15.8 | 14.8 | 17.7 |
| deutan   | 37.7 | **30.4** ✓ | 30.6 | 22.7 |
| protan   | 38.0 | 20.7 | **27.2** ✓ | 12.4 |
| tritan   | 34.9 | 22.5 | 18.2 | **33.1** ✓ |

✓ = the mode's target condition. Every alternate clears **27+** under its target
(vs classic's 14.8–17.7 under CVD — classic is the baseline, which is exactly why
the alternates exist). Bonus: the alternates stay broadly robust across the *other*
dichromacies too (mostly > 18), so a mismatched selection still reads.

## Headless test

`godot --headless --script res://scripts/dev/test_access.gd` (SceneTree script,
patterned on `test_keybinds.gd`, with `user://prefs.json` backup/restore):

```
palette data:
  ok   PALETTES has 4 modes
  ok   classic/deutan/protan/tritan palette has 4 colors
apply_palette:
  ok   apply deutan sets RED
  ok   still 4 seats after apply
  ok   mutates the SAME array in place (live readers update)
  ok   apply tritan sets MINT
  ok   apply classic restores shipped RED
  ok   unknown id falls back to classic
prefs persistence (palette + ui_scale) via user://prefs.json:
  ok   prefs.json opens for write / parses back to a Dictionary
  ok   palette pref survives round-trip
  ok   ui_scale pref survives round-trip
  ok   absent key returns caller default
ACCESS_TEST PASS (0 failures)
```

Note: `party_setup.gd` references autoload singletons that are not yet registered
as globals at `--script` compile time, so (unlike `test_keybinds`' self-contained
`player_input.gd`) it can't be preloaded here — the test round-trips the exact
JSON + `user://prefs.json` store its `set_pref`/`_load_prefs` use, and the windowed
boots below exercise the full party_setup read-and-apply path end-to-end.

## Windowed screenshots (read by eye)

All captured windowed at 1280×720 via `VerifyCapture --shots`. Real prefs.json
backed up and restored around every palette boot.

- **`access_tab.png`** — `--opensettings=4`. Confirmed: SCREEN SHAKE toggle,
  COLOR PALETTE dropdown (CLASSIC), UI SCALE slider at 100%, updated hint text.
- **`palette_classic.png` / `_deutan.png` / `_protan.png` / `_tritan.png`** —
  booted `--estate` with each palette pre-written to prefs.json. The estate
  GROUNDS top bar renders all four `PlayerBadge` shapes (●▲■◆) with palette-
  colored names, and the grounds panel repeats the colored names. Confirmed by
  eye for each: the four seat colors are clearly distinguishable and badges +
  names render. Colors visibly shift per mode — e.g. RED goes vermillion
  (deutan) → dark brick (protan) → clean red (tritan); BLUE deepens to indigo in
  tritan; MINT moves mint → teal → spring-green.
- UI SCALE was additionally verified at 1.3 (pre-written pref): the whole overlay
  scales up ~1.3× and the slider reads 130%, confirming the `content_scale_factor`
  path applies on boot.

## Caveats / notes

- **Applies-to-next-game**: `apply_palette` mutates the shared array live, so
  estate panels (rebuilt per phase) and the next launched game pick it up; a game
  already in progress keeps the palette it launched with. The ACCESS hint says so.
- **Badge fill color**: the estate/HUD `PlayerBadge.make(i, …)` calls don't pass
  an explicit `.color`, so badge *fill* stays the classic palette (its own
  `DEFAULT_COLORS`) while the *shape* is the CVD channel and the *name* label
  carries the active palette color. Wiring badge fill to the palette lives in
  `core/player_badge.gd` / `estate/`, which are out of this task's scope.
- The fresh worktree's asset import cache was stale (`btn_green.png`/font import
  warnings during `--import`); these are non-fatal — the theme and fonts render
  correctly in the actual windowed runs, as the screenshots show.
