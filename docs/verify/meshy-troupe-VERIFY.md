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
