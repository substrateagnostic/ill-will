# 07 — Visual Polish Audit (Art Director's Sweep)

Date: 2026-07-05. Engine: Godot 4.6.2, windowed captures via the VerifyCapture
harness, every screenshot read by eye. House look: warm chunky diorama (KayKit
characters, Kenney minigolf, Meshy props). Evidence shots:
`docs/verify/shots/polish_audit_*.png` (full set also under `verify_out/audit/`).

Severity scale:
- **JARRING** — obvious primitive/placeholder, breaks the diorama look
- **NOTICEABLE** — visibly primitive, but doesn't destroy the read
- **FINE-AS-IS** — primitive or simple, but charming/diegetic; do not churn

---

## Estate (title / lobby / grounds / auction / will reading)

Shots: `polish_audit_title.png`, `polish_audit_estate_stroll.png`,
`polish_audit_estate_auction.png`, `polish_audit_will_reading.png`.

| Finding | Where | Severity | Prescription |
|---|---|---|---|
| Market stall = 2 bare CSG boxes (grey slab + flat roof) beside the Meshy gilded pot | `estate/estate.tscn:158-166` | **JARRING** | Meshy market stall w/ striped canopy, same footprint (~2×1.5×1 + roof) |
| Monument obelisks = flat colored hex/box slabs ("Champion of Night N"), on-screen every phase, every night | `estate/estate.gd:1353` (`_redraw_monuments`) | **JARRING** | Stone obelisk/trophy plinth GLB, per-player tint band. **FENCED (estate.gd owned by another agent) — backlogged** |
| Picnic toys = 3 bare colored spheres on the lawn | `estate/estate.gd:646` (`_spawn_toys`) | NOTICEABLE | Beach ball / pumpkin / garden gnome props. **FENCED (estate.gd) — backlogged** |
| Graffiti wall = grey CSG slab (the Label3D text on it is the point; slab reads as a wall) | `estate/estate.tscn:171` | NOTICEABLE | Ivy-edged manor wall segment; low priority, text carries it |
| Trail pawns + gate statues = colored capsules | `estate/trail.gd:84` (`_make_pawn`) | NOTICEABLE | Capsules read as board-game pawns (intentional board metaphor); a chess-pawn GLB would be nicer but is not urgent |
| Trail stepping stones (tapered cylinder discs) + torus tollgate arches | `estate/trail.gd:40-59` | FINE-AS-IS | Read as stepping stones/rings — charming, do not churn |
| Executor desk (wooden box desk beside podium) | `estate/estate.tscn` (Desk nodes) | FINE-AS-IS | Reads as chunky writing desk; auction podium GLB sits next to it |
| Title screen: 4 KayKit heroes + logo on dark void | `estate/estate.gd` title | FINE-AS-IS | Strong read; void backdrop is a deliberate stage |
| Manor gate, castle, theater stage, stone lanterns, executor butler | estate.tscn | FINE-AS-IS | Already Meshy/Kenney — the house look works |

## Par for the Curse (flagship golf, all courses)

Shots: `polish_audit_par_fairway.png`, `polish_audit_par_crusher_fans.png`,
`polish_audit_par_spinner.png`, `polish_audit_par_magnet.png`.

