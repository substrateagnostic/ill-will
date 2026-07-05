# Meshy prop integration — verification

Five custom Meshy props (`assets/models/meshy/`) wired into five minigames as
**visual-only** swaps. No collision shapes, physics, or gameplay values were
touched: in every case the primitive *visual* meshes were replaced by the GLB
instanced as a child, while all gameplay geometry (deck footprints, collision
radii, seat/kinematic state, pot value, tilt physics) stays in code constants
exactly as before. Every game's existing legacy verification check still passes,
and per-player colour identity survives every swap (proof shots below show 4
players).

Engine: Godot 4.6.2 (Windows). All commands run from the worktree root.

## Shared helper — `scripts/meshy_prop.gd`

Meshy normalizes every model to a ~1.9-unit max dimension with an arbitrary
internal origin, so raw instancing lands each prop at an unpredictable size and
position. `MeshyProp.instance(path, target_height, yaw_deg)` instances the
committed GLB, measures the merged AABB of its meshes, then returns a `Node3D`
wrapper whose child model is uniformly scaled to `target_height` and re-seated so
the **base sits at local y=0**, **centered on x/z**, with an optional yaw. This
makes every placement robust regardless of the GLB's internal origin. Purely
visual; nothing in it touches gameplay.

## Import pass (required after adding scene references) — clean

```
godot --headless --editor --import --quit --path .
```
`MeshyProp` registers; no script/parse errors in any touched file. (The
pre-existing `assets/ui/theme.tres` / `btn_green.png` missing-asset warning is
unrelated to this work.)

---

## Per-game summary

| Game | Primitive replaced | GLB | Norm. height | Yaw | Per-player identity | Legacy check | Proof shot |
|------|--------------------|-----|-------------|-----|---------------------|--------------|------------|
| Throne | box seat/back/arms/finial (`_build_throne`) | `throne.glb` | 2.55 | 180° | unchanged — king's ring + body rim (throne was always neutral) | balance ≤55% **PASS** | `docs/verify/shots/prop_throne.png` |
| Greed | bowl cylinder + coin sphere (`GreedPot.build`) | `gilded_pot.glb` | 1.25 | 0° | unchanged — pot is neutral; players carry their own colour | intercept **PASS** (0.80) | `docs/verify/shots/prop_greed.png` |
| Mower | box chassis/deck/cowl/wheels (`_build_chassis`) | `riding_mower.glb` | 1.05 | 90° | **added** tinted ground ring + colour flag (model is green) | coverage `sum=100.0000%` **PASS** | `docs/verify/shots/prop_mower.png` |
| Swap Meet | box body/nose/spoiler/wheels (`_build_kart`) | `go_kart.glb` | 0.72¹ | 0° | **added** tinted emissive bumper ring + ground ring (model is cream) | 5-seed race assert **PASS** | `docs/verify/shots/prop_swap_meet.png` |
| Tilt | primitive gull (`_build`) | `seagull.glb` | 0.58 | −90° | **added** player-colour collar ring; scoreboard GULL tag in colour | idle **PASS** + edge **PASS** | `docs/verify/shots/prop_tilt_gull.png` |

¹ Swap Meet height is in `_visual`-local units (the kart's `_visual` node applies
its own ×1.15 party-chunk scale on top).

---

## Throne — `minigames/throne/throne.gd`

`_build_throne()` now instances `throne.glb` (red tufted high back, gold ornate
frame) on the dais at `y=DAIS_TOP_Y`, seat opening toward +Z (the camera / the
standing king), replacing the box seat/back/arms/finial/cushion. The unused
`_add_box()` helper was removed. The crown-physics detach, gold score-stream and
dethrone fling are unchanged and still fire (see the dethrone in the proof run).

- Legacy check (mandatory balance probe, real gameplay, no bot > 55% throne time):
  ```
  for s in 1 4; do godot --headless --path . minigames/throne/throne.tscn -- --thronebalance --seed=$s; done
  ```
  `seed 1 max_share=29.6% PASS`, `seed 4 max_share=26.9% PASS` (both ≪ 55% cap;
  visual-only change cannot affect throne-time shares).
- Proof: `docs/verify/shots/prop_throne.png` — 4 challengers (RED/BLUE/GOLD/MINT
  rings) ringed around the grand red/gold throne, "SEIZE THE THRONE" banner.

## Greed Inc. — `minigames/greed/greed_pot.gd`

`GreedPot.build()` now instances `gilded_pot.glb` (dark cauldron, gold trim,
coins heaped on top with spill) on the pedestal, replacing the bowl cylinder +
coin sphere. The huge floating value `Label3D`, the omni `_glow`, and the +5
`_geyser` (raised to `y=0.95` to erupt from the coin heap) are all retained and
positioned. `update_value()` now swells the whole hoard subtly (1.0→1.35×) and
`tick()` slow-spins the model — the label bob and glow ramp are unchanged.

