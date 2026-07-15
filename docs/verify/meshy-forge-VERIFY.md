# MESHY FORGE — 32-prop batch verification

Generated 2026-07-15 via Meshy.ai text-to-3D (paid account), model **`meshy-6`**
(first batch on v6; the 18 prior shipped assets used meshy-5), low-poly mode,
triangle topology, target polycount 8000, PBR **off** (house style is
flat-color), preview → refine → GLB into `assets/models/meshy/generated/`.

Pipeline research: `docs/design/15-meshy-pipeline.md`.
Tool: `tools/meshy_forge.ps1` (manifest-driven; `-PreviewOnly`, `-Resume`,
`-Only`, batched submissions ≤5 in flight, 429/5xx backoff, one auto-retry on
preview FAILED). Manifest: `tools/meshy_manifest.json` (32 props, house style
suffix appended to every prompt). Full task-id/credit record:
`tools/meshy_forge_report.json`.

House style suffix (verbatim from the three prior KEEP batches):
*"low poly, chunky toy-like proportions, flat colors, no textures needed,
game asset, clean silhouette, single object, Kenney/KayKit style"*.

## Credits

| Run | Props | Credits |
|---|---|---|
| Pilot (3 props, cost confirmation) | 3 | 90 |
| Full batch (remaining 29) | 29 | 870 |
| Contact-sheet retries (4 regenerations) | 4 | 120 |
| **Actual cumulative spend** | | **1080** |

Pilot confirmed 30 credits/prop (20 preview + 10 refine) — exactly the doc-15
estimate — before the full batch was unleashed. 0 API failures, 0 timeouts
across all 36 generations.

## Contact sheet

Windowed probe run (`tools/asset_probe.tscn`, new additive `--dir=`/`--groups=`
flags; defaults unchanged for old callers):

```
godot --path . tools/asset_probe.tscn -- --dir=res://assets/models/meshy/generated/ --groups=8 --shots=60,80,140,200,260,320,380,440,500 --outdir=verify_out/meshy_forge
```

