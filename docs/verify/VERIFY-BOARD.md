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
**re-verified unchanged after the P2 lane**, whose board_graph additions are
presentation-only marker pools):

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

## 4. THE CANONICAL MATCH RECEIPT (P2, frozen)

```
godot --headless --path . -- --procession --seed=7 --turncap=12 --nights=3 --autoplay=bots
```

frozen result (verified deterministic ×3 — the PROCESSION_NIGHT /
PROCESSION_MATCH / PROCESSION_HEIR lines hash identically run to run):

```
PROCESSION_NIGHT {"arrivals":[0,1,2],"awards":[["longest",0],["generous",-1],["bloodiest",2]],"bell_round":6,"grudge":[16,26,47,18],"letters":[false,false,false,false],"night":1,"rounds":7,"wreaths":[17,8,15,5]}
PROCESSION_NIGHT {"arrivals":[0,2,3,1],"awards":[["longest",3],["mourned",3],["bloodiest",1]],"bell_round":6,"grudge":[42,57,67,53],"letters":[false,false,false,false],"night":2,"rounds":7,"wreaths":[32,20,24,22]}
PROCESSION_NIGHT {"arrivals":[0,2,3,1],"awards":[["generous",0],["uninvited",3],["bloodiest",3]],"bell_round":6,"grudge":[70,71,98,81],"letters":[false,false,false,false],"night":3,"rounds":7,"wreaths":[54,25,36,40]}
PROCESSION_MATCH {"board":"estate_procession","board_firsts":[3,0,0,0],"deeds":[2,1,0,3],"grudge":[70,71,98,81],"heir":0,"heir_name":"RED","heirs":[0],"mini_wins":[5,3,3,4],"moved":[86,85,93,90],"nights":3,"seed":7,"src":{"arrival":[30,9,16,8],"award":[8,4,4,16],"liquid":[7,7,9,8],"mini":[16,12,16,16]},"turn_cap":12,"wreaths":[61,32,45,48]}
  seat 0 RED: ⚘61 (arr 30 + mini 16 + awd 8 + liq 7)  70¢  ◆2  moved=86  HEIR
  seat 1 BLUE: ⚘32 (arr 9 + mini 12 + awd 4 + liq 7)  71¢  ◆1  moved=85
  seat 2 GOLD: ⚘45 (arr 16 + mini 16 + awd 4 + liq 9)  98¢  ◆0  moved=93
  seat 3 MINT: ⚘48 (arr 8 + mini 16 + awd 16 + liq 8)  81¢  ◆3  moved=90
PROCESSION_HEIR RED (seed 7, 3 nights)
```

Seed-sweep secondaries (single-run records, same command with the seed swapped):

```
PROCESSION_MATCH … "seed":1  → wreaths=[41,45,56,38]  heir GOLD  board_firsts=[0,1,1,1]
PROCESSION_HEIR GOLD (seed 1, 3 nights)
PROCESSION_MATCH … "seed":11 → wreaths=[39,47,51,46]  heir GOLD  board_firsts=[0,1,1,1]
PROCESSION_HEIR GOLD (seed 11, 3 nights)
```

Seed 11 is the LETTERS witness: BLUE (4 wreaths after night 1, zero wins)
publicly accepts the LETTERS OF ADMINISTRATION on nights 2 and 3
(`"letters":[false,true,false,false]`) and closes at 47 wreaths — the dignity
floor doing balance work, announced, never hidden.

## 5. THE SINGLE-NIGHT RECEIPT (P2, frozen — `--nights=1`)

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
godot --path . -- --procession --seed=7 --turncap=12 --nights=1 --autoplay=bots --slowsim --outdir=verify_out/procession_p2
```

(`--slowsim` keeps ceremonies at full length so the announce cards render.)
Exit `-1073741819` after the snaps is the known harmless shutdown segfault.
Committed under `estate/procession/shots/`:

- `p2_breath_heatmap.png` — THE LAST BREATH meter in situ over the board, the
  aim heatmap glowing landing percentages down the roller's road.
- `p2_peddler_cart.png` — the priced cart UI: ten wares, prices, rules, purse.
- `p2_night_awards.png` — the night-award announcement card (3 drawn races).
- `p2_reading_totals.png` — THE READING finale's final accounting card.

P1a's board shots (`boardgraph_full_board.png`, `boardgraph_crossroads_prompt.png`,
`boardgraph_drive_minimap.png`) remain valid — topology unchanged.

## 8. DELIBERATELY LEFT FOR LATER LANES

- **P3 (presentation):** figurine pawns, true over-shoulder roll camera (P2
  ships a raised behind-the-roller frame), estate.gd hub surgery
  (PLAY-menu Deed dial still feeds an ignored config key; `par` real-launch
  catalog adapter — drawn today, simulated with an announced note), held-item
  glyphs on the HUD chips, Estate Stirs events.
- **P5 (online):** `_net_state` does not yet carry wreaths/inventory/match
  fields; LAST BREATH mirror re-cert per landmine 9 (roll_id/start-tick,
  reliable STOP intent).
- pawn_putt.gd stays on disk untouched (Par receipts reference its constants).
