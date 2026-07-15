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

## Pacing (3-seed bot soak receipts)

Bots stride at 0.87x and take a 2.6-5.6s mourning rest after scoring (greedy
pace-setter: 1.0-2.2s) — without this, four optimal bots strip all 10 relics by
t=47 and the T-25 escalation act never plays. With it (seeds 7/11/42):
- clean-out at t=57.7-64.5 of the 75s clock (escalation fires at ~50s);
- 7-10 catches, 3-6 shove-murders, 7-11 stings per round;
- seed 11 shows the full fake-out chain resolving into its real sting;
- seed 42 ends in a TIE CEREMONY (banks=11: the sudden-death relic).
Humans move at full 5.0 m/s — a hustling human out-paces every bot.

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

## Tally excerpts (seed 11, shipping code, 0 SCRIPT ERRORs)

```
WG_EVT t=51.69 | escalate t=50.0
WG_EVT t=61.16 | fakeout resolved -> real sting in 0.36
WG_EVT t=64.43 | round_end kind=clean
WG_TALLY seed=11 banks=10 catches=10 murders=6 shoves=7 hits=7 stings=11
  fakeouts=1 points={"0":6,"1":6,"2":5,"3":8} placements=[3, 0, 1, 2]
KILL_EVENTS n=10 [{"cause":"gazed","killer":1,"victim":0},
  {"cause":"gazed","killer":-1,"victim":0}, ...]
```

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
