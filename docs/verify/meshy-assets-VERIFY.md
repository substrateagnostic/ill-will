# Meshy custom assets — verification

Generated 2026-07-04 via Meshy.ai text-to-3D (paid account), model `meshy-5`,
low-poly mode, triangle topology, target polycount 8000, preview → refine → GLB.
All 10 requested assets succeeded on the first generation — no retries needed.

Pipeline: submit preview → poll → submit refine → poll → download GLB into
`assets/models/meshy/` → `godot --headless --editor --import --quit` →
probe scene `tools/asset_probe.tscn` (all GLBs on pedestals, house lighting,
1.8 m reference capsule) run windowed with `--shots`, screenshots read and judged.

## Probe screenshots

| Shot | Path |
|---|---|
| Overview (full row + 1.8 m capsule) | `docs/verify/shots/meshy_probe_overview.png` |
| Close-up: auction_podium, gilded_pot, go_kart, manor_gate | `docs/verify/shots/meshy_probe_group1.png` |
| Close-up: go_kart, manor_gate, riding_mower, seagull, stone_lantern | `docs/verify/shots/meshy_probe_group2.png` |
| Close-up: seagull, stone_lantern, table_lamp, throne | `docs/verify/shots/meshy_probe_group3.png` |
| Close-up: table_lamp, throne, wardrobe | `docs/verify/shots/meshy_probe_group4.png` |

Raw capture dir (gitignored): `verify_out/meshy_probe/`.

## Scale note

Meshy normalizes every model to a ~1.9-unit max dimension, so **each asset needs
a per-instance scale at integration** (AABB printed by the probe, listed below).
E.g. the wardrobe (1.01 × 1.91 × 0.82) is usable as-is next to a 1.8 m character;
the seagull (1.91 units tall) needs ~0.25×; the manor gate needs ~2.5×.

## Verdicts

Common prompt suffix on every asset: *"low poly, chunky toy-like proportions,
flat colors, no textures needed, game asset, clean silhouette, single object,
Kenney/KayKit style"*.

| # | Asset | For | Verdict | AABB (probe) | Notes |
|---|-------|-----|---------|--------------|-------|
| 1 | `wardrobe.glb` | Dead Weight | **KEEP** | 1.01 × 1.91 × 0.82 | Chunky two-door wardrobe, warm wood, rounded panels. Excellent Kenney fit. Near-correct scale out of the box. |
| 2 | `table_lamp.glb` | Dead Weight | **KEEP** | 0.81 × 1.91 × 1.20 | Classic shade + slim base, silhouette reads instantly. Base is a touch more "antique realistic" than chunky-toy; acceptable. Scale to ~0.35×. |
| 3 | `riding_mower.glb` | Mower Mayhem | **KEEP** | 1.90 × 1.23 × 1.47 | Bright green, chunky wheels, cutting deck, empty seat, no rider. Perfect toy-like read. |
| 4 | `go_kart.glb` | Swap Meet | **KEEP** | 1.91 × 0.89 × 1.26 | Rounded cream body, exposed steering wheel, no driver. Reads more vintage-toy-roadster than bumper-car and the seat well is shallow; still clean and chunky. Retint body per player at integration. |
| 5 | `seagull.glb` | Tilt | **KEEP** | 0.68 × 1.91 × 1.40 | Standing, wings folded, orange beak/legs. Legs slightly lanky vs. chunky-cute, but clean silhouette. Scale to ~0.25×. |
| 6 | `gilded_pot.glb` | Greed Inc | **KEEP** | 1.90 × 1.43 × 1.37 | Ornate dark cauldron, gold trim, coin pile heaped on top with spill around base. Exactly the Greed prop. |
| 7 | `throne.glb` | The Throne | **KEEP** | 0.84 × 1.90 × 0.74 | Red tufted high back, gold frame, ornate arms. Best-in-batch. |
| 8 | `stone_lantern.glb` | Estate trail | **KEEP** | 0.87 × 1.91 × 0.87 | Pagoda-cap stone lantern, weathered grey tiers. Reads great at distance. |
| 9 | `manor_gate.glb` | Estate | **KEEP** | 1.91 × 1.61 × 0.59 | Chunky stone block arch on square pillars. Scale up ~2.5× for walk-through. |
| 10 | `auction_podium.glb` | Estate | **KEEP** | 0.88 × 1.90 × 0.88 | Warm wood lectern with angled top on chunky pedestal. Clean. |

