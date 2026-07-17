# 27 — Night 6 Research Dossier (2026-07-17)

Ten research lanes ran in parallel (Fable ×2, Opus ×3, Sonnet ×4, GPT-5.6 via
Codex ×1) with different lenses: party-board loop mastery, gacha/mobile
mechanics ethically transplanted, arena environment audit, dark-comedy
presentation devices, onboarding, game-feel juice, spectator engagement,
meta-progression, audio infrastructure, and a cold second-model design review.
Full reports live in the session scratchpad; this doc is the curated synthesis —
what the fleet found, what night 6 builds, and what's queued for Alex.

## The headline findings

1. **The estate already records a saga it never performs.** Chronicle, ledger,
   vendetta{}, monuments, album — all on disk, real 5-night history (RED ×4
   monuments, BLUE back-to-back, MINT winless DOORMAT ×3) — and the game
   whispers it once and lets it scroll off. Ceremony + browsability is the gap,
   not data. (R8)
2. **The board's signature duel involves zero human decisions.** `_stake_for()`
   rolls RNG for humans too. Dokapon Kingdom's lesson: attributed humiliation,
   not the transfer, is what destroys friendships. (R1)
3. **The will-clause race is announced at minute 0 and paid at minute 25 with
   nothing in between** — the cheapest pacing fix in the report (announce
   current leaders at each HOUSE AWAKENS). (R1)
4. **A pile of shipped assets was never wired**: the purpose-built
   `tick_countdown` samples (the most-heard SFX moment plays a UI click
   instead), the entire `ui_*` menu SFX family, the `stinger_*` family, the
   crow GLB in zero arenas, `Ambience.play_bed()` unadopted. Night-4 lanes
   shipped assets; nobody cross-wired them. (R9, R3)
5. **The daylight walkabout was the only day island in the whole flow** —
   title (moonlit) → hub (day!) → board (moonlit). Fixed tonight per Alex's
   call. (director)
6. **Five games ship no intro card, including the anthology's hardest
   mechanics** (MASKED BALL, THE SÉANCE), and PALLBEARERS double-carded
   (fixed tonight, one line). (R5)
7. **Below/beyond the arenas is present but inert.** B8's dressing pass gave
   the outdoor games horizons; the AAA move now is a *reveal* — what the fall
   shows you, what's behind the throne, what's at the bottom of the well. (R3)
8. **Juice is unevenly distributed:** translation-only screenshake everywhere
   (no roll), six games attach FinalStretch but never fire its fov_punch, and
   `Input.start_joy_vibration` has zero occurrences in a couch party game. (R6)
9. **Ethical gacha transplants exist and fit the theme perfectly** — pity as
   "the estate takes pity," the 10-pull as a sealed-bequest ceremony, login
   streaks inverted into VISITATION HOURS (absence never punished, only drily
   noted). The report also lists eight dark patterns to never transplant. (R2)
10. **The Stanley Parable's best trick is unused:** the game says nothing when
    you stop playing — pause, idle, quit-confirm are all silent hooks in a
    game with a resident narrator. (R4)

## What night 6 builds (the wave)

| Lane | Contents | Source |
|------|----------|--------|
| W1 BOARD DRAMA | Interim Reading at HOUSE AWAKENS; sealed vendetta stakes (hold-to-raise, humans only, bots keep RNG); winner hangs an epitaph on the loser | R1 |
| W2 CEREMONY SAGA | Standing Grudge night-open card (vendetta finally performed); Funeral Statistics run-end audit; eulogy as itemised receipt | R8, R4 |
| W3 ARENA REVEALS | Crows on every outdoor horizon; TILT drowned-heirs graveyard + circling threat; echo well-bottom bone pit; throne stained glass; PALLBEARERS real mourners | R3 |
| W4 AUDIO CROSS-WIRE | tick_countdown fix; stinger inside fov_punch; ui_* adoption; first Music.duck() | R9 |
| W5 JUICE | Rotational screenshake house-wide; fov_punch for the six punchless games; first controller rumble | R6 |
| W6 STANLEY HOOKS | Executor narrates pause/idle/quit; séance wheel STOP button that does nothing; FINAL DISPOSITION label pass | R4, R2 |
| W7 INTRO WIRING | GAME_INTRO cards for masked_ball, seance, orbital, echo_chamber | R5 |
| direct | Moonlit walkabout (7688295); PALLBEARERS double-card fix (4486119) | Alex, R5 |

