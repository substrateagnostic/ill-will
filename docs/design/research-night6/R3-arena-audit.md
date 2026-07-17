# R3 — AAA ARENA / ENVIRONMENT AUDIT (ILL WILL, 14 minigames)

Lens: what the fixed camera actually sees below/beyond the play space, what
environmental depth exists, and the cheapest prop/plane/silhouette that would
transform each arena. Read-only pass over each `.tscn` + main `.gd`.

## Standing facts that shape every recommendation

- **Two lighting systems.** `core/env_kit.gd` (MOONLIT / CANDLELIT / STAGELIT)
  is the house look-as-code, adopted by 13 of 14 games. `minigames/widows_gaze`
  is the **lone holdout** still on a hand-rolled FILMIC `WorldEnvironment` — a
  house-consistency seam.
- **`scripts/arena_dressing.gd`** (`ArenaDressing.prop` / `.mound`) is the shared
  horizon helper. It loads any GLB id from `assets/models/meshy/generated/` (42
  props) or the wave-1 root. Already called by **tilt, greed, mower, swap_meet**
  (their `_build_b8_*` funcs). Pallbearers hand-rolls the same idea inline.
- **The B8 pass already happened** for the four outdoor arenas — the director's
  "TILT floats over nothing" is slightly dated: tilt has an ocean + 5 skerries.
  The *live* gap is that the space below/beyond is **present but inert** — a flat
  green disc, a flat purple box, a flat black void. The AAA move is to give that
  space a **reveal or a sign of life**, not to invent dressing from scratch.
- **Big free win on disk:** `npc_crow_perched.glb` (contact-sheet KEEP: "black
  crow, folded wings, perched, alert") and `npc_crow_flapping.glb` (KEEP as a 2nd
  perched silhouette) are **forged and completely unused inside arenas**. The
  estate's signature bird only appears in the lobby (`core/ambient_life.gd`) —
  and even there as a *tinted seagull stand-in* (`CROW_GLB := ""`), because the
  real crow was never wired. Also forged-and-unused-in-arenas: `estate_broken_angel`
  (mournful bowed angel), `estate_dry_fountain` (raven on the rim), `grave_cherub_stone`
  (weeping cherub), `estate_covered_well`, `monument_obelisk_small`, `board_grim_signpost`,
  `board_hearse_cart` / `board_hearse_ornate`, `relic_funerary_urn`.
- **`AmbientLife` (crows/groundskeeper/ghost queue/seagull) is lobby-only** and
  hard-gated OFF during minigames (`is_visible_in_tree()`), so none of that life
  reaches an arena. Arena horizons are all static.

---

## Per-game table

