# deadstate-VERIFY — Dead/ghost twin-stick controls + on-screen instructions

Owner playtest bug: the dead/ghost/alternate states broke the twin-stick
convention (LEFT = MOVE, RIGHT = AIM) and never told the dead player what their
new controls were. This pass enforces the convention in **dead_weight** and
**last_will**, adds live dead-state hint lines to **dead_weight / last_will /
tilt**, and makes the **last_will** shove readable. Bots are byte-identical
(they never touch the human aim/fling paths — proven by each game's own harness).

Scope touched: `minigames/**`, one additive method in `core/player_input.gd`,
and this doc. Nothing in `estate/`, `project.godot`, `scripts/`, `scenes/`.

## The one additive core method

`core/player_input.gd` — `get_aim_stick(p) -> Vector2` (additive; no existing
function changed). Raw right-stick vector `(JOY_AXIS_RIGHT_X, RIGHT_Y)` past a
0.25 deadzone, or `ZERO` for any non-pad device (KBM cursor -4, keyboard halves,
shared -3, bots). The twin-stick partner to `get_move` (left stick). Callers wire
LEFT (`get_move`) = MOVE, RIGHT (`get_aim_dir` cursor for -4 / `get_aim_stick`
for pads) = AIM, with a documented fallback to the move direction.

## 1. dead_weight — poltergeist / possessed furniture

Was: while possessing, a KBM ghost's prop was driven **toward the cursor**, so
WASD did nothing (the sin). Now:

| Seat | MOVE (drift the prop) | AIM the fling | FLING |
|------|----------------------|---------------|-------|
| KB+Mouse (-4) | WASD (`get_move`) | mouse cursor (`get_aim_dir`) | LMB (`just_pressed a`) |
| Pad | left stick | right stick (`get_aim_stick`) | A |
| fallback | — | (none) → fling along drift dir | — |

- `poltergeist.gd::_drive_possession` now **always** `apply_drive(move_input)`
  (LEFT drifts), and on `want_fling` calls the new `DWProp.fling(aim_fling or
  drift)` — a one-shot velocity burst (`FLING_SPEED 9 m/s`, `FLING_CD 0.55s`).
- `dead_weight.gd::_drive_ghost` human branch feeds `move_input=get_move`,
  `aim_fling = get_aim_dir | get_aim_stick`, `want_fling = just_pressed(a)`.
- Bots leave `aim_fling=ZERO`, never set `want_fling` → their whole drive is the
  same `apply_drive(move_input)` as before. **Byte-identical** (see §Determinism).

Fling probe (`--aimprobe=<deg>`, mouse pinned, real fling through the live path):
```
--aimprobe=0  : baseline prop_vel=(4.73,1.03,0.63) (WASD +X drift)
                fling prop_vel=(0.00,-0.21,7.36) dir=0deg  aim=0deg  matches=true
--aimprobe=90 : fling prop_vel=(3.83,-0.21,0.29) dir=86deg aim=90deg matches=true
```
Shots: `verify_out/dead_weight_aim_fling_{facing,acting}.png` — a possessed lamp
drifted +X by WASD, then hurled onto the cyan cursor ray.

Dead-state hint (windowed, `--deadhint` = seat 0 KBM human starts a ghost):
`verify_out/dw_deadhint/shot_0340.png` shows the bar:
> **RED IS DEAD — W/A/S/D drift · MOUSE aim · LEFT CLICK FLING · RIGHT CLICK release**

(live bindings via `PlayerInput.describe_binding`; a pad seat reads
`LEFT STICK drift · RIGHT STICK aim · (A) FLING · (B) release`.)

## 2. last_will — ghost gusts

Was: `g.set_aim(get_move(i))` — the ghost aimed the gust with the LEFT channel
(the sin). The spectral pew never moves, so aim now comes from the RIGHT channel:

- `last_will.gd::_drive_ghost` human branch: `aim = get_aim_dir(seat) (cursor) |
  get_aim_stick (right stick) | get_move (fallback)`, then `set_aim`. A still fires.
- Bots still go through `bots.decide_ghost → set_aim(d.aim)` — untouched.

Dead-state hint (windowed, `--deadhint` = seat 0 human, forced-killed at t=1):
`verify_out/lw_deadhint/shot_0900.png` shows the bar after the will theater:
> **RED IS DEAD — MOUSE aim the gust · LEFT CLICK = GUST (every 10s)**

## 3. Dead-state hint lines (dead_weight / last_will / tilt)

Each game's existing single hint bar flips to a per-state legend the moment a
**human** enters the alt state, with live bindings, then reverts when none remain:

| Game | Alt state | Hint (KBM example) | Shot |
|------|-----------|--------------------|------|
| dead_weight | poltergeist | `RED IS DEAD — W/A/S/D drift · MOUSE aim · LEFT CLICK FLING · RIGHT CLICK release` | `dw_deadhint/shot_0340.png` |
| last_will | ghost pew | `RED IS DEAD — MOUSE aim the gust · LEFT CLICK = GUST (every 10s)` | `lw_deadhint/shot_0900.png` |
| tilt | seagull | `RED IS A SEAGULL — W/A/S/D fly · LEFT CLICK = drop a BOMB` | `tilt_deadhint/shot_0420.png` |

tilt's controls were already fine (move + A = bomb); it only lacked the hint.
The tilt bar owns its own visibility once the round-1 intro window closes.

## 4. last_will — shove readability (presentation only)

The shove had no tell. `LWPawn._do_shove` now calls `on_shove_fired(pos,_face,
color)` the instant it releases (hit OR whiff). `last_will.gd::on_shove_fired`
spawns, in the shover's color: a **windup/impact ring** (WHEN) + a filled ~160°
**directional arc** out to `SHOVE_RANGE` (WHERE), both fading over ~0.28s. No
change to range / power / cooldown / timing — the shove resolves exactly as
before; skipped entirely in the headless tally so determinism is untouched.

Shot: `verify_out/lw_shove_cue.png` (`--shovecue`, snaps the first shove mid-arc)
— two color-tinted arcs + rings under the shoving pawns.

## Determinism / balance — bots byte-identical

- **last_will** `--willtally` (headless full bot match), matches `last_will/VERIFY.md`
  to the number:
  ```
  WILL_TALLY seed=1 rounds=3 wills=9 wills_per_round=3.00
  deaths: void=6 squish=3 | gusts=3  puppet_bonuses=4 carryovers=1
  WILL_TALLY seed=2 rounds=3 wills=9 wills_per_round=3.00
  deaths: void=6 squish=3 | gusts=16 puppet_bonuses=1 carryovers=2
  ```
- **dead_weight** — the all-bot path is byte-identical **by construction**. Bots
  drive a possessed prop through `DWGhost._drive_possession`, which for a bot
  reduces to exactly the old call:
  ```
  OLD (bot, aim_drive==ZERO):  dir = move_input; apply_drive(dir)
  NEW (bot, want_fling==false): apply_drive(move_input)          # identical
                                if want_fling …  # never taken by a bot
                                want_fling = false                # no-op
  ```
  `aim_fling` stays ZERO for bots, `want_fling` is only ever set in the human
  branch of `_drive_ghost`, and `_fling_cd` never leaves 0 (its decrement is
  guarded). `DWProp.fling()` is only reachable via `want_fling`. So no bot-visible
  state changed. NOTE: `--dwbalance` itself is **not** run-to-run reproducible —
  it resolves rounds through `call_deferred`, so frame-timing jitter (esp. under
  concurrent CPU load) shifts outcomes: the same seed 1 on the *same* code gave
  65.0% and 45.0% on two runs, and HEAD gave 80.0% — all contention artifacts, not
  behaviour differences. Uncontended sequential my-vs-HEAD (`--dwbalance=12`,
  seed 1, run strictly alone back-to-back — HEAD via `git stash` of the 3 scripts):
  ```
  A: MINE seed1 : LIVING WIN 66.7%  ghost-kill=4  (shove2 void6  poss24 hits51 avg15.0s)
  C: MINE seed1 : LIVING WIN 66.7%  ghost-kill=4  (shove3 void5  poss21 hits48 avg15.1s)
  B: HEAD seed1 : LIVING WIN 66.7%  ghost-kill=4  (shove1 void7  poss26 hits61 avg16.5s)
  ```
  All three agree on the headline (8/12 living wins) and ghost-kill=4. The only
  spread is sub-attribution/telemetry, and it jitters between the two MINE runs by
  the *same* amount as MINE-vs-HEAD — i.e. it is the harness's own frame-timing
  noise (slow-prop nudge scored shove-vs-void; DW VERIFY.md "Known issues"), not a
  behaviour change. MINE is indistinguishable from HEAD, matching the proof above.
- **tilt** `--tilttest=idle` PASS (platter stays 0.000°); `--tiltbots` seed 7
  runs to `match_end` placements `[3,0,2,1]` — UI-only change, sim unaffected.

## Audit — every other alt/secondary state (the two sins)

Swept greed, throne, orbital, swap_meet, mower, seance, understudy, par
(echo skipped — its ghosts are deterministic replays). **No violations found; no
fixes needed.**

| Game | Alt state | Wrong aim channel? | Missing dead hint? | Verdict |
|------|-----------|--------------------|--------------------|---------|
| greed | downed = 1s stun | N/A (no control/aim while stunned; tackle-lunge already RIGHT-channel, alive-only) | N/A (stun grants no controls) | clean |
| throne | king (seated) + brief dethrone fling | N/A (king powers are auto-targeted: radial decree, nearest-challenger guard) | already shown — persistent hint `"…A = SHOVE / DECREE · B = DASH / GUARD…"` | clean |
| orbital | dead → 3s respawn | N/A (no input while dead; live aim uses `get_aim_screen`, RIGHT) | N/A (dead has no controls) | clean |
| swap_meet | none (kart) | N/A (no aim channel) | N/A | clean |
| mower | 1.2s spinout | N/A (engine off, no control) | N/A | clean |
| seance | none (shared planchette; charlatan = hidden role, same controls) | N/A | N/A | clean |
| understudy | none (menu-nav; hidden role, same controls) | N/A | N/A | clean |
| par | ball dead/petrified = out for round | N/A (mouse/turn-based; out player skipped) | N/A (no hint bar; no controls when out) | clean |

Nothing routed to backlog: every alt state is either non-controllable
(stun/spinout/dead-wait/out-for-round), already RIGHT-channel + instructed
(throne's king), or has no aim/alt state at all.

## Repro commands
```
# dead-state hints (windowed; PNGs in verify_out/*_deadhint/)
godot --path . minigames/dead_weight/dead_weight.tscn -- --deadhint --shots=200,340 --outdir=verify_out/dw_deadhint
godot --path . minigames/last_will/last_will.tscn  -- --deadhint --shots=520,640,760,900 --outdir=verify_out/lw_deadhint
godot --path . minigames/tilt/tilt.tscn            -- --deadhint --shots=260,420 --outdir=verify_out/tilt_deadhint
# last_will shove cue (windowed; verify_out/lw_shove_cue.png)
godot --path . minigames/last_will/last_will.tscn  -- --shovecue --seed=3
# dead_weight fling follows the cursor
godot --path . minigames/dead_weight/dead_weight.tscn -- --aimprobe=0
# determinism
godot --headless --path . minigames/last_will/last_will.tscn -- --willtally --seed=1
godot --headless --path . minigames/dead_weight/dead_weight.tscn -- --dwbalance=20 --seed=1
# import after adding res:// files
godot --headless --editor --import --quit --path .
```
