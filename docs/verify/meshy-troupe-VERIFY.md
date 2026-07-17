# MESHY TROUPE — wave-2 forge verification (night 5)

10-prop extension of the 32-prop forge (see `meshy-forge-VERIFY.md` for the
pipeline, house-style suffix, and probe tool). Model **`meshy-6`**, preview →
refine, PBR off, `tools/meshy_forge.ps1` against `tools/meshy_manifest.json`
(troupe entries appended at END). Full task-id/credit record:
`tools/meshy_forge_report.json` (42 items + 7 `retired_generations`).

## Round 1 (10 props, 300cr, 0 API failures)

7 contact-sheet KEEPs landed in the batch-1 commit: `npc_mourner_elderly`,
`npc_groundskeeper`, `npc_crow_perched`, `board_hearse_ornate`,
`board_carry_coffin`, `board_funeral_wreath`, `monument_obelisk_small`. THE EXECUTOR and LANTERN POST briefs were satisfied
by already-shipped assets (`executor_butler.glb`, `estate_lamppost.glb`) —
60cr saved.

## Round 2 — re-rolls of the 3 rejects (90cr)

Audition sheet: `docs/verify/shots/meshy_troupe_rerolls.png`
(probe: `godot --path . tools/asset_probe.tscn -- --dir=res://assets/models/meshy/generated/
--only=npc_mourner_hooded,npc_crow_flapping,relic_funerary_urn --shots=60,140,220
--outdir=verify_out/troupe_rerolls`).

| Prop | Round-1 complaint | Round-2 verdict |
|---|---|---|
| `npc_mourner_hooded` | bare shins — robe must sweep the floor | **KEEP** — robe sweeps the floor, hands clasped |
| `relic_funerary_urn` | tureen proportions, wider than tall | **KEEP** — taller than wide, lidded classical urn |
| `npc_crow_flapping` | wings read as a flat glider, wanted mid-downstroke V | **KEEP (with note)** — converged to a second standing pose (raised head, long tail) rather than a flight pose. Retained as a second GALLERY silhouette variant, not a flight actor. Do not use for airborne moments. |

## Rigging + animation trial (8cr)

`executor_butler.glb` → Meshy `/openapi/rigging` (humanoid auto-rig,
height 1.9 m) → `/openapi/animation` preset **Idle** (action_id 0) →
`assets/models/meshy/executor_butler_idle.glb`. Task ids + credits:
`tools/meshy_rig_trial_report.json`; harness: `tools/meshy_rig_trial.ps1`.

Receipt (probe `--animate`, new additive flag in `tools/asset_probe.gd`):

```
PROBE_ANIM executor_butler_idle.glb playing 'Armature|Idle|baselayer' (4.03s)
```

Shot: `docs/verify/shots/meshy_rig_trial_idle.png` — butler renders correctly
human-sized mid-gesture beside the 1.8 m REF capsule.

**⚠ SCALE CAVEAT for integrators:** the rigged GLB's static mesh AABB reads
`(0.01, 0.02, 0.01)` — the armature applies ~×100 scale at runtime. Never
size this model from a merged mesh AABB (`MeshyProp`-style target-height
scaling will explode it). Place it at native scale, or key off a known
constant height (1.9 m).

## Credits (wave 2)

| Run | Credits |
|---|---|
| Round 1 (10 props) | 300 |
| Round 2 (3 re-rolls) | 90 |
| Rig + idle trial | 8 |
| **Wave-2 total** | **398** |

---

# RIGGING WAVE (night 5, lane E3) — the troupe gets real bones

Generalized the one-shot trial into a resumable, manifest-driven wave:
`tools/meshy_rig_wave.ps1` → `tools/meshy_rig_wave_report.json` (task ids,
credits, native heights). Same proven auth/poll pattern as the trial; one model
at a time, incremental report save per model, a single FAILED animation is
logged and skipped rather than aborting the run.

## Animation-library findings

The preset catalog is a **public** JSON endpoint (no auth):
`GET https://api.meshy.ai/web/public/animations/resources` → `result.list`
(**680** entries; fields `id` = action_id, `name`, `key`, `category`,
`subCategory`, `rigType`, `isFree`). No dedicated list endpoint under
`/openapi`; this web catalog is the source of truth.

- **rigType split:** 671 `style_02`, 5 `style_03`, 2 `biped`, 2 `style_01`.
  The trial only ever proved `style_01` (Idle, id 0). Nearly every expressive /
  funeral-fitting pose lives in `style_02`, so it was an open question whether
  the auto-rig could retarget them.
- **PROVEN this wave:** the auto-rig **does** retarget `style_02`. Gentlemans
  Bow (`action_id 42`, rigType `style_02`) succeeded on the hooded mourner's rig
  → clip `Armature|Gentlemans_Bow|baselayer` (7.30 s). **The whole 680-clip
  library is reachable, not just the four style_01/biped presets.**
