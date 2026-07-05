# THE SÉANCE — verification & design conformance

*Game #11, the anthology's first social-deduction game, hosted at the
Theater. Built against `docs/design/06-social-deduction-research.md`
pitch #1 and `docs/specs/anthology-module-contract.md`. Files:
`minigames/seance/` (seance.tscn, seance.gd, seance_bots.gd,
seance_figure.gd, seance_planchette.gd, seance_ui.gd, seance_words.gd).*

## Design conformance vs the research doc

### Followed as specified

| Doc requirement | Implementation |
|---|---|
| Co-op word-guess with a paid saboteur (Insider inverted) | Four sitters share ONE planchette; the Executor knows the word; the Charlatan is paid 2 grudge up front to make the sitting fail without getting caught. |
| Round flow ~4:00: Cast → task (90s) → open talk (30s) → locked vote (15s) → unmask + settle (~25s) | CAST ~22s, SÉANCE 90s cap, TALK 30s (8s when the whole table is bots), VOTE 15s, REVEAL sequence ~10s. Full 4-bot matches land at 2:00–3:30 game time. |
| Shared focus meter, decays over 90s, legible in aggregate | `focus` 0..90: passive decay 1.5/s; drawn as a HUD bar AND diegetically as ten tealights on the table that snuff as focus dies. |
| All four tap A in rhythm | The spirit candle at the head of the table pulses every 0.85s (plus a quiet tick). On-beat taps feed focus (+0.45), off-beat taps drain it (−1.1), spam counts as off-beat. Every tap flares the tapper's own candle — identical visual on/off beat, so rhythm is *watchable per suspect but not for four suspects at once*. That is the doc's deniability-by-parallelism, made literal. |
| Saboteur mistiming taps / nudging onto a wrong letter is deniable | Steering is NEVER visualized per player (one shared motion, like a real Ouija board). B-surges show one ANONYMOUS ripple on the planchette. Wrong letters cost 13 focus; correct letters pay 5 and fill the blanks. |
| Word guessed before meter dies = table wins; meter dies / clock out = Charlatan wins | Implemented exactly (`SEANCE_TASK success=... cause=spelled/focus/time`). |
| Two-button votes: stick swings across portraits, A locks, simultaneous locked votes, distributed scoring | Portrait row with per-voter badge chips; stick cycles, A locks irrevocably; every correct finger pays royalty INDIVIDUALLY — no majority ever resolves the scoring, per doc (d) preamble. |
| Economy: grudge in, royalty out | Fee: 2 grudge at cast. Success → each honest sitter +1 royalty. Fail + escape → Charlatan +2 royalty ("converted the fee"). Caught → Charlatan +2 grudge, each correct finger +1 royalty. Practice mode reports no currency. |
| The reveal always happens (pillar-1 walled garden) | The Executor unmasks the Charlatan at the end of every sitting, caught or not, and the word is disclosed if the séance died. |

### Adapted, and why

1. **Secret delivery: doc method #2 (eyes-closed narration), mechanically
   backed by method #4 (equal-length per-seat flashes).** The doc's ranked
   method #2 assumes roles were dealt before the narrator speaks (ONUW app
   model). On one shared screen with no dealt cards and no guaranteed
   rumble (KB/M players feel nothing — the doc itself forbids rumble as a
   sole channel), a player cannot learn "you are the one" without the
   screen touching them once. So the Cast keeps the Executor's eyes-closed
   liturgy but gives EVERY seat an identical-length private flash (~4.4s
   each): three read FAITHFUL, one reads the word and the contract. Equal
   beats mean timing leaks nothing. This is the honest minimum for our
   input set; the doc's "minimize how many seats need it" is satisfied at
   the floor (identity delivery requires all seats exactly once).
2. **The Charlatan knows the word (not just their role).** Insider's
   insider knows the answer; inverting to sabotage keeps that: the paid
   hand steers AWAY from letters only they know are right. This makes
   sabotage informed rather than random, which is what makes the tell
   behavioral (the doc's core argument for pitch #1).
3. **Letter commit is by dwell (0.9→1.15s hold), not by B-press.** A
   B-committed letter would be attributable on a shared screen (everyone
   sees who pressed), destroying deniability. Dwell keeps the commit a
   product of the SUM of hands; B is instead an anonymous surge (a yank
   with a 2.5s cooldown) — the saboteur's emergency tool and the honest
   players' course-correction, visually identical.
4. **Pointing is public during the vote; the LOCK is the commitment.**
   True hidden hovering is impossible on one screen. At a séance table you
   point with your whole arm; herding is a social risk, not a scoring one
   — distributed payouts mean a wrong herd only embarrasses the herd.
5. **Catch threshold**: "caught" = 2+ correct fingers (of 3 honest at a
   4-table; min(2, honest) below that). Individual correct fingers are
   paid royalty REGARDLESS — the threshold only decides the Charlatan's
   own fate, so the 2v2 stalemate trap the doc warns about cannot decide
   scoring.
6. **Points**: being caught voids the Charlatan's bonus entirely (the
   contract was "fail WITHOUT getting caught"): escape+fail 5, escape+
   success 1, caught 0. Honest: +2 on success, +1 for a correct finger.
7. **One sitting per module invocation** (config `rounds` is a length
   knob the game interprets; the doc's 3–5min pacing target IS one
   sitting). Practice = same flow, no stakes.

## Bot legibility evidence

