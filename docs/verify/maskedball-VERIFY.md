# MASKED BALL — verification & design conformance

*The Theater's third act. Built against `docs/design/06-social-deduction-research.md`
pitch #3 (Hidden in Plain Sight, staged) and `docs/specs/anthology-module-contract.md`.
Files: `minigames/masked_ball/` (masked_ball.tscn, masked_ball.gd, mb_dancer.gd,
mb_bots.gd, mb_ghost.gd). Module id `maskedball`, root extends `Minigame`.*

## The game in one breath

Twenty identical masked dancers waltz through a candlelit ballroom. Four of them
are the players — and nobody is told which. You find yourself by moving (your
dancer answers your stick), blend by dancing like the crowd, curtsy to the
throne for points, and spend your ONE mark to tear the mask off a body you
believe is human. Correct: big points, royalty, and the victim ghosts out.
Wrong: −3, grudge, and your own dancer flashes — the position leak.

## Design conformance vs the research doc (pitch #3)

| Doc requirement | Implementation |
|---|---|
| "Secret delivery: none — your identity IS your controlled body" | Zero screen-touch: the only deal is a seeded shuffle assigning 4 of 20 bodies to seats, and it is never displayed. No eyes-closed phase, no private cards, no rumble. The cheapest secret model of the three pitches, verbatim. |
| Crowd of identical NPC dancers as the hiding space | 20 dancers total (16 NPCs at 4 seats), ONE KayKit model for everyone (Rogue — hooded, on-theme), one ivory half-mask + gold crest riding the head bone. No color, ring, tag, or badge on any body mid-round. |
| NPCs wander scripted loops; humans betray themselves by purposeful motion | NPC brains: seeded counterclockwise swirl waypoints (the room slowly rotates — it reads as a waltz), pauses ≤ 2.4s, twirls, curtsies (45% chance near the throne, 10% elsewhere). Humans move at EXACTLY crowd speed — pace can never be the tell; intention is. Stillness > ~4s is a tell (no NPC ever statues that long). |
| Round flow ~3:00, "a single 2:30 waltz", simultaneous | INTRO ~3s (every body crowd-driven, so nobody can pre-track a spawn) → WALTZ 150s, fully simultaneous → REVEAL ~15s. |
| Private objective: "curtsy to the throne 3×" for points | A = CURTSY anywhere (a bluff in the open, and NPCs bow too); inside the gold "respects circle" it scores a pip: +2, max 3, ≥6s apart. Scored curtsies are announced UNNAMED by the Executor — the room learns only "somebody bowed for money, just now" and must catch who was mid-bow. Deniability by parallelism, same house move as the séance chant. |
| B = MARK a dancer you believe is human — one shot (HiPS's single bullet) | B = UNMASK the nearest unrevealed dancer within 1.7u. One mark per player for the whole waltz. Empty air does not spend the mark; a grab always lands on the NEAREST body (bystanders can eat a mark aimed past them — as in HiPS). |
| Marking a human = royalty; being marked = grudge; objective = points | Correct unmask: +6 pts, +2 royalty; victim +1 grudge, eliminated to spectator-ghost, ONE kill_event `{killer: accuser, victim, cause: "unmasked"}`. Waste: −3 pts, +1 grudge, waste-flash. Pips and survival (+4 at the buzzer) are points only. Fully distributed — no vote, no majority, ever. |
| No table vote — elimination is the in-engine action | Exactly as built; the 4-player vote-tie trap never exists. |

### Adapted, and why (the doc is thin here; choices in its spirit)

1. **Immediate mark resolution + spectator ghosts.** The doc says "spend your
   one mark … reveal at the buzzer" but its source game resolves the bullet on
   the spot, and the build brief asks for elimination-to-ghost and the
   NPC-penalty flash as live events. Marks resolve immediately: the drama
   (flash cascades, revenge hunts on a seen lunge) is the round's second act.
   Ghosts drift above the ball and can GUST the crowd (A) — a visual shiver
   that muddies the floor for the living. Nobody watches dead air.
2. **Buttons follow the doc, not the prompt paraphrase.** The research doc
   assigns A = the human action (curtsy) and B = MARK; the build prompt's
   summary said "A on a target = unmask". Where they conflict the doc is the
   design brief: A = CURTSY (bluffable everywhere, scoring in the circle),
   B = UNMASK. This also keeps A as the "co-op/table verb" across all three
   Theater games.
3. **The waste-flash is a self-inflicted REVEAL moment.** The prompt asks for a
   position leak; a bare flash plus the (required, named) scoring banner would
   leak identity anyway by inference. So the flash shows it honestly: the
   dancer strobes in the accuser's color with their glyph+name tag for 1.8s,
   then anonymity resumes — but the room remembers what it can track.
4. **Early curtain.** The waltz ends early if the floor empties to one player
   or nothing is left to earn or hunt (all living seats at 3 pips, no marks
   unspent). Bots end most decisive balls at ~120–140s.

## The PlayerBadge exception (deliberate, documented)

House rule is identity-always (badge + color on everything a player owns).
MASKED BALL is the anthology's one exception: **identity hiding IS the game**,
so no badge, color, ring, or tag rides any dancer mid-round. Badges and the
seat-pitch audio language (RED .90 / BLUE 1.00 / GOLD 1.12 / MINT 1.26) appear
at exactly the REVEAL moments: a human unmasking, a waste-flash, the ghost, the
last-dance lineup, and the ledger.

**Mitigation — the feather-glint private pulse.** Deflect your stick into the
feather band (0.15–0.5, below the move threshold) and your mask GLINTS while
your body stays put (1.4s cooldown). Every NPC mask also glints on its own
seeded 2–6s timer, so a glint means nothing to observers — the secret is the
*correlation with your own hidden stick*, which only you can generate and only
you can verify. Zero on-screen secret; colorblind-safe (the glint is ivory
for everyone, and self-ID never depends on color).

## Bots (per-seat, seeded, deterministic — mb_bots.gd)

- **Blend:** a bot knows its own body (fair — a human learns theirs in seconds
  via the glint) and drives it exactly like the crowd: same swirl waypoints,
  same speed, pauses kept under the NPC maximum so the stillness tell never
  fires on a bot. Three seeded curtsy windows send it to the throne; a seeded
  bluff timer makes it bow in the open, because only the guilty never bow.
- **Hunt:** bots read only public evidence, through seeded noise — (1) unnamed
  pip announcements: everyone mid-bow (or fresh out of one) near the throne
  shares the suspicion, split by set size; (2) the waste-flash: certainty 9,
  decaying as the crowd churns; (3) a witnessed unmask-lunge: a LEAD (~3.3),
  not a conviction, and witnesses take a 2–5s shock pause; (4) stillness > 4s.
  A bot spends its mark when suspicion clears its personal threshold
  (3.9–5.7; desperation 1.8–2.7 in the last fifth), hunts at a 1.07 stride,
  and fires ONLY when the grab would land on its target — never through a
  bystander. An 18% seeded misfire hunts the runner-up suspect instead; that
  is where organic bot wastes come from (seed 12 below).
- All rolls from one RNG in fixed tick order; crowd brain on a separate seeded
  stream; flavor/visuals on a third rng that never gates logic.

## Determinism evidence

`--mbtally` pins dt to exactly 1/60 (house trick: time_scale 8, 480 ticks/s)
and runs the full 4-bot match unattended to `finished()`.

Two full runs per seed, **entire stdout byte-compared**:

```
seed 1: BYTE-IDENTICAL     seed 2: BYTE-IDENTICAL     seed 3: BYTE-IDENTICAL
```

(An earlier wobble was the `MB_WALTZ_START t=` print using wall-clock
`game_time` across the 0.5s standalone-start timer; every deterministic print
now keys off the waltz clock. The sim itself never wobbled.)

## Three-seed match receipts (4 bots, unattended to finished())

```
MB_TALLY seed=1 unmasks=1 wastes=0 survivors=["RED", "GOLD", "MINT"] waltz_end=150.0
points: RED=16+ BLUE=4x GOLD=10+ MINT=8+ (+ survived, x unmasked)
curtsies: RED=3/3 BLUE=2/3 GOLD=3/3 MINT=2/3
KILL_EVENTS n=1 [{"cause":"unmasked","killer":0,"victim":1}]

MB_TALLY seed=2 unmasks=2 wastes=0 survivors=["BLUE", "MINT"] waltz_end=123.8
points: RED=6x BLUE=16+ GOLD=6x MINT=16+ (+ survived, x unmasked)
KILL_EVENTS n=2 [{"cause":"unmasked","killer":3,"victim":2},{"cause":"unmasked","killer":1,"victim":0}]

MB_TALLY seed=3 unmasks=2 wastes=0 survivors=["RED", "GOLD"] waltz_end=126.1
points: RED=16+ BLUE=6x GOLD=16+ MINT=6x (+ survived, x unmasked)
KILL_EVENTS n=2 [{"cause":"unmasked","killer":0,"victim":1},{"cause":"unmasked","killer":2,"victim":3}]
```

Wider sweep (seeds 1–12): kills 0–3 per ball, all in the second half of the
waltz (t≈91–137 — the HiPS endgame rush), peaceful balls exist (seeds 4, 9,
10), and seed 12 shows an organic bot waste → flash → revenge cascade
(`MB_FLASH seat=1 BLUE … t=125.0`, then BLUE is unmasked). Both mark outcomes
occur in the wild; placements always rank all four seats.

## Commands run

```
# import after adding res:// files (exit 0)
godot --headless --editor --import --quit --path .

# headless evidence: full 4-bot match, fast-forwarded, prints MB_TALLY + MB_RESULTS, quits
godot --headless --path . res://minigames/masked_ball/masked_ball.tscn -- --mbtally --seed=1
godot --headless --path . res://minigames/masked_ball/masked_ball.tscn -- --mbtally --seed=2
godot --headless --path . res://minigames/masked_ball/masked_ball.tscn -- --mbtally --seed=3
# (each run twice; stdout byte-identical per seed)

# 2-player sanity (crowd stays 20): resolves and ranks
godot --headless --path . res://minigames/masked_ball/masked_ball.tscn -- --mbtally --seed=1 --players=2

# windowed screenshot run: waltz capped at 90s, bots in photographer mode
# (blend/curtsy but never self-hunt) + two SCRIPTED beats — BLUE wastes a mark
# at ~26s, RED unmasks GOLD at ~48s — so every reveal state is photographed
godot --path . res://minigames/masked_ball/masked_ball.tscn -- --mbsnaps --seed=2
```

CLI user args: `--mbbots`, `--seed=N`, `--players=N` (2–4), `--mbtally`,
`--mbsnaps`, plus the global `--shots=`/`--quitafter=` VerifyCapture hooks
(the game also fires event snaps: crowd/unmask_npc/unmask_human/reveal/settle).

## Screenshots (`docs/verify/shots/`, read by eye, windowed 1280×720)

- `maskedball_crowd.png` — the candlelit ballroom mid-waltz: 20 identical
  hooded dancers with ivory masks (two caught mid-glint — the ambient noise
  floor the private pulse hides in), parquet, red velvet, chandeliers, throne,
  the gold respects circle, "DANCERS 20 · HUMANS AMONG THEM 4 · MARKS UNSPENT
  4", Executor: "Dance. Preferably like nobody in particular."
- `maskedball_unmask_npc.png` — the waste: banner "BLUE MARKS THE FURNITURE /
  −3 · their dancer flashes", BLUE's body strobing with the ▲ BLUE tag and a
  blue light pool (the position leak), Executor: "BLUE accuses an employee.
  The employee will dine on this for years."
- `maskedball_unmask_human.png` — the kill: "GOLD WAS HUMAN / RED collects the
  unmasking", ■ GOLD tag on the falling body, GOLD's ghost-wisp rising, marks
  counter dropped, Executor: "One mask off. GOLD, everyone. They bowed
  beautifully, considering."
- `maskedball_reveal.png` — the last dance: NPCs dimmed to silhouettes,
  survivors ringed and tagged (▲ BLUE, ● RED), ◆ MINT spotlit mid-unmasking
  (mask flown off), GOLD's ghost floating with its tag. "MINT, all along."
- `maskedball_verdict.png` — the ledger, one row per seat in placement order:
  "■ GOLD — 3 curtsies · unmasked BLUE · survived — 16 pts" … down to
  "▲ BLUE — 0 curtsies · marked the furniture · unmasked — −3 pts".

## Anthology contract compliance

- `begin(config)` / `finished(results)` via `report_finished` (no validation
  warnings in any run); standalone self-start 0.5s after `_ready`.
- `placements` include every roster seat (ties: earlier index); `points` may go
  negative on a waste — honest and legible ("marked the furniture: −3").
- `currency_events`: royalty 2 per correct unmask; grudge 1 to the victim and
  grudge 1 per wasted mark. Practice mode reports none.
- `kill_events`: exactly one per elimination, `killer` = accuser, `cause` =
  `"unmasked"`, appended in event order. Pure reporting.
- `highlights` ≤ 3; `monuments`: "Belle of the Ball" (survived + 3 pips + a
  correct unmask).
- Input via `PlayerInput` only (stick + A + B); seeded from `config.rng_seed`;
  no scene changes, no GameState writes, no `randomize()`.
- `roster[i].char_scene` is deliberately NOT used for the dancers — the crowd
  must be identical (the doc's core requirement). Roster color/name appear at
  reveal moments and on the ghost.

## Open items / notes

- The 20-body crowd is kinematic (no physics bodies): O(n²) soft separation +
  ellipse clamp, all in `_physics_process`, fixed iteration order.
- The Rogue's knives/crossbow stay visible — every dancer carries the same
  cutlery, so it leaks nothing, and everyone armed at a ball is very ILL WILL.
- A grab lands on the nearest body in reach; there is deliberately no reticle
  (a highlight would follow — and expose — the hunter). Humans learn spacing.
- Bot hunters stride at 1.07× crowd speed; humans can't. Human hunters have
  cunning instead; watching for the stride is a legitimate couch read.
- No user:// writes from any mode (`save_setup` paths never run in direct
  scene launches; verified against a pre-run snapshot of the user dir).
- Suggested director wiring (post-merge, not in this lane):
  - MODULES: `"maskedball": {"name": "MASKED BALL", "scene": "res://minigames/masked_ball/masked_ball.tscn", "mode": "contract", "theater": true},`
  - HOWTO: `"maskedball": {"goal": "A crowd of identical masked dancers — four of them are you, and nobody is told which. Find yourself, dance like furniture, curtsy to the throne for points, and spend your one mark to unmask a human. Wrong guess: you flash.", "a": "CURTSY (scores in the circle)", "b": "UNMASK (one mark)"},`

## THE CORONER (doc 32 redesign — twelfth watch, 2026-07-21)

The approved round-structure redesign, implemented by the codex lane and
finished/verified in-house after the job stalled pre-verification. Four
75s rounds, the letter-opener rotates through every seat (soak proves
unique=4), three hidden guests run icon errands (CLOCK / PUNCH / WEST)
among bot dancers for penny income, one close-range accusation per round:
CORRECT ends the round early and places the Coroner first; WRONG ("red
wax") places them fourth with zero income; silence takes third. New HUD
mb_errand_hud.gd; bots play both roles; _net_state/_net_apply extended.

Soak (headless, bots, receipts below are seed 1 verbatim):
```
godot --headless --path . res://minigames/masked_ball/masked_ball.tscn -- --mbtally --seed=N
godot --headless --path . res://minigames/masked_ball/masked_ball.tscn -- --mbtally --seed=1 --players=2
```
- Seeds 1-3: zero script errors; rounds resolve CORRECT/WRONG/buzzer.
- MBC_SOAK_COMPLETE rounds=4 coroners=[2, 3, 0, 1] unique=4 correct=2 wrong=2 unused=0 duration_each=[66.1, 75.0, 75.0, 62.4]
- MBC_TALLY placements=[1, 2, 0, 3] totals=RED=5/♠24 BLUE=9/♠25 GOLD=7/♠23 MINT=3/♠23
- 2-player: scales to 2 rounds, clean; MBC_TALLY placements=[1, 0].
- Board untouched: run_receipts.ps1 -Quick 2/2 PASS with this code live.

Timing note for the systemic pass (#84): full match ≈ 4×62-75s ≈ 4-5 min
(was ~168s) — per-round in the 60-120s band, whole-match length is a
producer call once the timing audit lands.
