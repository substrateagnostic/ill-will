# 28 — THE PROCESSION: The Unified Mode

*Night 7 (2026-07-18). The design that merges classic + procession into one
game. Synthesized from the night-7 research fleet (RA/RB/RC/RD +
tools/board_balance_sim.py, 90k simulated games) and Alex's producer spec.
STATUS: **PRODUCER-APPROVED 2026-07-18** (pending Codex addendum; tweaks
expected from playtests). Locked calls: FINAL BELL · PENNIES/WREATHS ·
LETTERS OF ADMINISTRATION in v1 · phases 1-2 greenlit · figurine pawns ·
Estate Stirs major/minor split · Book of the Dead cosmetic-first.*

---

## 0. Executive summary

ILL WILL becomes ONE game: **THE PROCESSION** — a Mario-Party-class board
game across a much larger estate, played over **3 nights**, where the board
is the core loop and the 15 minigames are its engine room. Classic Nights
retires. The auction, map voting, and player voting go with it.

The winner is decided Mario-Party-style by **end-of-game totals**, not race
position. Two currencies, both legible at a glance:

- **PENNIES** — shop money. Won in minigames, found on stones, stolen with
  style. Spent at the Peddler's Cart on items and sabotage.
- **WREATHS** — the victory currency. "Most wreaths inherits the estate."
  Earned from minigame placements, arrival order at the Manor Gate,
  announced night awards, and a small end-of-game penny liquidation.

**The night ends with THE FINAL BELL**: the first pawn through the Manor
Gate rings it — every other player gets exactly one more full turn, then the
night is scored. A turn cap backstops runaway nights. (Sim-validated; see §8.)

---

## 1. What survives, what dies (from RC-rework-audit.md)

**SCRAPPED:** auction (~250 lines), map/player voting analogues, side bets,
trail + parade, pawn_putt golf meter (salvaging bot logic + tick discipline),
the 24-space ring topology, Codicil deed-purchasing (the deed's *role* is
replaced by wreath streams).

**ADAPTS:** procession.gd (becomes the whole game), board_spaces grammar
(space-type table is already the right shape), board_camera (shot vocabulary
survives; over-shoulder is new), board_minimap THE DRIVE, executor_host,
estate.gd (major surgery — the biggest single risk), estate_state (save v2).

**SURVIVES UNTOUCHED:** all 15 minigames + their receipts, results_board,
podium, MomentScribe/newsreel/album, saga_cards (Standing Grudge + FINAL
AUDIT slot into the interludes), vendetta stakes (becomes GRUDGE MATCH),
final_stretch, shake/env kits, wardrobe + cosmetics, walkabout hub, bots.

---

## 2. The loop

```
TITLE → ESTATE GROUNDS (walkabout hub)
  - whole board visible below/around the grounds
  - wardrobe, settings, griefing, Executor — all in-world desks
  - ready-up at the PROCESSION GATE
NIGHT (repeat 3x):
  CYCLE (repeat until Final Bell or turn cap):
    1. ROLL PHASE — sequential, standings order (leader first),
       over-shoulder camera per minifig, ~30-40s for all four
    2. MOVE + RESOLVE — land the stone, shop if at a cart
    3. MINIGAME — random (THE INVITATION item can pick), all-play
       → pennies 10/6/3/1 + wreaths 2/1/1/0
  FINAL BELL → arrival wreaths 10/7/4/2 → 3 announced awards → standings
  INTERLUDE — will reading (night recap ceremony), one grounds minigame
    (interlude 1: random; interlude 2: the current DOORMAT picks, no
    repeat of interlude 1's game), wardrobe, LAST RITES cart, scars persist
FINALE — THE READING OF THE WILL: liquidation (10 pennies = 1 wreath),
  running totals revealed stream by stream, most wreaths INHERITS.
```

Board resets each night; wreaths, grudges, monuments, and epitaphs carry.
(Continuous-board and hybrid variants were simmed and scored worse or equal
on every metric while deleting the third act — see §8.)

## 3. The board

**Branching A-to-B graph, ~90 stones total, ~40 on any single pawn's path.**
From the LYCHGATE (start) to the MANOR GATE (finish), through two CROSSROADS
forks with three route personalities (RA §7c):

- **GARDEN ROW** — safe/long. Offerings + the Peddler's Cart. The shop route.
- **HOLLOW WOODS** — short/wild. Grave Goods boxes, Séance Circles, Roots.
- **WEEPING VALLEY** — the gamble. Fastest if the Ferryman favors you;
  studded with Open Graves and the toll.

