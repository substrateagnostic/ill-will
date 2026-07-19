# VERIFY-BOARD — THE PROCESSION graph board (P1a graph · P2 economy, night 7+1)

The ring→graph surgery (doc 28 §3, RC-rework-audit risk #1) plus the P2 lane:
sequential LAST BREATH rolls (d8), the aim heatmap, PENNIES/WREATHS, the priced
Peddler's Cart, night awards, THE LETTERS, and the 3-night match. This file is
the canonical home for the board's receipts. Precondition for every command:
the import gate — `godot --headless --editor --import --quit --path .` (exit 0).

---

## 1. THE RETIRED RING RECEIPT (do not "fix" a soak back to it)

The frozen seed-7 RING receipt is **dead with honor** (sanctioned, doc 28 §13).
Its final form, for the record — command:

```
godot --headless --path . -- --procession --seed=7 --deedgoal=4 --autoplay=bots
```

result (24-space ring, Codicil economy, W8 re-dealt bands):

```
PROCESSION_HEIR MINT (seed 7, 21 rounds)
  RED  ◆5  24♠  moved=76  pos=0
  BLUE ◆1  62♠  moved=89  pos=13
  GOLD ◆3  33♠  moved=82  pos=4
  MINT ◆5  31♠  moved=95  pos=19
```

`--deedgoal` and `--preset` are RETIRED flags (accepted, ignored, announced).
The Codicil is retired as a purchase stop; `codicil.gd` and `board_path.gd`
stay on disk, unwired. Any run that prints the old shape is a regression.

## 2. THE TOPOLOGY RECEIPT (--boardgraphtest)

```
godot --headless --path . -- --procession --boardgraphtest
```

frozen output (verified byte-identical across runs; LAYOUT stream is seeded
from board DATA, never the night seed, so this is night-independent —
**re-verified unchanged after the P2 lane** (presentation-only marker pools)
**and again after the P3 lane** (figurine pawns + ZF dressing + interludes)
**and again after THE A-LOOK lane** (board de-neon: flat ground surrounds, ring
patterns, brightness heatmap, ZERO-ENGLISH labels — all pure rendering:
`checksum=b269c570` must never move, and did not)):

```
BOARDGRAPH board=estate_procession nodes=76 edges=79
BOARDGRAPH route=GARDEN ROW len=27 (a=12 b=13) walked_gate_to_gate=32
BOARDGRAPH route=HOLLOW WOODS len=23 (a=10 b=11) walked_gate_to_gate=28
BOARDGRAPH route=WEEPING VALLEY len=25 (a=12 b=11) walked_gate_to_gate=30
BOARDGRAPH types blank=32(42.1%) offering=14(18.4%) seance=12(15.8%) grave_goods=7(9.2%) open_grave=4(5.3%) ferry_toll=3(3.9%) cart=1(1.3%) crossroads=2(2.6%) gate=1(1.3%)
BOARDGRAPH dist lychgate=27 fork1=25 fork2=14 merge=2 gate=0
BOARDGRAPH reach fork1->garden=OK
BOARDGRAPH reach fork1->hollow=OK
BOARDGRAPH reach fork1->valley=OK
BOARDGRAPH reach fork2->garden=OK
BOARDGRAPH reach fork2->hollow=OK
BOARDGRAPH reach fork2->valley=OK
BOARDGRAPH checksum=b269c570
BOARDGRAPH_OK
```

(The full `BOARDGRAPH dist_all` per-node distance-to-finish line also prints —
it is part of the frozen output; grep `BOARDGRAPH_OK` for the pass gate.)

## 3. SUPERSEDED — the P1a single-night PUTT receipt

The P1a receipt (simultaneous pawn_putt rolls, free items, single night) is
**superseded by P2** (sanctioned: the meter replaces the putt, the priced cart
replaces the handout, the match replaces the lone night). Its final form:

```
godot --headless --path . -- --procession --seed=7 --turncap=12 --autoplay=bots
→ PROCESSION_HEIR RED (seed 7, 9 rounds)   bell_round=8 arrivals=[0,2,1]
  grudge=[8,23,32,20] moved=[29,29,33,31]
```

Any run that prints a `PROCESSION_TALLY` line is pre-P2. The same command
today runs a full **3-night match** (match_nights defaults to 3).

## 4. THE CANONICAL MATCH RECEIPT (DR — RETIRE THE DEED, frozen)

```
godot --headless --path . -- --procession --seed=7 --turncap=12 --nights=3 --autoplay=bots
```

**SUPERSEDED — the P3 deed-currency record** (sanctioned, DR lane / doc 29
option A, producer-ruled): the ◆ Deed vestige is retired. The three will
clauses now pay **+1 WREATH** to their stat leader — booked to the
announced-award stream (doc 28 §6), so `wreath_src.award` and the finale sums
stay honest — instead of a ◆ Deed nobody could win or spend with. The chip,
the match receipt (`"deeds"` field gone), and the net mirror all drop ◆
entirely, and THE HOUSE AWAKENS loses its undocumented `deeds==0 → +10pp
dodge` nudge (a flat `0.45` now, no replacement hook). The eulogy's flavor
"heir" is now the ACTUAL crowned heir (`_match_order()[0]`), never a ◆ pick
that could name one heir seconds before a different one is crowned. Will
payouts moving ◆→⚘ plus the flattened hazard shift the wreath totals, so the
P3 record died with honor. Its final form, for the record: seed 7 → **HEIR
GOLD, wreaths [36,41,56,43]**, deeds [2,1,1,2], board_firsts [1,0,2,0]. Any
run that prints a `"deeds"` field, a `◆` on a chip/receipt, or the old wreath
totals is pre-DR.

**SUPERSEDED — the P2 match record** (sanctioned, prior lane's brief): P3 adds
the INTERLUDE GROUNDS MINIGAME between nights (doc 28 §2 — two more settled
games per 3-night match, EVENT-stream draws), so the P2 record died with
honor. Its final form, for the record: seed 7 → **HEIR RED, wreaths
[61,32,45,48]**, board_firsts [3,0,0,0], night lines ending
`"grudge":[70,71,98,81]`. Any run that prints a 3-night match with NO
interlude settlements between nights is pre-P3.

frozen result (DR — verified deterministic ×3, the PROCESSION_NIGHT /
PROCESSION_MATCH / PROCESSION_HEIR lines hash identically run to run; night 1
is byte-identical to the `--nights=1` single-night's night 1 (§5), since the
first interlude lands only after its record prints):

```
PROCESSION_NIGHT {"arrivals":[0,1,2],"awards":[["longest",0],["generous",-1],["bloodiest",2]],"bell_round":6,"grudge":[16,26,47,18],"letters":[false,false,false,false],"night":1,"rounds":7,"wreaths":[18,8,15,6]}
PROCESSION_NIGHT {"arrivals":[2],"awards":[["generous",0],["uninvited",3],["longest",2]],"bell_round":4,"grudge":[30,52,58,32],"letters":[false,false,false,false],"night":2,"rounds":5,"wreaths":[27,15,35,21]}
PROCESSION_NIGHT {"arrivals":[1,2],"awards":[["longest",2],["bloodiest",3],["mourned",3]],"bell_round":5,"grudge":[42,79,79,66],"letters":[false,false,false,false],"night":3,"rounds":6,"wreaths":[33,31,51,42]}
PROCESSION_MATCH {"board":"estate_procession","board_firsts":[1,1,1,0],"grudge":[42,79,79,66],"heir":2,"heir_name":"GOLD","heirs":[2],"mini_wins":[2,2,5,5],"moved":[58,81,87,82],"nights":3,"seed":7,"src":{"arrival":[12,20,20,11],"award":[9,1,14,14],"liquid":[4,7,7,6],"mini":[12,10,17,17]},"turn_cap":12,"wreaths":[37,38,58,48]}
  seat 0 RED: ⚘37 (arr 12 + mini 12 + awd 9 + liq 4)  42¢  moved=58
  seat 1 BLUE: ⚘38 (arr 20 + mini 10 + awd 1 + liq 7)  79¢  moved=81
  seat 2 GOLD: ⚘58 (arr 20 + mini 17 + awd 14 + liq 7)  79¢  moved=87  HEIR
  seat 3 MINT: ⚘48 (arr 11 + mini 17 + awd 14 + liq 6)  66¢  moved=82
PROCESSION_HEIR GOLD (seed 7, 3 nights)
```

The `award` stream now carries the will-clause wreaths on top of the night
awards (e.g. GOLD's `awd 14` and MINT's `awd 14` include their clause wins);
there is no separate ◆ column anywhere.

Seed-sweep secondaries (single-run records, same command with the seed swapped):

```
PROCESSION_MATCH … "seed":1  → wreaths=[55,53,74,34]  heir GOLD  board_firsts=[1,0,2,0]
PROCESSION_HEIR GOLD (seed 1, 3 nights)
PROCESSION_MATCH … "seed":11 → wreaths=[38,33,62,58]  heir GOLD  board_firsts=[0,1,0,2]
PROCESSION_HEIR GOLD (seed 11, 3 nights)
```

(Seed 1's heir flipped BLUE→GOLD under the DR sim shift — the retired hazard
nudge and the ◆→⚘ will payouts re-decided a close match; expected, sanctioned.)

Seed 11 remains the LETTERS witness: BLUE (4 wreaths after night 1, zero wins)
publicly accepts the LETTERS OF ADMINISTRATION on night 2
(`"letters":[false,true,false,false]`) and closes at 33 wreaths — the dignity
floor doing balance work, announced, never hidden.

Interlude rules in the record: interlude 1 is drawn RANDOM from the night's
unplayed games; interlude 2 is picked by the current DOORMAT (bottom wreaths),
never repeating interlude 1's pick — bots pick from the EVENT stream, a human
doormat draws nothing (pure input). Settlements land AFTER the night record
prints, so each PROCESSION_NIGHT line stays the board-night's own score.

## 5. THE SINGLE-NIGHT RECEIPT (P2, frozen — `--nights=1`; **re-verified
## byte-identical after P3** — a lone night has no between-nights interlude)

```
godot --headless --path . -- --procession --seed=7 --turncap=12 --nights=1 --autoplay=bots
```

frozen result (DR — verified deterministic ×3; the `"deeds"` field and the ◆
per-seat column are gone, and the will clauses fold +1⚘ each into the `award`
stream):

```
PROCESSION_NIGHT {"arrivals":[0,1,2],"awards":[["longest",0],["generous",-1],["bloodiest",2]],"bell_round":6,"grudge":[16,26,47,18],"letters":[false,false,false,false],"night":1,"rounds":7,"wreaths":[18,8,15,6]}
PROCESSION_MATCH {"board":"estate_procession","board_firsts":[1,0,0,0],"grudge":[16,26,47,18],"heir":0,"heir_name":"RED","heirs":[0],"mini_wins":[1,0,3,1],"moved":[31,29,31,30],"nights":1,"seed":7,"src":{"arrival":[8,5,3,1],"award":[5,0,4,1],"liquid":[1,2,4,1],"mini":[5,3,8,4]},"turn_cap":12,"wreaths":[19,10,19,7]}
  seat 0 RED: ⚘19 (arr 8 + mini 5 + awd 5 + liq 1)  16¢  moved=31  HEIR
  seat 1 BLUE: ⚘10 (arr 5 + mini 3 + awd 0 + liq 2)  26¢  moved=29
  seat 2 GOLD: ⚘19 (arr 3 + mini 8 + awd 4 + liq 4)  47¢  moved=31
  seat 3 MINT: ⚘7 (arr 1 + mini 4 + awd 1 + liq 1)  18¢  moved=30
PROCESSION_HEIR RED (seed 7, 1 nights)
```

Worth reading twice: RED and GOLD both close at **19 wreaths** — dead level —
and the crown breaks RED's way on the FIRST announced tie-break (most board
firsts: RED rang the bell), never a coin flip (doc 28 §15). The published
chain deciding a tie, alive in a receipt. (Pre-DR this was GOLD by one wreath;
RED's clause win, +1⚘, pulled it level.)

Turn-cap fallback (nobody crosses; DISTANCE RANKING pays the arrival wreaths —
doc 28 §8 rule 4):

```
godot --headless --path . -- --procession --seed=7 --turncap=4 --nights=1 --autoplay=bots
PROCESSION_NIGHT {"arrivals":[],"awards":[["longest",0],["generous",-1],["bloodiest",2]],"bell_round":-1,…,"rounds":4,"wreaths":[17,8,13,5]}
PROCESSION_HEIR RED (seed 7, 1 nights)
```

## 6. NAMED RNG STREAMS (Codex correction, adopted — P2 revision)

| Stream | Var | Seeded by | Draws |
|---|---|---|---|
| LAYOUT | board_graph local | `BOARD.layout_seed` (board DATA) | stone-type placement — never the night seed, so §2 never re-freezes with night features |
| ROLL | `_roll_rng` | seed×1103515245+12345 | ONE randi per turn seeds that turn's child stream (LAST BREATH consumes crit band + period + one face draw from it; bot brains use a salt-derived sibling), bot aim scans, bot crossroads choices |
| EVENT | `_event_rng` | seed×22695477+1 | séance slots, box draws, bot shop/item policy, minigame draw + minisim, award draws + visible tie-breaks, house-awakens |
| VOICE | `_voice_rng` | seed×134775813+5 | Executor line picks incl. LETTERS readings (presentation — pool edits can't shift the tally) |
| DRAMA | `_drama_prng` | seed×2246822519+3266489917 | interim lines, epitaphs (presentation, human-visible paths only) |

Humans draw NOTHING at a crossroads, an item prompt, or the cart (pure input),
so a mixed table diverges from the soak only through their choices, as designed.

## 7. SCREENSHOTS (windowed capture)

```
godot --path . -- --procession --seed=7 --turncap=12 --nights=1 --autoplay=bots --slowsim --outdir=verify_out/procession_p3
godot --path . -- --playmenutest --quitafter=500 --outdir=verify_out/procession_p3
```

(`--slowsim` keeps ceremonies at full length so the announce cards render.)
Exit `-1073741819` after the snaps is the known harmless shutdown segfault.
Committed under `estate/procession/shots/` (P3 set):

- `p3_figurine_pawns.png` — the four toy figurines on their stones (frozen
  sculpt pose, seat-colour bases, glaze).
- `p3_overshoulder_heatmap.png` — the over-shoulder roll frame: figurine
  shoulder, heatmap percentages glowing down the road, meter bottom-center.
- `p3_standings_drive.png` — the thinking budget in one frame: standings
  strip (rank/route/items), THE DRIVE inset, the meter — all during a roll.
- `p3_lychgate_dressed.png` / `p3_manor_gate_dressed.png` — the ZF hero
  gates dressing the start and finish.
- `p3_reaper_dormant.png` — THE REAPER looming motionless at the graveyard
  edge, barely lit.
- `p3_play_menu.png` — the simplified PLAY panel: THE PROCESSION only,
  nights + turn-cap dials, GO.

P2's shots (`p2_peddler_cart.png`, `p2_night_awards.png`,
`p2_reading_totals.png`) remain valid; `p2_breath_heatmap.png` is superseded
by the over-shoulder frame. P1a's board shots remain valid — topology
unchanged.

## 7a. THE A-LOOK — board de-neon presentation notes (this lane)

Producer-approved mockup **option A** (THE GROUNDS BAR, doc 28 §0a — the
ZERO-ENGLISH law made visible). PRESENTATION ONLY: every change is in
`board_graph.gd` rendering + `procession.gd`/`last_breath.gd` HUD plumbing; the
topology receipt (§2) and the match record (§4) were re-run and are unchanged.
The key discovery from the mockup lane: the old "neon arches" were the stone-rim
`TorusMesh` **rotated upright** (`rotation_degrees.x = 90`) — laid FLAT (no
x-rotation) the same torus becomes a ground-surround ring inlaid in the lawn.

What changed:

1. **GROUND SURROUNDS.** Every stone's rim torus is now flat on the ground,
   space-type tinted but SUBTLE and AGX-friendly (emission ≈1.3 typed / ≈0.14
   path — was a 2.6 upright neon rim). Path stones get a near-neutral whisper;
   specials a touch stronger + a soft inlay pool. All arch/neon verticals gone.
2. **LABELS DIE.** The always-on floating space-name tags AND the engraved rune
   glyphs are removed; so are the always-on "THE LYCHGATE" / "THE MANOR GATE"
   captions (the hero arch + the one warm gold gate-glow carry those). A space's
   NAME now surfaces ONLY: on the stone a travelling pawn will LAND on (the new
   `board.show_landing_label()`, driven at `travel_cut`, cleared after the
   reveal); at the crossroads prompt (the 2D picker, unchanged); and within ~2
   stones of a walkabout stroller (`board.reveal_names_near(world_pos, radius)`
   — a pooled per-frame API for the estate hub to drive; see "left for later").
3. **HEATMAP = BRIGHTNESS.** The aim heatmap lost its `%` text entirely.
   Probability is now ring **brightness/intensity** on the candidate stones
   (likelier = brighter), gently pulsing with the sweep. TYPE keeps the HUE
   (`S.color(type)`), heat modulates only INTENSITY — the candidate ring shares
   the stone's ground surround (flat, concentric). A crit-band release in
   prospect (`breath.in_crit_band()`) sharpens the contrast (brightest brighten,
   dimmest dim). Reads at couch distance; zero numbers anywhere.
4. **PATH RIBBON.** Route-tint on the world flagstones dimmed to near-subliminal
   (albedo lerp 0.14 → 0.05, base darkened). Route IDENTITY lives in THE DRIVE
   minimap (`board_minimap.gd`); the world stays dark and moody.
5. **RING PATTERN per type** — the colour-blind-safe interim read until the
   C-props lane gives each stone its own object (with text gone, type otherwise
   reads by HUE alone). Cheap accent geometry on the flat surround:

   | Type | Pattern | Read |
   |---|---|---|
   | `offering` | **SOLID** | clean full ring |
   | `seance` | **DASHED** | bright beads spaced around the ring |
   | `grave_goods` | **DOUBLE** | a second concentric inner ring |
   | `open_grave` | **NOTCHED** | radial tick bars crossing the ring |
   | `ferry_toll` | **GATED** | two cross-bars straddling the ring (toll arms) |
   | `crossroads` | **SPOKED** | four short spokes toward the centre |
   | `cart` / `gate` | **SOLID** | already unmistakable by hero prop + light |

**Screenshots** (throwaway probe `tools/board_alook_shots.tscn`, windowed;
committed under `estate/procession/shots/`):

```
godot --path . tools/board_alook_shots.tscn -- --outdir=verify_out/board_alook
```

- `alook_overview.png` — the de-neoned board from the overview home: flat inlaid
  ground rings, no uprights, no floating text.
- `alook_roll_heatmap.png` — roll phase, brightness heatmap live down the road,
  NO percent anywhere.
- `alook_ring_patterns.png` — a close pass: solid (offering) / dashed (séance) /
  double (box) / notched (open grave) rings side by side.
- `alook_crossroads.png` — a crossroads: the road picker + the in-world landing
  label, the ONLY names visible.

Out of scope (noted, not touched): the WREATH-OF-DEBT "DEBT" marker (an
announced-sabotage visibility feature, Pro Rules) and the per-pawn player-name
tags (player identity for a 4-up couch) stay — neither is a space-name label.

## 7b. THE GROUNDS G1 — the world-first inversion (doc 33, ninth watch)

The land is authored FIRST now. `estate/procession/grounds.gd`
(ProcessionGrounds) owns terrain (pure deterministic height function —
hand-rolled value noise, NO FastNoiseLite Resource, engine-version-proof),
authored path splines with real surfaces (flagstone approach / gravel garden /
grass maze / dirt hollow / causeway+plank valley / cut-stone climb), shaped
water (pond + brook, contour-clipped — never a plane edge), THE HEDGE MAZE
(4x7 authored grid, true path = garden_a's spline, dead-end branches, THE
CART COURT cell so the hearse hero parks clear of the walls), bridges (bone
bridge hero + garden footbridge), the terrain-rim droop, and the manor
silhouette on its rise (lit windows — the moving target visible from the
lychgate). `board_graph.generate()` consumes
`ProcessionGrounds.station_map()`: stations are arc-length-even, deck-aware,
≥2 stone-widths apart; the bezier + BOARD geometry fields died.

**RE-VERIFIED after the inversion, byte-identical, clean exit 0:** the §2
topology receipt (`checksum=b269c570 BOARDGRAPH_OK` — positions were never
hashed) and the §4 match receipt (seed 7 → HEIR GOLD, wreaths [37,38,58,48]
×3). Proven twice over: the noise swap moved every station's height between
runs and neither receipt moved — world positions feed presentation only.

Furniture ground-snaps through `_gsnap` (shallows clamp — nothing drowns on
the lakebed, nothing floats). Hop tweens scale arc/hang-time with station
gaps. `OVERVIEW_POS` climbed to frame the ~3x world. `reveal_names_near`
default radius 6→15 (≈2 stones at the new spacing).

**Screenshots** (probe `tools/grounds_shots.tscn`, windowed):

```
godot --path . tools/grounds_shots.tscn -- --outdir=verify_out/g1_grounds
```

Committed under `estate/procession/shots/` as `g1_*.png`: the TEST STRETCH
(maze overhead / corridor / mouth) + the lands (overview, boardwalk, bone
bridge, merge climb, forecourt, brook bridge).

Left for G2+: Meshy biome kits re-dress the same hedge wall lines / forest /
bog (doc 33 §5 manifest, ~900cr), brook shimmer + reeds, fireflies, the
windowed fps flyover probe (deferred until the heavy kits land — G1 is
MultiMesh + one terrain draw + one water draw), walkabout reveal wire-up
(unchanged contract), G3 hub migration.

## 8. DELIBERATELY LEFT FOR LATER LANES

- **Walkabout approach-reveal wiring (A-LOOK):** `board.reveal_names_near()` is
  built + verified, but the estate walkabout hub (`estate.gd`) does not yet call
  it each frame with the stroller's ground position. The board-side contract is
  ready; the hub wire-up rides the next estate-grounds lane.
- **C-props (next lane):** each special stone gets its own physical object so
  type reads by silhouette, not hue + ring-pattern. The A-LOOK ring patterns are
  the interim colour-blind read until then.

- **Estate Stirs (doc 28 §4):** the topology-event pools + THE CRYPT; THE
  REAPER stands dormant on the grounds until that lane wakes him.
- **P5 (online):** `_net_state` does not yet carry wreaths/inventory/match
  fields; LAST BREATH mirror re-cert per landmine 9 (roll_id/start-tick,
  reliable STOP intent).
- pawn_putt.gd stays on disk untouched (Par receipts reference its constants).
- CLASSIC NIGHTS is retired at the **UI level only** (P3): the PLAY panel no
  longer offers it, but its transition chain stays dormant on disk for the
  excision lane (landmine 6 — remove with replacement continuations).

**P3 probes:** `--parprobe` (with `--autoplay=bots`) exercises the legacy Par
catalog adapter end-to-end — real root-parented launch, real
finished(results), validated placements — recorded run: seed 7 →
`PARPROBE placements=[0, 3, 1, 2]`, exit 0. Real couches (any local human)
now play REAL minigames per cycle; probes and all-bot soaks keep the
deterministic minisim unless `--realmini`.