## Queued for Alex (morning menu material, not built tonight)

- **THE DISINHERITED** (R1 big swing): Dokapon's Darkling adapted — last place
  may accept the Executor's terms, 2 rounds veiled with fangs, never touches
  deeds. The genre's only beloved catch-up mechanic. 10–14h + a bot-soak
  balance night.
- **THE RECORDS** (R8 flagship): walk-up lectern almanac — hall of heirs,
  titles, monuments index, all-time standings. 8–12h, pure presentation.
- **"PREVIOUSLY, ON THE ESTATE"** (R8 big swing): 15–25s cold-open recap of
  last night via the existing Newsreel engine. 6–9h.
- **THE BEQUEST** (R2): sealed parcels at the will reading, wax-seal color
  tells, opened loser-first. 5–8h; touches the crowded ceremony chain.
- **VISITATION HOURS** (R2): return-to-estate arrival ceremony; absence noted,
  never punished. 3–4h.
- **Prediction/side-bet layer** (R7 + R1): reveal-cascade tile-type calls,
  vendetta onlooker side-calls, pre-minigame winner pool riding the roulette
  spin. All presentation-only under the meddle doctrine. 4–12h each.
- **Kill-cam port to echo_chamber's ghost-kill** (R6): the one juice item with
  real determinism risk; golf's timeline-neutral pattern exists to copy.
  10–16h.
- **widows_gaze EnvKit conversion** (R3): last game on a hand-rolled FILMIC
  env — a house-look seam.
- **Honest micro-putt for HOUSE AWAKENS** (R1): copy says "pawns putt for
  safety" but it's a pure RNG roll — a quiet violation of the "nothing hidden
  decides" pillar.
- **Ghost-meddle consistency pass** (R7): dead_weight/last_will/tilt each have
  bespoke pre-kit ghosts; unify onto the shared kit's attribution/cooldown
  idiom. Also: dead_weight's furniture-hurling poltergeist can cause void
  deaths — in tension with mischief-not-murder.

## R10 — the cold second-model read (GPT-5.6 via Codex)

Landed after the wave launched; converges with R1 on the central wound —
**agency inversion**: the most emotionally consequential board outcomes
(contested deeds, item targeting, vendetta stakes) are settled by seat order
or RNG, so resentment attaches to the rules instead of another player,
starving the grudge premise of stories. W1 fixes the vendetta half tonight.
Unique finds, all queued for Alex:

- **Board profiles + no-repeat docket**: blocks pass `rounds: 2` blindly to a
  with-replacement pool, producing 90s GREED next to 13s PALLBEARERS runs.
  Give every game a 60–90s board format + eligibility, pre-deal the docket.
- **Contested Codicil = seat-index bias**: simultaneous affordable crossings
  award to the first seat index; tied clause stats silently favor low seats.
  Fix = exact-landing priority, then smallest putt error, visible tiebreak.
  ⚠ sim change — would re-freeze receipts; needs a deliberate receipt bump.
- **The auction isn't an auction**: second-round "auction" hands everyone a
  random free item; the promised spite-bidding never happens. Reuse the
  8-second bid surface for three visible sabotage lots.
- **Finish-rule honesty**: "first to the required deeds is crowned" isn't
  reliably true once will clauses pay out; crown the threshold claimant,
  make clauses visible side-goals (the Interim Reading is the first step).
- **Procession settlement gap**: the board writes heir monument + graffiti but
  skips newsreel archive, ledger, chronicle, night count, nemesis record on
  its way back to the title. Also: toll graves can compound onto one player —
  cap income monuments at one grave per player.
- **LETTERS OF ADMINISTRATION** (adjacent-genre idea): gacha pity as probate
  paperwork — a visible claim card stamped each time you can't afford a
  reached Codicil or lose a contested filing; three stamps = uncontested
  first refusal on your next affordable filing. No free deeds, pure theme.

## Corrections the fleet made to the director's brief

- TILT is not floating over nothing (B8 gave it an ocean + skerries); the gap
  is the sea being *inert*. Briefs age fast on a repo moving this quickly.
- The putt phase is already simultaneous — the idle-watch moment is the reveal
  cascade, not the putt. Only vendetta is a true 2-act-2-watch beat.
- 5 of 15 games have some dead-seat ghost verb (three bespoke, pre-kit), not 2.