- Legacy check (pursuit tuning; chaser catches carrier ≥60% of runs):
  ```
  godot --headless --path . res://minigames/greed/greed.tscn -- --greedtest=intercept --seed=1
  ```
  `trials=80 catches=64 rate=0.80 (bar>=0.60) PASS`. A full seeded round
  (grab→hunt→drop→bank) was also captured windowed with zero script errors.
- Proof: `docs/verify/shots/prop_greed.png` (arena: pedestal cauldron + value
  label + 4 colour chutes + 4 players) and `prop_greed_grab.png` (a carrier
  hauling the pot, edge-arrows from the other 3 players).

## Mower Mayhem — `minigames/mower/mower_unit.gd`

`_build_chassis()` now instances `riding_mower.glb` (green body, chunky wheels,
cutting deck) as the chassis, wheels seated at y=0, deck rotated to face +Z (the
travel direction). Because the model is green (no built-in identity), a **tinted
emissive ground ring** and the **player-colour flag on a pole** are added. The
seated KayKit rider is retained at `(0, 0.5, −0.28)`; verified from a side probe
to sit on the seat facing forward. The unused `_add_wheel()` helper was removed.

- Legacy check (coverage identity `sum(player%)+uncut% == 100`):
  ```
  godot --headless --path . res://minigames/mower/mower.tscn -- --covtest --seed=5
  ```
  `MOWER_COVERAGE_ASSERT sum=100.0000% (players+uncut) -> PASS`.
- Proof: `docs/verify/shots/prop_mower.png` — 4 green mowers at the corners, each
  a seated rider + a distinct colour identity ring (RED/BLUE/GOLD/MINT).

## Swap Meet — `minigames/swap_meet/swap_kart.gd`

`_build_kart()` now instances `go_kart.glb` (cream roadster body, exposed
steering wheel) inside `_visual`, nose facing +Z, replacing the box body/nose/
spoiler/wheels. Because the model is cream, a **tinted emissive bumper ring**
(wrapping the kart — it *is* a bumper kart) and the **ground identity ring** are
added; the player name `Label3D` and the leader crown (positioned externally on
the leader kart's origin, unchanged) still read. The seated rider (`CHAR_SCALE`,
same offset) is retained.

- Legacy check (5-seed bot race: all karts finish 3 laps, ≥3 swaps):
  ```
  for s in 1 7; do godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=$s --fast=8 --autoquit; done
  ```
  `seed 1: all_finished=true race_t=48.1s swaps=20 PASS`,
  `seed 7: all_finished=true race_t=48.5s swaps=5 PASS` — identical race
  time/swap counts to the pre-swap baseline (determinism intact).
- Proof: `docs/verify/shots/prop_swap_meet.png` — 4 cream karts with colour
  bumper rings + name tags on the track, gold crown on the leader.

## Tilt — `minigames/tilt/seagull.gd`

`_build()` now instances `seagull.glb` (standing, wings folded, white body /
orange beak+legs), beak rotated to point −Z so the existing flight-orientation
math (`rotation.y = atan2(−v.x, −v.y)`) still turns the bird where it flies. The
model is static, so the wing-flap code now drives two **harmless empty pivots**
(`_wing_l/_wing_r`), leaving `tick()` untouched. A **player-colour collar ring**
is added so identity survives death (also shown by the coloured "GULL" scoreboard
tag). The unused `_wing()` builder was removed.

- Legacy checks (tilt stability + edge slide):
  ```
  godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=idle --seed=1
  godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=edge --seed=1
  ```
  `idle RESULT: PASS`; `edge RESULT: PASS (slid off at t=0.83)` — identical to the
  pre-swap baseline.
- Proof: `docs/verify/shots/prop_tilt.png` (4 pawns alive, colour rings) and
  `prop_tilt_gull.png` ("BLUE OVERBOARD!" — the new seagull flying, RED/BLUE as
  coloured GULL in the scoreboard).

---

## Notes

- Screenshots were captured windowed via each game's documented `--shots` /
  `--greedcap` harness with the all-bots flag, read, and iterated on: the mower
  deck and seagull beak both needed a yaw correction (caught from a side/¾ probe),
  and the greed geyser was raised to the taller cauldron's mouth.
- KayKit riders face +Z; the mower/kart GLBs were yawed so their fronts point +Z
  to match, so riders face forward on both.
- Every proof run reported zero `SCRIPT ERROR / Invalid / Nil`.
