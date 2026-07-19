# 29 — Deed Vestige Report

*Night 8 (M6 lane). Investigation only — no gameplay touched. Answers: what
mints a Deed ◆ in THE PROCESSION today, what the player sees, and whether it
still does anything.*

---

## 0. tl;dr

Deeds are alive, visible, and completely disconnected from who wins.

- **One mint site**: the per-night WILL READING (`_will_reading()`,
  `estate/procession/procession.gd:3404-3429`) hands out up to 3 deeds a
  night (one per will clause), up to ~9 across a 3-night match.
- **Always on screen**: every player chip shows `◆%d` next to the real
  currencies (`¢` pennies, `⚘` wreaths) every HUD refresh
  (`procession.gd:812-819`), and the match receipt prints a `"deeds"` array
  (`procession.gd:3546`) — this is the `[2,1,1,2]` you saw.
  Same visual weight as the two currencies that actually matter.
- **The crown ignores it.** `_match_heirs()`/`_match_order()`
  (`procession.gd:1392-1420`) tie-break on wreaths → board_firsts →
  night_final_rank → mini_wins_match → seat. Deeds never enter the chain.
- **It is not, however, pure decoration.** One hidden mechanical hook
  survives: in THE HOUSE AWAKENS hazard, a seat with **zero** deeds gets a
  +10 percentage-point bonus to dodge the catch (`procession.gd:3351`,
  `0.45 + 0.1 * float(deeds[i] == 0)`). Nothing in the UI tells the player
  this. It reads as balance noise, not an intentional deed-o-meter.
- **It also drives the closing eulogy.** `ProcessionEulogy` (called once,
  game-end, from `_finale()` at `procession.gd:1373`) picks a per-night
  "eulogy heir" by *argmax(deeds, grudge)* (`eulogy.gd:65,217-223`) and reads
  `eulogy.heir` ("We commend %s, who bought %s...") **immediately before**
  the real wreaths-crown is announced. If the deed leader and the wreath
  leader are different players (very possible — they're uncorrelated
  stats), the game names one "heir" in the eulogy and crowns a different
  player seconds later. That's a real, player-visible contradiction risk,
  not a hypothetical.

---

## 1. Where deeds get minted (the only live mint site)

`_will_reading()` — `estate/procession/procession.gd:3404-3429` — runs once
per night from `_night_settlement()` (`procession.gd:1205`, so 3× across a
match). For each of the 3 will clauses:

- **THE LONGEST PROCESSION** — most stones walked
- **THE MOST BETRAYED** — most pennies bled to graves/tolls
- **THE BLOODIEST HAND** — most vendetta/board wins

...the current stat leader (`_stat_leader(key)`, ties go to whoever hit it
first / stays unclaimed on a tie) gets `deeds[winner_seat] += 1`
(line 3413), a `"◆ %s — +1 Deed to whoever %s"` reveal line, and a small
flying `+1◆` number popup (`_pop_grudge(winner_seat, 1, "◆")`, which is the
same generic number-pop used for pennies deltas — just with the `◆` glyph
swapped in; the dedicated wax-sealed "Deed" parchment token,
`board_fx.gd:72 fly_deed()`, is defined but **never called** — dead FX).

**Confirmed dead / not mint sites:**
- `estate/procession/codicil.gd:27` (`deeds[player] += 1`, the old
  buy-a-Deed-at-the-Codicil purchase) — `ProcessionCodicil` has zero
  external references anywhere in the codebase. The Codicil board space
  isn't placed by `board_graph.gd` either (only the ring-era `board_path.gd`
  used it, also zero external references). Fully retired, matches doc 28
  §1 ("Codicil deed-purchasing... SCRAPPED").
- `estate/procession/presets.gd` (`ProcessionPresets`, `DEED_GOALS`) — old
  alternate win-condition dial ("FIRST CLAIM ENDS THE NIGHT AT FOUR DEEDS" /
  "SIX DEEDS" / "NINE DEEDS"). Zero external callers. `estate.gd`'s own
  `_deed_goal_label()`/`_cycle_deed_goal()` (lines 465-475) are themselves
  never called by anything. Confirms deeds were once meant to be a genuine
  victory condition and got orphaned mid-rework — extra context for why the
  vestige exists.

## 2. What the player experiences

