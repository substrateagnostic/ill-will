# THE UNDERSTUDY — verification

A couch-native, two-button re-engineering of the Spyfall odd-one-out for
EXACTLY four seats. Three players are the CAST and privately learn tonight's
PLAY; the fourth is the UNDERSTUDY, who never got the script and must deduce the
play from the rehearsal and blend. The house then names the pretender. THE
EXECUTOR runs the theater.

Module: `minigames/understudy/understudy.tscn` (+ `.gd`), root extends
`Minigame`. Helpers: `us_actor.gd`, `us_reveal.gd`, `us_board.gd`, `us_bots.gd`.

## The four-player problem, and the fix (distributed scoring)

A single majority accusation vote **deadlocks at four seats**. The understudy is
accused by at most three voters (the cast), so a "majority" conviction needs all
three cast to agree; a 2-1 or a 2-2 split reaches no majority and the classic
rule returns a hung jury — a stalemate that pays nobody.

THE UNDERSTUDY never asks the table for a consensus. **Every point is earned on
an individual choice**, so the round always resolves:

- **Rehearsal blend (understudy only):** +1 for each on-script cue the
  understudy sneaks in without the script. The cast trivially know the play, so
  their on-script cues are not skill and pay nothing.
- **Unmasking (each cast voter, independently):** +2 for accusing the true
  understudy. This is per-voter — it does not wait for a majority.
- **Survival (understudy):** +3 flat if fewer than two cast members correctly
  accused them (they escaped a working conviction).
- **Frame (understudy):** +2 if the actor the understudy pointed at drew the
  most accusations *and* an actual pile-on happened (top count ≥ 2).

A perfect 2-2 (or a total 1-1-1-1) split still produces a fully-ranked
scoreboard.

### Evidence: rounds where a majority stalemates but the ledger resolves

**Seed 3, Act 3 — the maximal deadlock (four-way 1-1-1-1):**
```
US_VOTE  act=3 understudy=MINT votes={RED->GOLD, BLUE->MINT, GOLD->BLUE, MINT->RED} accus={RED:1, BLUE:1, GOLD:1, MINT:1}
US_MAJORITY act=3 verdict=STALEMATE (top=1 needed=3)
US_DISTRIBUTED act=3 pts={RED=0, BLUE=2, GOLD=0, MINT=5} winner=MINT
```
Every actor has exactly one accusation — *no plurality exists at all*. The old
rule cannot name anyone. Distributed scoring still ranks the act cleanly:
MINT 5 (understudy blended two cues and survived a split house) > BLUE 2 >
RED = GOLD 0.

**Seed 1, Act 1 — two sharp eyes, no majority:**
```
US_VOTE  act=1 understudy=GOLD votes={RED->GOLD, BLUE->GOLD, GOLD->MINT, MINT->RED} accus={RED:1, BLUE:0, GOLD:2, MINT:1}
US_MAJORITY act=1 verdict=STALEMATE (top=2 needed=3)
US_DISTRIBUTED act=1 pts={RED=2, BLUE=2, GOLD=2, MINT=0} winner=RED
```
RED and BLUE both correctly fingered the understudy GOLD, but two of four votes
is not a majority — the old rule hangs the jury and pays nobody. Distributed
scoring still pays RED and BLUE +2 each for being right, GOLD +2 for a clean
blend, and leaves MINT (who misfired and had no blend to earn) at 0. The round
has a result; the two who saw through the act are rewarded whether or not the
table reached consensus.

## Secret delivery (one shared screen, two buttons, no phones)

**Sequential private reveal / eyes-down casting.** The house lights fall
(`us_reveal.gd`). THE EXECUTOR calls each seat in turn — "GOLD — YOUR PART,
everyone else eyes down." A face-down script card sits centre stage; on the
called player's **own A button** it turns over to show either **TONIGHT'S PLAY**
(cast) or the bare word **UNDERSTUDY** plus the six candidate play titles (the
odd one out, who must deduce which). A second A press turns it face-down and the
next seat is called. Nobody sees another's card. Bots take a deterministic
reading beat. See `docs/verify/shots/understudy_reveal.png`.

## Round flow and timings (real-time; bots run ~4× faster)

| Phase | What happens | Budget |
|---|---|---|
| INTRO | Executor announces the act | 2.6 s |
| CASTING | 4 sequential private reveals (A to read / A to commit) | ~1–8 s/seat |
| REHEARSAL | 2 passes × 4 players = 8 cues; each active player picks one word from a shared 3-true/3-foil grid (stick to move, A to lock). Off-script picks flag the tell. | ~2 s/cue, cap 6 s |
| VOTE | All four accuse simultaneously (stick across the other three, A to lock); board fills live | up to 10 s + 1 s settle |
| RESOLVE | Understudy revealed, verdict + distributed deltas, confetti for the act winner | 4.8 s |

A full bot act runs ~28 s; every sub-phase is capped so a human act stays under
90 s. Match length defaults to one act per player (each is understudy once).

## Bots (seeded, legible, deterministic)