Bots are seeded (`rng_seed ^ 0x5EA0CE`), deterministic per seed
(verified: two seed-5 tally runs produced byte-identical commit/vote/
verdict logs — "DETERMINISM PASS").

- **Guesser bots** hold a belief target: with per-bot `insight`
  (0.45–0.7) it is the word's next unrevealed letter (they try to spell
  in order — reads as intent), otherwise an English-frequency-weighted
  plausible letter (E before Q — wrong guesses look human). Chant jitter
  sigma 0.055–0.11s ≈ 85–99% on-beat.
- **Saboteur bot** plays honest for a 6s alibi window, then targets
  plausible-LOOKING letters that are not in the word (smart sabotage
  imitates honest error), degrades chant timing (~40–50% on-beat,
  deniable as lag), and yanks (B) when a correct letter is >25% charged —
  gated by a die roll so it is not clockable. It also votes, framing the
  clumsiest honest player.
- **Voting bots** read the game's public-evidence `suspicion` tally
  (wrong-commit pull attribution + off-beat ratio + surge proximity)
  through seeded noise — couch players, not auditors.

**Outcome spread across seeds 1–8 (full 4-bot matches to `finished()`):**

| seed | word | charlatan | task | caught | correct votes |
|---|---|---|---|---|---|
| 1 | GHOST | RED | FAIL (focus 0) | yes | 2 |
| 2 | COFFIN | MINT | success | no | 1 |
| 3 | GRAVE | GOLD | FAIL (focus 0) | yes | 2 |
| 4 | ESTATE | MINT | FAIL (focus 0) | yes | 3 |
| 5 | WINTER | BLUE | success | yes | 2 |
| 6 | CLOCK | GOLD | success | no | 1 |
| 7 | VELVET | BLUE | success | yes | 3 |
| 8 | GRAVE | BLUE | FAIL (focus 0) | no | 1 |

4/8 fail, 4/8 success — the co-op task is genuinely contested. **Control
run with `--seancesabo=off`** (charlatan seat exists, its bot plays
honest): seeds 1–4 all SUCCEED at focus 93–100 with 0–1 wrong commits —
proof the failures above are CAUSED by the saboteur's play, not by bot
incompetence. Suspicion correctly tops the charlatan in most sittings
(e.g. seed 2: MINT 3.74 vs next 1.32) while staying noisy enough for
escapes and occasional frame-jobs — behavioral deduction, not an oracle.

## Contract conformance

- `begin(config)` / `finished(results)` via `report_finished()`;
  placements include every roster player; `points` per player;
  `currency_events` per the economy above; `highlights` (≤3);
  `monuments`: "the Perfect Con" for a fail with ZERO correct fingers.
- `kill_events`: a successful unmasking reports exactly ONE kill — the
  first correct accuser to lock is the killer, victim = charlatan, cause
  `"seance"` (seed 3: `[{killer:3, victim:2, cause:"seance"}]`). No
  catch, no kill — nothing fabricated.
- Input via PlayerInput only (stick + A + B); per-seat bots honor
  `roster[i].bot`, standalone uses `PlayerInput.standalone_bot_default`.
- No physics bodies: the planchette is kinematic, so bot matches are
  deterministic at pinned dt. No `randomize()`; visual-only randomness
  uses a separate rng stream that never gates logic.
- Files touched: `minigames/seance/` + `docs/verify/` only.

## Commands run

```
godot --headless --editor --import --quit --path .
# full bot matches to finished(), fast-forwarded at pinned 1/60 dt:
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=N   # N = 1..8
# honest-baseline control:
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seancesabo=off --seed=N
# determinism: seed 5 run twice, logs diffed -> identical
# windowed screenshot run (event snaps fire automatically):
godot --path . res://minigames/seance/seance.tscn -- --seancebots --seed=3 --quitafter=20000
```

## Screenshots (docs/verify/shots/)

- `seance_cast_card.png` — the Cast: GOLD's private flash ("YOU WERE
  PAID — 2 GRUDGE, UP FRONT / THE WORD IS \"GRAVE\" / Bury it. Do not get
  caught.") over the eyes-closed blackout.
- `seance_board_sitting.png` — the sitting: candlelit table, three-row
  letter board with revealed (gold) and recoiled (dark red) letters,
  blanks + Executor clue up top, focus bar low, tealights snuffing,
  all four KayKit sitters with badge-glyph nameplates.
- `seance_accusations.png` — the vote: portrait row with badge chips
  (MINT locked on GOLD, others hovering), two-button hint line.
- `seance_reveal_unmask.png` — the unmask: "■ GOLD" banner, portraits
  dimmed to the guilty one, locked chips on display.
- `seance_settle_verdict.png` — the verdict: GOLD's mage collapsed
  under the stage spotlight (Death_A), "THE CIRCLE HOLDS THE TRAITOR",
  settlement rows (grudge eaten, royalties paid), Executor's last word.

## Open items

- Gamepad rumble as a redundant cast-confirm channel (doc method #5) is
  not wired — core has no rumble plumbing yet; the cast works without it.
- The Executor is text-only (per director notes, voice/TTS is a later
  experiment); all narration is in his register, no exclamation marks.
- Estate wiring (MODULES registry + Theater venue hosting) is the
  director's post-merge step by design.
- 2–3 player sittings work mechanically (catch threshold scales) but the
  format sings at 4 — the estate should prefer full tables for this one.
