# 33 — THE GROUNDS: Biome Map + Environment Manifest

*Night 8 (2026-07-19). The world-first inversion, producer-approved: the
environment is authored FIRST; the board's logical graph snaps onto path
stations THROUGH it. One continuous terrain for hub and board — carefully.
Laws in force: GROUNDS BAR (near-AAA path craft, no flat ground, no visible
tiling, integrated-GPU envelope), ZERO-ENGLISH, spacing ≥2 stone-widths.*

*STATUS (ninth watch, 2026-07-19 overnight): **G1 + G2 BOTH LANDED** —
`estate/procession/grounds.gd` + the station snap in `board_graph.generate()`
(G1), then the 26-piece Meshy grounds kit (26/26 first-try, 780cr) dressing
all three lands (G2): living hedge maze, true forest, grown bog, garden
statuary, footbridge hero. Topology checksum b269c570 unmoved throughout;
the match receipts were re-frozen the same watch by THE BOOK OF THE DEAD's
sanctioned draw-order change (VERIFY-BOARD §4), not by the grounds. Draw-call
receipt 118–1449 (<1500). Stills `g1_*.png` (bare land) + `g2_*.png`
(dressed), producer review pending the morning. Next: G3 hub migration.*

## 1. The estate, as geography

One terrain. South to north: you wake on the lawn, you walk the lands, you
end at the manor. The hub is not a menu — it is the forecourt.

```
                        ┌──────────────────────────┐
                        │      THE MANOR GATE       │  (rise, iron gates,
                        │   ═══ PROCESSION ROAD ═══ │   the Executor)
                        └───────────┬──────────────┘
              MERGE — lamplit stone road climbing the rise
        ┌──────────────┬────────────┴─────────┬───────────────┐
        │ GARDEN ROW   │   HOLLOW WOODS       │ WEEPING VALLEY│
        │ hedge MAZE,  │   true forest:       │ bog plain:    │
        │ parterre     │   canopy gloom,      │ open water,   │
        │ courts,      │   root-broken dirt   │ mist, reeds,  │
        │ fountain,    │   path, deadfall,    │ plank walks + │
        │ gravel walks │   fireflies          │ BONE BRIDGE,  │
        │ (walls read  │   (trunks read as    │ ferry landing │
        │  as lanes)   │    separation)       │ (water reads  │
        │              │                      │  as edges)    │
        └──────┬───────┴──────────┬───────────┴──────┬────────┘
               └─────── THE CROSSROADS GLADE ────────┘
                    (signpost, three gaps in the treeline)
                        ┌──────────┴───────────┐
                        │  THE LYCHGATE        │
                        │  ═══ FORECOURT ═══   │  ← THE HUB LIVES HERE
                        │  theater · wardrobe  │
                        │  stall · album wall  │
                        │  monument graveyard  │
                        └──────────────────────┘
        (THE CRYPT — future: sunken gallery beneath the garden/valley
         boundary; opens only by Reaper's Shortcut or Gravedigger purchase)
```

**Route identity = environment, not color.** Where two routes run near each
other the separation is physical: a hedge wall, a treeline, a stream with
exactly one bridge. Ring hue becomes redundant confirmation, not the carrier.

## 2. Path surfaces (per the producer's list)

| Place | Surface | Notes |
|---|---|---|
| Forecourt | worn flagstone → grass edges | ceremonial, walkable hub |
| Garden Row | raked GRAVEL | crunchy, formal, lamplit |
| Hedge maze section | gravel → clipped GRASS | the maze IS the path |
| Hollow Woods | DIRT broken by roots | narrow, uneven, canopy dark |
| Weeping Valley | PLANK boardwalk + stone causeway | over open water/mud |
| Bridges | stone footbridge (garden brook), BONE BRIDGE (valley) | existing hero |
| Merge → Manor | cut STONE road, lamp-lined | the processional climb |

Surfaces are in-engine mesh strips with vertex-blended materials (house
toy-macabre, AGX) — no tiling textures read at couch distance; variation by
mesh deformation + prop scatter, not shader cost.

## 3. Terrain + spacing law

- Sculpted heightmesh (in-engine): the forecourt sits low, woods roll,
  valley DIPS (water below path grade — drama for bridges), manor on a rise
  so the finish is visible from everywhere (the moving target, always).
- Stones sit ON path splines at stations: **≥2 stone-widths of visible path
  between stones** (more at landmarks). Walked paths 28-32 stations survive
  as-is — the world stretches, the graph doesn't change.
- The logical graph (nodes/edges/types/dist) is untouched: same data, same
  seeds, same receipts. Only world positions move. Topology checksum
  expected to survive byte-identical; if position feeds it, re-freeze is
  sanctioned and documented.

## 4. Hub unification — the careful part

Phased so estate.gd never breaks:
- **G1** author the terrain + path network + stations; board snaps on. Hub
  stays where it is (its own plateau) — untouched.
- **G2** the three lands dressed (biome kits, landmarks, props-in-place —
  the old C-step folds in here).
- **G3** THE MIGRATION: the hub's landmarks (theater, wardrobe stall,
  album wall, monuments) re-ground onto the forecourt terrain; walkabout
  bounds widen to the lands; ready-up = physically standing at the
  lychgate. estate.gd phase machine unchanged — only transforms move.
  Verified against the full estate smoke + all ceremony receipts.
- **G4** dressing waves + Estate Stirs events live in the world (the
  Reaper's shortcut carves through a REAL hedge wall).

Each phase lands with stills BEFORE the next fires. G1 includes the promised
**authored test stretch** (a hedge-maze segment of Garden Row) for approval.

## 5. Meshy environment manifest (draft — producer funds)

Terrain, paths, and water are in-engine (zero credits). Credits buy kits —
each kit = few base meshes, variation from rotation/scale/mirroring + mixed
variants (no visible repetition):

| Kit | Items | Est. credits |
|---|---|---|
| HEDGE MAZE | straight wall, corner, arch gap, broken/overgrown wall | ~120 |
| GARDEN | parterre bed, statuary ×2 (new poses), garden table, brook footbridge | ~150 |
| FOREST | tree ×4 variants, stump, root tangle, deadfall log, mushroom cluster | ~240 |
| BOG | twisted willow ×2, reed cluster, hummock, half-sunk fence, gallows tree | ~180 |
| LANDMARKS | maze centerpiece (weeping statue court), forest shrine tree, valley watch-ruin | ~110 |
| RETEX/FIXUPS | contingency for style misses | ~100 |
| **Total** | ~22 items | **~900cr** |

Balance after ZR ≈ 890 → **recommend topping up to ~2000cr** before G2 so
the wave runs uninterrupted (pull-immediately doctrine as always). Existing
heroes (gates, cart, shrine, bridges, NPCs, ~57-item catalog) all reused.

## 6. Perf envelope (the "gently push" clause)

Integrated-GPU targets: draw calls < ~1500 via MultiMesh for repeated kit
pieces (hedges/trees/reeds), LOD or imposters past ~40u for forest, one
Environment (EnvKit) + ≤12 dynamic lights live, water as a single animated
plane, no per-pixel extravagance. Richness = composition + variety, not
shader cost. Frame budget check in every GROUNDS lane receipt (windowed
fps probe on the full board flyover).