`us_bots.gd`. One seeded personality vector per player. `pick_cue()` and
`decide_vote()` consume the RNG, so the controller calls each **exactly once**
per beat / per round and caches the result — never per frame.

- **Cast at rehearsal:** always deliver an on-script cue (they read the script).
- **Understudy at rehearsal:** narrows the play from the cues already spoken and
  echoes a fitting word; acting *early*, with little to go on, it must gamble
  and frequently slips OFF-SCRIPT — that slip is the tell.
- **Cast at the vote:** accuse whoever slipped off-script; with no slip to go
  on it can only guess, so a clean blend scatters the cast (the 2v2 the scoring
  dissolves).
- **Understudy at the vote:** frames a cast member to muddy the count.

Determinism verified — two headless runs of seed 4 produced byte-identical
`US_` logs.

## Commands run

```
# import after adding res:// files
godot --headless --editor --import --quit --path .            # exit 0

# headless evidence, full 4-bot match, fast-forwarded, prints US_RESULTS + quits
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally --seed=1
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally --seed=2
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally --seed=3

# windowed four-moment screenshot capture -> docs/verify/shots/understudy_*.png
godot --path . res://minigames/understudy/understudy.tscn -- --ussnaps --seed=3

# normal (non-tally) all-bot match reaches report_finished with a valid shape
godot --headless --path . res://minigames/understudy/understudy.tscn -- --usbots --usrounds=2 --seed=9
```

CLI user args: `--usbots` (all seats bots), `--seed=N`, `--players=N` (2–4),
`--usrounds=N` (1–8), `--ustally` (headless evidence + quit), `--ussnaps`
(windowed 4-shot capture + quit), plus the global `--shots=` VerifyCapture hook.

## Three-seed match results (4 bots, 4 acts each)

```
US_TALLY seed=1 rounds=4 totals: RED=9 BLUE=9 GOLD=6 MINT=7  champ=RED
US_TALLY seed=2 rounds=4 totals: RED=2 BLUE=9 GOLD=6 MINT=7  champ=BLUE
US_TALLY seed=3 rounds=4 totals: RED=7 BLUE=9 GOLD=9 MINT=7  champ=BLUE
```
Champions and spreads vary by seed; every match resolves to a ranked board.
Across the three seeds every act's vote was logged with its majority verdict
(mostly STALEMATE) and its distributed resolution — see the per-act `US_VOTE`
/ `US_MAJORITY` / `US_DISTRIBUTED` lines.

## Screenshots (`docs/verify/shots/`)

- `understudy_reveal.png` — the private casting reveal: "RED — YOUR PART", the
  script card turned face-up to TONIGHT'S PLAY = THE HAUNTING, others eyes-down.
- `understudy_rehearsal.png` — the stage (red curtains, footlights, moon
  backdrop), four KayKit actors under spotlights with color+badge name tags,
  BLUE spotlit delivering the cue "CANDLE" from the 3-true/3-foil grid.
- `understudy_vote.png` — NAME THE PRETENDER: four target columns with live
  accusation chips (MINT's column shows two accusers, matching the log).
- `understudy_judgment.png` — the reveal: GOLD spotlit as THE UNDERSTUDY, the
  verdict "THEY WALK", and the distributed-scoring line "A SPLIT HOUSE — NO
  MAJORITY TO CONVICT / THE LEDGER SETTLES IT ANYWAY".

## Anthology contract compliance

- `begin(config)` / `finished(results)` implemented; standalone self-start after
  0.5 s if `begin` was not called. Results validated via `report_finished`
  (no validation warnings in the non-tally run).
- `placements` includes every roster player; `points` is index→raw score.
- `currency_events`: **royalty** to cast who see through the understudy and to an
  understudy who walks free; **grudge** to an unmasked understudy and to a cast
  member framed into taking the fall. Sampled per round from the vote outcome.
- `highlights` (≤3) and `monuments` (`phantom` = never unmasked as understudy;
  `inquisitor` = unmasked correctly every cast round) reported.
- `kill_events`: **intentionally omitted** — the game has no eliminations, KOs,
  or deaths. Accusations and unmaskings are social outcomes, not kills (the
  same reasoning by which Swap Meet's thefts were filtered from the kill fleet).
- Input via `PlayerInput` only (stick + A/B); one shared screen; no text entry,
  no phones. Identity is color + `PlayerBadge` shape everywhere a name appears.

## Open items / notes

- The research brief `docs/design/06-social-deduction-research.md` referenced in
  the task does not exist in this worktree (it is cited in `alexmemory.md` but
  was never committed here — likely lives with the concurrent Séance build).
  This game was therefore reconstructed from the prompt's Spyfall-style brief
  (odd-one-out, capped rehearsal, distributed scoring, ranked couch secret
  delivery) and the house patterns in `minigames/last_will/`. Where the missing
  doc would have set specifics, this prompt's interfaces governed.
- The vote board's rightmost column can lightly overlap the top-right scoreboard
  at 720p on the first act (scores all 0); cosmetic only.
- A perfectly-blending understudy usually escapes (correct by design — that is
  a good performance). Catching happens when they slip off-script under early
  order pressure; observed catch rate across sampled seeds ~25%.
