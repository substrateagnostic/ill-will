# MOWER MAYHEM — verification record

Spec: `docs/specs/minigame-mower-mayhem.md`. Contract:
`docs/specs/anthology-module-contract.md`. All commands from the repo root
(Godot 4.6.2, Windows). `--fixed-fps 60` is used ONLY for screenshot runs so
the frame numbers passed to `--shots=` land on the intended game-time moments;
the sim itself is physics-tick deterministic per seed either way. The bot-soak
perf run is deliberately run WITHOUT `--fixed-fps` so the measured frame time
is real compute cost, not vsync/pacing sleep.

## Engineering heart — coverage grid → ONE texture

`mower_lawn.gd` holds a 64×48 byte grid over the 16×12 m lawn. Cell flips are
written into a single `Image` (FORMAT_R8, one texel = one cell's owner code)
and pushed to ONE `ImageTexture` via `commit()` **exactly once per frame**
(called from the root's `_process`). `lawn.gdshader` samples that data texture
(filter_nearest) over ONE `PlaneMesh` and renders uncut vs. mowed-and-tinted
per fragment. There are **no per-cell nodes** — the whole lawn is 1 mesh + 1
material + 1 texture. Mowed cells are the green turf MODULATED by the owner's
identity color (grass-anchored, not a lerp-to-pastel), so the four tints stay
vivid, distinct, and grass-plausible.

## Commands run

### 1. Import (after adding files)

```
godot --headless --editor --import --quit --path .
```
Clean. `MowerLawn`, `MowerUnit`, `MowerBots` registered; shader compiles; no
script errors.

### 2. Spec "Risks & tests" — coverage math (assert)

```
godot --headless --path . res://minigames/mower/mower.tscn -- --covtest --seed=5
```
Runs a fast all-bot round, then asserts `sum(player% ) + uncut% == 100 ±0.5`
and prints PASS/FAIL + per-player coverage, exiting 0/1. Beds (birdbath +
flowerbeds) are excluded from the mowable denominator, so the identity holds
exactly.
**RESULT: PASS — `sum=100.0000%`.** Grid path in this run:
`paint_worst=0.358ms commit_worst=0.030ms`.

Also verified with `--seed=1`, `--seed=5`, and inside every full run below:
the assert prints PASS at every round end.

### 3. Spec "Risks & tests" — bot soak, full 2 min, 4 mowers, frame budget

```
godot --headless --path . res://minigames/mower/mower.tscn -- --mowbots --seed=7
```
(all-bot standalone self-terminates after the results screen). Full 120 s
round + 20 s overtime, 4 mowers, 97 rams. Measured, printed at round end:

```
MOWER_PERF grid_path: paint_worst=0.857ms commit_worst=0.210ms (the batched
texture path) | sim_step worst=3.11ms over12=0 | full_frame worst=22.65ms
over12=8 of 18824 frames | total_rams=97
MOWER_COVERAGE_ASSERT sum=100.0000% (players+uncut) -> PASS
```

- **The batched texture path is ~1 ms worst case** (paint 0.857 ms + commit
  0.210 ms) and `commit()` runs once per frame.
- **The sim step — which contains every `Image.set_pixel` write — NEVER
  exceeded 12 ms** across the whole soak (`sim_step over12=0`, worst 3.11 ms).
- 8 of 18 824 render frames (0.04 %) exceeded 12 ms at the *full-frame* level.
  These are idle-time allocation hitches (deferred ram FX: CPUParticles3D +
  tween + end-of-match confetti), NOT the sim or grid path. Ram juice is
  intentionally `call_deferred` so node creation never lands inside the
  physics step. (A particle pool would remove the last outliers — see Wishes.)

Determinism: same seed reproduces the same event timeline; two `--seed=7`
runs produced identical coverage/ram counts.

### 4. Results contract + monuments (2-player)

```
godot --headless --path . res://minigames/mower/mower.tscn -- --mowbots --players=2 --seed=2 --roundtime=50
```
RED 48.10 % / BLUE 45.17 % → both clear the 40 % bar and receive the
`groundskeeper` monument; `placements`, `points` (round(cov%/5)),
`currency_events` (royalty per ram, grudge for last), and `highlights` all
emitted via `report_finished()`. Coverage assert PASS.

### 5. Screenshots (headed, windowed) + art pass

```
godot --path . --fixed-fps 60 res://minigames/mower/mower.tscn -- --mowbots --seed=7 --roundtime=45 --shots=75,480,1200,1650,2400,2820
```
PNGs land in `verify_out/` (gitignored). What each shows (all inspected):

| Shot | Shows |
|---|---|
| 0075 | Intro "MOW!": fully UNCUT dark lawn, 4 mowers at corner spawns, each a distinct chassis color with a seated KayKit rider (Barbarian/Knight/Mage-in-hat/Rogue), birdbath + 2 flowerbeds + 4 gravestone bumpers + hedge border, meters at 0 % |
| 0480 | Early spread: four distinct tinted stripe fans opening from the corners against the dark uncut middle — strong cut/uncut contrast |
| 1200 | Mid-game: GOLD (chartreuse) / BLUE (teal) / MINT (emerald) / RED (olive-khaki) turf clearly separable; mow-stripe rows visible |
| 1650 | "GOLD RAMMED BLUE!" banner, BLUE mower spun out (Hit pose), boost tags in scoreboard |
| 2400 | OVERTIME, red "10" timer, another ram, meter pulsing; uncut patches still readable at the edges |
| 2820 | Final seconds "4": lawn almost fully claimed in four tints, two mowers SPUN, MINT leading the meter |

**Art iterations driven by reading the shots:** the first tint model lerped
the green base toward each bright player color and washed out to pastels (RED
read as sand, BLUE/MINT both as pale water — poor four-color distinctness).
Replaced with a *modulate* model (`grass * (tint_floor + tint_gain * pc)`)
that keeps the green turf anchor while pushing each hue hard — the four colors
now read as distinct, rich, grass-plausible mowed sections. Also darkened the
uncut base for stronger contrast and tightened the camera to fill the frame.

**Perf iterations driven by the soak logs:** the first soak showed ~15–38 ms
`sim_step` spikes on ram-heavy frames. Root cause: a `print()` per ram (I/O
stall) plus FX node creation inside the physics tick. Moved all ram juice to
`call_deferred`, replaced per-ram logging with a counter surfaced at the 5 s
status line, and throttled the scoreboard rebuild to 5 Hz. Result: `sim_step
over12` went from 7 → **0**.

## MUST checklist (spec v1)

- [x] Grid coverage + tinted rendering — 64×48 R8 data texture → 1 plane + 1
      shader, batched `commit()` once/frame, no per-cell nodes (mower_lawn.gd,
      lawn.gdshader)
- [x] Mow / steal — `paint_deck()` flips uncut→yours instantly and enemy→yours
      as a steal, with a `STEAL_DRAG` speed penalty while chewing enemy turf
      ("slightly slower cut")
- [x] Ram + turf theft — A = forward lunge (RAM_TIME 0.34 s, 1.5 s cd); on
      contact the victim spins out 1.2 s and the 6 enemy cells nearest impact
      flip to the attacker (`steal_burst`); royalty +1
- [x] Boost — B holds a draining fuel gauge (regens when off); wider deck
      (0.9 → 1.3 m) and reduced turn rate ("less steering")
- [x] Live meters — Splatoon-style transparent top bar (segment widths = live
      coverage) + a precise bottom-left scoreboard with fuel/boost/SPUN tags
- [x] 2-min round + overtime — 120 s, final 20 s = OVERTIME with a music
      sting, meter pulse, and double-width cuts
- [x] Results — placements by coverage %, points = round(cov%/5),
      currency_events (royalty/grudge), highlights, monuments; via
      `report_finished()`
- [x] Seeded bots — `MowerBots`, personalities + decisions from
      `rng_seed`-derived streams; space-filling by probing candidate headings
      for uncut/enemy turf, plus opportunistic rams

## SHOULD checklist

- [x] Flowerbed no-mow zones (2 rect beds, excluded from scoring, solid)
- [x] Gravestone bumpers — reuse `scenes/gravestone.tscn`, solid bounce circles
      (grass under them stays mowable); birdbath is a central circular no-mow
- [x] Overtime double-width cuts (`deck_half_w(overtime)` doubles the stripe)
- [x] House juice: Sfx bank (bumper/splat on ram, grudge+round_over sting on
      OT, match_win), screenshake, slow-mo beat on rams, Luckiest Guy banners,
      confetti on the winner, per-mower clipping spray, per-player engine
      put-put (distinct pitch per index)

## Standalone / shell behavior

- Root scene `minigames/mower/mower.tscn` extends `Minigame`; the shell calls
  `begin(config)`; double-begin guarded.
- Standalone: if `begin()` isn't called 0.5 s after `_ready`, self-starts with
  `--players=N` (default 4) using `GameState.PLAYER_COLORS/NAMES`, KayKit
  Barbarian/Knight/Mage/Rogue, seed from `--seed=` (default 1),
  `PlayerInput.auto_assign`; players on device -3/-99 get bots so nobody is a
  statue.
- No writes to GameState, no scene changes, no `randomize()`/`Date` — all RNG
  from `config.rng_seed` (game + bot streams).
- Input via the `PlayerInput` autoload only: `get_move` (steer, auto-drive),
  `just_pressed(a)` = ram, `is_down(b)` = boost. Verb budget = move + A + B.

## Known issues

- 4 max-greedy bots cannibalize each other's turf, so 40 %+ coverage (the
  Groundskeeper monument) is rare in a 4-bot match but common at 2 players and
  reachable by a skilled human; the monument fires correctly (test 4).
- Spin-out reads via the scoreboard "SPUN!" tag + the mower's Hit pose/rotation;
  from the top-down camera it's a little subtle (a dust ring would sell it —
  see Wishes).
