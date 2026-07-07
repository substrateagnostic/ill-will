# THE FINAL STRETCH kit (Q1) + THE DECIDING MOMENT standard (Q2) — verification

The last two items of the doc-09 AAA queue. One shared helper —
**`core/final_stretch.gd`** (`class_name FinalStretch`) — gives every timed game
the same closing language: `game_light` under play, crossfade to `game_tense`
at each game's own threshold, a warm-red screen-edge lighting nudge, a last-10s
rising tick ladder, and a timer pulse. And the deep slow-mo the anthology used
to spend on *every* death is now **reserved** for the round/match-DECIDING
kill: 0.25x for 0.8-0.9s + a fov punch (-5/-6) + a name banner; ordinary deaths
demote to 0.5x/0.2s (doc 08's anti-goal, finally enforced).

Presentation only. No rng streams, no sim writes, no new prints. The kit is
never constructed on a headless receipt path (each game gates `attach()`
behind its existing fx discipline), so every determinism receipt below is
proven byte-identical against a `git stash` baseline of the same HEAD.

---

## The kit (`core/final_stretch.gd`)

| Piece | Spec |
|---|---|
| `play_started()` | `Music.play_slot("game_light")` when PLAY begins |
| `escalate()` | once per round: `game_tense` crossfade + the lighting nudge (edge tint 0.16, slow 0.5 Hz breathe; reduced-motion drops the breathe, keeps the tint) |
| `round_reset()` | back to `game_light`, nudge fades, tick ladder re-arms |
| `tick(seconds_left)` | last 10 s: one exact-pitch tick/second, 1.0 → 1.55 (greed's CLOSING BELL cadence, generalized) + a font-size timer pulse (reduced-motion drops the pulse, keeps the tick) |
| `match_ended()` | nudge fades under the winner tableau; the estate owns the next crossfade |
| `FinalStretch.fov_punch(cam, base, depth, dur)` | the Q2 camera language — real-time (`set_ignore_time_scale`) so it resolves WITH the real-time deep-freeze window; no-op under reduced motion |

The vignette lives on CanvasLayer 0 (under every game's HUD). Tick voices are
a 2-player exact-pitch pool (the Sfx pool's random wobble would break the
ladder — greed's `_bell_tick` precedent).

## Per-game wiring (Q1)

| Game | game_light | game_tense threshold | Ticks/pulse | Bespoke beat kept (no double-trigger) | Mirror (client-side, existing facts) |
|---|---|---|---|---|---|
| tilt | each `_start_round` | SUDDEN DEATH (T-15 of 60s) | last 10s (+OT window) | "SUDDEN DEATH / THE PIN RISES", "THE ESTATE SPLITS NOTHING" | `sd` flip → escalate; round fact → reset; `mw` → end |
| mower | `_start_round` | OVERTIME (T-20) — the sting `mower/VERIFY.md` always claimed | last 10s | "OVERTIME! DOUBLE-WIDE CUTS" | `ot` flip → escalate; phase → start/end |
| greed | each `_start_round` | CLOSING BELL "LAST BANKS!" (T-15) | **pulse only — the bell owns the ticks** (doc 09 reconciliation) | whole CLOSING BELL (warn/bell/approach/ticks) | `bell` fact → escalate / round-reset; mirrored `tmr` → pulse |
| throne | `_start_match` | SUCCESSION CRISIS (T-30); overtime keeps the tense bed | last 10s of regulation | crisis banner + "THE COURT WILL NOT ADJOURN" | `hot` flip → escalate; `gt` → ticks; DONE → end |
| orbital | `begin` | **FINAL ORBIT** T-30 (new §4.3 beat): banner + Executor line "THE ESTATE CALLS TIME. OLD ORBITS STILL KILL." + starfield tinted 20% toward red (kit vignette OFF — the threat ladder owns the red edges) | last 10s | threat ladder untouched | — (not mirrored) |
| swap_meet | GO!!! | FINAL LAP! call | distance ladder once the leader enters the last 10% (no lap timer → no pulse) | FINAL LAP banner, photo finish | — (not mirrored) |
| echo_chamber | rounds 1-4 reset | **round 5 plays tense start-to-finish** + credit line "THE ESTATE COLLECTS ITS ECHOES" | last 10s of every round (gap-A fix) | floor collapse, irony pack | — (not mirrored) |
| dead_weight | each `_start_round` | THE HOUSE AWAKENS (T-30 of 75s) | last 10s | awaken banner + candlelight dim | `aw` flip → escalate; `ri` → reset; `tmr` → ticks |
| last_will | races 1-2 reset | **the FINAL RACE plays tense start-to-finish** + `_flash_exec("The final race. The estate settles all accounts tonight.")` | ladder into the 135s hard cap | crypt/probate Executor beats | — (not mirrored) |

No snapshot grew: every mirror trigger reads facts already on the wire
(`sd`/`ot`/`bell`/`hot`+`gt`/`aw`+`ri`+`tmr`, phase, death counters).

## Per-game wiring (Q2 — THE DECIDING MOMENT)

| Game | Deciding trigger | Promote | Demote (was) |
|---|---|---|---|
| tilt | fall leaves ≤1 standing | 0.25x/0.8s + fov 50→44 + "X HOLDS THE PLATTER" (the existing name banner lands the same beat); mirror: fov punch off the standing count in the same snapshot | 0.5x/0.2s (was 0.35x/0.32s on EVERY fall) |
| dead_weight | fall leaves ≤1 living (§8.2) | 0.25x/0.8s + fov 52→46 + round banner stamped **LAST ONE STANDING**; mirror: same, from alive flags + death counters | 0.5x/0.2s (was 0.32x/0.4s on every fall) |
| last_will | death leaves ≤1 racer with lives (§10.2) | 0.25x/0.9s (the will theater's own −6 fov beat follows) | 0.5x/0.2s (was 0.3x/0.38s on every death) |
| echo_chamber | KO in the final round's last 10s — no time to answer | 0.25x/0.85s + fov 52→46 + "THE DYING SECONDS CLAIM X" (self-echo keeps its own banner, gains the depth) | ordinary KOs already demote-compliant (45ms hitpause); §2.1 self-echo beat kept at 0.3x/0.5s |
| throne | every dethrone IS the beat (§9.3: keep 0.2x/0.6s, add the camera) | fov 49→44→49 synced to the 0.6s crown tumble, host + mirror (`kn` delta) | unchanged per doc 09's own call |

Reduced-motion (`PartySetup.pref("screen_shake")`): deciding deaths fall back
to the demoted 0.5x/0.2s and every fov punch no-ops.

---

## Receipts — determinism (byte-diff vs `git stash` baseline, same HEAD)

Method: stash all changes → re-import → run → unstash → re-import → run the
identical commands → `cmp`. Full raw logs byte-identical for six of nine; the
other three differ ONLY in wall-clock perf numbers / engine exit-noise lines
(see below), never in a sim line.

| Receipt | Command (headless) | Verdict |
|---|---|---|
| tilt idle | `--tilttest=idle` | **byte-identical (raw)** |
| tilt edge | `--tilttest=edge` | **byte-identical (raw)** |
| tilt gull | `--tilttest=gull` | **byte-identical (raw)** |
| throne | `--thronebalancefast --thronescale=8 --seed=1` | **byte-identical (raw)** |
| greed | `--greedtest=intercept --seed=1` (`rate=0.80 PASS`) | **byte-identical (raw)** |
| masked_ball | `--mbtally --seed=1` (untouched game, control) | **byte-identical (raw)** |
| mower | `--covtest --seed=1` (`sum=100.0000% PASS`, same cov%, same rams) | **sim lines byte-identical**; only `paint_worst/commit_worst` ms differ — proven wall-clock noise (two runs of the SAME build differ the same way) |
| dead_weight | `--dwbalance=20 --seed=1` (`LIVING WIN 65.0%`, telemetry identical) | **sim lines byte-identical**; after-log appends engine exit-noise only |
| last_will | `--willtally --seed=1` (`wills=9 wpr=3.00`, totals identical) | **sim lines byte-identical**; after-log appends engine exit-noise only |

The appended exit noise is Godot's `N resources still in use at exit` /
ObjectDB report: referencing `FinalStretch` from the game scripts adds the kit
script to the resource count at forced `quit()`. It prints after the receipt,
never inside it. Filter used for the three:
`grep -v "paint_worst|commit_worst|MOWER_PERF|resources still in use|ObjectDB|at: cleanup|at: clear"` → `cmp` = identical.

## Receipts — liveness (full 4-bot match to `finished()` in every touched game)

All headless, **0 SCRIPT ERRORs** in every log:

| Game | Run | Proof of finish |
|---|---|---|
| tilt | `--tiltbots --rounds=2 --roundtime=25 --seed=3` | `match_end {...placements...}` + KILL_EVENTS |
| mower | `--mowbots --seed=3` (self-quits) | `MOWER_COVERAGE_ASSERT ... PASS` + results |
| greed | `--greedbots --rounds=2 --roundtime=40 --seed=3` | `match_end {...}` (both rounds rang the bell → escalate exercised) |
| throne | `--thronebots --matchtime=60 --seed=2` | dethrones + `THRONE_OT_END t=90.0 cap` + report |
| orbital | `--orbbots --autoquit --matchsec=60 --fast=6 --seed=3` | `ORBITAL_RESULTS` + `ORBITAL_ASSERT ... PASS` (FINAL ORBIT fired at T-30) |
| swap_meet | `--swapbots --autoquit --fast=6 --laps=2 --seed=11` | all four `FINISH t=... place=N` |
| echo | `--echobots --echofast=15 --seed=2` | `ECHO_MATCH_OVER champ=BLUE placements=[...]` |
| dead_weight | `--dwbots --seed=2` | `DW_MATCH_OVER champ=GOLD pts=10` |
| last_will | `--willbots --willrounds=2 --seed=2` | `LW_MATCH_OVER champ=GOLD pts=6` + `LW_VALIDATE problems=0` (race 2/2 = the final race: escalate + Executor line exercised live) |

Estate boot smoke: `--estate --quitafter=400` → exit 0, **0 SCRIPT ERRORs**.
Import pass (`--headless --editor --import --quit`): no parse errors (only the
pre-existing meshy-cosmetics jpg import warnings).

## Screenshots (windowed, read by eye — `docs/verify/finalstretch-shots/`, .gdignore'd)

| File | What it shows |
|---|---|
| `greed_lastbanks_stretch.png` | T-15: "LAST BANKS!", pot pulse — pre-nudge frame for comparison |
| `greed_ticks_stretch.png` | T-10: hot red "9", **warm-red edge nudge clearly up** vs the frame above |
| `tilt_suddendeath_stretch.png` | "SUDDEN DEATH / THE PIN RISES", red-hot platter, timer 4 mid-ladder |
| `tilt_deciding_freeze.png` | the round-ending fall mid-0.25x freeze: fov punched in, victim tumbling at the rim, "GOLD HOLDS THE PLATTER +4" |
| `orbital_final_orbit_stretch.png` | T-30 "FINAL ORBIT" + "THE ESTATE CALLS TIME. OLD ORBITS STILL KILL." + starfield leaning warm |
| `dw_house_awakens_stretch.png` | "THE HOUSE AWAKENS" + candlelight dim (escalate rides the same beat) |
| `dw_deciding_freeze.png` | mid-freeze, fov punched: "LAST ONE STANDING / BLUE BOOTS RED INTO THE VOID / BLUE SURVIVES ROUND 1" (staged via the existing `--dwevict` evidence pin, 2 players) |
| `echo_round5_stretch.png` | round 5 tense: floor collapse under the escalated bed, edge nudge visible |
| `echo_deciding_freeze.png` | "THE DYING SECONDS CLAIM RED" at 3.8s left, arena visibly punched in |

Regenerate (windowed):
```
godot --path . minigames/greed/greed.tscn -- --greedbellcap --outdir=verify_out/finalstretch
godot --path . minigames/tilt/tilt.tscn -- --tiltbots --rounds=1 --roundtime=16 --seed=5 --shots=850,1722 --outdir=verify_out/finalstretch
godot --path . minigames/orbital/orbital.tscn -- --orbbots --matchsec=42 --seed=3 --shots=860 --outdir=verify_out/finalstretch
godot --path . minigames/dead_weight/dead_weight.tscn -- --dwbots --players=2 --dwevict=0 --seed=2 --shots=115 --outdir=verify_out/finalstretch
godot --path . minigames/echo_chamber/echo_chamber.tscn -- --echobots --echofast=12 --seed=2 --shots=3900,3990,...,4980 --outdir=verify_out/finalstretch
```
(FX runs consume real-time freezes, so exact frame indices drift a little
between machines — the tilt log's `frame=` stamps recalibrate them in one pass.)

## Notes / known limits

- The kit's music calls are inaudible in stills; the receipts for the audio
  path are the no-op-safe `Music.play_slot` contract (already exercised by the
  estate) plus clean logs on every windowed run with the tracks present.
- Greed keeps its own tick ladder; the kit's is disabled there by option —
  one audio ladder per room (doc 09's reconciliation rule).
- `user://` note: standalone harness runs rewrite `party_setup.json` (device
  auto-assign) as they always have; a backup of the full user dir taken this
  session was restored after the last run.