Raw captures (gitignored): `verify_out/meshy_forge/shot_*.png`.
Committed copies (director's review set):

| Shot | Contents (row is alphabetical) | Path |
|---|---|---|
| Overview | full 32-prop row + 1.8 m capsule | `docs/verify/shots/meshy_forge_overview.png` |
| Group 1 | award_architect, doormat, hoarder, landlord | `docs/verify/shots/meshy_forge_group1.png` |
| Group 2 | award_landlord, nemesis, reckoner, snake, workhorse | `docs/verify/shots/meshy_forge_group2.png` |
| Group 3 | workhorse, board_codicil_pedestal, crypt_door, deed_token, grim_signpost | `docs/verify/shots/meshy_forge_group3.png` |
| Group 4 | grim_signpost, hearse_cart, planchette, tollgate_arch, waypoint_lantern | `docs/verify/shots/meshy_forge_group4.png` |
| Group 5 | waypoint_lantern, estate_broken_angel, covered_well, dead_tree, dry_fountain | `docs/verify/shots/meshy_forge_group5.png` |
| Group 6 | dry_fountain, hedge_topiary, iron_gate, lamppost, wheelbarrow | `docs/verify/shots/meshy_forge_group6.png` |
| Group 7 | wheelbarrow, grave_celtic_cross, cherub_stone, headstone_cracked, headstone_plain | `docs/verify/shots/meshy_forge_group7.png` |
| Group 8 | headstone_plain, iron_fence_plot, mausoleum_front, small_obelisk, tilted_slab | `docs/verify/shots/meshy_forge_group8.png` |

## Verdicts (judged from the contact sheet)

Meshy normalizes to ~1.9-unit max dimension — **every prop needs a
per-instance target height at integration** (use `MeshyProp.instance(path,
target_height)`; manifest `target_height_hint` is the authored suggestion).
AABBs below are the probe's raw (uniform-normalized) sizes.

### GRAVES — 8/8 KEEP

| Asset | Verdict | AABB | Notes |
|---|---|---|---|
| grave_headstone_plain | **KEEP** | 1.07 × 1.91 × 0.96 | Clean rounded headstone on rough base. |
| grave_headstone_cracked | **KEEP** | 1.01 × 1.91 × 0.60 | Jagged crack + green moss accents. Reads instantly. |
| grave_celtic_cross | **KEEP** | 0.60 × 1.91 × 0.61 | Ringed cross, stepped base, carved shaft. Best-in-category. |
| grave_small_obelisk | **KEEP** | 0.74 × 1.91 × 0.74 | Clean taper to pyramid point. |
| grave_tilted_slab | **KEEP** | 1.91 × 0.74 × 1.57 | Cracked slab sinking into a mound, moss accent. |
| grave_mausoleum_front | **KEEP** | 1.91 × 1.41 × 1.65 | Mini facade: peaked roof, columns, sealed door. Grand. |
| grave_cherub_stone | **KEEP** (regen) | 1.20 × 1.91 × 0.95 | v1 cherub was an illegible knob; v2 winged cherub kneels weeping against the stone — prominent and mournful. |
| grave_iron_fence_plot | **KEEP** | 1.91 × 1.47 × 1.05 | Headstone ringed by rust-red spiked iron fence. |

### AWARDS — 8/8 KEEP

| Asset | Verdict | AABB | Notes |
|---|---|---|---|
| award_workhorse | **KEEP** | 0.94 × 1.32 × 1.91 | Ox + cart/plow on orange stepped base. |
| award_architect | **KEEP** | 0.79 × 1.91 × 0.68 | Compass astride a column-stemmed cup. Dark finish; reads fine. |
| award_snake | **KEEP** | 0.83 × 1.90 × 1.20 | Coiled cobra rearing to strike. |
| award_landlord | **KEEP** | 0.94 × 1.91 × 0.62 | Moustached landlord bust with gold key on wooden base. Meshy added the bust; it lands as a portrait trophy — fits the superlative's mockery. |
| award_doormat | **KEEP** | 1.45 × 1.09 × 1.91 | Gold-framed mat reading "WELCOME MUT" (AI-garbled MAT). The typo is honestly funnier; director may re-roll if it grates. |
| award_hoarder | **KEEP** | 0.90 × 1.91 × 1.10 | Gold-crowned figure bursting from a coin-stuffed chest. |
| award_nemesis | **KEEP** (regen) | 1.44 × 1.91 × 0.90 | v1 was a glowering bust in a cup (no daggers); v2 is a clean crossed-daggers X on a trophy base. |
| award_reckoner | **KEEP** | 1.00 × 1.91 × 0.65 | Justice figure holding visibly unbalanced scales. |

### BOARD — 8/8 KEEP

| Asset | Verdict | AABB | Notes |
|---|---|---|---|
| board_waypoint_lantern | **KEEP** | 0.83 × 1.91 × 0.54 | Carved stone with a hollow-eyed green-man face + small lantern on top. Creepier than briefed, exactly ILL WILL's register. |
| board_tollgate_arch | **KEEP** | 1.33 × 1.91 × 0.97 | Ornate wrought-iron arch + gate. Matches trail tollgate slots. |
| board_codicil_pedestal | **KEEP** (regen) | 0.68 × 1.90 × 0.68 | v1 was a scattered platter; v2 single fluted column, golden scroll on top. Clean objective-marker read. |
| board_deed_token | **KEEP** (regen) | 1.04 × 0.85 × 1.90 | v1 was a white blob; v2 parchment stack + red ribbon bow + wax seal. |
| board_hearse_cart | **KEEP** | 1.91 × 1.86 × 1.08 | Draped black curtains, orange spoked wheels, no horse. |
| board_planchette | **KEEP** | 1.90 × 0.33 × 1.66 | Flat triangular pointer with dark lens. Séance-ready. |
| board_grim_signpost | **KEEP** | 0.92 × 1.91 × 0.83 | Crooked multi-arrow post. |
| board_crypt_door | **KEEP** | 1.91 × 1.87 × 0.72 | Stone arch + iron-banded wooden door. |

### ESTATE DRESSING — 8/8 KEEP

| Asset | Verdict | AABB | Notes |
|---|---|---|---|
| estate_dead_tree | **KEEP** | 1.18 × 1.91 × 1.10 | Gnarled bare branches, strong silhouette. |
| estate_dry_fountain | **KEEP** | 1.89 × 0.76 × 1.90 | Cracked empty basin, raven perched on rim. On-prompt. |
| estate_lamppost | **KEEP** | 0.55 × 1.91 × 0.55 | Black iron post, warm glowing lantern head. |
| estate_hedge_topiary | **KEEP** | 1.01 × 1.91 × 1.00 | Block hedge with arch relief. Green is brighter than gothic; sits fine under house lighting. |
| estate_broken_angel | **KEEP** | 0.85 × 1.91 × 0.85 | Mournful weathered angel on plinth. |
| estate_wheelbarrow | **KEEP** | 1.91 × 1.03 × 0.71 | Wooden barrow heaped with dark dirt. |
| estate_iron_gate | **KEEP** | 1.03 × 1.91 × 0.22 | Spiked fence-gate section, nicely thin (0.22 deep). |
| estate_covered_well | **KEEP** | 1.18 × 1.91 × 1.01 | Stone well, peaked orange roof, crank. Charming. |

**32 / 32 KEEP. 4 regenerated once after contact-sheet review (retired v1 task
ids + reasons recorded in `tools/meshy_forge_report.json` →
`retired_generations`). 0 hard failures.**

Style consistency: as with prior batches, refined models carry baked flat-ish
textures slightly richer than pure Kenney/KayKit; the meshy-6 set sits
comfortably next to the 18 shipped meshy-5 props under the probe's house
lighting. Nothing photoreal or noisy.

## Prompts + task IDs

Prompts live in `tools/meshy_manifest.json` (the 4 regenerated ids carry
their v2 prompts). Per-id preview/refine task IDs and credits:
`tools/meshy_forge_report.json`.

## Re-running

```
# full batch, skipping anything already downloaded
powershell -File tools\meshy_forge.ps1 -Resume

# regenerate one prop after editing its manifest prompt
#   delete assets/models/meshy/generated/<id>.glb first, then:
powershell -File tools\meshy_forge.ps1 -Resume
#   (or target it directly)
powershell -File tools\meshy_forge.ps1 -Only <id>

# contact sheet
godot --headless --editor --import --quit --path .
godot --path . tools/asset_probe.tscn -- --dir=res://assets/models/meshy/generated/ --groups=8 --shots=60,80,140,200,260,320,380,440,500 --outdir=verify_out/meshy_forge
```

API key: read at runtime from `C:\Users\agall\projects\Dead_Attestation\.env`
(`MESHY_API_KEY`) — never written to the repo, never logged.

## Integration status

**Not integrated** — per the brief, monuments/board wiring belongs to another
lane. Deliverables here: the tool, the manifest, 32 GLBs + import sidecars +
extracted textures, the report JSON, and the contact sheet.
License/provenance: `assets/models/meshy/LICENSE-NOTE.md`.