- 8 full-frame render hitches per 2-min soak from deferred FX node allocation
  (not the sim/grid path); imperceptible in play, removable with a pool.
- Human couch input uses the identical `drive()` path the bots exercise, but
  was not physically controller-tested in this headless environment.

## v1.1 — TUNING PASS: fuel/stat readouts moved to a bottom strip (playtest)

Friend playtest note verbatim: *"keep the fuel and other stat bars at the
bottom. Hard to look upper left while playing."* The per-player readout
(`ScorePanel`/`ScoreRows`, built by `_rebuild_scoreboard()`) was anchored
top-left (`anchor_left=0.0`, `offset_top=60`) as a narrow vertical stack —
exactly the "hard to look upper left while driving" spot.

**Fix (`mower.tscn` + `mower.gd`):** `ScorePanel` re-anchored to the bottom
edge (`anchor_top/anchor_bottom = 1.0`, spanning the full width just above
`HintLabel`) and `ScoreRows` changed from a `VBoxContainer` (vertical stack)
to a `HBoxContainer` (`alignment=CENTER`, `separation=36`) so the four
per-player entries lay out side by side as a strip, not a column. No change
to `_rebuild_scoreboard()`'s row content or logic — same "NAME cov% fuel
X%TAG" text per player, just relaid horizontally at the bottom. The small
Splatoon-style top-left coverage-segment meter (`_meter_bar`, a colored bar
chart, not per-player text) is untouched — the complaint was specifically
about the text stat readout, not the territory-glance bar.