| Finding | Where | Severity | Prescription |
|---|---|---|---|
| Crusher = brown box hammer stacked on striped box pad + skinny cylinder pillar; most placeholder object in the flagship game | `scenes/traps/crusher.tscn` | **JARRING** | Meshy iron press-head/anvil block scaled into the exact 0.85×0.55×0.85 hammer footprint (collision untouched) |
| Spinner = flat orange box-cross on a grey disc (reads as paper pinwheel) | `scenes/traps/spinner.tscn` | **JARRING** | Meshy 4-arm wooden sweeper cross fitted to the 2.0-span arm footprint |
| Fan = flat yellow zone + bare white pole + thin disc (unreadable as "fan") | `scenes/traps/fan.tscn` | **JARRING** | Meshy standing pedestal fan (caged blades) at same pole position; keep yellow wind-zone tint |
| Magnet post = skinny grey pole + colored cap + pink rings | `scenes/traps/magnet.tscn` | NOTICEABLE | Horseshoe-magnet-on-post GLB; rings already sell the effect (backlogged, budget) |
| Spikes = cylinder posts (not even cones) on a box plate | `scenes/traps/spikes.tscn` | NOTICEABLE | Cone spikes or spike-strip GLB (backlogged) |
| Black hole = dark disc + torus ring | `scenes/traps/black_hole.tscn` | FINE-AS-IS | Reads instantly as a void disc; motion sells it |
| Wall/moving wall/ramp/boost/water/sand/ice/trampoline/bumper/portal | `scenes/traps/*` | FINE-AS-IS | Read as minigolf furniture in the Kenney idiom |
| Windmill + tunnel traps | `scenes/traps/{windmill,tunnel}.tscn` | FINE-AS-IS | Already Kenney minigolf GLBs |
| Gravestone death markers (box + cylinder top), accrete every round | `scenes/gravestone.tscn` | NOTICEABLE | Proper headstone GLB would compound across 9 rounds. **FENCED (scenes/ outside trap allowance) — backlogged** |
| Courses (fairway/dogleg/green/the_gauntlet) | `scenes/courses/` | FINE-AS-IS | Kenney flags/castle/windmill/obstacles already dress them |

## Dead Weight — the biggest single win

Shot: `polish_audit_dead_weight.png`.

| Finding | Where | Severity | Prescription |
|---|---|---|---|
| ALL FOUR possessable props are primitives: LAMP = cylinder, CRATE = cube, CHAIR = box, WARDROBE = box. The furniture IS the game ("THE DEAD POSSESS THE FURNITURE") and every one is a bare brown block | `minigames/dead_weight/prop.gd:123-141` (`_tier_mesh`) | **JARRING** | WARDROBE → existing `meshy/wardrobe.glb`; LAMP → existing `meshy/table_lamp.glb` (both free); CRATE + CHAIR → 2 Meshy generations. Keep collision shapes + possession glow (emissive overlay) |
| Attic table / rug / void-edge glow bars | `dead_weight.gd:161-229` | FINE-AS-IS | Diorama table + glowing boundary read great |

## Last Will

Shots: `polish_audit_last_will_pendulum.png`.

| Finding | Where | Severity | Prescription |
|---|---|---|---|
| Pendulum = box gallows arm + box plank blade w/ slats; dominates the screen while sweeping | `minigames/last_will/lw_pendulum.gd:64-125` | **JARRING** | Meshy scythe/axe pendulum blade on the same swing pivot, same blade footprint |
| Boulder = sphere + 4 sphere lumps | `minigames/last_will/lw_boulder.gd:79` | NOTICEABLE | Lumpy rock reads OK in the dark palette; proper rock GLB backlogged |
| Yard lanterns = box posts + box cages (many) | `minigames/last_will/last_will.gd:447` | NOTICEABLE | `stone_lantern.glb` already exists — free swap, backlogged (perf: ~16 instances) |
| Broken chapel arch (background boxes) | `last_will.gd:363-417` | NOTICEABLE | Background silhouette; acceptable at distance |
| Skeletal hand cursor (box bones) | `lw_hand.gd:28` | FINE-AS-IS | Deliberate procedural skeleton art, reads well |
| Circular graveyard platter + gravestones | `last_will.gd:594` | FINE-AS-IS | Dark palette carries them |

## Echo Chamber

Shot: `polish_audit_echo.png`.

| Finding | Where | Severity | Prescription |
|---|---|---|---|
| 3 cover pillars = bare brown cylinders in a bare brown arena — the only objects in the game | `minigames/echo_chamber/echo_chamber.gd:318` (`_spawn_pillars`) | **JARRING** | Meshy broken stone columns, same radius footprint (collision untouched) |

## Greed Inc.

Shot: `polish_audit_greed.png`.

| Finding | Where | Severity | Prescription |
|---|---|---|---|
| 4 vault crates = plain brown cubes | `minigames/greed/greed.gd:1121` (`_build_crates`) | **JARRING** | Same Meshy crate as Dead Weight's CRATE (shared asset, zero extra generations) |
| Corner chutes = glowing colored pads + funnel cones | `greed.gd:1075` | FINE-AS-IS | Glow + color = legible banking zones; motion/geysers sell them |
| Gilded pot + pedestal | `greed_pot.gd` | FINE-AS-IS | Already Meshy |