**Space ratios** (RA §1b, modern-MP calibrated): ~45% path stones, ~20%
OFFERING (+3 pennies), ~15% SÉANCE CIRCLE (event wheel; ~1/3 of spins touch
wreaths ±1), ~8% GRAVE GOODS (free item box), ~5% OPEN GRAVE, ~4% FERRYMAN'S
TOLL, remainder crossroads/NPC/cart. Hazards deliberately rare — modern MP's
lesson is positive variance, not punishment.

**One public meaning per stone** (board_spaces doctrine, kept). Minimap THE
DRIVE gets route-colored ribbons.

## 4. THE ESTATE STIRS (topology events)

Drawn per GAME from two pools (producer call, 2026-07-18), **announced by
the Executor** at game start as omens ("tonight, the bog is hungry"), fired
at fixed night beats with full camera moments (board_camera money-shot
vocabulary). **Guaranteed minimum per game: 1 MAJOR + 1 MINOR.**

**MAJOR (permanent reroutes — the board is different from here on):**
1. **THE REAPER'S SHORTCUT** — a colossal scythe arcs down and carves a
   passage between routes... and INTO THE CRYPT (see below). (Rigged +
   animated Meshy hero.)
2. **THE BONE BRIDGE** — rises from the bog; Weeping Valley gains a bypass.
3. **THE LANDSLIP** — a hillside gives way; one Hollow Woods segment now
   empties into Weeping Valley (routes cross-contaminate).
4. **THE PROCESSION ROAD** — ghostly pallbearers tread a brand-new stone
   path between two distant points; anyone may walk it, it whispers.

**MINOR (temporary or single-stone drama):**
1. **THE FLOOD** — Garden Row closes for 2 turns; carts board their windows.
2. **THE HUNGRY GRAVE** — one stone collapses into an Open Grave, permanently.
3. **THE HEARSE MOVES ON** — the Peddler's Cart relocates to another route.
4. **THE WAKE** — mourners crowd 3 stones for 2 turns; landing there costs a
   toast (−2 pennies) but pays a wreath rumor (+1 séance-style spin).
5. **CROW COURT** — the murder convenes on a stone; first to pass it is
   robbed (−3 pennies), scattering them.

**THE CRYPT (the fourth route — event-gated scarcity):** the shortest path
in the game, pitch dark, claustrophobic camera, one guaranteed Open Grave.
It has no crossroads entrance — it opens ONLY via the Reaper's Shortcut or
a Gravedigger purchase. A route you *earn or buy*, never a menu option.

No two games play the same board. All announced, never hidden (Pro Rules
discipline — nothing hidden decides). Moving set pieces are cheap drama —
pool grows over time.

## 5. The roll — THE LAST BREATH meter (RD candidate B)

A fast oscillating slider (triangle wave, **700ms full sweep, ±60ms seeded
jitter re-dealt every roll**). Release position `p` bends a **real,
auditable** d6 distribution (geometric kernel k=1.6): full-left =
[40/25/15/10/6/4]%, center peaks 3/4, full-right mirrors. A **45ms crit
band**, re-dealt every roll (W8 doctrine on a new surface), sharpens to
k=3.2 — a crit roughly **doubles your top-face certainty without changing
your aim**. Die stays d6 in v1 (the entire economy is tuned to 1-6 moves).

Hard rules carried from RD: never randomize after release commits; the
weights must be real (MP's fake dice-timing scandal is the cautionary tale —
our --autoplay receipts make rolls auditable, so honesty is enforceable);
meter HUD is never occludable.

Bots: same distribution, target-face inversion of the aim curve, persona
crit-appetite; single host rng draw per release in queue order keeps
receipts byte-identical.

## 6. The economy (all numbers)

| Stream | Amount | Notes |
|---|---|---|
| Minigame pennies | 10/6/3/1 per cycle | the income heartbeat |
| Minigame wreaths | 2/1/1/0 per cycle | flattened (sim: 3/2/1/0 over-rewards skill) |
| Arrival wreaths | 10/7/4/2 | crossing order, then distance; ties random |
| Night awards | 3 announced × 4 wreaths | drawn from pool, §7 |
| Liquidation | 10 pennies → 1 wreath | at game end only |
| Offering stone | +3 pennies | |
| Open Grave | −3 pennies | |
| Ferryman's Toll | −2 pennies | |

