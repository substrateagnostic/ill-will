# Visual polish pass — verification

Phase 2 of the art-director sweep (audit: `docs/design/07-visual-polish-audit.md`).
Eight Meshy generations (the hard cap) + two free reuses of already-committed
GLBs closed the top-ranked JARRING findings. **Every swap is visual-only**: no
collision shape, mass, trap timing, hit constant, spawn point or physics value
changed — verified by diffing behavior harnesses against pre-change baselines
captured from the same worktree via `git stash` (identical seeds, same machine).

Engine: Godot 4.6.2 (Windows), windowed captures read by eye.
Import pass after adding the GLBs: clean (no script/parse errors).

## New assets (all preview -> refine, model `meshy-5`, art_style `realistic`,
## style direction in-prompt: "low poly, chunky toy-like proportions, flat
## colors, game asset, clean silhouette, Kenney KayKit style")

| Asset | For | Preview task | Refine task |
|---|---|---|---|
| `crate.glb` | Dead Weight CRATE + Greed vaults | `019f3573-cb38-7500-a378-036301c17598` | `019f3575-afc4-73db-ba79-c9326e5de51e` |
| `armchair.glb` | Dead Weight CHAIR | `019f3573-cb37-733f-8add-34504b983d2b` | `019f3574-c0f7-7379-9e58-301801bafad3` |
| `crusher_head.glb` | Par crusher hammer | `019f3573-cb3a-7504-953d-4a629cccb3b3` | `019f3575-20b3-7551-900d-9552bd495425` |
| `spinner_arms.glb` | Par spinner cross | `019f3573-cb3a-7145-a6c2-53eb5d174828` | `019f3574-901c-736b-afb2-97ac87c15370` |
| `pendulum_blade.glb` | Last Will pendulum | `019f3573-cb3b-7506-9896-5ebd81d0ddea` | `019f3574-61aa-7360-b35e-574e4e5c1d4e` |
| `market_stall.glb` | Estate market stall | `019f3573-cb3a-7503-90bf-895012020987` | `019f3575-52a7-7180-bc9e-96810d36b62f` |
| `broken_column.glb` | Echo Chamber pillars | `019f3573-cb38-7502-ab4e-31d906f69509` | `019f3575-7fd2-7563-a12c-947ea91b2e00` |
| `pedestal_fan.glb` | Par fan | `019f3573-cb3b-739e-b4fb-9318536a8e31` | `019f3574-60b4-735f-a575-406446366a0d` |

Probe (`tools/asset_probe.tscn`, auto-discovers GLBs): all 8 render clean, AABBs
recorded — see `docs/verify/shots/polish_probe_new_assets1.png` / `..._2.png`.
Free reuses: `wardrobe.glb` (Dead Weight WARDROBE), `table_lamp.glb` (LAMP).

---

## Per-swap evidence

Before shots are the Phase 1 audit captures (`polish_audit_*.png`); after shots
are `polish_*_after.png`, same harness + seed wherever the game is deterministic.

### 1+2. Dead Weight — all four possessable props (`minigames/dead_weight/prop.gd`)

`_tier_mesh()` primitives replaced by `_build_visual()`: MeshyProp-normalized
GLB per tier (wardrobe/table_lamp/crate/armchair), height = exact collider
height, re-centered on the body origin like the old centered primitive, and the
visual footprint clamped per-axis to (a hair over) the collider so what you see
is what slams you. Possession glow/dent now drive duplicated per-surface
materials (emission + albedo lerp) — same constants, same wobble, colliders,
masses and kill logic untouched. Primitive fallback kept if an asset is missing.

- Before: `polish_audit_dead_weight.png` (bare boxes/cylinder)
- After: `polish_dw_after.png` (wardrobe, X-braced crates, red-cushion chairs,
  lamps) and `polish_dw_after_possessed.png` (possessed crate glowing GOLD and
  hunting — the emissive overlay reads exactly like the old glow)
- Behavior: `--dwbalance=20 --seed=1` → `LIVING WIN % = 65.0%` — **identical to
  the documented pre-swap table** in `minigames/dead_weight/VERIFY.md` (target
  55–75%). Note: single `--dwbots` runs are not run-deterministic even on
  unchanged code (verified: two pre-change baseline runs with the same seed
  diverge), so the aggregate balance harness is the meaningful check. Zero
  script errors.

### 3. Greed Inc. — vault crates (`minigames/greed/greed.gd::_build_crates`)

Box mesh → `crate.glb` at the exact 0.95 footprint (per-axis clamp), fixed
varied yaws so the four vaults don't read as clones. StaticBody + BoxShape
untouched.