- **No raking/sweeping preset exists.** Every "sweep" in the catalog is martial
  (Sweep Kick 217/455, Backflip Sweep Kick 453/604, Leg Sweep 213); there is no
  broom/rake/mop labor loop. So Old Rake keeps his **procedural rake prop** (the
  swinging `_rake` node + leaf logic) now layered over a real skeletal idle —
  honest to what the library actually names.
- Funeral-adjacent poses noted for future picks (all `style_02`): Formal Bow 41,
  Dozing Elderly 38, Depressed Full Turn Left 579, Kneel on One Knee 365,
  Thoughtful Walk 121, Elderly Shaky Walk 553, Limping Walk 558.

## Per-model results (rig once, animate; 27 cr total)

| Model | Rig height (native) | action_id → clip | Credits |
|---|---|---|---|
| `npc_groundskeeper` | **1.8 m** | 0 Idle → `Armature\|Idle\|baselayer` (4.03 s) | rig 5 + idle 3 |
| `npc_mourner_elderly` | **1.65 m** | 0 Idle → `Armature\|Idle\|baselayer` (4.03 s) | rig 5 + idle 3 |
| `npc_mourner_hooded` | **1.75 m** | 0 Idle **and** 42 Gentlemans Bow → `Armature\|Gentlemans_Bow\|baselayer` (7.30 s) | rig 5 + idle 3 + bow 3 |

Rig credits 15 + anim credits 12 = **27 cr**. Outputs (statics NOT replaced):
`npc_groundskeeper_idle.glb`, `npc_mourner_elderly_idle.glb`,
`npc_mourner_hooded_idle.glb`, `npc_mourner_hooded_bow.glb`. Each extracted an
embedded `*_texture_0.png` on Godot import (butler precedent) — committed with
its `.import` sidecars.

**⚠ SAME SCALE CAVEAT as the trial:** every rigged GLB's static mesh AABB reads
`(0.01, 0.02, 0.01)` (armature applies ~×100 at runtime — see the probe log
below). NEVER size these from a merged AABB. `MeshyProp.instance_rigged(path,
native_height, target_height, …)` trusts the recorded rig height instead; that
is the only correct integrator, and it is what `core/ambient_life.gd` uses.

## Wiring (core/ambient_life.gd — presentation only)

Each member prefers its animated GLB via `AmbientLife.rigged_or_null([...],
native, target)` and falls back to the old static+procedural path when absent:

- **Old Rake (Groundskeeper):** rigged idle (native 1.8 → target 1.35). The
  procedural rake sweep + leaves + stare/survey all layer on top. New: the
  skeletal loop is **frozen** (`speed_scale = 0`) for the duration of the STARE
  so he genuinely stops — the stare is the joke — and resumes on exit. Falls
  back to the tinted KayKit Barbarian.
- **The Queue (two mourners):** front = elderly on the idle (native 1.65), still
  runs the pocket-watch gag; back = hooded, prefers the **bow** (pay respects),
  falling back to its own idle (native 1.75). The continuous whole-body ghost
  **hover is gated off on the rigged path** (it fought the skeletal loop); the
  shuffle-forward / step-aside / check-watch staging beats are kept. Both remain
  ghostified. Fall back to the KayKit Mage/Rogue stand-ins.

Untouched: crows, seagull, atmosphere, moody lantern, the ghost queue's door.

## Verification evidence

- **(a) probe audition** — `godot --path . tools/asset_probe.tscn --
  --dir=res://assets/models/meshy/generated/ --animate --shots=60,140,220
  --only=npc_groundskeeper_idle,npc_mourner_elderly_idle,npc_mourner_hooded_idle,npc_mourner_hooded_bow`
  Receipts:
  ```
  PROBE_ANIM npc_groundskeeper_idle.glb  playing 'Armature|Idle|baselayer' (4.03s)
  PROBE_ANIM npc_mourner_elderly_idle.glb playing 'Armature|Idle|baselayer' (4.03s)
  PROBE_ANIM npc_mourner_hooded_bow.glb  playing 'Armature|Gentlemans_Bow|baselayer' (7.30s)
  PROBE_ANIM npc_mourner_hooded_idle.glb playing 'Armature|Idle|baselayer' (4.03s)
  PROBE_AABB npc_groundskeeper_idle.glb  size=(0.01, 0.02, 0.01)   # the caveat, live
  ```
  Shots: `docs/verify/shots/meshy_rig_wave_audition.png` (+ `_audition2.png`) —
  all four render full human-scale beside the 1.8 m REF, clearly mid-animation
  (groundskeeper weight-shifting with his fork, elderly head-bowed on a cane,
  hooded caught mid-bow).
- **(b) windowed estate, live in the grounds** — reused the B3 `--ambienttest`
  harness (`godot --path . -- --ambienttest`). Code-path receipts prove each
  member took the rigged branch:
  ```
  AMBIENT_RIGGED groundskeeper <- .../npc_groundskeeper_idle.glb
  AMBIENT_RIGGED mourner       <- ["...npc_mourner_elderly_idle.glb"]
  AMBIENT_RIGGED mourner       <- ["...npc_mourner_hooded_bow.glb", "...npc_mourner_hooded_idle.glb"]
  ```
  Shots: `docs/verify/shots/meshy_rig_wave_estate_groundskeeper.png` (Old Rake
  rigged + staring, leaves scattered) and `_estate_queue.png`. Note the estate
  snaps use the wide stroll camera, so the two graveyard mourners read small at
  distance — the close read is the probe audition above (this is the honest
  fallback the brief allows: audition + code-path receipt).
