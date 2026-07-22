# TIMING PASS (#84) — CONTEXT MODES + PER-GAME PRESETS

Producer ruling: minigames get a launch-context (**board** vs **standalone**).
BOARD targets ~75-90s per game so the procession never stalls (hard ceiling
~4-5min for the theater trio — séance/understudy/masked_ball — since they only
ever run in the overnight interlude, never the per-cycle draw). STANDALONE
keeps today's full length. **Presets set dials, never hardcode.**

Precondition for every command below: the import gate —
`godot --headless --editor --import --quit --path .` (exit 0, run twice on a
cold checkout).

## The mechanism

`estate/procession/procession.gd` gained one small preset table (`BOARD_PRESETS`
+ `BOARD_DEFAULT`, right after the `MINIGAMES` const) and a `_board_config(id)`
helper that merges a game's board overrides over the long-standing blanket
board default. Both launch sites now build the config through it instead of a
bare hardcoded literal:

- `_run_minigame()` (contract launch — real modules, `begin(config)`):
  `launch_cfg.merge(_board_config(id), true)` before `module.begin(launch_cfg)`.
  Also stamps `"context": "board"` (informational — no game currently branches
  on the string; every actual behavior change is a plain dial value).
- `_run_legacy_minigame()` (Par's "gamestate" launcher): `GameState.rounds_total`
  now reads `_board_config(id).get("rounds", 2)` instead of a bare `2`.

Games not listed in `BOARD_PRESETS` fall back to `BOARD_DEFAULT = {"rounds": 2}`
— the same blanket value every contract game got before this pass. **Their
board experience is completely unchanged by this pass.**

Verified directly (no scene tree needed — `_board_config` is a pure dict merge)
via a throwaway `--script` check instantiating `procession.gd` off-tree and
calling `_board_config()` for every game id; every entry below matches:

```
BOARD_CONFIG deadweight -> {"round_time":25.0,"rounds":3}
BOARD_CONFIG greed -> {"round_time":35.0,"rounds":2}
BOARD_CONFIG lastwill -> {"rounds":1}
BOARD_CONFIG maskedball -> {"round_time":55.0,"rounds":2}
BOARD_CONFIG orbital -> {"match_len":80.0,"rounds":2}
BOARD_CONFIG seance -> {"rounds":2,"talk_time":18.0}
BOARD_CONFIG par -> {"rounds":2}
BOARD_CONFIG mower -> {"round_time":45.0,"rounds":2}
BOARD_CONFIG echo/tilt/throne/widowsgaze/pallbearers/swap/understudy -> {"rounds":2}
```

And end-to-end for real: `godot --headless --path . -- --procession --seed=7
--turncap=4 --nights=1 --autoplay=bots --realmini` (forces live modules, not
the deterministic MINISIM) ran a full 4-round night, drawing ORBITAL, GREED,
THRONE, and PALLBEARERS in turn. GREED's own begin() log confirms the preset
actually arrived through the whole pipeline:

```
GREED_EVT t=0.00 frame=1722 | begin players=4 seed=2511678617 rounds=2 bots=[true, true, true, true]
GREED_EVT t=39.97 frame=6818 | round_start 2 pot=3   (round 1 ended near round_time=35 via timeout)
```

The night resolved cleanly with no `PROCESSION MODULE ERROR` (which would fire
on an invalid placements array from any of the four real modules, including
the two whose launch config this pass changed):

```
PROCESSION_NIGHT {"night":1,"rounds":4,"wreaths":[6,10,16,13], ...}
PROCESSION_MATCH {"heir":2,"heir_name":"GOLD","nights":1,"seed":7,"turn_cap":4, ...}
PROCESSION_HEIR GOLD (seed 7, 1 nights)
```

(PALLBEARERS printed four `Lambda capture at index 0 was freed` engine errors
during its intro on this run — pre-existing in that game's own code, merged by
another lane last night; PB still reported a valid `match_end` with placements
and this pass never touches pallbearers.gd, so it's noted here but out of
scope.)

## PRESET TABLE

| Game | Standalone length (unchanged) | Board preset (dials changed) | Board length (measured/estimated) |
|---|---|---|---|
| **dead_weight** | Best-of-3, `ROUND_TIME=75s` (~225-300s worst case; VERIFY.md's own doc already said best-of-3 — see rider (a) below) | `rounds=3` (restored — see rider a), `round_time=25.0` | ~70-90s (measured seed 1: rounds start t=12.5/23.6/42.4, match over well inside 90s) |
| **greed** | `rounds=3` (max, ceiling == default), `ROUND_TIME=90s` (~270-300s worst case) | `rounds=2`, `round_time=35.0` | ~80-90s (measured: round 1 timeout at t=36.75, round 2 starts t=39.97 in the real `--realmini` soak) |
| **last_will** | `races_total=3`, ~135s/race (course-driven, no timer dial) → ~400s+ | `rounds=1` (races_total=1) | ~135-150s — **judged NOT further shortenable**, see below |
| **masked_ball** (theater) | `ROUND_COUNT=4`, `ROUND_TIME=75s` → ~300s (5min, at the ceiling) | `round_time=55.0` (ROUND_COUNT stays 4 — errand-guest/Coroner rotation must complete) | ~220-250s (~4min; measured `--mbtally --mbroundtime=55`: all 4 rounds show `duration=55.0`, rotation completes 1/4→4/4) |
| **orbital** | `MATCH_LEN=180s` (~3min) | `match_len=80.0` | ~80-90s (config path verified via `_board_config`; the pre-existing `--matchsec=` CLI override, which now shares the same var, proven functional at 80s) |
| **seance** (theater) | `TALK_TIME=30s` core ≈135s + overhead ≈167s measured (audit) | `talk_time=18.0` (light trim only — SEANCE_TIME/VOTE_TIME untouched) | ~155s — already comfortably inside the 4-5min theater ceiling; trim is a nicety, not a requirement |
| **mower** | `ROUND_TIME` raised 45s→60s (audit: "overcorrected LOW") | `round_time=45.0` (pinned back to the pre-existing board length so the standalone bump doesn't leak into board) | 45s, unchanged from before this pass |
| **par** (legacy `GameState.rounds_total`) | `rounds_total=4` (3 normal + chaos), turn-based, no per-hole timer dial beyond `BUILD_TIME_LIMIT=25s` | `rounds=2` (now routed through `_board_config`, same value as before) | unchanged — see PAR verdict below |
| echo, tilt, throne, understudy, widows_gaze, pallbearers | unaudited this pass | `rounds=2` (unchanged blanket default) | unchanged from before this pass |
| swap_meet | out of scope (being rebuilt by another lane tonight) | untouched | n/a |

## Riders

**(a) Dead Weight doc/code drift — FIXED.** `minigames/dead_weight/VERIFY.md`
already documented "Best-of-3" and the standalone code already defaulted
`rounds_total` to 3 (`dead_weight.gd` begin(): `clampi(int(config.get("rounds",
3)), 1, 9)`) — the drift was entirely in `procession.gd`'s board launcher,
which hardcoded `"rounds": 2` for **every** contract game regardless of the
target's own documented shape. Through the board — the only way most players
ever meet this game — Dead Weight silently ran a 2-round match, never the
documented best-of-3. Fixed by giving it its own `BOARD_PRESETS` entry
(`rounds=3`) instead of inheriting the blanket default, and by making
`ROUND_TIME` itself config-driven (`round_time` var + `config.get("round_time",
ROUND_TIME)`, clamped `[15, 75]`) so best-of-3 still fits the board's pace. Also
added `--dwroundtime=` (mirrors the existing `--dwrounds=`) for manual/VERIFY
testing.

**(b) Dial gaps closed:**
- **greed** — the round ceiling was hard-coupled to the default
  (`clampi(config.get("rounds", ROUNDS), 1, ROUNDS)` — `ROUNDS=3` was both the
  default *and* the max, so no preset could ever ask for more). Decoupled via a
  new `MAX_ROUNDS := 9` ceiling (matches dead_weight's own convention);
  `ROUNDS` stays the standalone default. Also added `config.get("round_time",
  ROUND_TIME)` — previously `round_time` was CLI-only (`--roundtime=`), fully
  unreachable from a launch config.
- **last_will** — `races_total` was floor-only: `if int(config.get("rounds",
  3)) < 3: races_total = ...` meant a preset could shrink the race count below
  3 but never hold it there or raise it — asking for `rounds >= 3` was silently
  ignored. Replaced with a plain `clampi(int(config.get("rounds", 3)), 1, 5)`
  (bounds match the existing `--willrounds=` CLI clamp). Verified races_total=1
  completes cleanly (`--willbots --willtally --willrounds=1`: `LW_BEGIN
  races=1`, `LW_RACE_START 1/1`, `WILL_TALLY races=1` — no hang, no crash on
  the `races_total > 1`-gated code paths).
- **masked_ball** — opted out of dials entirely: `_waltz_len = ROUND_TIME` was
  unconditional, config.rounds wasn't even read for anything but the errand
  rotation. Added `_waltz_len = clampf(float(config.get("round_time",
  ROUND_TIME)), 25.0, ROUND_TIME)`. `_round_total` (the Coroner/errand rotation
  length) is deliberately left alone — it's tied to `players.size()` for
  fairness (every seat gets one turn as the accused), not a pacing knob; the
  ruling's own guidance was "keep 4 rounds so the errand-guest rotation
  completes." Added `--mbroundtime=` for VERIFY testing (mirrors the pattern
  used for the other games). Verified via `--mbtally --mbroundtime=55`: all 4
  rounds report `duration=55.0` instead of `75.0`, rotation still completes.
- **PAR** — see verdict below.

## PAR verdict

Par (`res://scenes/main.tscn`, the legacy minigolf mode) launches through
`_run_legacy_minigame()`, a "gamestate" adapter (doc: P3 landmine 3) that
mutates `GameState` globals and root-parents the scene, rather than calling
`begin(config)` like every other module. That's what "unreachable" meant: its
one dial (`GameState.rounds_total`, holes played) was a bare literal `2` typed
directly into procession.gd, completely outside the config/preset system every
other game now uses — a future board tuning pass would have had no lever to
pull for Par at all.

**Wired the cheap part.** `GameState.rounds_total` now reads
`_board_config("par").get("rounds", 2)` — same value as before (2), but Par now
participates in the same preset table as every other game. Bumping Par's board
hole count up or down in the future is a one-line `BOARD_PRESETS["par"]`
edit, same as any other game.

**Did not wire the rest — documented why.** Par's actual per-hole pacing has
two components neither of which is cleanly dialable without touching core
turn logic (out of hard scope for this pass):
1. `BUILD_TIME_LIMIT := 25.0` (`scripts/main.gd`) — the shot-clock for placing
   traps before a hole's putting phase. It's a plain constant, not read from
   `GameState` or any config at all; making it a dial means either adding a new
   `GameState` field the classic flow doesn't otherwise have, or threading a
   config value through `scripts/main.gd`/`scripts/game_state.gd` — both of
   which are core turn-loop files, and `scripts/main.gd` is also the file the
   Classic-flow excision lane (#75) is actively working in tonight. Touching
   it risks a collision for a dial nobody asked to tune this pass.
2. Actual putt-resolution time is emergent (ball physics + AI/human decision
   speed), same shape as last_will's races — no timer to dial at all, only a
   round *count* (already wired above).

Net effect: Par's board length is unchanged from before this pass (2 holes),
but it now has the same lever every other game has for the next tuning round.

## Games judged NOT to need (further) shortening

- **last_will** — the floor bug is fixed and the board preset drops to 1 race,
  but a single lap is still ~135-150s (course length is the pacing, not a
  timer), well past the nominal 75-90s target. Shortening further means either
  a shorter course or a lap-completion time cap — both are core-mechanic
  changes, out of hard scope ("do NOT touch minigames' core mechanics — only
  timing/round/target dials"). 1 race is the correct board dial; the overrun is
  the game's physical nature, not a bug.
- **seance** — already measures ~167s standalone against a 4-5min theater
  ceiling; even at full standalone length it has ~2x headroom to spare. The
  `talk_time` trim (30s→18s) is a light, safe touch-up, not a fix for a
  problem — séance was never going to blow the procession's pace.
- **masked_ball** — also theater-ceilinged, and its standalone length (~300s)
  was right at the edge rather than over it. The `round_time` dial (75s→55s)
  gives real headroom (~4min) without cutting into the errand-guest rotation
  that makes the Coroner mechanic work.

## Receipts

`powershell -ExecutionPolicy Bypass -File tools/run_receipts.ps1 -Quick`:
2/2 PASS, canonical md5 `ccd25c2c82ad7e744595837ca949a8df` unmoved — the sim
path (`--autoplay=bots` without `--realmini`) never touches `_run_minigame`'s
real-module branch at all (`if _minisim: return _sim_placements()`), so no
board preset value is reachable from the canonical receipts; confirmed by
inspection and by the unchanged checksum.
