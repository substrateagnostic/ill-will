# R7 — SPECTATOR ENGAGEMENT: what do non-active players do

*Night-5 research lane R7. Lens: waiting players, players whose turn it isn't,
players losing badly. Read-only audit of the current repo + external research
on Mario Party, Jackbox, Fall Guys, Smash, and Wits & Wagers.*

---

## 0. Correcting the brief's premise (important — read first)

The brief assumes a turn-based putt ("during the board's putt phase, what do
the 3 non-putting players DO?") and elimination-benched minigames ("during 1v1
or 2v2 minigames, what do benched players do?"). Both assumptions are **false
in the current build**, and the correction changes where the real gaps are:

1. **The putt is already simultaneous, not turn-based.** `estate/procession/
   pawn_putt.gd` (`ProcessionPawnPutt.begin_roll`) spins up one `PuttMeter`
   per roster seat and drives all four charge/release state machines in the
   same `_physics_process` tick — every player charges and releases at once,
   each with a screen-corner meter and a **live space-target preview** (F29,
   `preview_spaces()`, shipped in commit `321c1f1`). Nobody waits during the
   putt itself; this is already good design. The genuine idle-watch moment is
   the phase *after* the putt: the **serial REVEAL CASCADE** (`procession.gd`
   `_reveal_beat`), where one seat's landing is narrated at a time while the
   other three watch. That moment **already has a solution**: F24
   reveal-cascade REACT buttons (`_poll_reactions` / `_spawn_reaction`,
   commit `ee416e9`) — waiting players tap B/Up/Down to float an attributed
   HA!/OOH/OOF glyph over the victim's stone. It's real, shipped, and
   doctrine-clean (no sim/rng touch).
2. **No minigame in the anthology benches a player.** All 14 minigames are
   4-seat: 12 are simultaneous free-for-all/co-op, `understudy`/`seance`/
   `masked_ball` are talk-based with all four bodies on screen the whole
   round, and `pallbearers` is 2v2 but **both teams race in the same shared
   3D scene at once** — nobody is ever waiting on the sideline for their
   turn. The one place the anthology genuinely creates a "2 act, 2 watch"
   moment is **the board's VENDETTA space** (a 1v1 grudge-stake duel between
   two pawns while the other two do nothing) — see doc `24-board-broadcast-
   standard.md` F14, which stages the duel visually but never gives the two
   onlookers a lever. That's the real "1v1 while others watch" surface, and
   it's currently idle.

Net effect: the two "gaps" named in the brief are already solved or don't
exist as framed. The real remaining gaps are (a) VENDETTA's onlookers, (b)
the pre-minigame dead air (roulette/GET READY), and (c) idle pawn body
language during MOVE/REVEAL — none of which need a new elimination surface.

---

## 1. External research