## Throne

Shot: `polish_audit_throne.png`.

| Finding | Where | Severity | Prescription |
|---|---|---|---|
| Corner pillars + sphere flames | `throne.gd:930` | FINE-AS-IS | Read as giant candles in the dark hall — accidentally great |
| Throne-room walls = flat brown box slabs | `throne.gd` (arena build) | NOTICEABLE | Would need banners/wainscot texture work, not a prop swap; backlogged |
| Crown = torus + 5 cone spikes | `throne.gd:681` | NOTICEABLE | Small on screen; gold material carries it. Backlogged (budget) |
| Throne itself | `throne.gd` | FINE-AS-IS | Already Meshy |

## The rest (verified fine)

| Game | Verdict | Notes (shot) |
|---|---|---|
| Seance | FINE-AS-IS | Candlelit table, cylinder-fold curtains, Ouija disc all read beautifully (`polish_audit_seance.png`). Planchette is small + dark; skip |
| Understudy | FINE-AS-IS | Box stage + curtains + sphere moon = intentional theater set (`polish_audit_understudy.png`) |
| Orbital | FINE-AS-IS | Planets are supposed to be spheres; starfield + ribbons lovely (`polish_audit_orbital.png`). White pedestal nubs = minor |
| Mower | FINE-AS-IS | Meshy mowers + trails carry it; flowerbeds (box + sphere flowers) mildly toy-like = NOTICEABLE, charming (`polish_audit_mower.png`) |
| Swap Meet | FINE-AS-IS | Fully Kenney-dressed track; wooden ramp reads fine (`polish_audit_swap.png`) |
| Tilt | FINE-AS-IS | Target-pattern platter + Meshy gull; pin barely visible (`polish_audit_tilt.png`) |

---

## Ranked fix list (visible-seconds-per-night × jarringness)

**FIXED (Phase 2 complete — see `docs/verify/visual-polish-VERIFY.md`; 8 Meshy generations + 2 free reuses):**

1. **Dead Weight furniture set** — wardrobe.glb + table_lamp.glb reuse (free) + **crate** + **chair** generations. The whole game is these props.
2. **Par crusher hammer** — **crusher head** generation. Flagship game, drafted constantly.
3. **Par spinner cross** — **sweeper blades** generation.
4. **Par fan** — **pedestal fan** generation.
5. **Greed vault crates** — reuse the crate generation (free).
6. **Last Will pendulum** — **scythe blade** generation. Screen-dominating hazard.
7. **Echo Chamber pillars** — **broken column** generation. Only objects in the arena.
8. **Estate market stall** — **market stall** generation (estate.tscn is in-fence).

**Backlogged (ranked, with reasons):**

1. Estate monument obelisks (`estate.gd:1353`) — highest-value estate fix, **gated on estate.gd fence**. Prescription: obelisk/plinth GLB, tint band per player, MeshyProp height ~1.3.
2. Shared gravestone prop (`scenes/gravestone.tscn` + `scripts/gravestone.gd`) — accretes all night in Par; outside my fence (scenes/ root). Prescription: headstone GLB swap-in.
3. Last Will yard lanterns → existing `stone_lantern.glb`, free but ~16 instances; verify perf then swap.
4. Estate picnic toys (`estate.gd:646`) — gated on estate.gd fence. Prescription: ball/gnome props.
5. Par magnet post — horseshoe magnet GLB (1 generation when budget refreshes).
6. Par spikes — cone spikes or spike-strip GLB.
7. Throne walls — needs texture/banner pass, not a prop swap.
8. Throne crown — small gold crown GLB (1 generation).
9. Last Will boulder — rock GLB.
10. Trail pawns (trail.gd, in-fence but FINE-adjacent) — chess-pawn GLB if ever.
11. Estate graffiti wall slab — ivy wall segment.
12. Mower flowerbeds — flower-box GLB.

Total placeholder findings: 31 (8 JARRING, 12 NOTICEABLE, 11 FINE-AS-IS clusters).
