# VERIFY-BOARD — THE PROCESSION graph board (P1a, night 7+1)

The ring→graph surgery (doc 28 §3, RC-rework-audit risk #1). This file is the
new canonical home for the board's receipts. Precondition for every command:
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
from board DATA, never the night seed, so this is night-independent):

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

Ratio conformity vs doc 28 §3 targets (45/20/15/8/5/4): path 42.1%+gate,
offering 18.4%, séance 15.8%, box 9.2%, grave 5.3%, toll 3.9%, remainder
cart + crossroads. Walked-path lengths are the producer-locked d8 defaults
(28–32 stones gate-to-gate; median night closes in roll-phase 5–6).

## 3. THE NEW FROZEN NIGHT RECEIPT (seed 7)

Canonical command (the `--turncap=N` night-length dial replaces `--deedgoal`):

```
godot --headless --path . -- --procession --seed=7 --turncap=12 --autoplay=bots
```

frozen result (verified deterministic ×3):

```
PROCESSION_TALLY {"arrivals":[0,2,1],"bell_round":8,"board":"estate_procession","deeds":[0,0,1,1],"grudge":[8,23,32,20],"heir":0,"heir_name":"RED","left":[0,0,0,2],"moved":[29,29,33,31],"positions":[75,75,75,73],"rounds":9,"routes":["common","common","common","common"],"seed":7,"turn_cap":12}
  seat 0 RED: ◆0  8♠  moved=29  pos=75  route=common  left=0  HOME#1
  seat 1 BLUE: ◆0  23♠  moved=29  pos=75  route=common  left=0  HOME#3
  seat 2 GOLD: ◆1  32♠  moved=33  pos=75  route=common  left=0  HOME#2
  seat 3 MINT: ◆1  20♠  moved=31  pos=73  route=common  left=2
PROCESSION_HEIR RED (seed 7, 9 rounds)
```

Seed-sweep secondaries (single-run records, same command with the seed swapped):

```
PROCESSION_HEIR BLUE (seed 1, 9 rounds)    bell_round=8 arrivals=[1,3]
PROCESSION_HEIR BLUE (seed 11, 8 rounds)   bell_round=7 arrivals=[1,2]
```

Turn-cap fallback (nobody crosses; DISTANCE RANKING decides — doc 28 §8 rule 4):

```
godot --headless --path . -- --procession --seed=7 --turncap=4 --autoplay=bots
PROCESSION_HEIR BLUE (seed 7, 4 rounds)    arrivals=[] left=[12,11,12,20]
```

## 4. NAMED RNG STREAMS (Codex correction, adopted)

| Stream | Var | Seeded by | Draws |
|---|---|---|---|
| LAYOUT | board_graph local | `BOARD.layout_seed` (board DATA) | stone-type placement — never the night seed, so §2 never re-freezes with night features |
| ROLL | `_roll_rng` | seed×1103515245+12345 | putt band deals, bot aim jitter/start ticks, bot crossroads choices |
| EVENT | `_event_rng` | seed×22695477+1 | séance slots, item draws, minigame pick + minisim, house-awakens, bot vendetta stakes |
| VOICE | `_voice_rng` | seed×134775813+5 | Executor line picks (presentation — pool edits can't shift the tally) |
| DRAMA | `_drama_prng` | seed×2246822519+3266489917 | interim lines, epitaphs (presentation, human-visible paths only) |

Humans draw NOTHING at a crossroads (the prompt is pure input), so a mixed
table diverges from the soak only through their choices, as designed.

## 5. SCREENSHOTS (windowed capture)

```
godot --path . -- --procession --seed=7 --turncap=12 --autoplay=bots --outdir=verify_out/boardgraph
```

Exit `-1073741819` after the snaps is the known harmless shutdown segfault.
Committed under `estate/procession/shots/`:

- `boardgraph_full_board.png` — the grounds overview: LYCHGATE south, three
  route ribbons, MANOR GATE north with the Executor presiding.
- `boardgraph_crossroads_prompt.png` — the A/B/C road picker (gamepad-first,
  gold focus ring), stay-the-road stone counts 29/25/27.
- `boardgraph_drive_minimap.png` — THE DRIVE inset with route-coloured ribbons.

## 6. DELIBERATELY LEFT FOR LATER LANES

- **P1b (LAST BREATH meter):** pawn_putt.gd untouched — still the movement
  input (1–6). The d8 arrives with the meter; nothing in the walk code
  assumes a max roll. Home pawns' meters still show during the roll (the
  simultaneous-roll wart) — dies with sequential turns.
- **P2 (economy):** pennies/wreaths collapse (internal `grudge` kept per RC
  §3), the Peddler's Cart priced shop (today it hands one free item), FINAL
  BELL arrival wreaths 10/7/4/2, night awards, sabotage-targeting rules,
  `--nights=3` outer loop. Will clauses still pay ◆ as ceremony trophies.
- **P3:** estate.gd surgery (its PLAY-menu Deed dial now feeds an ignored
  config key — harmless), over-shoulder roll camera, minifig pawns.
- **P5:** online pair re-cert (`_net_state` already carries graph node ids,
  routes, arrivals, bell).
