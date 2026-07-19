# ASSET FINISH AUDIT (lane ZA, night 8) — consistency + rig candidates

Producer observation that started this lane: *"some of the boardgame
pieces/meshy gens for environment look like unpainted 3D prints/plastic
(maybe a lack of detail) — not sure why/if it's intentional as it's not every
piece... looks a bit unfinished since it's not consistent across the game."*
Plus: *"the ravens flying unrigged are hilarious but let's try to rig
everything that can/should move" (pre-release priority).*

Read-only investigation + report, with two exceptions the brief explicitly
allowed: (1) fixing a genuine import/material **wiring** bug found along the
way — no art/texture edits — and (2) fixing a stale asset-path reference. Both
are call-out sections below, not buried in the table.

## Method

Two independent passes, cross-checked against each other:

1. **Technical pass** — `tools/finish_audit.gd` (new, headless), walks every
   GLB in `assets/models/meshy/generated/` (66 files: the 57 items in
   `tools/meshy_forge_report.json` + 9 rigged/animated variants from the
   later rigging waves), inspects the actual imported `BaseMaterial3D` on
   every mesh surface (`has_albedo_tex`, `metallic`, `roughness`), locates the
   sibling extracted texture Godot's importer leaves beside each glb
   (`<name>_0.jpg` for statics, `<name>_texture_0.png` for rigged output),
   and computes a downsampled luminance mean/stddev for that texture (flat,
   low-detail bakes read as low stddev). Run:
   `godot --headless --path . tools/finish_audit.tscn -- --dir=res://assets/models/meshy/generated/`