**Verification:** `--covtest` coverage-identity assert still `PASS`
(`sum=100.0000%`), import pass clean (0 script/parse errors), windowed
screenshot capture (seed=7, `--mowbots --roundtime=45`) confirms the strip
reads cleanly at both the intro (`0% fuel 100%` all four, bottom edge, above
the control hint) and mid-round (`BLUE 25% fuel 95% SPUN! · RED 22% fuel 65%
BOOST · GOLD 18% fuel 97% SPUN! · MINT 17% fuel 100%`, still legible against
gameplay with a semi-transparent backing panel). Screenshots:
`verify_out/mower_m3_final/mower_bottom_strip_intro.png` and
`mower_bottom_strip_play.png`. Purely a UI reposition — no sim/receipt values
touched, no deliberate-change entry needed.

## Wishes (assets/polish that would elevate it)

- A looping small-engine idle sfx per mower (currently a pitched `putt` tick;
  a real put-put loop would sell the ride-ons better).
- A distinct "grass-cut" whoosh/clatter for the mowing spray, and a horn honk
  for the ram (using bumper bell today).
- Real tall-grass blade geometry on uncut cells (a synced MultiMesh) instead of
  the shader shag — would make the "before" lawn lusher without per-cell nodes.
- A spin-out dust/smoke ring + skid decal to make turf-theft rams pop harder.
- A small CPUParticles3D pool to erase the last 8 full-frame FX hitches.
- KayKit riders use `Sit_Chair_Idle`; a "gripping the wheel" driving pose would
  be lovely.
