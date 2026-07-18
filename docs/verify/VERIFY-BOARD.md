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
**and again after the P3 lane** (figurine pawns + ZF dressing + interludes:
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

## 4. THE CANONICAL MATCH RECEIPT (P3, frozen)

```
godot --headless --path . -- --procession --seed=7 --turncap=12 --nights=3 --autoplay=bots
```

**SUPERSEDED — the P2 match record** (sanctioned, this lane's brief): P3 adds
the INTERLUDE GROUNDS MINIGAME between nights (doc 28 §2 — two more settled
games per 3-night match, EVENT-stream draws), so the P2 record died with
honor. Its final form, for the record: seed 7 → **HEIR RED, wreaths
[61,32,45,48]**, board_firsts [3,0,0,0], night lines ending
`"grudge":[70,71,98,81]`. Any run that prints a 3-night match with NO
interlude settlements between nights is pre-P3.

frozen result (P3 — verified deterministic ×3, the PROCESSION_NIGHT /
PROCESSION_MATCH / PROCESSION_HEIR lines hash identically run to run; night 1
is byte-identical to P2's night 1, since the first interlude lands only after
its record prints):

```
PROCESSION_NIGHT {"arrivals":[0,1,2],"awards":[["longest",0],["generous",-1],["bloodiest",2]],"bell_round":6,"grudge":[16,26,47,18],"letters":[false,false,false,false],"night":1,"rounds":7,"wreaths":[17,8,15,5]}
PROCESSION_NIGHT {"arrivals":[2,3],"awards":[["generous",0],["uninvited",3],["longest",3]],"bell_round":5,"grudge":[18,56,44,63],"letters":[false,false,false,false],"night":2,"rounds":6,"wreaths":[26,16,30,26]}
PROCESSION_NIGHT {"arrivals":[2,1],"awards":[["generous",2],["bloodiest",1],["uninvited",3]],"bell_round":5,"grudge":[17,86,57,78],"letters":[false,false,false,false],"night":3,"rounds":6,"wreaths":[35,33,51,36]}
PROCESSION_MATCH {"board":"estate_procession","board_firsts":[1,0,2,0],"deeds":[2,1,1,2],"grudge":[17,86,57,78],"heir":2,"heir_name":"GOLD","heirs":[2],"mini_wins":[2,4,4,5],"moved":[73,82,83,82],"nights":3,"seed":7,"src":{"arrival":[14,15,25,9],"award":[8,4,8,12],"liquid":[1,8,5,7],"mini":[13,14,18,15]},"turn_cap":12,"wreaths":[36,41,56,43]}
  seat 0 RED: ⚘36 (arr 14 + mini 13 + awd 8 + liq 1)  17¢  ◆2  moved=73
  seat 1 BLUE: ⚘41 (arr 15 + mini 14 + awd 4 + liq 8)  86¢  ◆1  moved=82
  seat 2 GOLD: ⚘56 (arr 25 + mini 18 + awd 8 + liq 5)  57¢  ◆1  moved=83  HEIR
  seat 3 MINT: ⚘43 (arr 9 + mini 15 + awd 12 + liq 7)  78¢  ◆2  moved=82
PROCESSION_HEIR GOLD (seed 7, 3 nights)
```

Seed-sweep secondaries (single-run records, same command with the seed swapped):

```
PROCESSION_MATCH … "seed":1  → wreaths=[49,71,41,39]  heir BLUE  board_firsts=[0,3,0,0]
PROCESSION_HEIR BLUE (seed 1, 3 nights)
PROCESSION_MATCH … "seed":11 → wreaths=[30,36,69,59]  heir GOLD  board_firsts=[0,1,1,1]
PROCESSION_HEIR GOLD (seed 11, 3 nights)
```

Seed 11 remains the LETTERS witness: BLUE (4 wreaths after night 1, zero wins)
publicly accepts the LETTERS OF ADMINISTRATION on nights 2 and 3
(`"letters":[false,true,false,false]`) and closes at 36 wreaths — the dignity
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

frozen result (verified deterministic ×3):

```
PROCESSION_NIGHT {"arrivals":[0,1,2],"awards":[["longest",0],["generous",-1],["bloodiest",2]],"bell_round":6,"grudge":[16,26,47,18],"letters":[false,false,false,false],"night":1,"rounds":7,"wreaths":[17,8,15,5]}
PROCESSION_MATCH {"board":"estate_procession","board_firsts":[1,0,0,0],"deeds":[1,0,0,1],"grudge":[16,26,47,18],"heir":2,"heir_name":"GOLD","heirs":[2],"mini_wins":[1,0,3,1],"moved":[31,27,31,30],"nights":1,"seed":7,"src":{"arrival":[8,5,3,1],"award":[4,0,4,0],"liquid":[1,2,4,1],"mini":[5,3,8,4]},"turn_cap":12,"wreaths":[18,10,19,6]}
PROCESSION_HEIR GOLD (seed 7, 1 nights)
```

Worth reading twice: RED rings the bell first but GOLD's three minigame wins +
liquidation take the night by ONE wreath — end-of-game totals deciding, not
race position (doc 28 §0, the "robbed" metric alive in a receipt).

Turn-cap fallback (nobody crosses; DISTANCE RANKING pays the arrival wreaths —
doc 28 §8 rule 4):

```
godot --headless --path . -- --procession --seed=7 --turncap=4 --nights=1 --autoplay=bots
PROCESSION_NIGHT {"arrivals":[],"awards":[["longest",0],["generous",-1],["bloodiest",2]],"bell_round":-1,…,"rounds":4,"wreaths":[16,8,13,4]}
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

## 8. DELIBERATELY LEFT FOR LATER LANES

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
