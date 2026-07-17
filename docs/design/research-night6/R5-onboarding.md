# R5 — Onboarding & Per-Minigame Instruction Quality Audit

Scope: ILL WILL (`C:\Users\agall\projects\un_party_game`), Godot 4.6.2, 15 modes
registered in `estate/estate.gd` MODULES (14 folders under `minigames/` + `par`,
which is the golf mode living at `res://scenes/main.tscn`).

## 1. The two onboarding systems that exist today

**A. `estate/howto_cards.gd` (estate-owned).** Every game gets an entry in the
`HOWTO` dict (goal string + `a`/`b`/`jump` verb labels). This text is shown in
two places:
- The selector's "PICK A GAME" how-to card (exhibition mode).
- The pre-night **GET READY** gate (`show_get_ready`), up to `READY_GATE_TIME =
  15.0`s, with live control glyphs (`PlayerInput.describe_binding` /
  `InputGlyphs`), a per-seat "PRESS A" chip, and a plain-text countdown
  ("begins in Ns"). No radial ring, no rotating tips, no visible arena/demo
  behind it — it's a static panel.

**B. `core/ui_kit/intro_card.gd` (module-owned, the "AAA beat", doc 14 §5).**
A `CanvasLayer` overlay: big name + one-line goal + live control chips +
**rotating tip line** + a procedural **radial READY ring** (auto-starts at a
configurable `auto_secs`, default 6s) + per-seat player-badge pips that light
up as each human readies. Critically, this card is a *dim translucent overlay*
(`Color(0.05,0.04,0.07,0.72)`) drawn over whatever 3D scene is already loaded —
so in principle the arena is visible (if dim) behind the card, though no game
currently animates a bot demo through it (confirmed: `_start_round()` — the
actual gameplay tick — only fires after the card finishes; bots don't move
during the card in any game inspected).

**The wiring switch:** `estate.gd`'s `MODULES` dict carries an optional
`"intro": true` flag per game. `_launch_game()` (line 1857) implements "the
double-gate collapse": if `intro:true` **and** it's a couch launch (no remote
humans), the estate's GET READY card is skipped entirely and the game boots
straight into its own IntroCard. If remote humans are present, the estate
still shows a stripped "everyone in" minimal sync card, then the module's
IntroCard runs its full goal+controls+tips+ring. If `intro` is absent/false,
the estate's full 15s GET READY text card is the **only** onboarding the
player gets before the round starts.

## 2. Per-game inventory

Games **with** their own `GAME_INTRO`/IntroCard (`"intro": true` correctly
wired, module boots straight to its own card, goal text tightened to one
sentence, live tip rotation, radial ready ring):

| Game | Card goal text (as shown) | Words |
|---|---|---|
| MOWER MAYHEM | "Mow stripes in your color — coverage IS score." | 9 |
| TILT | "One platter, one pin. Last one aboard wins the round." | 10 |
| GREED INC. | "The pot fills forever. Bank it at your chute — but carrying makes you a slow, glowing target." | 17 |
| DEAD WEIGHT | "Sumo brawl in the attic. Shove rivals off — the fallen return as furniture-hurling ghosts." | 15 |
| THE THRONE | "Whoever SITS scores every second but can't move. Gang up, drain their GRIP, fling them off." | 16 |
| LAST WILL | "A funeral race where DYING IS A POWER. Three lives each — first body to the crypt inherits." | 16 |
| THE UNDERSTUDY | "Three know tonight's PLAY. One is faking. Spot the Understudy — or bluff through as one." | 15 |
| THE WIDOW'S GAZE | "Rob the wake while she weeps. FREEZE when she turns — or be taken." | 12 |
| PALLBEARERS | "Carry the pall to the crypt first. You share one coffin — steer together or drop the dead." | 16 |

These 9 are genuinely good — single clear objective, one dominant verb up
front, ≤17 words, real-key control chips, a countdown players can see filling.
This already substantially matches the WarioWare/Mario-Party synthesis this
anthology's own doc 14 (§5, citation MP-INSTR-1) already researched.

