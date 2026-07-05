# Kill-Attribution + Dead Weight Style Unification — VERIFY

Scope: `minigames/swap_meet/`, `minigames/dead_weight/`, `docs/verify/` only.
Godot 4.6.2.stable. All commands run from the repo root.

Two independent deliverables:
1. **PART 1 — kill attribution.** Both games now report an optional
   `kill_events: Array of {killer:int, victim:int, cause:String}` in their
   `finished` results (killer `-1` = environment/self). Reporting only —
   gameplay is byte-identical.
2. **PART 2 — style unification (dead_weight only).** The "dark void" arena is
   re-lit and re-surrounded to the house warm-diorama look (mower / greed),
   without touching geometry, gameplay dimensions, or identity accents.

---

## PART 1 — kill_events

### Where the events are appended (the existing KO / royalty paths)

**dead_weight** — `_on_fighter_fell(index)` (fires once per void death, at the
exact spot that already resolves kill credit for royalties/grudges):
- ghost kill (poltergeist furniture) → `{killer: ghost_idx, victim, cause:"furniture"}`
- living boot → `{killer: booter_idx, victim, cause:"shove"}`
- accident / walked off → `{killer:-1, victim, cause:"void"}`

`print("KILL_EVENTS n=", ...)` is emitted at the top of `_finish_match()`
(next to `DW_MATCH_OVER`), and `kill_events` is included in the results dict.

**swap_meet** — the race is non-lethal by design (windmill boom is explicitly
non-lethal; every kart finishes), so the only aggressor-harms-victim event is
the **swap heist**: a thrown orb that moves the thrower up and the victim down
"wrecks" the victim's race. Appended in `_do_swap()` on the exact line that
already credits the thrower's royalty (`who == a and gain >= 1`):
- normal heist → `{killer: thrower, victim: swapped, cause:"kart_wreck"}`
- golden-orb heist (robs the leader) → `cause:"golden_swap"`

`print("KILL_EVENTS n=", ...)` is emitted right after `SWAPMEET_RESULTS`, and
`kill_events` is included in the results dict.

The contract's `Minigame.validate_results()` ignores unknown keys, so
`kill_events` is a clean optional addition (no validation warnings).

### Verification — counts consistent with logged/visible kills

**swap_meet** (all-bot race, seed 11, tick-deterministic `--fast`):
```
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=11 --fast=8 --autoquit
```
- `KILL_EVENTS n=20`. The log shows exactly **20** `SWAP` lines, every one
  with thrower `gain >= 1`. Independent cross-check: the game's own
  `gaining={0:2, 1:6, 2:3, 3:9}` tally sums to **20** = kill_events count.
- The single golden swap (`SWAP ... golden=true` at t=43.3) is tagged
  `cause:"golden_swap"` (killer 0, victim 1); the other 19 are `kart_wreck`.

**swap_meet determinism** — the reporting addition is byte-neutral. Two
identical-seed runs produced **byte-identical** `KILL_EVENTS` lines (n=20,
same order, same killer/victim/cause):
```
run A: KILL_EVENTS n=20 [... killer:3,victim:1 ... golden_swap killer:0,victim:1 ...]
run B: KILL_EVENTS n=20 [... identical ...]
```

**dead_weight** (balance fast-sim, seed 7):
```
godot --headless --path . res://minigames/dead_weight/dead_weight.tscn -- --dwbalance=4 --seed=7
```
- The invariant **`KILL_EVENTS n` == number of `DW_DEATH` lines** holds in
  every run observed, with matching killer/victim/cause. Examples:
  - `n=3` with 3 deaths, all `THE CHAIR (GOLD) CLAIMS …` → 3× `furniture`, killer 2.
  - `n=2` with 2 deaths (`… CLAIMS BLUE` furniture + `BLUE BOOTS RED` shove) →
    `[{furniture,killer:2,victim:1},{shove,killer:1,victim:0}]`.

> Note: `--dwbalance` runs at `Engine.time_scale = 6.0` (fast-forward) and is
> **inherently non-deterministic run-to-run** — the same seed yielded 3, then 2,
> then 2 deaths across runs, because the number of physics ticks per round
> drifts with wall-clock under time-scaling. This is pre-existing behavior (see
> dead_weight/VERIFY.md "headed runs are not frame-identical"), **not** an effect
> of these changes. What is invariant and what matters here is that
> `KILL_EVENTS` always mirrors the `DW_DEATH` log 1:1.

