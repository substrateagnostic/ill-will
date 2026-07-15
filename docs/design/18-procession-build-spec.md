# 18 — THE PROCESSION: Director's Decisions + Build Spec (2026-07-15)

Based on doc 13 (board-mode research). Decisions made by the fourth-watch
director under Alex's full-autonomy delegation; every one is overridable in
the morning. Logged in alexmemory.md.

## The eight calls (doc 13 §E)

- **Q1 Movement verb → PUTT YOUR PAWN** (frozen Par physics, skill over luck).
  The séance planchette becomes the SÉANCE CIRCLE space's event mechanic, not a
  roll variant. Gravestone-smash deferred.
- **Q2 Trail → (b) absorbed.** One board engine, presets: QUICK WAKE
  (decision-layer-off, Koopathlon-style score=movement — the old Trail's soul)
  and THE PROCESSION (full board). No third parallel system.
- **Q3 Hard currency → DEEDS.** One syllable, legible at a glance, and the
  estate's owner is a trusts & estates attorney — deeds to the manor it is.
  Grudge stays the soft currency.
- **Q4 Length → default SHORT PROCESSION (Deed goal 4, ~25 min)** with the
  Deed-goal dial exposed in night setup (4/6/9 = Wake/Procession/Vigil).
- **Q5 Simultaneity → (a) parallel roll+move, staggered Executor reveal.**
  The wedge. Parallelize the boring part, serialize the funny part.
- **Q6 Nemesis → YES.** Vendetta duel spaces trigger 1v1 wager when your
  nemesis is within reach. The estate's soul stays on the board.
- **Q7 Hidden info → ZERO hidden arbiters.** Codicil location, will clauses,
  space effects all announced. Legible deviousness.
- **Q8 Build increment → FULL APPROACH A NOW.** The B-first recommendation is
  human-team risk management; our risk management is agent verification loops
  and the budget is deep. Quick Wake falls out of the same engine as a preset
  flag, not a predecessor.

## Session structure (locked for v1)

One Procession = one complete wake: an HEIR IS CROWNED every session.
Persistence stays WORLD-level, not score-level: monuments, gate statues,
vendettas, graffiti, wardrobe all persist across nights as today. (The old
multi-night trail-position campaign survives inside QUICK WAKE preset for
continuity.)

```
NIGHT SETUP: seats → Deed goal dial → board intro flyover (Executor greeting)
ROUND LOOP:
  ROLL   ~8s  all 4 putt their pawns simultaneously (hold-release power meter,
              own corner UI, sweet-spot bands = exact space targeting;
              pawn rolls along the drive rail, stops on a space)
  MOVE   ~5s  pawns travel at once; whole-board camera
  REVEAL ~9s  staggered Executor cascade, one landing at a time, camera pushes
              in per victim; grudge/deeds fly visibly
  every 2nd round → AUCTION (item shop) → MINIGAME → RECKONING
  every 3rd round → THE HOUSE AWAKENS (all-in survivathon; losers slip back)
NIGHT END (Deed goal reached): WILL-READING (pre-announced clauses = bonus
  Deeds) → most Deeds INHERITS → podium → monuments written to the estate
```

## Space grammar v1 (doc 13 §C table, all effects announced)

WEEPING GRAVE (lose Grudge; player-monument graves pay their owner) ·
SHRINE (gain Grudge/blessing) · THE STALL (buy sabotage item) ·
CODICIL (pay Grudge → claim Deed; relocates after each claim) ·
SÉANCE CIRCLE (planchette event, communal, pre-announced) ·
TOLLGATE (pass=pay owner, land=collect pot) ·
VENDETTA (nemesis within N spaces → 1v1 wager duel)

~24 spaces looping the estate drive. Board furniture from tonight's Meshy
batch (waypoint stones, tollgate arch, codicil pedestal, signpost, hearse).

## Engine architecture (new files, minimal estate.gd hooks)

`estate/procession/` — procession.gd (round state machine + net mirror),
board_path.gd (rail + space graph over the existing grounds),
board_spaces.gd (space grammar + effects table), pawn_putt.gd (roll verb,
reusing frozen putt physics constants), codicil.gd (economy),
executor_host.gd (reveal cascade lines + camera calls), presets.gd
(Wake/Procession/Vigil dials). Integration: one new phase in estate.gd's
night flow + a PLAY-menu entry. Online: same _net_state/_net_apply house
pattern from day one; putt intents are seat-attributed (solves what Par
online needs, in new code).

## Non-negotiables

Putt physics constants stay frozen (reuse, don't retune). No hidden state.
Every ceremony skippable by all-players-press-A except the win reveal.
Minigame contract untouched — any of the 13 games slots into the block.