| # | Game | Preset / camera | What the camera sees below / beyond | Existing dressing | What's missing | Cheapest transform | Meshy assets |
|---|------|-----------------|-------------------------------------|-------------------|----------------|--------------------|--------------|
| 1 | **tilt** | MOONLIT · cam (0,15.5,14.5)→(0,0.4,0) fov50 | Platter over a flat green ocean disc (70r, y=-6). Pawns splash into it and vanish. 5 rock skerries (arc 215–335°, r15–18) carry estate props on the far horizon. | `_build_b8_horizon`: mausoleum, dead trees, headstones, 1 lit lamppost, obelisk on mounds (`ArenaDressing`). Ocean is mirror-calm StandardMaterial. | **The sea itself is empty** — the director's flagged shot. The fall pays off into nothing. No life on the near water. | Drowned-heirs graveyard breaking the surface *near the splash zone* (existing `grave_tilted_slab` / `grave_mausoleum_front` / `grave_headstone_cracked` set low so only tops show) + ONE slow circling threat (dark fin, or a forged leviathan eye / colossus hand the splash reveals). Perch a crow on the nearest skerry. | REUSE grave props + `npc_crow_perched`. OPTIONAL forge: `leviathan_eye` or `drowned_colossus_hand`. |
| 2 | **greed** | CANDLELIT · cam (0,15.5,12.8)→(0,0.9,0) fov56 | Warm wood vault floor, felt money-pit inlay, 4 low walls (h1.4). Reads as a gold-rimmed slab in black. | `_build_b8_dressing`: broken columns + iron gate + 2 dim stone lanterns on the −z far side ("antechamber past the money-room"). | Only the far (−z) wall has depth; the vault ceiling/upper walls are pure black — the room has no *top*. | Hang the black above the walls: a couple of tall crates/`broken_column` shadows + a faint hanging chandelier or a barred cellar window (emissive) on the back wall so the vault feels enclosed, not floating. A crow on the iron gate. | REUSE `broken_column`, `estate_iron_gate`, `npc_crow_perched`. 0 forge. |
| 3 | **dead_weight** | CANDLELIT attic · cam (0,13.5,11.5)→(0,0.3,-0.4) fov52 | 12×12 slab; walk off the ±6 lip into a void. Dark room floor 64×64 (y=-6.75), a chunky table the diorama rests on, a warm amber "void ring" gutter. Dust motes drift. | `_build_surround` (room floor + table) + `_build_void_ring`. Genuinely dressed as a warm attic diorama. | The room *beyond* the table is undifferentiated dark floorboards — no furniture silhouettes to sell "attic." | A few tall attic silhouettes past the table edge (existing `wardrobe`, `armchair`, `table_lamp` wave-1 props) so the diorama sits in a *room*, not on an island of table. | REUSE `wardrobe`, `armchair`, `table_lamp`. 0 forge. |
| 4 | **masked_ball** | STAGELIT ballroom · cam (0,11.6,12.2) fov45 | 21×15 parquet floor, bespoke candle BallSpot pool, throne, chandeliers. Crowd of 20 dancers. | `_build_ballroom` / `_build_throne` / `_build_chandeliers`. Rich mid-ground. | No walls / upper architecture — the ballroom fades to black above the floor; grand room reads as a lit rug in a void. | Tall arched windows or hanging estate banners (emissive quads, house plum + moonlight) upstage behind the throne so the glints have somewhere to live. | Procedural emissive planes; OPTIONAL reuse `manor_gate`. 0 forge. |
| 5 | **seance** | CANDLELIT/STAGELIT · cam (0,7.35,8.9)→(0,0.72,-0.4) fov42 | Low, intimate. Plank stage 22×20, séance table, spirit board, TableSpot candle pool. | `_build_stage` / `_build_table` / `_build_board`. The dark IS a mechanic (eyes-closed beats). | Intentionally dark, so restraint is right — but the stage edges dissolve to nothing; no hint of the room holding the séance. | One or two candelabra/`stone_lantern` silhouettes at the stage edge + a shrouded portrait/`estate_broken_angel` half-lit upstage — depth without lifting the dark. | REUSE `stone_lantern`, `estate_broken_angel`. 0 forge. |
| 6 | **understudy** | STAGELIT theater · cam (0,3.55,8.7)→(0,1.35,0) fov52 (frontal) | Boards 13×7, back wall, painted backdrop panel with an **emissive moon**, red curtains, footlights, house seats. | `_build_stage/_curtains/_footlights/_house_seats`. **Best-dressed interior** — a real stage picture. | Very little — the backdrop already carries the depth. Maybe empty above the proscenium. | (Low priority) A hint of fly-loft / hanging sandbags above, or an audience silhouette bump in the dark house. | 0 forge. Lowest-need arena. |
| 7 | **echo_chamber** | STAGELIT shrinking ring · cam (0,16.5,12.5)→(0,0.5,0) fov52 | Warm tabletop discs on a 30r table (y=-9.8) inside a culled well-wall ring. **Round 5: the outer disc falls away and fighters ring out into black.** | `_build_surround` (table + well-wall), inner/outer discs, glowing ring boundary, pillars. | The ring-out — the whole climax of the mode — drops losers into **flat black**. The well has no bottom, no reveal. | Give the well a lit bottom far below: a heap of bones / grasping hands / a green pit-glow so round-5 elimination *reveals where the losers go*. Bone heap = existing grave props scattered at the pit floor + one green OmniLight. | REUSE grave props. OPTIONAL forge: `bone_pile` or `grasping_hands`. |
| 8 | **mower** | MOONLIT lawn · cam (0,15,10.2)→(0,0,-0.2) fov52 | 16×12 lawn, cut-stripe coverage meter is the score. Enclosed by low hedges. | `_build_b8_horizon`: headstones, 2 dead trees, 2 lit lampposts, cracked stone, obelisk just past the hedge line (`ArenaDressing`). Well-dressed horizon. | Horizon is static gravestones — no *life*. A night lawn wants a bird. | Perch 1–2 crows on the horizon headstones/lampposts; optionally a `estate_dry_fountain` (raven on rim) or `estate_wheelbarrow` in a corner as groundskeeper's-tools flavor. | REUSE `npc_crow_perched`, `estate_dry_fountain`, `estate_wheelbarrow`. 0 forge. |
| 9 | **pallbearers** | MOONLIT procession · cam (0,13.5,21)→(0,0.7,-4) fov60 | Ground plane 30×44, two gravel lanes, mud + downhill bands, twin crypt doors (warm glow), swing gates, hooded-capsule mourners with candles, 5×3 scattered headstones. | `_build_ground/_lanes/_crypt/_gates/_mourners/_scatter_graves`. **Richest arena** — reads as real estate grounds. | Mourners are grey capsules — the one crude element in an otherwise finished set. | Swap capsule mourners for the forged `npc_mourner_hooded` / `npc_mourner_elderly` (KEEP; already on disk, used only in the lobby). Perch crows on the scattered graves. | REUSE `npc_mourner_hooded`, `npc_mourner_elderly`, `npc_crow_perched`. 0 forge. |
| 10 | **swap_meet** | MOONLIT night market · cam (0,28.5,22)→(0,0,0.9) fov45 | Kart track on a 24.2r felt table; room floor 240×240 far below (y=-7.5) catches the shadow. Castle, obstacles, windmill booms. | `_build_b8_horizon`: lamppost ring + iron gate + hedges on the felt rim (`ArenaDressing`) + minigolf castle/windmill decor. Dressed. | Steep top-down; the far room floor is a flat brown plane — the "market at night" needs market silhouettes, not just estate props. | A couple of `market_stall` (wave-1) + `board_grim_signpost` on the felt rim, crows on the lampposts, to sell "night market" over "kart circuit." | REUSE `market_stall`, `board_grim_signpost`, `npc_crow_perched`. 0 forge. |
| 11 | **last_will** | MOONLIT gauntlet · traveling cam (0,13.9,11.8) | Funeral-procession pier over a **deep-purple sea** (unshaded box 520×260 at y=-26) that silhouettes falling bodies. Traveling embers. Overview shot looks down the whole route. | `_build_world` sea + `LWCourse` + hazards (pendulums, spinner, walls). The sea below is a genuine, thematic void floor. | The sea is a flat purple slab — falling bodies silhouette against *nothing*. The hero overview shot has an empty vanishing point. | Silhouettes in the sea: a half-wrecked hearse-barge + 2–3 leviathan `ArenaDressing.mound` humps at the vanishing point, so every void-fall and the survey shot reveal something down there. | REUSE `board_hearse_ornate` (tint dark) + `ArenaDressing.mound`. 0 forge. |
| 12 | **widows_gaze** | *FILMIC (own env!)* parlor · cam (0,16.5,18.5)→(0,0.4,-1.6) | Enclosed mourning parlor: parquet floor, walls, coffin/bier, relic pedestals, furniture, candles, the Widow upstage. ProceduralSky bg. | `_build_floor/_walls/_wake_end/_rope_end/_furniture/_relics` + `WGWidow`. Fully enclosed, well-furnished. | **Not an arena-depth gap — a house-look seam.** Only game NOT on EnvKit; uses FILMIC tonemap + hand-rolled sun/fill, so its blacks/glow don't match the anthology. | Convert to `EnvKit.CANDLELIT` (matches the interior siblings). Add `add_dust_motes` for the still parlor air. Medium risk (an approved look changes). | 0 forge. Consistency fix, not dressing. |
| 13 | **throne** | CANDLELIT great hall · cam (0,10.6,11.3)→(0,1.15,-0.35) fov49 | Floor 12×12, red carpet + runner, 3-step dais, throne, corner pillars + flickering torches, four **3.4-tall** walls. | `_build_floor/_carpet/_dais/_throne/_pillars_and_torches/_walls`. Dressed mid-ground. | At this pitch the camera looks **over the low back wall into pure black** — the hall has no upper architecture; grandeur stops at 3.4m. | A tall emissive **stained-glass arched window** (house plum + gold) behind/above the throne — blooms under AGX glow, gives the flung-crown climax a backdrop. Or twin hanging estate banners. | Procedural emissive quad + leading. 0 forge. |
| 14 | **orbital** | Bespoke space (AGX) · cam space rig | Planets in orbit over a 700-star field (r48–70), lethal ball trails, ghost-meddle pulses. | `_build_stars/_build_planet_visual` + threat fx. Bespoke, deliberate, approved x-ray reads. | Little — the void is the *point* here and the starfield already fills it. | (Low priority) A distant nebula gradient plane or one ringed gas-giant silhouette for a hero backdrop; risk of muddying the threat reads, so leave unless asked. | 0 forge. Leave as-is. |

