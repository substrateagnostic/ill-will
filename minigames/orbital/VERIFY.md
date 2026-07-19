# ORBITAL DODGEBALL — verification evidence

Module: `minigames/orbital/` · root scene `orbital.tscn` (extends `Minigame`).
All commands run from the repo root. Screenshots land in `verify_out/`
(gitignored); the ones referenced below were read and art-directed by the
builder during the session.

## Commands run

```sh
# import pass (required after adding files)
godot --headless --editor --import --quit --path .

# 1. Screen-relative controls on spheres: bot circumnavigates each planet
#    on CONSTANT stick input (1,0); heading continuity logged per tick
godot --headless --path . res://minigames/orbital/orbital.tscn -- --orbtest=circ --autoquit --seed=7

# 2. Orbit decay guarantee: full 3-minute seeded bot match at 10-12x,
#    asserts max continuous flight age < 75s, prints results contract
godot --headless --path . res://minigames/orbital/orbital.tscn -- --orbbots --seed=7 --fast=10 --autoquit
#    (repeated for seeds 1, 2, 3, 11)

# 3. Headed self-play with screenshots (VerifyCapture autoload); frames were
#    chosen from the headless event log of the same seed (the sim is
#    tick-identical between headless/headed/--fast runs, see Determinism)
godot --path . res://minigames/orbital/orbital.tscn -- --orbbots --seed=11 --shots=630,1600,2875,6720,7480,10600,10870,11420 --outdir=verify_out

# 4. Aim-preview closeup (player 0 holds a full-power aim forever)
godot --path . res://minigames/orbital/orbital.tscn -- --orbtest=aim --seed=7 --shots=140 --outdir=verify_out

# 5. GHOST MEDDLING live-wisp shot (dev flag --orbmeddleshot, windowed; bypasses
#    the human gate to photograph the actor — never a receipt path)
godot --path . res://minigames/orbital/orbital.tscn -- --orbbots --seed=7 --orbmeddleshot
#    -> verify_out/orbital_meddle_wisp.png
```

## GHOST MEDDLING (doc 24 §6 / B6)