- **(c) headless import clean** (no SCRIPT ERROR / Parse Error); **estate
  game-load smoke** `godot --headless --path . -- --estate --estatebots
  --quitafter=240` — clean, rigged receipts present.
- **(d) procession receipt unchanged** — `godot --headless --path . --
  --procession --seed=7 --deedgoal=4 --autoplay=bots` →
  `PROCESSION_HEIR BLUE (seed 7, 17 rounds)`. Presentation-only; sim untouched.

## Credits (rigging wave)

| Run | Credits |
|---|---|
| 3 rigs (5 each) | 15 |
| 4 preset animations (3 each) | 12 |
| **Rigging-wave total** | **27** |

---

# ARENA HERO PROPS (night 6, lane Z3) — TILT ocean + echo_chamber well

Four hero props to upgrade the arena-reveal work (lane W3 builds zero-forge
placeholders in parallel; these swap in after director review). Same pipeline —
`meshy-6`, preview → refine, PBR off, house-style suffix, `tools/meshy_forge.ps1`
against manifest entries `category: ARENA_HERO`. Ran with `-Only` against a
**scratch** `-ReportPath` (never the shared `meshy_forge_report.json`, which the
`Save-Report` rewrite would otherwise clobber to 4 items — the documented
footgun); results then hand-merged **additively** into the ledger.

## Round 1 (4 props, 120cr, 0 API failures)

Contact sheet: `docs/verify/shots/meshy_hero_Z3_overview.png` (full row + 1.8 m
REF), `_keeps.png` (bone heap / grasping hands / colossus hand close-up),
`_colossus_leviathan_v1.png` (colossus hand + leviathan v1).
Probe: `godot --path . tools/asset_probe.tscn -- --dir=res://assets/models/meshy/generated/
--only=sea_drowned_colossus_hand,sea_leviathan_fin,pit_bone_heap,pit_grasping_hands
--groups=4 --shots=45,72,132,192,252 --outdir=verify_out/hero_Z3`.

| Prop | Probe AABB (normalized) | Verdict |
|---|---|---|
| `sea_drowned_colossus_hand` | 0.68 × 1.91 × 0.52 | **KEEP** — weathered stone hand + forearm rising vertically, fingers half-open, reads as a colossal statue breaking the surface. Menacing at the TILT splash zone. |
| `pit_bone_heap` | 1.81 × 0.41 × 1.91 | **KEEP** — low wide mound of jumbled bones with several skulls prominent on the crown; reads clearly from directly above for echo_chamber's well bottom. |
| `pit_grasping_hands` | 1.14 × 1.90 × 1.13 | **KEEP** — cluster of skeletal hands/forearms splayed and reaching up from a dirt mound; comic-macabre, not gory. Strong funny read — the audition winner for the well bottom. |
| `sea_leviathan_fin` | 0.75 × 0.74 × 1.91 | **MISS → re-roll** — generated a whole crested sea creature (visible head + legs), not a mostly-submerged dorsal-ridge silhouette. |

## Round 2 — leviathan re-roll (30cr) → REJECTED

Adjusted prompt hard toward an isolated headless fin ("ONLY the fin… no head,
no face, no legs, no body… like a submarine sail"). Re-roll still wrong:
`docs/verify/shots/meshy_hero_Z3_leviathan_reject_v2.png` — a chaotic spiky mass
with a stray white bone/tooth protrusion at the base; no clean fin silhouette.

**Verdict: REJECT `sea_leviathan_fin`** (one re-roll spent, per house rule).
Meshy keeps composing a full animal / spiky clutter instead of a smooth arch.
For this specific shape — a slow, smooth, mostly-submerged spine hump reading at
distance — a **hand-built extruded fin primitive (lane W3) will beat generative**.
Rejected GLB + textures NOT shipped; both v1 and v2 task ids recorded in
`meshy_forge_report.json → retired_generations`. The dual-use LAST WILL
purple-sea humps should use the same hand-built silhouette.

## Credits (arena-hero batch, lane Z3)

| Run | Credits |
|---|---|
| Round 1 (4 props × 30) | 120 |
| Round 2 (leviathan re-roll) | 30 |
| **Batch total** | **150** |
| ...of which shipped (3 KEEP × 30) | 90 |
| ...of which retired (leviathan v1+v2) | 60 |

Balance: **1610 before → 1490 after the 4-prop round → 1460 final** (Δ 150
total incl. the leviathan re-roll; confirmed via GET /openapi/v1/balance).
Ample — no top-up needed. Ledger merge is additive: 42→45 items, 7→9 retired,
summary/note updated.