---

## Cross-cutting themes (ranked by impact-per-effort)

1. **Crows everywhere (one shared change, 5+ arenas).** `npc_crow_perched` is a
   KEEP asset sitting unused. Add a thin `ArenaDressing.crow()` convenience (or
   just `ArenaDressing.prop(self,"npc_crow_perched",0.4,pos,yaw)`) and drop 1–3
   onto the *existing* horizon props of tilt / mower / greed / swap_meet /
   pallbearers. The estate's motif bird, currently absent from every arena, now
   silhouetted on the gravestones across the whole anthology. ~2h, **0 forge.**

2. **Inert space → reveal.** tilt's sea, echo_chamber's well, last_will's sea are
   all flat voids under the climax beats. Each wants ONE silhouette/reveal so the
   fall pays off. Mostly reuse (grave props, mounds, hearse); at most one hero
   forge (leviathan / grasping hands).

3. **Interiors have no ceiling.** greed / masked_ball / throne all read as a lit
   floor in black because nothing lives above the low walls. Cheapest fix is an
   emissive upper element (barred window, arched stained glass, hanging banner)
   — 0 forge, blooms under AGX.

4. **Two housekeeping items** (note, not dressing): wire the real crow into
   `AmbientLife` (`CROW_GLB` still `""`), and bring `widows_gaze` onto EnvKit.

---

## TOP 5 (impact per effort) — returned to director

1. **Crows on every outdoor horizon** — a shared `ArenaDressing` helper + drops in
   tilt/mower/greed/swap_meet/pallbearers. ~2h, asset on disk, 0 forge.
2. **TILT: the sea stops being empty** — drowned-heirs graveyard breaking the
   surface by the splash zone + one circling threat. ~2–3h; 0 forge (reuse) or 1
   hero forge (`leviathan_eye`/`drowned_colossus_hand`).
3. **echo_chamber: the well gets a bottom** — round-5 ring-out reveals a lit pit
   (bone heap + green glow). ~2h; 0–1 forge (`bone_pile`/`grasping_hands`).
4. **throne: stained-glass window kills the dead black** above the back wall.
   ~1.5h, emissive quad, 0 forge.
5. **pallbearers: swap capsule mourners for the forged `npc_mourner_*`** (KEEP,
   already on disk) + crows on the graves. ~1.5h, 0 forge.