**Wits & Wagers (North Star Games).** Every player writes a numeric guess to
a trivia question and places it face-up on a betting mat; then everyone bets
poker chips on *whichever guess* (their own or a rival's) they think is
closest without going over, at odds printed on the mat. The entire game is
built on the insight that **you don't need to be right yourself to have a
stake in the outcome — you only need to correctly judge who else is right.**
This is the exact shape of a spectator wager: it turns "watching someone
else act" into "having money on someone else's act."
[Wikipedia](https://en.wikipedia.org/wiki/Wits_and_Wagers),
[UltraBoardGames rules](https://www.ultraboardgames.com/wits-and-wagers/game-rules.php)

**Jackbox "enhanced spectator."** Beyond the 4-8 active players, unlimited
audience members join via a room code and **vote on outcomes that feed back
into the live game** (biasing which answer advances, filling an "audience
slice" on a wheel) rather than only watching. The design principle: the
audience's vote must land somewhere the active players can see and react to,
or it reads as decorative.
[Jackbox blog](https://www.jackboxgames.com/blog/how-audience-play-along-differs-in-each-jackbox-game)

**Fall Guys spectator mode.** On elimination you're dropped into a
free-cycling camera over the *surviving* field with no lever at all — pure
observation. Community sentiment on this is explicitly negative ("auto-
spectating" threads on Steam) — confirms the TV Tropes "Player Elimination"
critique doc 24 already cites: *watching with no agency is the failure mode
to avoid, not a baseline to copy.*
[Player Assist](https://playerassist.com/how-to-spectate-in-fall-guys/),
[Fandom](https://fallguysultimateknockout.fandom.com/wiki/Spectator_Sport)

**Mario Party VS/Duel/Bonus Stars.** Recent entries have players ante a flat
coin stake into VS Spaces and land Bonus Stars for passive meta-conditions
(most happening spaces, most coins across all minigames) — betting exists but
almost entirely as *self*-stakes (you bet on your own outcome), not on
someone else's, which is precisely the gap Wits & Wagers' "bet on a rival"
mechanic fills and Mario Party doesn't.
[Mario Wiki: Bonus Star](https://www.mariowiki.com/Bonus_Star)

**Smash Bros. crowd.** The in-game crowd is a pure audio layer (gasps near
the ledge, cheers on multi-KOs) with zero interactivity — useful only as a
reference for *cheap* ambient reactivity (F27's idle-business ask), not for
a wager mechanic.
[SmashWiki: Crowd](https://www.ssbwiki.com/Crowd)

**Takeaway for ILL WILL:** the only one of these five references that solves
"what does a non-active player who is not eliminated *do*" is Wits & Wagers'
bet-on-a-rival mechanic. Jackbox and Mario Party both assume the audience/
bettor is voting on *unknowns the sim hasn't decided yet* (which risks an
RNG-adjacent sim touch); Wits & Wagers instead lets you bet on **an outcome
that has already been decided but not yet revealed to you** — which maps
exactly onto ILL WILL's existing "flying numbers travel from a decided state,
never decide it" doctrine (doc 24 §0, rule 1). This is why the ideas below
bet on *already-resolved-but-unrevealed* sim state, never on a fresh roll.

---

## 2. In-repo audit: the ghost-meddle doctrine, corrected count

`core/ghost_meddle.gd` is used by exactly **2 of 15** games —
`minigames/echo_chamber/echo_chamber.gd` and `minigames/orbital/orbital.gd` —
confirmed via `_meddle.add_ghost(...)` call sites. But grepping the wider
`minigames/` tree for elimination/lives/respawn patterns turns up **three
more games that already invented their own bespoke ghost-equivalent before
the shared kit existed**:

| Game | Elimination shape | Existing "dead" mechanic | On shared kit? |
|---|---|---|---|
| `echo_chamber` | KO → `RESPAWN_TIME` (2s) gap, then back | `GhostMeddle` SIM meddle ("STIRRED A COLD DRAFT") | Yes |
| `orbital` | KO → `RESPAWN_DELAY` gap, then back | `GhostMeddle` PRESENTATION meddle ("RATTLED THE VOID") | Yes |
| `dead_weight` | Falls into the void mid-round → poltergeist until next round | `DWGhost`/`poltergeist.gd` — **possesses furniture and hurls it at the living** (richer/more aggressive than the shared kit's "garnish" invariant; flagged below) | No — bespoke, predates the kit (it's literally named the kit's own "exemplar" in `ghost_meddle.gd`'s docstring) |
| `last_will` | 3 lives (`LIVES := 3`), then out for the rest of that race | `LWGhostSeat` (`lw_ghost.gd`) — a floating pew that gusts the living for royalties, 10s cooldown, own `CooldownRing` | No — bespoke, the kit's own docstring calls it the "template" |
| `tilt` | Falls off the platter mid-round → seagull until next round | `TiltSeagull` (`seagull.gd`) — free-flight, drops guano bombs on survivors every 4s | No — fully independent invention, never referenced by `ghost_meddle.gd` |

**Correction to the brief: it's 5 of 15 games with a dead-seat verb, not 2.**
Two use the shared kit; three independently reinvented the same idea before
the kit existed. This matters for part (b) below.

**A doctrine flag worth surfacing (not this lane's job to fix):**
`dead_weight`'s poltergeist can possess and hurl furniture at living players,
which reads as more than a "garnish" — hurled props plausibly *cause* a void
death, which is arguably a ghost *killing*, in tension with
`ghost_meddle.gd`'s own "MISCHIEF, NOT MURDER" invariant. It predates that
invariant being codified (the invariant's docstring literally cites
`dead_weight` as the *exemplar*, suggesting the rule was written by
generalizing from it, and may not have been checked against the letter of its
own possess-and-hurl kill potential). Worth a look by whoever owns B6/F25,
not scoped here.

### Part (b): which of the remaining 13 could honestly get a ghost meddle?

Excluding the 5 above, the other **9 minigames plus the board's VENDETTA
moment** have **no elimination surface at all** — nobody is ever a dead human
seat, so there is nothing to raise a wisp for without inventing a fake "sin
bin" state that isn't in the current design:

| Game | Why it can't honestly host a ghost meddle |
|---|---|
| `widows_gaze` | Explicitly designed to avoid dead time — "no dead time (caught players respawn in 1.2s)" is a stated design goal, not a gap. 1.2s is too short to register a ghost verb at all. |
| `greed` | Tackled carrier drops the pot and keeps playing instantly — no stun, no KO. |
| `mower` | Continuous coverage race, no elimination. |
| `swap_meet` | Race with position swaps, nobody is ever removed from play. |
| `throne` | Dethroned player is flung down the steps but immediately re-enters the scramble — never "dead," just repositioned. |
| `masked_ball`, `understudy`, `seance` | Talk/deduction games — all four bodies are on screen and controllable for the entire round; there is no seat to be "out." |
| `pallbearers` | 2v2, but both teams race simultaneously in the same scene; a drop delays a team, it doesn't remove a player. |
| Board `VENDETTA` | The two non-dueling pawns aren't eliminated — they're just unattended. Different problem (see idea #2), not a ghost-meddle candidate. |

**Honest answer: none of the 9 can honestly support the ghost-meddle
mechanism as specified (dead HUMAN seat, wisp, cooldown-gated verb).**
Forcing it onto a game with no elimination would mean inventing an
elimination state the design doesn't otherwise want (`widows_gaze` in
particular explicitly rejects dead time as a design goal). The doctrine is
already applied everywhere it honestly fits (5/15). The real remaining
spectator-engagement gap is a **different tool** for games that never kill
anyone: prediction/wager layers (Wits & Wagers model), not ghosts.

---

## 3. Proposals

### (a) The wager/prediction layer, relocated to where it actually fits

Putt-phase "predict which tile" doesn't work as literally specced (everyone
putts at once, so there's no idle bettor during the charge). Two honest
homes for the same idea, both using **already-decided-but-unrevealed** sim
state (never a fresh RNG draw — this is what keeps it doctrine-clean per
doc 24 §0 rule 1):

- **Reveal-cascade space-type call.** The instant a seat's putt resolves,
  `spaces[i]` (destination tile) is already computed
  (`ProcessionPawnPutt._release`), but the tile's *type* (SHRINE / WEEPING
  GRAVE / TOLLGATE / SÉANCE / VENDETTA / STALL / blank) isn't narrated until
  that seat's individual reveal beat, seconds later, one at a time. During
  the wait, the *other* three seats (who share `_reveal_beat`'s existing
  input-poll loop with F24) get one silent guess at the type before the
  Executor's line lands it.
- **Pre-minigame prediction pool.** Reuse the already-shipped `_minigame_
  block` roulette + "GET READY" splash (F22, commit `44bdf08`) — a beat
  where all four players currently just watch a card, doing nothing. Let
  each lock a silent guess for who wins the upcoming game; resolve against
  the `finished(results)` contract every one of the 14 games already returns.
  This is the cheapest possible spectator hook because it touches **zero**
  per-game code — only `procession.gd`/`executor_host.gd` at the boundary
  every game already crosses.

### (b) Ghost-meddle doctrine coverage — see table above (§2). No further
minigame is an honest candidate; the actionable follow-up is *consistency*
(migrate `dead_weight`/`last_will`/`tilt` onto the shared attribution-toast +
`CooldownRing` idiom) not *coverage*.

### (c) Cheaper still

- **F27 (doc 24, unbuilt): idle pawn business during MOVE/REVEAL.** Lean on
  a headstone, kick a pebble, flinch at a passing crow — reuses the Ambient
  Life Kit (B3) wholesale. Zero new systems, zero new input handling, purely
  visual. The single cheapest fix for "frozen diorama" energy.
- **VENDETTA side-call.** The two non-dueling pawns get one button-tap to
  call the duel's winner before `_resolve_vendetta` prints its result —
  correct callers get an attributed toast only (no grudge/points touch in
  v1). Mirrors Wits & Wagers' core insight (bet on someone else's contest)
  at the one true 1v1-while-2-watch moment the anthology actually has.

---

## RANKING — top 5 (joy per effort)

1. **Reveal-cascade space-type call** — bet on the tile-type before the
   Executor narrates it, using the F24 poll loop that already exists.
2. **VENDETTA onlooker side-call** — give the two non-dueling pawns at the
   board's only real 1v1 a one-tap stake in the outcome (Wits & Wagers
   transplant).
3. **Pre-minigame prediction pool** — universal, touches zero per-game code,
   reuses the shipped roulette/GET READY beat and the results contract.
4. **Ghost-meddle consistency pass** (not new coverage) — unify
   `dead_weight`/`last_will`/`tilt`'s bespoke ghosts onto the shared kit's
   attribution/cooldown idiom; flag the poltergeist murder-vs-mischief
   tension to B6's owner.
5. **F27 idle pawn business** — cheapest possible fix, pure Ambient Life Kit
   reuse, no new mechanic at all.

---

*Sources: Wits & Wagers ([Wikipedia](https://en.wikipedia.org/wiki/Wits_and_Wagers),
[UltraBoardGames](https://www.ultraboardgames.com/wits-and-wagers/game-rules.php));
Jackbox enhanced spectator ([Jackbox blog](https://www.jackboxgames.com/blog/how-audience-play-along-differs-in-each-jackbox-game));
Fall Guys spectator mode ([Player Assist](https://playerassist.com/how-to-spectate-in-fall-guys/),
[Fandom](https://fallguysultimateknockout.fandom.com/wiki/Spectator_Sport));
Mario Party Bonus Stars/VS ([Mario Wiki](https://www.mariowiki.com/Bonus_Star));
Smash crowd ([SmashWiki](https://www.ssbwiki.com/Crowd)).
In-repo: `core/ghost_meddle.gd`, `estate/procession/pawn_putt.gd`,
`estate/procession/procession.gd`, `minigames/dead_weight/poltergeist.gd`,
`minigames/last_will/lw_ghost.gd`, `minigames/tilt/seagull.gd`,
`minigames/echo_chamber/echo_chamber.gd`, `minigames/orbital/orbital.gd`,
`docs/design/24-board-broadcast-standard.md`.*
