# Playtest Bugs — VERIFICATION

Four bugs from the game's first outside tester. Engine: Godot 4.6.2 (Windows).
All commands run from the worktree root; screenshots land in `verify_out/`
(gitignored) and were read + critiqued by the builder. Every headless run
reported zero `SCRIPT ERROR / Parse Error / Invalid call / Nil`.

Import pass (required after adding files / on a fresh worktree):
```
godot --headless --editor --import --quit --path .
```

Root-cause method: each bug was traced to the exact line/geometry BEFORE any
fix. Two bugs (swap ramp, echo ring-out) needed dev harness flags to film the
required beats because the trigger is a HUMAN mis-play the seeded bots never
reproduce — the non-reproduction by bots is itself a finding.

---

## BUG 1 — ECHO CHAMBER: "I can go off the map and be safe"; ignores rounds=4

`minigames/echo_chamber/echo_chamber.gd`, `fighter.gd`

### 1a. Walkable apron beyond the ring (campers never fight)

**Root cause.** The arena floor collider is a `CylinderShape3D` of radius
`ARENA_R = 8.0`, but the yellow boundary ring (`_inner_ring`) sits at
`ARENA_R * SHRINK = 5.6`. So the ring between r=5.6 and r=8.0 — the "apron" —
is solid, standable, AND safe in rounds 1..(final-1). A camper walks out there
and the fight never comes to them. (In the final round the apron physically
falls away; the bug is that rounds before it are unguarded.)

**Fix.** Added `RING_R = ARENA_R * SHRINK` (5.6) as the enforced boundary and
`_enforce_ring(delta)`, called every PLAY tick over **live fighters only**:
- a live fighter beyond `RING_R` gets a flashing **"THE RING DEMANDS"** billboard
  warning (`fighter.set_ring_warning`) for `RING_WARN_T = 1.5`s;
- if still outside at 1.5s → **ring-out KO down the existing `on_fall_death`
  path** (killer −1, cause `"ring_out"`), then a "X — THE RING DEMANDS" credit;
- stepping back inside cancels the timer.

Ghosts are separate `EchoGhost` nodes, never in `fighters`, so replayed past
selves outside the ring **trigger nothing** (verified: ghost-drift assertion
still `max_err=0.000000`). Two supporting fixes so nobody spawns into a warning:
`_edge_spawn` now lands at `RING_R * 0.82` (was `platform_r()*0.82` = 6.56,
outside the ring); bot wander targets are bounded to `ring_r()*0.85` (was
`platform_r()*[0.35,0.9]`), so bots fight in the arena instead of camping the
apron and ringing themselves out.

### 1b. Echo ignored `config.rounds` (played 5 when shell passed 4)

**Root cause.** `begin()` read `rng_seed` but never `rounds`; every flow check
used the `const ROUNDS = 5` (`ROUND %d / %d`, `round_no >= ROUNDS`, final-round
shrink, final-round center respawn). The shell (`estate.gd:1634`) passes
`"rounds"` (default 4) per the module contract (`core/minigame.gd:19`); echo
threw it away — matching sibling games would honor it (`greed.gd:162`).

