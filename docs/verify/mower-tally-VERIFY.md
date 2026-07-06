# MOWER TALLY CEREMONY — verification record

Implements queue item **#3 / Q3** of `docs/design/09-aaa-gap-analysis.md`
(§5.1, "MOWER — vs Splatoon turf feel"): the missing endgame ceremony.
Godot 4.6.2, Windows. Scope: `minigames/mower/` ONLY. **Presentation only** —
coverage math, scoring, results payload and bot behavior are untouched, proven
byte-identical below.

## What the prescription asked for (§5.1, table row 1)

> THE TALLY: time-up → freeze mowers 0.8s + "TALLYING…" → each player's turf
> saturates in sequence (emission ramp on owner cells, 0.6s each, worst→best)
> while their % counts up 0→final in 72pt center digits with `card` roll ticks
> → winner flag + `match_win` + confetti. ≈4.5s total, replacing the current
> instant banner + 3.0s hold.

## What was built

The old `_end_round` printed `"%s TAKES THE LAWN! %d%%"` in the same frame the
round ended and held 3.0s (`mower.gd:485-489`). That instant reveal is gone.
Now, at time-up, `_end_round` builds `_results` (unchanged) and hands off to a
coroutine `_run_tally()`:

1. **Freeze + calculate beat (0.8s).** Play is already frozen (the sim stops the
   instant `phase` leaves `PLAY`). The live meter + scoreboard **hide** so the
   standings are genuinely withheld (the Splatoon "calculating" move — the HUD
   updaters are now gated to `PLAY`/`INTRO` so they freeze at time-up). A
   "TALLYING…" banner shows and the **camera pulls** from the 3/4 play angle to
   a fuller, more overhead framing of the whole 16×12 lawn (a 0.7s tween of
   `Camera3D.position` → `(0,20,6.5)` + `fov` → 54).
2. **Sequential turf reveal (0.58s each, worst→best).** For each player in
   ascending coverage order, `mower_lawn.gd:set_tally(owner_code, gain)` drives
   two new shader uniforms (`tally_owner`, `tally_gain`, plus `tally_active`):
   that player's cells **saturate to their pure hue and glow** (a luma-preserving
   push toward the full-value player color + hue-matched `EMISSION`) while every
   other player's turf **recedes to 38% brightness**, so each reveal pops in
   turn. Simultaneously the 72pt centre digits **count up 0→final** with a
   `Sfx.play("card")` roll tick on each integer change (throttled to ~30 Hz so it
   reads as a roll, never a machine-gun), and the badge+name (shape+color, never
   color-alone) identify who is being counted.
3. **Winner stamp (flourish, ~1.0s hold).** The best-coverage player is revealed
   last (their turf stays lit). The banner slams in — `"%s TAKES THE LAWN!"`
   with a 1.7→1.0 `TRANS_BACK` stamp pop — `Sfx.play("match_win")` fires, the
   winning mower `cheer()`s, `_confetti()` bursts in their color, and a camera
   shake punctuates the impact.

`report_finished(_results)` now fires when the ceremony completes
(`_tally_done`, with a `phase_t >= 6.0` fallback so the round can never hang),
replacing the old flat 3.0s gate. Total ≈ 0.8 + 4×0.58 + 1.0 ≈ **4.4s**, matching
the ≈4.5s prescription. `--covtest` (headless math assert) skips the ceremony and
quits immediately as before.

### Files touched (mower/ only)

| File | Change |
|---|---|
| `minigames/mower/lawn.gdshader` | +3 uniforms (`tally_owner`, `tally_gain`, `tally_active`); spotlight branch saturates the counted owner to hue + emission, recedes the rest |
| `minigames/mower/mower_lawn.gd` | `set_tally(owner_code, gain)` — sets the 3 uniforms (owner 0 = ceremony off) |
| `minigames/mower/mower.gd` | `_end_round` hands off to `_run_tally()`; new `_build_tally_ui / _run_tally / _tally_set_player / _on_tally_value / _tally_camera_pull / _stamp_pop`; RESULTS gate waits on `_tally_done`; HUD meter/scoreboard frozen to `PLAY`/`INTRO` |

## Determinism — results BYTE-IDENTICAL vs master

Presentation-only claim proven by diffing the `report_finished` results payload
(placements, points, currency_events, kill_events, highlights, monuments) between
master and this branch at identical seeds:

```
godot --headless --path <repo> res://minigames/mower/mower.tscn -- --covtest --seed=N
```

| seed | master len | branch len | case-sensitive equal |
|---|---|---|---|
| 1 | 1802 | 1802 | **YES** |
| 5 | 2176 | 2176 | **YES** |
| 7 | 2302 | 2302 | **YES** |

Coverage assert still `MOWER_COVERAGE_ASSERT sum=100.0000% -> PASS` at every seed;
the tally reveal never touches the grid, `owner_cells`, or `coverage_pct`.

## Screenshots (windowed, `--fixed-fps 60`, read by eye)

```
godot --path <repo> --fixed-fps 60 res://minigames/mower/mower.tscn -- \
  --mowbots --seed=7 --roundtime=14 --quitafter=1300
```

`_run_tally` calls the harness `VerifyCapture.snap()` at the two key beats
(active because `--quitafter` sets it). PNGs (copied into `docs/verify/shots/`):

| Shot | File | Shows |
|---|---|---|
| Tally mid-count | `shots/mower_tally_midcount.png` | Camera pulled overhead; RED being counted — its turf saturated to salmon-red across the upper lawn while every other player's turf has receded to dark green; badge ▲/● + "RED" + big **17%** digits in the lower third; banner cleared |
| Winner stamp | `shots/mower_tally_winner_stamp.png` | "BLUE TAKES THE LAWN!" banner stamped up top; BLUE's 37% turf glowing sky-blue across the lawn, others receded; BLUE badge + "BLUE" + **37%** below; confetti/`match_win` fired |

Both inspected: composition is clean (count-up parked in the lower third never
collides with the upper-center banner), the per-player spotlight reads as the
correct player hue (fixed an initial version where the bright sun washed the
emission to white — now luma-preserved so it saturates to hue instead), and the
worst→best drama order lands the winner last.

## Notes / iterations

- **White-blowout fix.** First spotlight added full-color emission + albedo boost;
  under the scene's bright white directional light + filmic tonemap this washed the
  counted turf to near-white (a de-saturation, the opposite of the intent). Replaced
  with a luma-preserving hue push (`hue * luma`) + gentle hue-matched emission so the
  turf saturates to the player color instead of blowing out.
- **Banner collision fix.** The count-up first shared the vertical center with the
  banner and overlapped it; moved the count-up block into the lower third and hid the
  "TALLYING…" banner once the reveal sequence begins.
- No `user://` writes: the mower standalone path (`PlayerInput.auto_assign` →
  `assign`) is in-memory only; nothing to back up/restore.