- Before: `polish_audit_greed.png` — After: `polish_greed_after.png`
- Behavior: `--greedtest=intercept --seed=1` →
  `trials=80 catches=64 rate=0.80 (bar>=0.60) PASS` — **byte-identical** to the
  pre-change baseline run and to the documented value.

### 4. Echo Chamber — cover pillars (`minigames/echo_chamber/echo_chamber.gd::_spawn_pillars`)

Cylinder mesh → `broken_column.glb` stretched to the 3.0 collider height and
squeezed x/z to the 0.45-radius collider footprint; varied yaws. Colliders
untouched.

- Before: `polish_audit_echo.png` — After: `polish_echo_after.png` (white
  fluted ruin stubs — the arena finally has a place)
- Behavior: `--echobots --echofast=8 --seed=1` — round structure, ghost counts
  and scores identical to baseline; only real-time jitter differs (round-start
  frame ±2, headless perf line). Zero script errors.

### 5. Last Will — the pendulum (`minigames/last_will/lw_pendulum.gd`)

Chain/plank/slats/edge boxes → `pendulum_blade.glb` (metal shaft + crescent
blade) hung from the same pivot, blade stretched on local X to fill the exact
lethal span the hit constants imply (`HIT_ALONG` 1.7 → 3.4 wide). Swing math,
hit detection, telegraph strip, retract: untouched (`_finish_setup()` shared
tail). Primitive fallback kept.

- Before: `polish_audit_last_will_pendulum.png` — After:
  `polish_lw_pendulum_after.png` (mid-sweep via `--willskip=11`, dark scythe
  silhouette over the red strip)
- Behavior: `--willtally --seed=1` — all tally lines identical to baseline
  except timing jitter of ±0.1s on round-start stamps. Zero script errors.

### 6. Par — crusher (`scripts/traps/crusher_trap.gd`)

`_ready()` hides `HammerMesh` and parents a MeshyProp `crusher_head.glb` to the
Hammer body, stretched to **exactly** the 0.85 × 0.55 × 0.85 hammer collider
(probe-verified: 0.850 × 0.55 × 0.850 after scale). Pad, pillar, author
AccentBand, slam timing and kill zone untouched.

- Before: `polish_audit_par_crusher_fans.png` — After:
  `polish_par_crusher_after.png` (mid-slam in-game) and
  `polish_crusher_closeup.png` (isolated stage: head raised, seated, aligned)
- Behavior: forced-trap bot run (seed 2) — game output identical; only the
  autobuild scheduler's frame indices differ (real-time scheduling noise also
  present between two unchanged-code runs).

### 7. Par — spinner (`scripts/traps/spinner_trap.gd`)

`_ready()` hides the two box arms and parents `spinner_arms.glb` (flat 4-arm
wooden cross, arms axis-aligned with the two crossed colliders) to the
AnimatableBody, span scaled to the exact 2.0 arm footprint, flattened ≤0.42.
Spin, colliders and AccentHub untouched.

- Before: `polish_audit_par_spinner.png` — After: `polish_par_spinner_after.png`
- Behavior: forced-trap bot run (seed 2) — **byte-identical log** to baseline.

### 8. Par — fan (`scripts/traps/fan_trap.gd`)

`_ready()` hides the bare pole/disc and stands `pedestal_fan.glb` (caged fan)
at the pole position facing -Z (the wind). Wind zone, push force, pole
collision untouched.

- Before: `polish_audit_par_crusher_fans.png` (yellow pad + bare pole read) —
  After: `polish_par_fan_after.png` (four caged fans + translucent wind lanes)
- Behavior: forced-trap bot run (seed 2) — identical modulo scheduler frame
  indices (as crusher).

### 9. Estate — market stall (`estate/estate.tscn` only; estate.gd untouched)

The two CSG boxes (`Stall`, `StallRoof`) replaced by one `market_stall.glb`
instance with a baked transform (AABB measured offline: scale 1.2575 → height
1.5, base seated at y=0, same 30° yaw and position; the stall never had
collision). The gilded pot still fronts it.

- Before: `polish_audit_estate_stroll.png` — After:
  `polish_estate_stall_after.png` (striped-canopy vendor stall)
- Behavior: full bot night (`--estate --estatebots --mockonly`, windowed)
  completes GROUNDS → AUCTION → games → **READING OF THE WILL** (event snap
  fired at frame 4593 vs 4601 in the audit run) with zero script errors;
  `--strolltest` and title boot clean.

---

## user:// hygiene

`estate_save.json` / `cosmetics.json` / `party_setup.json` / `prefs.json` were
backed up (MD5s recorded) before any run; bot-night runs rewrite
`estate_save.json`, so the originals were restored and hash-verified after the
final run. `--wardrobetest` self-restores (verified "saves restored" in its log).

## Meshy budget

8 generations used / 8 cap. 0 failures, 0 retries.