**Fix.** `_rounds = clampi(int(config.get("rounds", ROUNDS)), 1, ROUNDS)` in
`begin()`; all six flow references switched `ROUNDS -> _rounds`. Standalone
default stays 5 (via `_default_config()`'s `"rounds": ROUNDS`). Added a
standalone `--echorounds=N` knob (mirrors greed's `--rounds`) for verification.

### Verification

```
# rounds contract honored end-to-end: exactly 4 rounds, final round shrinks
godot --headless --path . minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=4 --echorounds=4 --seed=1
# -> ROUND_START 1..4, MATCH_OVER after round 4 (was 5)

# ring warning + KO, WINDOWED (dev flag parks fighter 0 on the apron)
godot --path . minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --ringtest --echofast=8 --seed=1 --outdir=verify_out
# -> verify_out/echo_ringwarn.png, verify_out/echo_ringko.png ; ECHO_RINGTEST ko r=7.0

# full standalone (5 rounds) — new bot baseline, determinism intact
godot --headless --path . minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=5 --seed=1
```
- `echo_ringwarn.png` — yellow ring; RED (Barbarian) parked on the apron OUTSIDE
  the ring; "THE RING DEMANDS" flashing above them; other 3 fighting inside. READ.
- `echo_ringko.png` — big "RED — THE RING DEMANDS" banner; RED collapsed at the
  ring edge; scoreboard shows RED dropped. READ.
- Determinism: `ECHO_DETERMINISM round=5 ghosts=12 max_err=0.000000 OK` (ghost
  replay unaffected). `ring_out_events=0` in a full bot game → the bot-wander
  fix keeps bots in the arena; they never suicide off the ring.
- **New bot baseline** (`--echobots --echofast=5 --seed=1`): `champ=BLUE
  placements=[1,3,2,0]`. Bot-sim outcomes shifted vs. pre-fix — intended (bots
  now roam inside the ring).

---

## BUG 2 — SWAP MEET: "get stuck on the ramp and it doesn't let me off"

`minigames/swap_meet/swap_meet.gd`, `swap_kart.gd`

**Root cause / investigation.** The shortcut is a narrow (`SC_HW - KART_R` ≈
1.05 half-width) math corridor with a plank launch ramp (`swap_track.sc_floor`,
s 2.0→4.6 rising to 1.35, then a jump gap). The seeded bots pure-pursuit the
centre-line and clear it at full speed EVERY time — a 4-kart, 3-lap bot race
logs `SC_ENTER → JUMP v=5.0 → SC_EXIT` for every entry with zero stalls. So the
trap is a **human low-speed / mis-steer case**: a player who brakes, gets boom-
knocked, or noses into the ramp rail grinds to ~0 speed while auto-throttle and
the wall-bounce clamp keep cancelling, and the corridor is too tight to wriggle
free — exactly "stuck and it won't let me off". Bots not reproducing it is why
it survived to an outside tester.

**Fix (stuck detection + gentle nudge, per the ticket).** Added
`_ramp_unstick(kart, q, s_sc, dt)` in the on-shortcut branch of `_constrain`.
When a kart is on the shortcut, grounded, `|speed| < 1.0`, and the raw player
intent is held (`kart.last_input_mag >= 0.5`) for **1.5s continuously**, it gets
ONE gutter-style nudge: re-centred on the corridor a step further along
(`sc_sample_at(s_sc + 1.2)`), heading/vel aligned to the path tangent, and a
little forward speed handed back (`max(speed, 3.0)`). No teleport past the jam
beyond that single step. The gate (`|speed|<1.0` for 1.5s) is impossible for the
always-~5u/s bots, so **their sim is untouched**.

### Verification

```
# bot determinism preserved — re-run vs. pre-change baseline, byte-identical
godot --headless --path . minigames/swap_meet/swap_meet.tscn -- \
  --swapbots --seed=3 --players=4 --fast=8 --laps=3
# -> SC_ENTER/JUMP/SC_EXIT/LAP/FINISH lines IDENTICAL to baseline; 0 SC_UNSTICK

# forced-stuck dev harness proves the unstick trips, WINDOWED
godot --path . minigames/swap_meet/swap_meet.tscn -- --swapstuck --seed=3 --players=4
# -> SC_UNSTICK t=1.5 p=0 s=2.9 ; verify_out/swap_unstick.png
```
- Determinism: event log **identical** to the pre-fix baseline (`diff` clean),
  and `SC_UNSTICK` count `= 0` for the bot race — the anti-trap never fires for
  bots, so their receipts are unchanged.
- `swap_unstick.png` — kart 0 (RED, crowned leader) jammed on the plank ramp,
  nudged back onto the shortcut and moving again; fired at exactly the 1.5s
  threshold. READ.

---

## BUG 3 — GREED INC.: "Never lets me grab the gold"

`minigames/greed/greed.gd`, `greed_bots.gd`, `greed_player.gd`

**Investigation — bots do NOT bypass the hold.** A bot's `grab` intent flows
through the **same** `_handle_action` path as a human: `me.grab_hold += delta`
accumulates while it holds `grab` in range, and `_do_grab` only fires at
`grab_hold >= GRAB_TIME (0.6)`. There is no code path where a bot becomes carrier
without the 0.6s hold (`_do_grab` is the sole grab→carrier sink). So the hold is
already symmetric.

**Root cause — unfair tie-break.** Players are ticked in **index order**
(`for p in roster.size()`), and the first to reach `GRAB_TIME` grabs and resets
everyone. On equal progress the **lower index wins** — so a lower-indexed BOT
beats a tied, higher-indexed HUMAN every time. That is the "never lets me grab"
feel: the human is in a fair race but loses ties to seat order.

**Fix (minimal, human tie-break; bot-only byte-identical).** Added
`_grab_winner_over(p, delta)`: when the player crossing `GRAB_TIME` is a bot and
a HUMAN is tied on effective progress (`hq.grab_hold + delta >= me.grab_hold`),
still holding A within range, the **human** takes the pot. With no humans in the
contest it returns `p` unchanged, so bot-only sims are byte-identical and the
documented `--greedtest=intercept` kinematic receipts (independent of the grab
path) are untouched.

### Verification

```
# intercept receipts UNCHANGED (hard constraint) — identical to VERIFY.md
godot --headless --path . minigames/greed/greed.tscn -- --greedtest=intercept --seed=1
# -> trials=80 catches=64 rate=0.80 PASS   (baseline: 0.80)
godot --headless --path . minigames/greed/greed.tscn -- --greedtest=intercept --seed=4
# -> trials=80 catches=54 rate=0.68 PASS   (baseline: 0.68)

# bots still grab + bank normally (no humans -> override is a no-op)
godot --headless --path . minigames/greed/greed.tscn -- --greedbots --seed=3 --rounds=1 --roundtime=30
# -> grab p3/p1/p0 ... round_end scores[...]; deterministic per seed
```
- Intercept rates **exactly match** the documented baseline (0.80 / 0.68) — the
  grab change does not touch the tackle/movement model.
- Bot-only greed is deterministic and unchanged (the override cannot fire without
  a human seat).

---

## BUG 4 — PAR FOR THE CURSE

`scripts/main.gd`, `scripts/round_manager.gd`, `scripts/course.gd`, `scripts/ball.gd`

### 4a. "All the characters are facing the wrong way" (caddies) — FIXED

**Root cause.** `main.gd:171` hardcoded `caddy.rotation_degrees.y = 105.0 * side`
(`side = -1` for even seats, `+1` for odd). That yaw ignores where each caddy
stands, so left-bank caddies (which should look right, toward the green) stared
off at −105°, away from the course.

**Fix.** Face each caddy at the course centre. KayKit models look down +Z, so
`rotation.y = atan2(dir.x, dir.z)` with `dir = course.course_center - caddy_pos`
makes the model's forward `(sinθ,0,cosθ)` equal `dir` normalized — pointing
exactly at the centre. Verified numerically for fairway (`center=(0,0,-8.25)`):

| seat | caddy pos (x,z) | rotation.y | forward → |
|---|---|---|---|
| 0 (L) | (−4.5, −8.05) | +92.5° | +x, toward centre |
| 1 (R) | (+4.5, −8.05) | −92.5° | −x, toward centre |
| 2 (L) | (−4.5, −6.55) | +110.7° | +x/−z, toward centre |
| 3 (R) | (+4.5, −6.55) | −110.7° | −x/−z, toward centre |

```
godot --path . scenes/main.tscn -- --parbots --nokillcam --course=fairway \
  --seed=2 --shots=40,150 --outdir=verify_out
```
- `shot_0150.png` — all four caddies flank the fairway and face **inward** toward
  the green (was a fixed ±105° stare). READ.

### 4b. "I put the ball in but it made me go again" — INVESTIGATED, OPEN ITEM

**Do-not-guess-fix per the ticket.** I could not find, and bots cannot
reproduce, any path where a HOLED-OUT (sunk, `resolved`) player is granted
another stroke. The turn machinery is provably closed against it:

- `on_ball_sunk(p)` is wired directly to `Ball.sunk` and sets
  `resolved[p]="sunk"` the instant the ball enters the `CupArea` (`mark_sunk`).
- Every selector excludes resolved players: `current_player()` returns
  `turn_order[_turn_pointer]`; `_advance_turn()` only emits `turn_started` for a
  candidate where `not resolved.has(candidate)`; `is_turn_ready()` returns false
  when `resolved.has(current_player())`. So a resolved seat can never be current,
  never be re-emitted, and can never putt.
- Instrumented `_advance_turn` to log every emitted turn with the resolved set
  and ran par bot matches (seed 2, fairway, 3 rounds): **no sunk player ever
  reappears** in the turn stream. `DBG_TURN` cross-checked against `BALL_SUNK`:
  once a seat sinks it is absent from all later turns that round.

**Most plausible remaining vector (needs a human to reproduce).** The cup
`Area3D.body_entered` (trigger radius 0.27) only fires on ENTER, while the cup
magnet (`course.gd`, radius 0.36, force 26) pulls slow balls in. In the common
case (all bot sinks logged `BALL_SUNK`) this works. The suspect edge is a ball
that comes to rest ON the lip inside magnet range but never crosses the trigger
boundary from outside (e.g. settling exactly on the rim, or a gutter-delivered
ball placed atop the cup): `came_to_rest` fires, the turn advances, and the
player is asked to putt a ball that *looks* holed. This is a
perception/cup-trigger geometry case, not a turn-logic defect, and was NOT
guess-fixed. Instrumentation (temporary `_advance_turn` print) is documented
here for the next human-driven repro session; a candidate hardening (widen the
cup trigger to meet `MAGNET_RADIUS`, or add a "resting inside magnet radius →
mark_sunk" latch in `course._physics_process`) is noted but deliberately not
applied without a reproduction.

---

## Determinism summary

| Game | Fix changes bot sim? | Receipt |
|---|---|---|
| Echo | YES (intended — bots roam inside ring) | new baseline `champ=BLUE placements=[1,3,2,0]`; ghost-drift `max_err=0.000000` |
| Swap | NO | event log byte-identical to baseline; `SC_UNSTICK=0` for bots |
| Greed | NO (override no-ops without humans) | `--greedtest=intercept` identical (0.80 / 0.68 PASS) |
| Par | NO (caddy = presentation; 4b untouched) | `FINAL_RESULT` path unchanged |