**Peddler's Cart (MP price ratios: premium ≈ 2 minigame wins):**

| Item | Cost | Effect |
|---|---|---|
| LUCKY PENNY | 5 | +2 on your next roll |
| BLACK VEIL | 5 | negate your next hazard |
| PALLBEARER'S SHOVEL | 7 | dig ahead 3 stones |
| CROW'S CUT | 10 | steal 5 pennies from a chosen rival |
| FUNERAL BELL | 12 | drag the track leader back 3 stones |
| WREATH OF DEBT | 20 | trap-stone: first rival to land pays you 5 |
| THE INVITATION | 22 | choose the next minigame (the rare picker) |
| WILL-O'-THE-WISP | 25 | teleport to the next checkpoint/NPC |

**Rubber-banding (legible, opt-in only):** wreath last place shops at 30%
off; sabotage items only target pawns still on the track (**pawns through
the gate are home — beyond the reach of grudges**).

## 7. Night awards (the bonus-star ceremony)

Drawn 3 per night from a pool, **announced at night start, races visible
mid-night** (interim reading). MEASURED DESIGN LAW from the sim: award
categories must be **de-correlated from the main win path** — adding
earnings/spending awards to the pool raised the skilled seat's win rate by
4 points because both correlate with winning minigames. The pool must stay
majority luck/behavior-weighted:

- **LONGEST PROCESSION** (most stones moved — roll luck)
- **MOST MOURNED** (most graves/hazards eaten — inverse luck, on-brand)
- **GENEROUS TO A FAULT** (most spent at carts — behavior)
- **THE UNINVITED** (most séance spins — event luck)
- **BLOODIEST HAND** (most minigame wins — the one skill award, max 1 drawn)

## 8. Sim results (tools/board_balance_sim.py, 10k games × variants × 3 skill mixes)

| Metric | A: FINAL BELL | B: continuous, no arrival | C: hybrid warp |
|---|---|---|---|
| Seat fairness (equal skills) | 24.5–25.3% ✔ | 24.5–25.7% ✔ | 24.6–25.4% ✔ |
| Skilled seat (1.2× edge) wins | 50.5% | 46.7% | 46.9% |
| Skilled seat (1.35× shark) wins | 61.2% | 57.4% | 56.8% |
| Comeback (night-1 last → top-2) | ~17% | ~15% | ~17% |
| Robbed (best minigamer loses) | ~30% | ~28% | ~30% |
| Night length | 9.5 turns avg, cap 12 | fixed 8 | fixed 8 |