**PALLBEARERS BUG:** it has a complete, well-written `GAME_INTRO` const and
calls `_present_intro_card()` exactly like the other 8 — but its entry in
`estate.gd`'s `MODULES` (line 28) is missing `"intro": true` (comment tag
`# B7-HOOK` marks it as an unfinished hook). Result: on a couch launch, the
estate shows its **full 15s GET READY card** (goal text pulled from the older,
looser `HowtoCards.HOWTO["pallbearers"]` string — different wording than the
module's own card) and then, the instant the scene loads, PALLBEARERS
immediately shows **its own IntroCard again** — same information, twice,
back-to-back, with two different phrasings of the same goal. This is the
anthology's newest mechanic (first 2v2 blended-stick co-op carry) and the one
most in need of a single clean explanation — instead it gets a redundant
double-card. **One-line fix:** add `"intro": true` to the pallbearers entry.

Games with **no module-level IntroCard at all** — onboarding is *only* the
estate's static 15s GET READY text card, no ring, no tips, no per-game demo:

| Game | Estate HOWTO goal text (as shown today) | Words | Mechanic novelty |
|---|---|---|---|
| ECHO CHAMBER | "Duel beside your own GHOST — it replays your previous round. Shatter the others before the past catches up." | 19 | High — "fighting a translucent copy of your past self" is a concept, not an action; unpicturable from text |
| ORBITAL DODGEBALL | "Dodgeball on a tiny planet. Throws ORBIT forever — a 45-second-old ball still kills, and its thrower still gets paid." | 20 | High — orbital ball physics is a genuinely novel visual; "orbits forever" means nothing until seen |
| SWAP MEET | "Kart race where your weapon TRADES PLACES with whoever it hits. The lead is a rumor." | 15 | Medium — "trades places" (position-swap-on-hit) is unusual enough to want a visual |
| THE SÉANCE | "A co-op séance: guide the planchette to the spirit's word — but one of you was paid in grudge to make it fail without getting caught. The Executor is the medium." | 31 | Very high — hidden-traitor/social-deduction mechanic in a 4-clause sentence |
| MASKED BALL | "A crowd of identical masked dancers — four of them are you, and nobody is told which. Find yourself, dance like furniture, curtsy to the throne, and spend your one mark to unmask a human. Wrong guess: you flash." | 38 | Highest in the anthology — hidden-identity-among-20-clones, four combined verbs (find/dance/curtsy/unmask), by far the longest goal text of any game |

These five are exactly the games where a static paragraph is weakest: three of
them (SÉANCE, MASKED BALL, and to a lesser extent UNDERSTUDY, which *does*
have a card) are hidden-role/social-deduction mechanics that genre precedent
(Jackbox, social party games) teaches almost never work from text alone — they
need either a worked example or a live look at what "you" actually see when
you're the traitor/impostor/understudy. ECHO CHAMBER and ORBITAL are novel
*physics* concepts (fighting your own replayed ghost; a ball that never stops
orbiting) that are trivially clear once seen and nearly opaque as prose.

`PAR FOR THE CURSE` (golf) is the exception worth naming separately: it also
has no module IntroCard, but it is the anthology's flagship/tutorial game and
additionally gets the one-time **HOUSE RULES** card (first-night economy
primer, 5 lines, up to 45s for humans) — so it is comparatively over-taught,
not under-taught. Not a top-5 offender.

## 3. First-five-minutes flow (title → new game → walkabout → procession)

Traced through `estate/estate.gd` phases (`LOBBY → SELECTOR/GROUNDS → AUCTION
→ CHOOSING → GAME → RECKONING`) and `docs/design/18-procession-build-spec.md`:

- Title → seat-claim is a press-your-own-device flow (`core/party_setup.gd`),
  already matches the Overcooked/TowerFall "claim = your own input" pattern
  doc 14 §1.1 already researched and scored well against.
- First-ever estate (fresh slot) gets the one-time HOUSE RULES card explaining
  the DEEDS/GRUDGE/ROYALTIES economy before the first AUCTION — good, matches
  Jackbox's "explain the abstraction once, plainly" instinct.
- THE PROCESSION (board mode) is spec'd with a "board intro flyover (Executor
  greeting)" at night setup (doc 18, NIGHT SETUP line) and an explicit design
  rule that **all space effects are announced, zero hidden arbiters** (Q7) —
  this is the correct call per the same genre precedent (Jackbox/Mario Party
  board legibility) and already implemented as a design constraint, not a gap.
- The minigame **selector→howto→PLAY/PRACTICE** flow already offers a
  no-stakes PRACTICE button for 13 of 14 non-golf games (`show_howto`, line
  262: excluded only for `id == "par"`) — this is a good existing safety net
  and already close to the "practice round" convention Mario Party and this
  project's own doc 14 already cite (MP-INSTR-1). The gap isn't the *presence*
  of practice; it's that entering practice for the 5 no-intro-card games still
  only shows the same thin static text, not a demo.