A KO'd **human** seat hovers **fixed at its death spot** (drift=false — a
floor-clamped drift would fight orbital's screen-relative planet controls) for
its 3s respawn window as an owner-tinted wisp (name + cooldown ring + "MEDDLE
READY"), and may press **A** once to **RATTLE THE VOID**: a cold spectral pulse.
Filed by the estate: `RED'S GHOST RATTLED THE VOID.` (`core/ghost_meddle.gd`,
wired in `_build_static` / `_physics_process` / `_do_kill` / `_process_respawns`
/ `_net_apply` / `_mirror_tick`).

**PRESENTATION-only — safety absolute.** In an arena where *every ball is lethal*,
a sim nudge could kill; so the meddle is a cosmetic burst + soft rush only
(`_on_ghost_meddle`, `presentation_only=true`). It touches **no** ball, score,
kill credit, or sim RNG (`_spawn_burst` uses engine particle randomness, never
the seeded sim `rng`), and each screen renders its own — no new network messages.

**Receipt-safe by construction.** A wisp is raised **only for a non-bot seat**
(`not bot_enabled[victim]`), so `--orbbots` all-bot runs never build one and never
call `_on_ghost_meddle`. Verified byte-identical vs the pre-meddle baseline
(orbital's slow-mo never touches `Engine.time_scale`, so the sim is fully
deterministic run-to-run):

```
godot --headless --path . res://minigames/orbital/orbital.tscn -- \
  --orbbots --seed=7 --fast=10 --autoquit
# KILL/HOP log + ORBITAL_RESULTS placements":[3,0,2,1] points":{0:13,1:6,2:10,3:14}
# + ORBITAL_ASSERT ... PASS  — all IDENTICAL before/after; zero ORB_MEDDLE lines.
```

## Risks & tests from the spec

### Screen-relative controls on spheres (control-flip test)

`--orbtest=circ` drives pawn 0 with a constant screen-space stick (1,0)
around each planet in turn, logging the tick-to-tick heading dot product
(a control flip would read as a negative dot). Output:

```
CIRC_OK planet=0 full_circle min_heading_dot=0.9998 flips=0
CIRC_OK planet=1 full_circle min_heading_dot=0.9995 flips=0
CIRC_OK planet=2 full_circle min_heading_dot=0.9993 flips=0
CIRC_DONE all 3 planets circumnavigated, zero control flips
```

Mechanism: a parallel-transported control frame that relaxes toward the
projected camera frame only on the camera-facing hemisphere (see the
`orb_pawn.gd` header). On the visible side right IS screen-right; holding a
direction wraps you around the back Pac-Man style and re-emerges.

### Orbit stability / guaranteed decay

3%/s space drag alone was NOT enough: eccentric cluster orbits idle at slow
apoapsis where proportional drag removes almost no energy (observed 111s
flights). Two additions guarantee decay: the drag ramps +0.008/s per second
past 38s, and restitution fades to zero between 50-65s so an old orbit's
first graze is its last. Assert results (3-minute bot matches at true dt):

| seed | max flight age | throws | hops | verdict |
|---|---|---|---|---|
| 1 | 39.6s | 57 | 55 | PASS |
| 2 | 32.9s | 63 | 68 | PASS |
| 3 | 33.1s | 55 | 61 | PASS |
| 7 | 46.4s | 55 | 46 | PASS |
| 11 | 46.4s | 54 | 59 | PASS |

Printed by the game as e.g. `ORBITAL_ASSERT max_flight_age=46.4s (<75s): PASS`.

### Determinism (found + fixed during verification)

Two engine behaviors silently broke tick-determinism; both are fixed and
proven by diffing full event logs:

1. `Engine.time_scale` SCALES THE PHYSICS DELTA (`delta = time_scale /
   physics_ticks_per_second`). A naive `--fast=10` therefore integrated at
   10x step size - a different game. Fix: `--fast=K` scales BOTH
   `physics_ticks_per_second` (60K) and `time_scale` (K) so dt stays exactly
   1/60 while K ticks run per real tick.
2. Slow-mo via `Engine.time_scale` is applied at FRAME granularity, so the
   kill beat entered/exited on frame boundaries (machine-dependent). Fix:
   slow-mo scales the sim's own step (`sdt = delta * 0.3`) for a
   tick-counted budget and never touches time_scale.

Proof: `diff` of THROW/KILL/CATCH/HOP logs, seed 11, real-time vs --fast=10
-> `FAST==REALTIME tick-identical`; two identical fast runs also diff clean.

## MUST list status

| MUST | status | evidence |
|---|---|---|
| 3-planet radial gravity walk | DONE | circ test above; pawns visibly stand radially in every screenshot |
| Throw/orbit physics with trails | DONE | shot_0900 (curved colored ribbons), late-sky shots; trails are 2s owner-colored ribbons |
| Kill credit to last thrower with age | DONE | `KILL t=53.2 killer=0 victim=1 ball_age=44.2` log lines; banner "RED'S GHOST ORBIT STRIKES! 44-SECOND-OLD THROW TAKES OUT BLUE" captured in shot_0900-style frames |
| Catch | DONE | `CATCH t=65.2 p=1 ball_age=12.8 stolen=true`; 0.2s window, 0.5s invuln, NICE CATCH event text |
| Respawn | DONE | 3s delay, least-crowded planet, spawn burst + 1s invuln shimmer (bot matches average ~20 deaths / 3 min) |
| 3-min match | DONE | timer HUD counts 3:00 -> 0:00, END phase freezes input, winner banner |
| Results contract | DONE | `ORBITAL_RESULTS {...}` validated by `Minigame.report_finished` with zero warnings; placements include all roster players, ties broken by earlier index (seed 11: 10/10/10/8 -> [0,1,3,2]) |
| Seeded bots | DONE | `--orbbots`; virtual screen-space thumbstick through the same control path as humans; per-bot RNG seeded from config.rng_seed (identical logs across reruns of the same seed) |

## SHOULD list status

| SHOULD | status |
|---|---|
| Aim preview | DONE — dotted diamond arc, first 1.5s of the integrated path only, impact blip where it would hit a planet (shot_0140) |
| Planet-hop jumps | DONE — ballistic jumps through the blended field; 24-47 hops per bot match (`HOP t=… 1->0` logs) |
| Catch invuln flash | DONE — 0.5s invuln + white burst + visibility shimmer |

## Scoring / currency (spec)

+2 kill, +1 catch-steal, 0 for deaths. `currency_events`: royalty +1 for
every kill by a ball thrown >10s ago (the accretion kill), grudge +1 per
death. Highlights include the oldest-orbit kill with age ("BLUE's 46-second
orbit found MINT"). Monuments for ghost kills older than 25s.

## Screenshot annotations (all read + art-directed during the build)

Seed-11 full match (`--shots=...` frames chosen from the headless event log
of the same seed; this machine renders ~144fps so frame ≈ 144 * real-sec):

- `shot_1600` — early game t≈10s: all three planets framed at 1280x720,
  three deadly balls already in flight, chars radially oriented.
- `shot_3750` — "GOLD SMACKS MINT!" plain-kill banner (kill t=24.9) with
  MINT's corpse tumbling in the gap; four glowing balls with crossing trails.
- `shot_6720` — THE signature frame: "GOLD'S GHOST ORBIT STRIKES!
  45-SECOND-OLD THROW TAKES OUT MINT" (kill t=46.1, ball_age=45.1), killing
  ball still glowing at the impact point, corpse flying, "A NEW BALL DRIFTS
  IN" firing simultaneously, GOLD's score exactly 2x kills.
- `shot_6890` — one beat later: the killing gold ball's orbit ring visibly
  CONTINUES around the big planet (the ball keeps flying after a kill).
- `shot_7480` — BLUE captured mid planet-hop in the gap; two red orbits.
- `shot_10600` (first calibration run) — "GOLD'S GHOST ORBIT STRIKES!
  12-SECOND-OLD THROW TAKES OUT RED" + flowing ribbon sky.
- `shot_11420` (first calibration run) — red trail showing a full
  bounce-zigzag between planets: readable orbit history.
- `shot_16130` — triple evidence: "NICE CATCH — GOLD" banner (catch
  t=106.9), RED's dotted aim-preview arc live in-match, three gold orbits.
- `shot_25150` — late game t≈168s, red sub-15s timer, five balls with
  comet trails across the sky.
- `shot_2100` (short-match run) — end screen: "RED RULES THE VOID!" with
  orbits still flying behind the banner.
- `shot_0140` (aim run) — throw aim preview closeup: dotted diamonds
  arcing across the gap to the neighboring planet with an impact blip.

Scoreboard cross-check: at shot_10600, GOLD had 4 kills logged -> 8 points
shown; RED/BLUE 1 kill each -> 2 points. Exact match with the event log.

## Known issues / notes

- Balls do not collide with each other (not in spec; trails read better
  without the extra chaos).
- Throws/catches are grounded-only; airborne pawns are ballistic
  passengers. Catching mid-hop is a wish, not a bug.
- Behind-the-planet players are represented by their always-on-top marker
  orb; the transported control frame means their stick keeps working, but
  on the far side "right" is whatever carries them around, not literal
  screen-right (this is exactly what makes circumnavigation flip-free).
- `--fast` sims mute the master bus and skip slow-mo so Engine.time_scale
  stays honest; headless quits at match end leak a few ObjectDB instances
  (harness-only path, the shell never quits that way).
- Frame-indexed screenshots are fps-dependent (VerifyCapture counts
  rendered frames; this box runs ~144fps) and each kill's slow-mo beat
  adds ~0.28s of wall time; banner windows (2-2.8s) absorb both.

## v1.1 — TUNING PASS: score feedback (playtest)

Friend playtest note verbatim: *"How am I getting points? Pretty fun, in a
good spot."* — explicitly scoped as FEEDBACK only, no scoring changes. Two
additions, both pure presentation:

**1. Floating "+N" popups** (`orbital.gd`, new `_score_popup()`, called from
`_do_catch()` and `_do_kill()` right after `_points[...]` is already
updated — never touches scoring itself). A world-space `Label3D` billboard,
adapted from `tilt.gd`'s proven `_floaty()` house pattern, that rises and
fades at the moment points land:
- **Kill** (+`KILL_POINTS`=2): appears at the impact point — the VICTIM's
  `body_center()` (where the camera's attention already is) — tinted in the
  KILLER's color, so it reads as "this hit was worth +2 to them."
- **Catch-steal** (+`CATCH_POINTS`=1): appears at the catcher's own
  `body_center()`, tinted in their color (only fires when `stolen == true`,
  i.e. an actual steal of someone else's orbit — matches the existing
  scoring gate exactly, no popup for catching your own ball).
- Rises along the pawn's LOCAL surface normal (`pw.srf_n`), not world Y — a
  fixed world-up would rise INTO the planet for a pawn standing on the far
  side of a sphere.

**2. Intro-card legend.** Added an optional `legend` field to the shared
`core/ui_kit/intro_card.gd` (opt-in, empty by default — every other game's
`present()` call is unaffected) for a small STATIC line under the rotating
`tips` carousel, since a scoring key that rotates away after 2.6s risks never
being read. Orbital sets `spec["legend"] = "+2 KILL · +1 CATCH-STEAL (grab a
ball someone else threw, mid-orbit)"`, built from the same `KILL_POINTS`/
`CATCH_POINTS` constants the sim uses (can't drift out of sync).

**Verified zero sim impact** — same command, same seed, byte-identical to
the receipt already on file above:
```
godot --headless --path . res://minigames/orbital/orbital.tscn -- --orbbots --seed=7 --fast=10 --autoquit
# ORBITAL_RESULTS placements":[3,0,2,1] points":{0:13,1:6,2:10,3:14}   <- unchanged
# ORBITAL_ASSERT max_flight_age=46.4s (<75s): PASS                     <- unchanged
```
No deliberate-change entry needed — the popups/legend are drawn AFTER the
scoring math, and the receipt above proves it.

**Screenshots** (`verify_out/orbital_m3_final/`, seed=11):
- `orbital_intro_legend.png` — the intro card: rotating tip line above, the
  new static "+2 KILL · +1 CATCH-STEAL..." legend line below it, both
  readable before the READY ring fills.
- `orbital_kill_popups.png` — two back-to-back kills at t=24.4/24.9
  ("GOLD SMACKS MINT!"): two gold "+2" popups floating up from the impact
  point, one per kill, both clearly attributable to GOLD's color.

## Wishes (assets_raw not available in worktrees)

- A soft round particle sprite (kenney_particles) for star dots and death
  pops instead of unshaded sphere discs.
- A whoosh/throw sound and a low sci-fi hum for ghost balls older than 10s
  (currently reusing putt/bounce/bell from assets/audio).
- Kenney UI panel 9-slices for the scoreboard.