**10 / 10 KEEP. No REGENERATE-LATER, no REJECT.**

Style consistency: refined models carry baked flat-ish textures rather than pure
vertex colors — slightly richer surfaces than the Kenney minigolf kit, but they
sit comfortably in the warm chunky diorama under the house lighting (see group
close-ups). Nothing reads photoreal or noisy.

## Generation prompts + Meshy task IDs

| Asset | Prompt (before common suffix) | Preview task | Refine task |
|---|---|---|---|
| wardrobe | A chunky wooden wardrobe cabinet, tall with two closed doors, slightly cartoonish, rounded edges, warm brown wood, standing upright | `019f2fd3-fb5a-780d-bb94-394324e17c4f` | `019f2fd5-74c4-7574-8a69-62ba3b807406` |
| table_lamp | An antique table lamp with a rounded lamp shade on a slim ornate base | `019f2fd4-7865-7815-b0be-ff5e8d4c21a9` | `019f2fd7-da6c-75c4-8f98-152913918bd0` |
| riding_mower | A small riding lawn mower, toy-like, green body with a seat and steering wheel, no driver, chunky wheels | `019f2fd4-86a4-754a-8ff6-7b8b9af6255f` | `019f2fd9-793b-7930-9e3b-bd6c39515292` |
| go_kart | A bumper-car style go-kart with one open empty seat and a rounded bumper body, no driver, chunky wheels | `019f2fd4-9604-785e-8fee-961f88081ec5` | `019f2fd6-64f9-7850-8430-cba8a37dfd65` |
| seagull | A cute cartoon seagull standing on two legs with wings folded, white body, grey wings, orange beak and feet | `019f2fd4-a598-7860-aa79-d878eb7ae7a5` | `019f2fd6-6b7b-792d-88fa-aa786e9e3ee9` |
| gilded_pot | An ornate gilded pot cauldron with a round belly, overflowing with a pile of gold coins on top | `019f2fd4-b5dd-7868-a5c1-826ebf9553b1` | `019f2fd8-e142-79bc-a85f-eab111b19b3d` |
| throne | A regal royal throne with a tall ornate high back, gold frame and red velvet cushions, chunky and imposing | `019f2fd4-c481-786e-ad58-d9bb9f7fbeb9` | `019f2fd6-72e6-78a7-9da1-209558180bb8` |
| stone_lantern | A stone garden lantern, japanese pagoda style cap on a carved stone pedestal, weathered grey | `019f2fd4-d26b-7870-8c91-14b1a2092e05` | `019f2fd6-797a-7854-9370-cc94b2355457` |
| manor_gate | A small stone manor gate archway, two square pillars joined by a rounded arch on top, weathered grey stone | `019f2fd4-e268-78f8-a71d-387125e4f01e` | `019f2fd6-80d3-78a9-89c8-ede9df072390` |
| auction_podium | A wooden auction podium lectern, an angled reading top on a chunky pedestal stand, warm polished wood | `019f2fd4-f1fc-78f9-97da-2abbcc1b857e` | `019f2fd5-bb55-7839-8d95-ec19d78a8020` |

## Re-running the probe

```
godot --path . tools/asset_probe.tscn -- --shots=60,110,170,230,290 --outdir=verify_out/meshy_probe
```

Shots: 60 = overview, 110/230/170/290 = close-up passes along the row.
The probe auto-discovers every `.glb` in `assets/models/meshy/` — new assets
appear without editing the scene.

## Integration status

**Not integrated.** Per the brief, wiring assets into game scenes is the
director's pass. License/provenance: `assets/models/meshy/LICENSE-NOTE.md`.
