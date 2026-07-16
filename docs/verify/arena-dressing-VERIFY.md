# ARENA DRESSING (B8) — verification record

Wave B8 of night 5 (`docs/design/23-directors-plan-night5-2026-07-16.md`):
horizon silhouettes + estate dressing for the anthology's plainest minigame
arenas, built from the forged Meshy props in `assets/models/meshy/generated/`
(+ the earlier `assets/models/meshy/` wave — columns, lanterns).

## Survey

Read every `minigames/*/`'s world-build code and cross-checked against
`docs/verify/*_netshots_*` / existing screenshots. 10 of 14 games are already
dressed and/or fully enclosed (walled rooms, curtained stages, or a
diorama-on-a-table surround like `dead_weight`/`echo_chamber`) — no horizon
is ever visible from their fixed cameras, so B8 would add nothing. `orbital`
and `echo_chamber` are also mid-edit by lane B6 (elimination-game logic);
skipped per the director's conflict-avoidance note. `last_will` and
`pallbearers` are the house's own reference examples of this exact pattern
already done well (box-built gravestones/lanterns + `MeshyProp` gate/column,
`last_will`; deterministic `grave_*`/`estate_*` scatter, `pallbearers`).

**Four arenas were genuinely plain** — flat floor/void, nothing beyond the
play surface, confirmed via before-screenshots:

| Game | Was | Now |
|---|---|---|
| `minigames/tilt/` | platter floating in a flat dark void (no shoreline at all) | 5 rock skerries carrying a mausoleum front, dead trees, headstones, obelisk, one lit lamppost — a coastline glimpsed across the night sea |
| `minigames/greed/` | gold-rimmed vault slab floating in pure black | 4 broken columns + an iron gate flanked by 2 dim stone lanterns — an old antechamber past the money-room walls |
| `minigames/mower/` | lawn behind low hedges, nothing past them | headstones, dead trees, obelisk and 2 lit lampposts just past the hedge line, on-brand with the gravestone bumpers already reused inside |
| `minigames/swap_meet/` | night-market track ending at a bare brown table rim | a lamppost ring, a market gate and 2 hedges on the existing grass apron between the track and the table edge |

## Shared helper

`scripts/arena_dressing.gd` (`class_name ArenaDressing`) — a thin, reused
wrapper matching the house's `MeshyProp`/`EnvKit` convention:
- `ArenaDressing.prop(parent, id, height, pos, yaw_deg, light)` — one forged
  prop by manifest id, checking both `assets/models/meshy/generated/` (wave 2)
  and `assets/models/meshy/` (wave 1, e.g. `broken_column`/`stone_lantern`),
  scaled/seated via `MeshyProp`, optional dim `OmniLight3D`.
- `ArenaDressing.mound(parent, pos, top_r, bottom_r, height, color)` — a cheap
  dark unshaded silhouette shape to ground floating dressing (tilt's rock
  skerries) without adding a second textured mesh per cluster.

## Camera-frustum correction (the one real bug caught by verification)

First pass placed dressing at "clearly past the play bounds" radii chosen by
eyeball (e.g. tilt r=33-37). Screenshots before vs. after were **pixel-
identical** in the background — nothing rendered. Root cause: every one of
these games uses a fixed, steeply-pitched camera, and ground-plane points
either climb above the top of frame past a certain distance in the "away"
direction, or drop below the bottom of frame almost immediately on the
"near" (same-side-as-camera) arc. Derived each camera's actual forward/up
basis and the resulting depth-vs-up screen bounds, then re-picked every
position to land inside the verified visible frustum (see the doc-comments
above each `_build_b8_*` function for the numbers). Re-screenshotted; the
dressing is now clearly visible in all four (see Screenshots below). A
`greed.gd` typo caught in the same pass: `Vector3(1, 1)` (2-arg, invalid) —
fixed to `Vector2(1, 1)` for the corner-sign iterator.

## Regression evidence (byte-identical before -> after)

Import (`godot --headless --editor --import --quit --path .`): clean, no
`SCRIPT ERROR`/`Parse Error`, both before the dressing and after (three
passes — the fresh-worktree cosmetics-jpg transient errors self-healed by
pass 3, as expected).

| Game | Command | Before | After |
|---|---|---|---|
| tilt | `--tilttest=idle --seed=1` | PASS | PASS |
| tilt | `--tilttest=edge --seed=1` | PASS, off at t=0.83s | PASS, off at t=0.83s |
| mower | `--covtest --seed=5` | `sum=100.0000% -> PASS` | `sum=100.0000% -> PASS` |
| greed | `--greedtest=intercept --seed=1` | `catches=64 rate=0.80 PASS` | `catches=64 rate=0.80 PASS` |
| swap_meet | `--swapbots --seed=1 --fast=8 --autoquit` | `race_t=48.1s swaps=20 PASS` | `race_t=48.1s swaps=20 PASS` |

All four commands are exact copies of the "commands run" already documented
in each game's own `VERIFY.md`. No sim/RNG/physics/collision was touched —
every added node is a plain `MeshInstance3D`/`MeshyProp` wrapper or a dim
`OmniLight3D`, parented directly under the game root, outside all play
bounds, with zero per-frame processing.

## Screenshots

Before: `verify_out/b8_before/tilt_shots/`, `mower_shots/`, `greed_shots/`,
`swap_shots/`. After (same seeds/frames): `verify_out/b8_after/tilt_shots/`,
`mower_shots/`, `greed_shots/`, `swap_shots/`. Full regression logs alongside
in `verify_out/b8_before/*.log` and `verify_out/b8_after/*.log`.

## Not dressed (and why)

`dead_weight`, `greed`'s siblings `throne`/`seance`/`understudy`/
`widows_gaze`/`masked_ball` are fully enclosed (walls/curtains/backdrop) —
no horizon is ever in frame. `last_will`/`pallbearers` already carry this
exact treatment. `echo_chamber`/`orbital` skipped — concurrent B6 edits, and
`orbital`'s space setting doesn't take estate dressing anyway.