No countdown-ring or live-arena element exists anywhere in the title→walkabout
path itself; the two countdown mechanisms (HOUSE RULES's plain seconds-left
label, GET READY's plain seconds-left label) are both text, while the module
IntroCard's radial ring is visually the strongest countdown affordance in the
anthology — another argument for pushing more games onto the IntroCard path
rather than leaving them on the estate-only gate.

## 4. External comparison (quick web research, cited)

- **WarioWare**: instructions are a single imperative verb ("Dodge!", "Eat!",
  "Squash!", "Jump!") shown for a few seconds before the microgame begins —
  the extreme floor for "one verb, no paragraph." [en.wikipedia.org/wiki/WarioWare;
  mariowiki.com/Microgame]
- **Overcooked**: teaches by throwing players into simple one-button-interact
  gameplay and letting failure (burning food) force real-time role
  renegotiation rather than more upfront text — "learn by burning," not by
  reading. [superjumpmagazine.com/overcooked-how-design-creates-teamwork]
- **Mario Party** (already researched in this repo, doc 14 §5, MP-INSTR-1):
  instructions are shown **alongside a small live demo viewport** of the
  minigame being played, with a practice input window before the timed round
  starts — instruction + demonstration + a free rep, not text alone. This
  anthology's own IntroCard pattern implements the "instruction" half of that
  (goal + controls + ring) but not the "live demo viewport" half — no game
  anywhere shows the mechanic being demonstrated (by bots or otherwise) while
  the card is up.
- **Jackbox**: audience-readable rules are short, plain-language, and
  explicitly designed to be parsed by someone glancing at a shared TV, not
  read carefully — the anthology's 9 wired IntroCard games hit this bar; the
  5 unwired ones (especially SÉANCE at 31 words and MASKED BALL at 38) do not.

## 5. Proposed standard

Every minigame's onboarding should have, in order: **(1)** its own
`GAME_INTRO` const + `IntroCard` (not just the estate's generic gate), with
`"intro": true` set in `estate.gd`'s MODULES so the estate gate collapses
instead of stacking; **(2)** a single-sentence, single-dominant-verb goal line
≤20 words in the house's probate-deadpan voice, paired with live real-key/pad
glyph chips (already standard via `PlayerInput.describe_binding`); **(3)** a
visible countdown the player doesn't have to read (the radial ready ring,
already built) rather than a plain "begins in Ns" label, and — for any
mechanic that can't be pictured from one sentence (hidden-role, novel
physics, blended-input co-op) — a plain clarifying line in the tip-rotation
slot (Jackbox-plain, e.g. "you'll only find out it's you") standing in for
the live-demo-viewport this anthology hasn't built yet.

## 6. Top 5 worst offenders (ranked) + fix

1. **PALLBEARERS** — real bug, not a gap: `"intro": true` missing from its
   `estate.gd` MODULES entry causes a redundant double-card (estate's GET
   READY text card immediately followed by its own, differently-worded,
   IntroCard) on the anthology's newest co-op mechanic. Fix: add `"intro":
   true` to the MODULES entry (one line, `estate/estate.gd:28`).
2. **MASKED BALL** — 38-word, 4-verb goal text, hidden-identity-among-clones
   mechanic, zero module IntroCard. Fix: add a `GAME_INTRO` const (tighten to
   one sentence, e.g. "Find yourself among 20 identical dancers — curtsy to
   score, save your one mark to unmask a human"), wire `_present_intro_card()`
   the same way the other 9 games do, set `"intro": true`.
3. **THE SÉANCE** — 31-word goal describing a co-op hidden-traitor mechanic
   in one dense sentence, zero module IntroCard. Fix: same pattern — a short
   goal line plus a tip-rotation line that plainly states what the secret
   saboteur sees that everyone else doesn't (the genre-standard clarifying
   beat social-deduction games always need).
4. **ORBITAL DODGEBALL** — the anthology's most physically novel mechanic
   ("throws orbit forever") described only in prose, no module IntroCard, no
   visual. Fix: wire the existing IntroCard pattern (goal text already
   exists in `HowtoCards.HOWTO`, just needs a `GAME_INTRO` const + the
   `_present_intro_card`/`"intro": true` hookup already proven in 9 other
   files).
5. **ECHO CHAMBER** — "duel your own ghost" is a concept, not a picturable
   action, with zero module IntroCard; players' first reaction to seeing a
   translucent duplicate fighter with no explanation is likely confusion.
   Fix: same wiring, with a tip line explicitly stating "the translucent
   fighter is YOUR OWN past round, not an opponent."

(SWAP MEET has the same "no module card" gap as #4/#5 but its goal text is
shorter and the mechanic is closer to genre-familiar kart-item chaos, so it
ranks 6th, just outside the top 5.)

## 7. Total effort estimate

The fix is almost entirely **wiring an already-proven pattern**, not
redesigning anything: 9 of 15 games already have a working `GAME_INTRO` const
+ `_present_intro_card()`/`_intro_then()` hook + `"intro": true` flag, so the
same ~15-20 line pattern can be copy-adapted per remaining game.

- PALLBEARERS fix: 1 line, ~5 minutes.
- ECHO CHAMBER, ORBITAL, SWAP MEET: tighten existing HOWTO text into a
  `GAME_INTRO` const, add the IntroCard hook, flip the MODULES flag, smoke-test
  with a screenshot — roughly 20-30 minutes each (3 games ≈ 1-1.5 hours).
- THE SÉANCE, MASKED BALL: same wiring plus actually rewriting the goal text
  down from 31/38 words to a single clean sentence, and drafting a genuinely
  clarifying tip line for the hidden-role mechanic (needs a little more
  writing care than the other three) — roughly 30-45 minutes each (1-1.5
  hours combined).

**Total: well under one working session, roughly 3-4 hours** including
verification screenshots for all 6 touched games (5 new cards + 1 flag fix),
no engine/architecture changes required.
