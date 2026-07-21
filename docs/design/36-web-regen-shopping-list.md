# 36 — Web Regen Shopping List (Meshy Ultra, web-only session)

Producer session doc. Alex on Meshy Ultra web: ~100 free regens/generation,
3 variants per spin, no credits burned. Spin liberally. No API, no commits —
this doc plans the session; Claude wires results in after.

House style suffix (append by hand — web UI has no auto-suffix like the
forge script does):
> low poly, chunky toy-like proportions, flat colors, no textures needed,
> game asset, clean silhouette, single object, Kenney/KayKit style

## PRIORITY 1 — The Elderly Mourner, sans cane

Twice forged, twice failed. Meshy keeps drawing the cane.

**v2 prompt (verbatim, `tools/meshy_manifest_rigging_batch.json`):**
> A stooped elderly mourner standing with both hands clasped together in
> front at the waist, empty hands, no cane, no props, hunched posture, dark
> somber Victorian mourning clothes, standing neutral pose, both legs
> together not mid-stride, slightly oversized head for readability

**v3 prompt (verbatim, `tools/meshy_manifest_rigging_batch_retry.json` —
already the "try harder" rewrite, still lost):**
> A stooped elderly mourner standing upright unaided on both feet, both
> empty hands clasped together in front at chest height, absolutely no
> cane, no walking stick, no staff, no props of any kind held or nearby,
> hunched shoulders but supporting own weight with no aid, dark somber
> Victorian mourning clothes, standing neutral pose, both legs together not
> mid-stride, slightly oversized head for readability

**Why it failed** (commit `c2b1d5e`, `5cd8a21`): v2 missed, v3 missed —
"Meshy insists on the cane." Not a rig glitch either — forensics found and
stripped a real +17.65% Hips scale defect, but "cane not rescued, weight
smear too." The cane is baked into the geometry: "stooped/hunched elderly"
free-associates a cane no matter how many negations pile on top.

**Spin variations** (drop the trigger framing):
- Cut "stooped"/"hunched" entirely — try "standing fully upright."
- Swap "elderly" for "white-haired" — same age read, different word.
- Three separate spins on hands: "clasped in front at chest height,"
  "folded in prayer," "arms at sides, palms in."
- New prop appears instead (rosary, handkerchief)? Different failure —
  keep it, flag it, let Claude judge salvageability.

**ACCEPT:** no cane/staff/stick anywhere, touching ground or not · hands
empty or clasped/folded, not reaching · same toy-macabre house style
(chunky, flat-color, low-poly, no photoreal/painterly drift) · same
character family as the shipped elderly mourner (dark Victorian mourning
dress, oversized head, somber).

**REJECT:** any held object at all · style drift · T-pose, fused limbs, or
anything off a clean standing neutral. Spin 3 at a time, free — burn
through it, this one's overdue.

## PRIORITY 2 — Auto Split experiments

Web Auto Split feature. Record output even on failure — a negative result
still closes the question.

**(a)** `assets/models/meshy/generated/npc_mourner_elderly.glb` (the
ORIGINAL, cane-and-all, still shipped). Run Auto Split — does it isolate
the cane as its own part? Yes → code-side fix path opens (detach, hide,
done, no more Priority-1 spins needed). No → note why (fused mesh, bad
boundary, whatever it reports).

**(b)** `assets/models/meshy/seagull.glb` (top-level, not `generated/` —
`minigames/tilt/seagull.gd` TiltSeagull + `core/ambient_life.gd` Seagull).
Goal: wing separation. Meshy auto-rig flatly refuses birds (2/2 HTTP 422
"Pose estimation failed" at both 0.6m and 1.7m — confirmed body-plan
rejection, `tools/meshy_seagull_rig_report.json`). Hand-split wings was
the only path left to a real flap pivot; Auto Split may do it for free.

Record both: parts count, boundary quality, usable or garbage. Screenshot
if the UI shows a preview.

## PRIORITY 3 — Butler alternates (optional, spare regens only)

`executor_butler_v2` already shipped, approved (mustache canon, tray-less,
tray now a BoneAttachment3D). Only spin this after Priorities 1 and 2.

**Verbatim prompt (`tools/meshy_manifest_rigging_batch.json`):**
> A distinguished elderly butler standing upright in a formal black
> tailcoat with a white bow tie and white waistcoat, wearing white formal
> gloves, both hands empty and resting down at his sides, dignified
> neutral standing pose, both legs together not mid-stride, slightly
> oversized head for readability

Same accept/reject bar as Priority 1.

## LOGISTICS

**Download everything immediately** — Meshy purges in ~3 days. The
retexture wave already lost original task ids to this; don't repeat it.

**Drop into `assets/models/meshy/generated/`**, existing convention:
`<id>.glb` + `<id>_0.jpg` (base + thumbnail) · `<id>_idle.glb` /
`<id>_idle_cNNN.glb` (rigged+animated, `cNNN` = Meshy action id, e.g.
`c243` Idle 3, `c47` Listening Gesture) · `<id>_idle_cNNN_texture_0.png`
(sidecar). Elderly-mourner regens: next free suffix is `v4` — v2/v3 stay
on disk, rejected but needed for comparison.

**Tell Claude after any download** — import gate + rig + audit pipeline
runs automatically from there.

**Native heights** (use these downstream, not raw AABB — reads ~1/100
scale per the rig audit):

| id | height (m) |
|---|---|
| `executor_butler_v2` | 1.9 |
| `npc_mourner_elderly` / `_v2` / `_v3` | 1.65 |
| `npc_mourner_forhire` | 1.7 |
| `npc_ferryman` | 1.85 |
| `npc_mourner_hooded` | 1.75 |
| `npc_widow` | 1.6 |
| `prop_cane_wooden` | 0.9 (unrigged prop) |
| `prop_serving_tray_silver` | 0.35 (unrigged prop) |
| `npc_magpie` | 0.28 (bird, auto-rig refuses — same class as seagull) |

New elderly-mourner variants: target 1.65m unless proportions visibly shift.
