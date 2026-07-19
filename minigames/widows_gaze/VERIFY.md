# THE WIDOW'S GAZE — verification

Red light / green light at a wake, with sabotage. Single 75s round, 4 players
(any human/bot mix), contract module registered in `estate.gd` as `widowsgaze`.

## The skill window (tuning receipts)

- Movement is acceleration-based: `MOVE_SPEED 5.0`, `FRICTION 20.0` — a full-speed
  stop bleeds to the epsilon in ~0.215s.
- `STOP_EPSILON 0.7` (14% of run speed): the catch rule is
  `horizontal_speed() > 0.7 while the gaze is ON`.
- The sting is `STING_TIME 0.5`; eyes lamp on when it ends. Release the stick by
  ~0.28s into the sting and you live. React later and the coast-down betrays you.
  A controlled stop reads as skill; an over-run reads as greed.
- Fake-outs (post T-25 escalation): same 3-note ladder, but the third note FALLS
  (pitch 0.72 vs 1.45) — learnable on repeat listens. The sting after a fake-out
  is always real, `0.35-0.8s` later.
- Shoved pawns stumble `0.4s` (knock 8.5, decay 22/s) — a shove landing in the
  sting's back half or under the gaze is a murder (attributed via `shove_by`).

## v1.1 — TUNING PASS: widened catch grace (playtest)