| Site | What happens | File |
|---|---|---|
| WILL READING card, 3×/match | "◆ [Clause] — +1 Deed to whoever [led]" read aloud, deed count shown | `procession.gd:3404-3429`, dialog `procession.will_reading.line` |
| Live HUD chip, constantly | `"12¢  ⚘3  ◆2  ..."` — deeds sit at equal visual weight next to the two real currencies, every frame | `procession.gd:806-819` |
| Flying number, on mint | `+1◆` pop from pawn to chip (generic number-fly, not special) | `procession.gd:3415` → `board_fx.gd fly_number` |
| Closing EULOGY, once/match | Names a flavor "heir" by deed count (can contradict the real crowned heir seconds later); deed count also breaks which of the 6 descriptor templates (bloody/betrayed/hoarder/mourner/pious/idle) each other seat is assigned | `eulogy.gd:55-104, 217-223` |
| HOUSE AWAKENS hazard, every 3rd round | Hidden +10pp dodge-the-catch bonus if `deeds[seat] == 0` | `procession.gd:3351` |
| Match receipt / tally | `"deeds": [2,1,1,2]` printed alongside wreaths/grudge every run | `procession.gd:3546, 3553-3556` |
| INTERIM READING, mid-night | "◆ [Clause] — [leader] leads, [metric]" — same 3 clauses, running standings | `procession.gd:3374-3376` calling `_interim_reading()` |

Everywhere else deeds appear in `dialog/dialog.json` (the Codicil purchase
pool, the old ring-board "buy a Deed" flavor, the orphaned
`procession.heir.crown` line that still describes an heir crowned by deed
count) is dead — confirmed zero live callers. Left untouched in the M6
vocabulary pass since those lines don't describe an active winning/scoring
mechanic (see companion note in the M6 handoff).

## 3. Does it affect the outcome?

**No**, for who wins. `_match_order()`/`_match_heirs()`
(`procession.gd:1392-1420`) is the entire tie-break chain: wreaths →
board_firsts → night_final_rank → mini_wins_match → seat order. Deeds are
not read anywhere in it.

**Marginally yes**, for one hazard round's odds (House Awakens, +10pp dodge
if you're at zero — a small comeback nudge for whoever's behind on the
will-clause races, never explained to the player).

**Yes**, for the eulogy's flavor "heir" pick and per-seat commendation
assignment — cosmetic in the sense that it doesn't change scores, but very
much *visible* and can read as a narrative contradiction against the real
crown.

## 4. Options for the producer

**A — Retire ◆ entirely.** Drop the `deeds` array, the will-clause
"+1 Deed" payout, the chip's `◆%d`, and `eulogy.gd`'s `_argmax_deeds` (swap
the eulogy "heir" pick to wreaths-leader, or drop the heir line and let the
descriptor-assignment pass run over all seats). Cleanest read: two
currencies, no third silent number. Costs: the 3 will clauses need a new
payout (small wreaths or pennies bump instead of a deed?) or become
pure-flavor announcements with no reward at all; the House Awakens
underdog-mercy nudge needs a new hook (e.g. key off wreath rank instead of
deeds) or gets dropped.

**B — Rename + repurpose.** Keep the mechanic, make it earn its HUD slot:
fold deeds into the wreaths economy directly (e.g. each will-clause win
pays 1-2 wreaths instead of/in addition to a deed — matches doc 28's
"WREATHS — earned from minigame placements, arrival order, announced night
awards" list, will clauses would just be added to that list), and drop the
separate ◆ counter. The eulogy's "heir" pick becomes trivially
wreaths-consistent since there's only one number now.

**C — Leave it, but be honest about it.** Keep ◆ as a pure flavor tally (a
"most decisive/most claimed" trophy shelf), but (1) visually de-emphasize
it from the two real currencies on the chip so it doesn't read as "a third
thing that matters," (2) fix the eulogy so its flavor "heir" pick can never
contradict the real crowned heir (e.g. only call someone "heir" in the
eulogy if they're also a `_match_heirs()` winner, otherwise route them
through the normal descriptor pool), and (3) either document or drop the
House Awakens hidden bonus so it's not an unexplained mechanic.

**Recommendation:** **B.** The three will clauses ("longest procession,"
"most betrayed," "bloodiest hand") are good content — they're just paying
out in a currency nobody can spend or win with. Routing their payout into
wreaths costs almost no code (the mint site is one line,
`procession.gd:3413`) and removes the eulogy contradiction risk for free,
since there'd be nothing left to `_argmax_deeds` against. It also means the
HUD chip drops to the two currencies doc 28 actually promises the couch
("Two currencies, both legible at a glance"), which is the design's own
stated bar. A is defensible too if the producer would rather cut the will
clauses' reward entirely and keep them pure bragging-rights callouts; C is
the only option that keeps a UI element with no scoring meaning, so
it's the one I'd pick last.

---

*No gameplay changed for this report. Mint-site and effect claims verified
by direct code read, not assumption — see file:line citations above.*
