# VERIFY-AIM — Mouse aim for KB+Mouse players (device -4)

Adds **cursor aim** to the action verbs of four minigames for the KBM player
(PlayerInput device `-4`, LMB=A / RMB=B). The rule everywhere:

> When a **human** player's device is `-4` and `get_aim_dir` (or `get_aim_screen`)
> returns non-zero, the aim replaces the facing-derived direction **for the action
> only**. Movement stays WASD (characters do **not** turn toward the cursor while
> merely walking), but the character **does** face the aim during the action so the
> animation reads. Bots and non-KBM devices are **byte-identical** — their code
> paths never sample the aim.

Aim is sampled where input is already read (never inside a replay/record path).
Echo records the *actual* fire direction, so ghost replays stay honest.

## Shared plumbing — `core/player_input.gd`

- `get_aim_dir(p, from_pos, cam)` — now gated on `device_of(p) == -4` **first**,
  then an optional debug injection, then the real cursor ray. Empty injection ⇒
  identical to before.
- `get_aim_screen(p, world_anchor, cam)` — **new**. Unit screen-space vector
  (x=right, y=up) from the anchor's projected position toward the cursor. For
  games whose action plane isn't the world horizontal (Orbital's spheres).
- `set_debug_aim` / `set_debug_aim_screen` — verification-only injection used by
  the `--aimprobe` modes. Never called in normal play, so real cursor / gamepad /
  keyboard-half / bot behavior is untouched.

## Per-game delta

| Game | Action now cursor-aimed | Left as-is (per rule) | Hook | Aim source |
|------|-------------------------|-----------------------|------|------------|
| **echo_chamber** | light + heavy swing (arc centered on cursor, body faces it) | **parry** (direction-agnostic), **dash** (movement-directed) | `fighter._start_light/_start_heavy` overwrite `yaw` via `_aim_yaw()` | `get_aim_dir` |
| **orbital** | throw aim + dotted preview (heading chases cursor) | catch, walk, jump | `orb_pawn._aim_turn_mouse` maps `get_aim_screen` into the screen-relative tangent frame (`frame_r`/`up_t`); world feeds it through `step()` | `get_aim_screen` |
| **greed** | tackle lunge (pounce toward cursor, body faces it) | grab (unchanged), dash (movement-directed) | `greed._attempt_tackle` → `greed_player.lunge_toward()` (face + `apply_knock`) | `get_aim_dir` |
| **dead_weight** | living **shove** cone + poltergeist **prop-fling** force | hop (B), ghost free-fly (WASD) | `DWFighter._do_shove` uses `aim_face`; `DWGhost._drive_possession` uses `aim_drive` | `get_aim_dir` |

### Why the recorded/replay path stays honest (echo)
Echo's ghost replays re-fire recorded swings using the recorded `yaw`, and the
30 Hz recorder samples `f.yaw` each physics step. Because the swing overwrites
`yaw` **once at swing start** and the fighter is `_busy()` (rooted) for the whole
swing, that single value feeds the arc (`resolve_swing`), the model rotation, AND
the recorder — so a ghost replays the exact direction the live swing used. No new
field was needed in the recording; the honest value was already the thing sampled.

## Verification

Every game exposes a debug arg that pins a synthetic cursor for player 0 (a KBM
human) and fires one real action through the normal code path, screenshotting a
**facing** baseline and an **acting** frame. A **white** ray marks the baseline
facing/heading; a **cyan** ray marks the cursor. The action follows cyan.

Convention: aim angle in degrees, world dir `(sin θ, 0, cos θ)` (0°=+Z=toward
camera/front, 90°=+X=screen-right). Probe forces facing 90° off the aim.

### echo_chamber — `--aimprobe=<deg>`
```
godot --path . res://minigames/echo_chamber/echo_chamber.tscn -- --aimprobe=0 --outdir=verify_out
```
- `ECHO_AIMPROBE face=90deg aim=0deg body_before=90deg` → `body_after=0deg matches_aim=true`
- Shots: `verify_out/echo_aim_facing.png`, `verify_out/echo_aim_acting.png`
  (body rotates off the white facing ray onto the cyan aim ray for the swing).

Legacy (all-bot) determinism — **byte-identical**:
```
godot --headless --path . res://minigames/echo_chamber/echo_chamber.tscn -- --echobots --echofast=5 --seed=1
```
```
ECHO_DETERMINISM round=1 ghosts=0  max_err=0.000000 OK
ECHO_DETERMINISM round=2 ghosts=4  max_err=0.000000 OK
ECHO_DETERMINISM round=3 ghosts=8  max_err=0.000000 OK
ECHO_DETERMINISM round=4 ghosts=12 max_err=0.000000 OK
ECHO_DETERMINISM round=5 ghosts=12 max_err=0.000000 OK
ECHO_MATCH_OVER champ=GOLD placements=[2, 0, 3, 1]
```