**Verdict: variant differences are small after fairness fixes — the choice
is about FEEL, and A is the only one with a third act.** B (Alex's alt)
deletes arrival scoring and with it the homestretch drama; its "cleaner
scoring" also concentrates wreaths in minigame placements (pure skill).
**Ship A.** The structural rules the sim discovered are non-negotiable
regardless of variant:

1. **Roll order = current wreath standings, leader first** (leader commits
   blind, trailers act informed — catch-up + seat fairness in one rule).
2. **Home pawns are untouchable** (no belling someone out of the manor).
3. **All ties break explicitly and visibly** (stable-sort bias gave seat 0
   an 11-point edge in early sims — the real game gets ceremony tie-breaks).
4. **Turn cap 12 with distance ranking** as the no-crossing fallback.
5. **LETTERS OF ADMINISTRATION (locked, v1):** at night start, a player
   with zero minigame wins AND bottom wreaths may publicly accept the
   Letters — the Executor reads it as a dry legal formality (comedy doing
   balance work). That night only: cart at 30% off, one free CROW'S CUT,
   arrival award bumped one tier. Opt-in, announced, time-boxed — the
   Dokapon-Darkling shape. (The 0.75× seat wins only ~4-6% of games
   without a dignity floor; comeback target ~20%.)

Comeback rate (~17%) is below the ~20% target: close the gap with the
LETTERS mercy draw + séance wreath swings, not with invisible handicaps.

## 9. Downtime (the restored sequential-roll tax)

**THE DOCTRINE (Alex, 2026-07-18): "Downtime is any time spent not
THINKING or not ACTING."** The old procession's failure was not idle hands
— it was illegibility at speed: "a simulator with an occasional putt," too
fast to calculate strategy, too opaque to strategize about at all. So the
budget below has TWO sides, and legibility is the harder one:

**Action budget:** roll act ≤5s, travel ≤2s (hold-A fast-forward), one
Executor line, full 4-seat roll phase ≤40s.

**Thinking budget (a waiting seat must always be able to answer these at a
glance):** where is everyone, what route are they on, what do they hold,
what are the three announced award races, what do I want from my next roll.
Concretely: persistent standings strip with route icons + penny/wreath
counts; THE DRIVE always visible during the roll phase; camera cuts that
frame the DECISION (the crossroads ahead, the stone they'll land on), not
the walk; the crossroads choice telegraphed one roll early so rivals can
scheme against it. Between-move stillness with a readable board is not
downtime — it's the strategy layer.

The three waiting seats also always have a job:

- **BOOK OF THE DEAD** — sealed bet on the coming minigame's winner.
  **v1: cosmetic stakes only** (boast lines, no economy touch). v2, only
  with clean UX (old side-bets failed on usability, producer verdict):
  1-penny ante, and a **self-bet tax** — betting on YOURSELF and losing
  pays a larger penalty than a wrong bet on a rival, so the table shark
  can't compound wins by default-betting themselves.
- **REACT glyphs** over the roller (shipped F24 system, new surface).
- Walkabout presence: run alongside the board, emotes, scrap-collecting,
  chapel bell (cooldown + audio ducking under the crit tell). The meter
  widget itself is never occludable — background heckling fair, HUD foul.

## 10. NPCs (one beat each, never a cutscene)

THE GRAVEDIGGER (movement items), THE WIDOW (blessing/curse), THE FERRYMAN
(pay to cross the valley), THE MOURNER-FOR-HIRE (award nomination), THE
MAGPIE (steals or gifts), THE EXECUTOR at the Manor Gate (rings the Bell,
reads the will).

## 11. Art + Meshy manifest (post-approval, pull-immediately doctrine)

- **Figurine pawns (producer call — option b):** NOT walking mini-people.
  Toy-style figurines of the four characters on round bases that HOP
  stone-to-stone with a clack. Build from the existing character meshes in
  a static sculpt pose + cylinder base, slight glaze/ceramic material —
  in-engine, zero Meshy cost, perfect likeness. The fiction stays clean:
  you play a board game ABOUT them while the characters themselves run
  alongside heckling.
- **Heroes:** THE REAPER (rigged + scythe animation), BONE BRIDGE (rise
  anim), the LYCHGATE, MANOR GATE arch, PEDDLER'S CART (hearse-drawn).
- **NPCs:** gravedigger, widow, ferryman + skiff, mourner, magpie.
- **Board furniture:** route-biome sets (garden hedges, hollow trees,
  bog/valley stones), checkpoint shrines, stone variants per space type.
- Balance 1460 credits; Alex tops up freely; every asset downloaded to the
  repo the moment it finishes (3-day purge + weekly reset insurance).

## 12. Online (RB-online.md)

Ship order: **Tailscale tonight** (zero code — ENet host/join over virtual
IPs), **self-hosted noray relay** on Alex's home server next (~half a day:
punchthrough feeds the existing ENetMultiplayerPeer calls; pin a commit).
UPnP/W4/EOS rejected with reasons in RB. 15 of 16 minigames already mirror.

## 13. Migration + receipts

- **Save compat is low-risk** (RC §4): slot_1's five real nights live
  outside `run{}`. Migrate legacy 1:1, add schema tag, loader is
  get()-tolerant. NEVER wipe.
- **Currency rename is display-layer only**: internal `"grudge"` strings
  keep their names or 14 minigame receipts re-freeze for nothing.
- **Receipts re-found in layers** as the board lands: topology → movement →
  full night → 3-night game → net pair, plus tools/run_receipts.ps1 as the
  first suite runner. The seed-7 procession receipt dies with honor.

## 14. Build phases (post-approval)

1. **Board graph + roll meter** (the ring→graph surgery, biggest risk,
   worktree lane + fresh receipts).
2. **Economy + cycle loop** (pennies/wreaths, cart, awards, FINAL BELL).
3. **Presentation** (over-shoulder cam, minifigs, THE DRIVE ribbons,
   Executor beats, interlude ceremonies).
4. **THE ESTATE STIRS + NPCs + Meshy wave.**
5. **Presence layer + Book of the Dead.**
6. **Online pass + polish + full receipt suite.**

Phases 1-2 are the sim made real; 3 is where it starts feeling like the
game; each phase merges only with receipts + screenshots per house rules.

---

*Addendum slot reserved: R-E (Codex cold read) lands here when it returns.*