2. **Visual pass** — `tools/asset_probe.tscn` (existing tool, unmodified),
   run in 7 category batches (`--only=`, `--groups=`, `--shots=`,
   `--outdir=verify_out/finish_audit/<category>`) to keep each page to
   8–12 props. Committed contact sheets: `docs/verify/shots/asset_finish_<category>_*.png`
   (overview + close-up groups per category — **44 images total**, this is
   the producer's review set).

**Headline technical finding:** every single one of the 66 GLBs has its
albedo texture correctly wired (`has_albedo_tex=true`, texture path resolves)
— there is **no** "material exists but doesn't reference the texture" import
bug anywhere in this set. What *is* real and systemic: the 9 rigged/animated
GLBs (Meshy `/rigging` + `/animation` output) import with **metallic=1.0,
roughness=0.41**, while all 57 static GLBs import with **metallic=0.0,
roughness=0.8** — same albedo texture, different PBR response. See "WIRING
BUG FOUND + FIXED" below; this, not missing textures, is the mechanical cause
behind part of the "plastic" read.

## Classification table

Verdict legend: **PAINTED** (reads finished) · **PLASTIC** (flat/unpainted
read) · **BORDERLINE**. Cause: **(a)** import/material wiring defect ·
**(b)** genuinely flat/low-detail texture bake from generation · **(c)**
intentional flat shading that reads fine in context (not a defect).

### GRAVES (8/8) — 6 painted, 2 plastic

| Asset | Verdict | Cause | Tex σ | Recommended fix | Est. cr |
|---|---|---|---|---|---|
| grave_headstone_plain | **PLASTIC** | (b) flat, no crack/moss detail | 20.6 | `/retexture`: add weathering/moss to match its cracked sibling | ~12 |
| grave_small_obelisk | **PLASTIC** | (b) flat white, no stone shading | 6.9 | `/retexture`: add stone-grain/weathering | ~12 |
| grave_iron_fence_plot | BORDERLINE | fence is painted; headstone panel behind it is flat | 46.7 (fence dominates the average) | leave — fence carries the read | — |
| grave_headstone_cracked | PAINTED | — | 20.7 | — | — |
| grave_celtic_cross | PAINTED | — | 22.4 | — | — |
| grave_tilted_slab | PAINTED | — | 49.3 | — | — |
| grave_mausoleum_front | PAINTED | — | 21.2 | — | — |
| grave_cherub_stone | PAINTED | — | 23.4 | — | — |

### AWARDS (8/8) — 8 painted, best-in-class

All eight (`award_workhorse/architect/snake/landlord/doormat/hoarder/nemesis/reckoner`)
are vividly painted toy-trophy pieces — gold, brown wood, black cup, coloured
gems. No issues. This category is the house-style reference: when Meshy is
given a genuinely multi-colour prompt (trophy + figure + base in different
materials), the flat-PBR pipeline sings.

### BOARD + BOARD_DRESSING (11) — 10 painted, 1 plastic

| Asset | Verdict | Cause | Tex σ | Recommended fix | Est. cr |
|---|---|---|---|---|---|
| board_grim_signpost | **PLASTIC** | (b) flat wood-tan, no grain/paint | 4.9 (2nd-lowest of all 66) | `/retexture`: wood grain + weathering | ~12 |
| board_waypoint_lantern, tollgate_arch, codicil_pedestal, deed_token, hearse_cart, planchette, crypt_door, hearse_ornate, carry_coffin, funeral_wreath | PAINTED | — | 20–58 | — | — |

### ESTATE_DRESSING + PLACEHOLDER_SWEEP (10) — 8 painted, 2 plastic

| Asset | Verdict | Cause | Tex σ | Recommended fix | Est. cr |
|---|---|---|---|---|---|
| estate_broken_angel | **PLASTIC** | (b) flat grey, zero crack/weathering — lowest σ of all 66 assets | 3.4 | `/retexture`: weathered marble + moss | ~12 |
| monument_obelisk_small | **PLASTIC** | (b) flat white, no shading | 14.9 | `/retexture`: stone texture | ~12 |
| estate_dead_tree, estate_hedge_topiary | PAINTED (c) | intentionally flat (bare-branch silhouette / block-hedge green) — reads fine, not a defect | 3.8 / 13.1 | leave | — |
| estate_dry_fountain, lamppost, wheelbarrow, iron_gate, covered_well, relic_funerary_urn | PAINTED | — | 25–52 | — | — |

### NPC_TROUPE + ARENA_HERO + PROCESSION_NPC statics (12) — 11 painted, 1 borderline

Character work across the board is the strongest category — full skin
tones, clothing detail, expressive faces (`npc_groundskeeper`, `npc_reaper`,
`npc_ferryman`, `npc_widow`, `npc_gravedigger`, both mourners). `pit_bone_heap`
and `pit_grasping_hands` read well (browned bone detail). One borderline:

| Asset | Verdict | Cause | Note |
|---|---|---|---|
| sea_drowned_colossus_hand | BORDERLINE | (c) intentionally flat weathered-stone hand | reads correctly as *statue*, not character — leave |

### PROCESSION_STATIC (8) — 7 painted, 1 plastic

| Asset | Verdict | Cause | Tex σ | Recommended fix | Est. cr |
|---|---|---|---|---|---|
| **lychgate** | **PLASTIC** | (b) flat white/cream, no wood grain or stone shading | 4.0 (3rd-lowest of all 66) | `/retexture`: timber + stone texture | ~12 |
| reaper_scythe, bone_bridge, manor_gate, peddlers_cart, ferryman_skiff, checkpoint_shrine, grave_goods_chest | PAINTED | — | 21–57 | — | — |

`lychgate` is the highest-*priority* plastic hit in this whole audit — it's
the procession's opening landmark (doc 19/28 §4, the walk-up at match start),
so every player sees it in the first ten seconds of every match.

## WIRING BUG FOUND + FIXED — rigged-GLB material default

**Cause (a).** Every one of the 9 rigged/animated GLBs shipped so far
(`npc_reaper_walk`, `npc_reaper_sweep`, `npc_ferryman_idle`,
`npc_gravedigger_idle`, `npc_groundskeeper_idle`, `npc_mourner_elderly_idle`,
`npc_mourner_hooded_bow`, `npc_mourner_hooded_idle`, `npc_widow_idle`) carries
the **exact same albedo texture** as its static sibling, but imports with
`metallic=1.0, roughness=0.41` instead of the house-style `metallic=0.0,
roughness=0.8` every static prop gets. Meshy's `/rigging` + `/animation`
re-export apparently omits `pbrMetallicRoughness.metallicFactor`, so Godot's
glTF importer falls back to the spec default (`1.0`) instead of the flat,
matte value the original text-to-3D output specifies explicitly. Under the
probe's lighting this reads as a hard glossy specular sheen on cloth — the
"unpainted plastic/rubber toy" look, and it explains the "not every piece" of
the producer's note precisely: it's *only* the 9 rigged variants, uniformly.

Confirmed visually: `docs/verify/shots/asset_finish_rigged_prefix_g2.png`
and `_g5.png` (pre-fix — note the bright specular streak on `npc_reaper_sweep`
and `npc_reaper_walk`'s robe folds, absent from the static `npc_reaper`
alongside them) vs. `docs/verify/shots/asset_finish_rigfix_postfix_reaper_walk.png`
and `..._reaper_sweep.png` (post-fix, matte, matching the static).

**Fix (shipped, this branch):** `scripts/meshy_prop.gd`,
`MeshyProp.instance_rigged()` — the single choke point every rigged Meshy
GLB in the game goes through (`estate/procession/board_graph.gd` procession
NPCs, `estate/procession/executor_body.gd` the Executor, `core/ambient_life.gd`
the ambient troupe, `minigames/pallbearers/pallbearers.gd` spectators). Added
`_degloss_rigged_materials()`: after instancing, duplicate any surface
material with `metallic > 0` and reset it to `metallic=0.0, roughness=0.8`
(the exact static house-style values). Verified via
`godot --headless --path . tools/finish_audit.tscn -- --dir=res://assets/models/meshy/generated/ --via-meshyprop`,
which routes every skinned GLB through the real `MeshyProp.instance_rigged()`
path (not a raw load) and confirms `metallic=0.00 roughness=0.80` on all 9.
This is an import-default correction at the integration layer, not an art or
texture change, and it retroactively fixes every current *and future* rigged
integration (including `executor_butler_idle.glb`, outside the
`generated/` scope of this audit, and any PALLBEARERS rigged spectators).

## WIRING BUG FOUND + FIXED — PALLBEARERS coffin pointed at a never-forged filename

Unrelated to the material issue, found while tracing which `generated/`
assets are actually wired up: `minigames/pallbearers/pb_coffin.gd`'s Meshy
swap seam (`COFFIN_GLB`) pointed at
`res://assets/models/meshy/generated/board_pall_coffin.glb` — a filename that
was **never generated**. `ResourceLoader.exists()` correctly detected this
every run and silently fell back to hand-built primitives (a "styled
walnut+gold casket" graybox, per the code's own comment and
`minigames/pallbearers/VERIFY.md` line 157: *"No coffin GLB exists yet"*).
That was accurate the night PALLBEARERS shipped — but `board_carry_coffin.glb`
(BOARD_DRESSING wave, forged the same week) is exactly the asset this seam
was written for: a dark-wood coffin with gold corner fittings and carry
handles, and it reads **PAINTED** on this audit's own contact sheet
(`docs/verify/shots/asset_finish_board_g1.png`). The swap seam was simply
never re-pointed at it.

**Fix (shipped, this branch):** `minigames/pallbearers/pb_coffin.gd` —
`COFFIN_GLB` now points at `board_carry_coffin.glb`. Verified: (1) windowed
capture harness (`--pallbearercap --seed=8`) shows the real coffin model in
the carry/drop screenshots — `docs/verify/shots/asset_finish_pallbearers_coffin_fixed_carry.png`
and `_drop.png`; (2) deterministic receipt (`--pallbearertest --seed=5`)
byte-matches the documented VERIFY.md receipt (same drop/finish/points/
placements) — render-only, zero sim impact, as the file's own docstring
promises.

## RIG CANDIDATES INVENTORY

Checked every `ambient_life.gd` member, every board NPC, and every place a
Meshy or custom GLB is driven by a `Tween`/`_process` instead of a skeleton.
Most of what looks static is **intentionally** static — logged below so
nobody re-opens settled calls.

### Should rig — real gaps

| Asset / system | Current behaviour | Verdict |
|---|---|---|
| **`minigames/tilt/seagull.gd` (`TiltSeagull`)** | Eliminated TILT players fly a static `seagull.glb` (wings folded, single mesh). The code **already writes wing-flap animation** — `tick()` computes `flap = sin(_clock*9.0)*0.62` and applies it to `_wing_l`/`_wing_r` — but those are **empty `Node3D` pivots** (`_build()`'s own comment: *"empty wing pivots: the static model has no separate wings, but tick() still rotates these each frame — harmless, keeps the flap code untouched"*). The bird glides perfectly rigid while game logic thinks it's flapping. This is almost certainly the producer's literal "ravens flying unrigged" — it's **player-controlled** (WASD flight while dead, every eliminated player stares at it) and the single most visible unrigged mover in the game. | **RIG — highest priority** |
| **`core/ambient_life.gd` (`Seagull` class, §3.5)** | Same `seagull.glb`, same "no wing flap" limitation, driven by a pivot-rotation "wheel" tween + a position-tween "swoop" dive over the estate grounds. Lower visibility than TILT (ambient background, not player-controlled) but same asset — see credit note below. | **RIG — same asset as above, ride-along** |
| `npc_crow_perched` / `npc_crow_flapping` | Perched decoration only (`ArenaDressing.crow()`, `AmbientLife.CrowGallery`) — small hop/aim via tween while standing on a stone. **`npc_crow_flapping` is director-banned from flight** (`docs/verify/meshy-troupe-VERIFY.md`: "converged to a second standing pose... Do not use for airborne moments"). | Not a candidate — tween is correct for a perched bird |
| Groundskeeper's rake | Body is already rigged (idle skeletal loop, RIGGING WAVE night 5); the rake swing itself is a procedural prop tween because **no rake/sweep preset exists in Meshy's 680-clip catalog** (confirmed in `docs/verify/meshy-troupe-VERIFY.md`). | Not a candidate — correct existing pattern |
| Board pawns (figurine tokens), hearse/wheelbarrow/planchette board landmarks | **Producer-locked, doc 28 §11 option b**: "NOT walking mini-people. Toy-style figurines... frozen Idle a beat in: a stance, not a T-pose" — the hop-clack tween IS the intended board-game-piece read. | Not a candidate — deliberate art direction |
| PALLBEARERS bearers (`pb_carrier.gd`) | Already full KayKit skeletal animation (`Idle`/`Running_A`/`Walking_A`). | Not a candidate — already rigged |

### Rig candidate count: **1 asset, 2 consumers** (`seagull.glb` — TILT's `TiltSeagull` and the ambient troupe's `Seagull`). A single successful Meshy rig pass fixes both "hilarious unrigged" instances at once, since they share the GLB.

**Feasibility caveat, not yet proven:** every successful rig in this project
to date (`npc_reaper`, `npc_ferryman`, `npc_gravedigger`, `npc_groundskeeper`,
2 mourners, `npc_widow`, `executor_butler`) has been a **biped/humanoid**.
Meshy's public animation-preset catalog researched for the RIGGING WAVE is
671/680 entries `style_02` (human), with only 2 `biped`/2 `style_01` and no
avian/quadruped presets identified. Whether Meshy's `/rigging` auto-rig
endpoint produces a usable skeleton on a **bird** shape at all is unconfirmed
in this codebase — recommend a small paid preview spend to test before
committing to a full wave (see plan below). If auto-rig rejects/mangles the
bird shape, the fallback is a hand-split wing mesh (separate `MeshInstance3D`
nodes the existing `_wing_l`/`_wing_r` tween code can drive directly, zero
additional Meshy spend) rather than a skeletal rig.

## PROPOSED PRE-RELEASE WAVE PLAN

Balance: 975cr (approved). Total estimated spend below: **well under 100cr**,
leaving generous headroom.

| Wave | Items | Est. cr | Notes |
|---|---|---|---|
| **1. Retexture batch** | grave_headstone_plain, grave_small_obelisk, board_grim_signpost, estate_broken_angel, monument_obelisk_small, lychgate (6 assets) | ~72cr (6 × ~12cr, `/retexture` pricing unconfirmed in-repo — verify actual cost via balance delta on the first call before batching the rest) | Same house-style prompt suffix as the original forge, plus "add weathering/crack/grain detail matching [sibling asset]" per item. `lychgate` is highest priority (first-impression landmark). |
| **2. Seagull rig feasibility test** | 1× `/rigging` attempt on `seagull.glb` | ~5cr rig + ~3cr if any preset animation is worth trying = ~8cr | If the auto-rig produces a clean bird skeleton, wire it through `MeshyProp.instance_rigged` in both `minigames/tilt/seagull.gd` and `core/ambient_life.gd`'s `Seagull` class (both already import `MeshyProp`) and retire the empty `_wing_l`/`_wing_r` pivots in favour of a real flap animation. If it fails, fall back to a hand-split wing mesh — no further Meshy spend. |
| **3. (optional) borderline polish** | grave_iron_fence_plot, sea_drowned_colossus_hand | 0cr — leave as-is | Both are intentional-flat (c), not defects; only revisit if the director wants extra polish headroom after waves 1–2. |
| **Total (waves 1+2)** | 7 asset touches | **~80cr** | ~8% of approved balance |

## Counts (final)

- **Painted: 58 / 66** (49 originally-painted statics + 9 rigged variants now
  fixed by the metallic wiring correction)
- **Plastic (genuine retexture candidates): 6 / 66** — grave_headstone_plain,
  grave_small_obelisk, board_grim_signpost, estate_broken_angel,
  monument_obelisk_small, lychgate
- **Borderline: 2 / 66** — grave_iron_fence_plot, sea_drowned_colossus_hand
- **Wiring bugs found and fixed (code, no art changes): 2** — the rigged-GLB
  metallic/roughness default (9 assets, `scripts/meshy_prop.gd`) and the
  PALLBEARERS coffin stale-filename swap seam (`minigames/pallbearers/pb_coffin.gd`)
- **Rig candidates: 1 asset / 2 consumers** — `seagull.glb`
  (`minigames/tilt/seagull.gd` `TiltSeagull`, `core/ambient_life.gd` `Seagull`)
- **Estimated pre-release wave cost: ~80cr** of the 975cr approved balance