### orbital — `--aimprobe=<deg>` (screen-space angle)
```
godot --path . res://minigames/orbital/orbital.tscn -- --aimprobe=90
```
- `ORB_AIMPROBE heading_before=(1.00,0.00,0.00)` → `heading_after=(0.00,1.00,0.00)` (screen-right → screen-up = cursor)
- Shots: `verify_out/orbital_aim_facing.png` (dotted preview along fixed heading),
  `verify_out/orbital_aim_acting.png` (preview + thrown ball track the cyan cursor ray).

Legacy — **byte-identical**:
```
godot --headless --path . res://minigames/orbital/orbital.tscn -- --orbtest=circ --autoquit --seed=7
  CIRC_OK planet=0 ... min_heading_dot=0.9998 flips=0
  CIRC_OK planet=1 ... min_heading_dot=0.9995 flips=0
  CIRC_OK planet=2 ... min_heading_dot=0.9993 flips=0
  CIRC_DONE all 3 planets circumnavigated, zero control flips
godot --headless --path . res://minigames/orbital/orbital.tscn -- --orbbots --seed=7 --fast=10 --autoquit
  ORBITAL_SIM throws=55 hops=46 kills={0:6,1:3,2:5,3:6} ...
  ORBITAL_ASSERT max_flight_age=46.4s (<75s): PASS
```

### greed — `--aimprobe=<deg>`
```
godot --path . res://minigames/greed/greed.tscn -- --aimprobe=0
```
- `GREED_AIMPROBE face=90deg aim=0deg body_before=90deg` → `body_after=0deg lunge_dir=0deg matches_aim=true (moved 0.86m)`
- Shots: `verify_out/greed_aim_facing.png`, `verify_out/greed_aim_acting.png`
  ("RED MUGGED BLUE" — real tackle fired, p0 pounced onto the cyan aim ray, not
  the white facing ray).

Legacy — **byte-identical** (balance model is a separate pure-kinematic sim):
```
godot --headless --path . res://minigames/greed/greed.tscn -- --greedtest=intercept --seed=1
  GREED_INTERCEPT trials=80 catches=64 rate=0.80 (bar>=0.60) PASS
```

### dead_weight — `--aimprobe=<deg>` (poltergeist fling) and `--aimshove=<deg>` (living shove)
```
godot --path . res://minigames/dead_weight/dead_weight.tscn -- --aimprobe=0
  DW_AIMPROBE fling baseline prop_vel=(9.77,-0.33,1.19) (WASD +X)
  DW_AIMPROBE fling prop_vel=(-1.24,-0.07,28.20) dir=-3deg aim=0deg matches=true
godot --path . res://minigames/dead_weight/dead_weight.tscn -- --aimshove=0
  DW_AIMSHOVE face=90deg aim=0deg victim_before=(0.00,1.50)
  DW_AIMSHOVE victim moved 1.18m dir=0deg aim=0deg matches=true
```
- Shots: `verify_out/dead_weight_aim_fling_{facing,acting}.png` (a possessed lamp
  driven +X by WASD, then **hurled onto the cyan cursor ray at ~28 m/s** — furniture
  thrown at the mouse), `verify_out/dead_weight_aim_shove_{facing,acting}.png`
  (fighter faces 90° off the cursor, shoves, body + victim-knockback snap to the aim).

Legacy balance (all-bot ⇒ aim never sampled) — band unchanged:
```
godot --headless --path . res://minigames/dead_weight/dead_weight.tscn -- --dwbalance=20 --seed=1
  living-shove=0 ghost-kill=8 void/accident=12
  LIVING WIN % = 60.0%   ghost-decided % = 40.0%   [target living 55-75%]  PASS
  telemetry: possessions=47 ghost_hits=117 avg_round=17.2s
```

## Judged WRONG / left out
None of the **requested** aims were omitted — all four are implemented. The
actions deliberately left un-aimed are the ones the rule itself excludes:
**echo** parry (a stance, no direction) and dash; **orbital** catch and jump;
**greed** grab and dash; **dead_weight** hop and the ghost's un-possessed
free-fly. Note on greed: the tackle *hit* is proximity-based (omnidirectional
range check), so the cursor lunge is a positioning pounce + facing, not a change
to whether the tackle connects — it makes the human's tackle read as a deliberate
dive at the target rather than a stationary flail.