Friend playtest note verbatim: *"Not enough leeway between her turning around
and stopping."* The catch enforcement (`widows_gaze.gd` step 4, "THE GAZE
TAKES") and the Widow's `whip_turn(STING_TIME)` tween both complete at the
exact same instant — `gaze_t >= STING_TIME` fires `_begin_watching()`, which
calls `widow.set_gaze(true)` AND flips `gaze = Gaze.WATCHING` in the same
frame the turn tween lands on `GAZE_YAW`. The catch check runs immediately
after in the same tick, so there was literally zero buffer between "her turn
visually finishes" and "the freeze check goes live" — a player reacting to
the completed turn (rather than purely anticipating the sting's audio ladder)
had no window at all.

**Fix:** a new `GAZE_GRACE := 0.08` constant (`widows_gaze.gd`). The eyes
still lamp on instantly at `gaze_t >= STING_TIME` (the visual telegraph is
unchanged — no delay added to the tell itself), but the catch-check loop now
reads `if gaze == Gaze.WATCHING and gaze_t >= GAZE_GRACE:` — holding fire for
0.08s (≈5 frames @60fps, about a third of the ~0.215s full-stop decel curve)
right as watching begins. `STING_TIME` (the 0.5s anticipation window itself)
is untouched — this is a small forgiveness pad at the transition instant, not
a lengthening of the tell.

**Why 0.08s, not more:** tested 0.06/0.08/0.12 against the 3-seed bot soak.
All three measurably loosen catch rates (seeded bot decisions sit close to
the STOP_EPSILON timing boundary, so a few extra frames of forgiveness flips
several close calls per match — and because a caught-vs-escaped branch
reorders every subsequent RNG draw in that seed's stream, small input changes
cascade into materially different match lengths/outcomes, not just a
proportionally smaller version of the same match). 0.08s was chosen as a
constant that reads as "a handful of frames," not a redesign — modest by
construction, whatever its downstream bot-stat footprint turns out to be.

**Receipt — deliberate-change doctrine.** `godot --headless --path . res://minigames/widows_gaze/widows_gaze.tscn -- --wgbots --wgtally --seed=N --wgfast=4`:

| seed | OLD (pre-tune) | NEW (v1.1, GAZE_GRACE=0.08) |
|---|---|---|
| 7 | `banks=10 catches=7 murders=4 shoves=6 hits=6 stings=9 fakeouts=0` · `round_end kind=clean t=59.42` · `placements=[1,0,3,2]` | `banks=10 catches=3 murders=2 shoves=4 hits=4 stings=8 fakeouts=0` · `round_end kind=clean t=51.98` · `placements=[1,0,2,3]` |
| 11 | `banks=10 catches=10 murders=6 shoves=7 hits=7 stings=11 fakeouts=1` · `round_end kind=clean t=64.56` · `placements=[3,0,1,2]` (this was the doc's existing "Tally excerpts" receipt below) | `banks=10 catches=2 murders=2 shoves=3 hits=3 stings=8 fakeouts=0` · `round_end kind=clean t=54.17` · `placements=[3,0,2,1]` |
| 42 | (not previously receipted verbatim in this doc; the Pacing section below cites its clean-out timing/TIE CEREMONY qualitatively) | `banks=10 catches=10 murders=6 shoves=8 hits=8 stings=12 fakeouts=1` · `round_end kind=clean t=69.41` · `placements=[2,3,1,0]` |

All three seeds still complete cleanly (0 SCRIPT ERROR, valid
`placements`/`points`/`currency_events`/`highlights`/`kill_events`, a
`widowmaker` monument fires in the windowed screenshot run below). The
**Pacing** section immediately below is the OLD (pre-tune) baseline
narrative — its specific catch counts and clean-out timing window are now
historical; the mechanism it describes (bots outpacing the escalation act
without deliberate pacing) is unchanged, only the catch odds shifted per the
table above.

Windowed event screenshots re-verified with the new grace window (seed=5):
`verify_out/widows_gaze_m3/` — `widows_gaze_catch.png` shows a shove-murder
landing cleanly under "SHE WATCHES" (`gaze_t=0.13` at contact, i.e. after the
0.08s grace, per the `WG_EVT` log line `shove p2 -> p1 gaze=WATCHING
gaze_t=0.13`); all eight capture beats (shove/red/green/grab/bank/catch/
murder/results) still land. Whole-project smoke (`--quitafter=300`) clean, 0
SCRIPT ERROR.

## Pacing (3-seed bot soak receipts)

Bots stride at 0.87x and take a 2.6-5.6s mourning rest after scoring (greedy
pace-setter: 1.0-2.2s) — without this, four optimal bots strip all 10 relics by
t=47 and the T-25 escalation act never plays. With it (seeds 7/11/42), PRE
v1.1 GAZE_GRACE tune:
- clean-out at t=57.7-64.5 of the 75s clock (escalation fires at ~50s);
- 7-10 catches, 3-6 shove-murders, 7-11 stings per round;
- seed 11 shows the full fake-out chain resolving into its real sting;
- seed 42 ends in a TIE CEREMONY (banks=11: the sudden-death relic).
Humans move at full 5.0 m/s — a hustling human out-paces every bot.

**Post v1.1 (GAZE_GRACE=0.08, see the tuning section above):** the same three
seeds now clean-out at t=51.98-69.41 (escalation still ~t=50-50.1, unchanged
— only catch odds shifted) with 2-10 catches, 2-6 shove-murders, 8-12 stings.
Seed 42 still ends via `kind=clean` in this re-run (not the TIE CEREMONY
path this time) — expected seed-stream sensitivity, not a regression; see
the deliberate-change table above for exact per-seed old/new numbers.

## Commands run

```powershell
# 1. headless import (clean — pre-existing cosmetics jpg errors only)
godot --headless --editor --import --quit --path .

# 2. bot-only full round, headless, tally receipts (sim-identical 4x clock)
godot --headless --path . res://minigames/widows_gaze/widows_gaze.tscn -- `
  --wgbots --wgtally --seed=7 --wgfast=4

# 3. windowed event-based screenshots
godot --path . res://minigames/widows_gaze/widows_gaze.tscn -- `
  --wgbots --wgcap --outdir=verify_out/widows_gaze --seed=5

# 4. whole-project game-load smoke (estate boots, module registered)
godot --headless --path . -- --quitafter=300
```

## Tally excerpts (seed 11, PRE v1.1 GAZE_GRACE tune, 0 SCRIPT ERRORs)

```
WG_EVT t=51.69 | escalate t=50.0
WG_EVT t=61.16 | fakeout resolved -> real sting in 0.36
WG_EVT t=64.43 | round_end kind=clean
WG_TALLY seed=11 banks=10 catches=10 murders=6 shoves=7 hits=7 stings=11
  fakeouts=1 points={"0":6,"1":6,"2":5,"3":8} placements=[3, 0, 1, 2]
KILL_EVENTS n=10 [{"cause":"gazed","killer":1,"victim":0},
  {"cause":"gazed","killer":-1,"victim":0}, ...]
```

Post v1.1 (GAZE_GRACE=0.08), the same seed:
```
WG_EVT t=51.70 | escalate t=50.0
WG_EVT t=54.17 | round_end kind=clean
WG_TALLY seed=11 banks=10 catches=2 murders=2 shoves=3 hits=3 stings=8
  fakeouts=0 points={"0":5,"1":4,"2":5,"3":7} placements=[3, 0, 2, 1]
```
No fake-out fired in this particular re-run (fewer stings overall before the
round cleaned out); fake-outs are still live (seed=42's post-tune run above
shows `fakeouts=1`), this is per-seed variance from the same cascading-RNG
sensitivity noted in the tuning section.

Both catch flavors occur: `killer=-1` (the Widow took an over-runner) and
`killer>=0` (a shove-murder, royalty paid); `KILL_EVENTS` carries
`cause:"gazed"` per the module contract. Every `WG_EVT` line (grabs / stings /
catches / murders / banks / fakeouts) is timestamped for replay.

## Screenshots (verify_out/widows_gaze/)

- `widows_gaze_green.png` — GREEN mid-heist: widow weeping over the coffin,
  mourners downfield among the relics, warm parlor light.
- `widows_gaze_red.png` — the whip-turn: lights dropped, her eyes lamped on,
  "SHE WATCHES" up, the room frozen.
- `widows_gaze_catch.png` — spectral lightning arcing from her eyes to a caught
  mourner.
- `widows_gaze_murder.png` — a shove-murder credited on the banner
  ("X FED Y TO THE WIDOW!").
- `widows_gaze_shove.png` — HIT KIT contact: coil/pop + spark cone.
- `widows_gaze_results.png` — the champion banner + confetti.

## CLI args

`--wgbots` (all seats bot), `--seed=N`, `--players=2..4`, `--roundtime=S`,
`--wgtally` (print tally + quit at match end), `--wgfast=K` (Engine.time_scale
soak; fixed-step physics keeps the sim identical), `--wgcap` (+ `--outdir=`)
windowed event screenshots, `--shots=` via the house VerifyCapture.

## Design deviations (from the build brief)

- No hop: `core/player_input.gd` has no "jump" action as of this build; the
  brief says skip it in that case (another lane owns input changes).
- Shove-murders pay the killer +1 point (in addition to the royalty event) —
  greed's tackle-royalty precedent; "most banked value" still dominates.
- Relic layout is a fixed constant, not seeded — the net mirror rebuilds the
  identical wake with zero extra snapshot bytes, and fairness reads at a glance.
- Widow is primitives + cloth-dark materials behind a one-line Meshy swap seam
  (`WGWidow.WIDOW_GLB`).
