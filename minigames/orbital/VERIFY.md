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

# 3. Headed self-play with screenshots (VerifyCapture autoload)
godot --path . res://minigames/orbital/orbital.tscn -- --orbbots --seed=11 --shots=630,2700,4090,5910,9540,10560,11250 --outdir=verify_out

# 4. Aim-preview closeup (player 0 holds a full-power aim forever)
godot --path . res://minigames/orbital/orbital.tscn -- --orbtest=aim --seed=7 --shots=140 --outdir=verify_out
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
first graze is its last. Assert results (3-minute bot matches, 8 balls late):

| seed | max flight age | verdict |
|---|---|---|
| 1 | 64.6s | PASS |
| 2 | 66.8s | PASS |
| 3 | 65.4s | PASS |
| 7 | 69.2s | PASS |
| 11 | 58.5s | PASS |

Printed by the game as e.g. `ORBITAL_ASSERT max_flight_age=58.5s (<75s): PASS`.

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

## Screenshot annotations (seed 11 run)

- `shot_0630` — early game: all three planets framed, pedestal balls,
  KayKit chars radially oriented, first trails in the sky.
- `shot_2700` — ghost-orbit kill banner (33s-old throw), corpse fling,
  death burst.
- `shot_4090` — "NICE CATCH — BLUE — A 12-SECOND ORBIT!" event text.
- `shot_5910` — mid-game sky with multiple orbit ribbons.
- `shot_9540` — 54-second ghost kill banner late game.
- `shot_10560` — late-game spirograph sky (7-8 balls in circulation).
- `shot_11250` — end screen: "X RULES THE VOID!", winner cheer, confetti.
- `shot_0140` (aim run) — throw aim preview: dotted diamonds arcing across
  the gap to the neighboring planet with an impact blip.

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
- Frame-indexed screenshots drift ~15 frames per kill in headed runs
  because of the slow-mo beat; banner windows (2-2.8s) absorb it.

## Wishes (assets_raw not available in worktrees)

- A soft round particle sprite (kenney_particles) for star dots and death
  pops instead of unshaded sphere discs.
- A whoosh/throw sound and a low sci-fi hum for ghost balls older than 10s
  (currently reusing putt/bounce/bell from assets/audio).
- Kenney UI panel 9-slices for the scoreboard.