The dead_weight append lives inside `_on_fighter_fell` (only runs on a death
that already happened) and only pushes to an array read at match end — it
cannot alter RNG, physics, or control flow. Byte-identical behavior by
construction.

---

## PART 2 — dead_weight style unification

Target: make dead_weight belong at the same party as `mower` / `greed` — a
warm diorama (warm table/floor surround, warm directional sun with shadows,
soft ambient, filmic tonemap), instead of a cold platform floating in a black
void.

### What changed (all in `_build_stage` / new `_build_surround` / `_build_void_ring`)

| Element | Before (dark void) | After (house warm diorama) |
|---|---|---|
| Background | `BG_COLOR` near-black `(0.05,0.045,0.08)` | `BG_SKY` dark **warm** room gradient (greed-family) |
| Ambient | cool purple `(0.52,0.5,0.62)` @0.85 | warm `(0.55,0.47,0.40)` @0.62 |
| Fill light | **cool blue** `(0.55,0.68,1.0)` | **warm** `(0.92,0.76,0.58)` |
| Sun | warm `(1.0,0.92,0.8)` @1.15, shadows | warm `(1.0,0.93,0.8)` @1.25, shadows (kept) |
| Fog | cold void fog, density 0.02 | removed (house games have none) |
| Surround | none (black) | warm **table** the arena rests on + dark-warm **room floor** (both decorative, no collision) |
| Void gutter | neon **cyan** `(0.2,0.95,1.0)` | warm hazard **amber** `(1.0,0.55,0.16)` — now reads like greed's gold trim while still marking the lethal edge |
| Glow | 0.7 / bloom 0.18 | 0.55 / bloom 0.12 (gentler, house-tuned) |

Calibration note: a first pass flooded the whole frame with mid-brown (flat,
the surround competed with the arena). Comparing against a live `greed` capture
showed the house look is a **bright warm arena popping against a *dark* warm
surround**, so the sky, ambient, and surround materials were darkened so the
lit arena is the hero.

### Untouched (verified by diff + by eye)

- **Geometry / gameplay dimensions**: the 12×12 ±6 floor slab, `VOID_Y`, spawn
  corners, prop layout, camera. The two new meshes (`RoomFloor`, `Table`) are
  bare `MeshInstance3D` with **no `CollisionShape3D` / `StaticBody`** and sit
  BELOW / INSIDE the ±6 lip, so a shoved fighter still falls clear into the drop.
- **Identity accents**: ghost translucency (unshaded alpha orbs + wisps),
  possessed-furniture glow, prop materials, the red rug, player identity rings.
  Confirmed still reading in the after shots (see frame 360: translucent ghost /
  possession over the scrum).

### Commands + screenshots (WINDOWED; read by eye)

```
# before (captured before edits) and after (same seed + same frames)
godot --path . res://minigames/dead_weight/dead_weight.tscn -- --dwbots --dwghosts=2 --seed=3 --shots=170,260,360 --outdir=verify_out/dw_before
godot --path . res://minigames/dead_weight/dead_weight.tscn -- --dwbots --dwghosts=2 --seed=3 --shots=170,260,360 --outdir=verify_out/dw_after
# house reference for calibration
godot --path . res://minigames/greed/greed.tscn -- --greedbots --seed=3 --shots=240 --outdir=verify_out/greed_ref
```

Committed matched pair (frame 260, identical command/seed/frame, only styling
differs):
- `docs/verify/style_dw_before.png` — black void, floating platform, neon-cyan
  gutter, cool-blue rim on the fighters.
- `docs/verify/style_dw_after.png` — warm table/room surround, amber gold-trim
  gutter, warmly-lit fighters and props; the arena is the hero.

### Import pass

```
godot --headless --editor --import --quit --path .
```
Class registration clean (`Minigame`, `DWFighter`, `DWGhost`, `DWProp`). The
only import errors are pre-existing UI-theme/font cache rebuilds
(`btn_green.png`, `Fredoka.ttf`, `theme.tres`) unrelated to these edits, and no
`SCRIPT ERROR` / `Parse Error` from swap_meet.gd or dead_weight.gd in any run.

---

## Contract note

`docs/specs/anthology-module-contract.md` gets the prose `kill_events` schema
from a separate agent; this change implements the field in the two games and
was written to match the described shape
(`{killer:int, victim:int, cause:String}`, killer `-1` = environment/self,
`cause` = short slug).
