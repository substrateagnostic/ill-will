# SWAP MEET — verification evidence

Module: `minigames/swap_meet/` · root scene `swap_meet.tscn` (extends
`Minigame`). All commands run from the repo root. Screenshots land in
`verify_out/` (gitignored); every shot referenced below was read and
art-directed by the builder during the session.

No physics bodies anywhere: karts, orbs, walls (corridor math around a
Catmull-Rom loop), the shortcut ramp and the windmill booms are all
hand-integrated in `_physics_process`, so the sim is tick-deterministic
by construction.

## Commands run

```sh
# import pass (required after adding files)
godot --headless --editor --import --quit --path .

# 1. Five-seed bot race suite: 3 laps each, prints per-kart lap times,
#    swap tally, and a PASS/FAIL assert line
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=1 --fast=8 --autoquit
#    (repeated for seeds 2, 3, 7, 11)

# 2. Swap immunity (spec risk): scripted orb drops — swap, blocked
#    counter-orb inside the 1s window, clean swap after expiry
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swaptest=immunity --autoquit

# 3. Determinism: event logs (SWAP/THROW/LAP/FINISH/GOLD/JUMP/KNOCK/BOOST)
#    diffed across runs
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=11 --fast=8 --autoquit   # twice
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=11 --autoquit           # realtime

# 4. Headed screenshot runs (WINDOWED; --shotsec captures at wall-clock
#    seconds computed from the same seed's headless event log)
godot --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=11 --autoquit --shotsec=6.0,16.95,28.75,45.4,48.4,48.9,52.5
godot --path . res://minigames/swap_meet/swap_meet.tscn -- --swaptest=moment --autoquit --shotsec=0.8,1.85,2.0,2.4

# 5. VerifyCapture autoload contract path (--shots frame indices)
godot --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=11 --shots=300,900 --outdir=verify_out
```

## Risks & tests from the spec

### Five-seed bot race (all bots finish 3 laps, lap times, swap tally)

| seed | race time | laps (per kart, s) | swaps | blocked | golden used | verdict |
|---|---|---|---|---|---|---|
| 1 | 48.1s | 14.0–16.8 | 20 | 2 | yes | PASS |
| 2 | 48.9s | 14.5–16.9 | 15 | 3 | claimed, holder led | PASS |
| 3 | 47.0s | 14.3–16.8 | 18 | 2 | no spawn window use | PASS |
| 7 | 48.5s | 14.3–17.1 | 5 | 2 | yes | PASS |
| 11 | 46.8s | 14.7–16.7 | 20 | 3 | yes | PASS |

All 20 bot karts finished 3 laps in < 50s (< 3min required); swaps
average **15.6 per race** (>= 3 required). Printed by the game as e.g.
`SWAPMEET_ASSERT all_finished=true race_t=46.8s(<180) swaps=20(>=3): PASS`.

Lap-split note: a swap that carries a kart across the start line shows up
as a tiny/huge split pair (seed 11: `p1=[0.1,...] p3=[...,32.1,...]`).
Splits are POSITIONAL — they travel with the seat, which is exactly what
a position swap means. The sums still match the race clock.

### Swap immunity (anti ping-pong)

`--swaptest=immunity` drops three scripted orbs on kart 1: at t=1.0
(hits -> swap #1), at t=1.8 (arrives inside the 1s immunity -> must sail
through), at t=3.5 (immunity expired -> swap #2). Output:

```
SWAP t=1.3 thrower=0 victim=1 golden=false gain=1
SWAP_BLOCKED t=2.1 victim=1
SWAP t=3.8 thrower=2 victim=1 golden=false gain=1
SWAPMEET_TEST immunity swaps=2 blocked=1: PASS
```

Swaps are atomic (both kinematic "souls" — position, velocity, heading,
corridor, progress, lap timing — exchanged in one tick, then both karts
get 1s immunity). In live races the immunity visibly fires 2-3x per race
(`blocked=` column above) with a "X IS SWAP-PROOF" event line.

### Determinism

`--fast=K` scales `physics_ticks_per_second` together with
`Engine.time_scale` so dt stays exactly 1/60 (orbital's proven recipe);
the swap hit-stop is tick-counted (`sdt = 0` for 5 ticks) and never
touches `time_scale`. Proof: full event-log diff, seed 11 —
`FAST==FAST tick-identical` (111 lines) and `REALTIME==FAST
tick-identical`.

## MUST list status

| MUST | status | evidence |
|---|---|---|
| 3-lap circuit | DONE | ~90u tabletop loop, LAP/FINISH log lines, LAP x/3 HUD |
| Auto-throttle karts | DONE | move.x steers, forward is automatic, move.y pull = brake/reverse |
| Drift-boost (hold B, boost ~ drift time, 2s cd) | DONE | `BOOST t=.. tier=1/2` lines; sparks recolor blue->orange->purple by charge; mini +2.5 / turbo +4.0 |
| Swap orbs, true position+velocity exchange | DONE | `soul()`/`apply_soul()` swap position, velocity dir+speed, heading, y/vy, corridor, hints, progress, lap-cross time; 3s cd; 1.2s-class lob (0.95s flight, ~8-12u range), generous 0.9u hit sphere |
| Golden orb | DONE | spawns every 40s AHEAD OF THE TRAILING kart (the comeback verb lands where it's needed); leaders can't claim it; homing throw swaps holder with the current leader; `GOLD_SPAWN/GOLD_CLAIM/SWAP golden=true` lines; used in 3/5 seed races |
| Checkpoints / scoring | DONE | 4 gate arches +1 each (pulse in scorer's color), finish order 5/3/2/1 on top; running score rows sorted by live race position |
| Results contract | DONE | `SWAPMEET_RESULTS {...}` passes `Minigame.report_finished` with zero warnings; placements = finish order, DNF by progress (timeout cap 170s); royalty per swap gaining >=1 place, grudge per swap out of 1st; highlights: cruelest pickpocket, golden victims, fastest lap; monument "The Pickpocket" at 5+ gaining swaps |
| Seeded bots (racing line + opportunistic throws) | DONE | pure-pursuit corridor line, drift on sustained corners, throws at lined-up karts (prefer those placed better), position-weighted shortcut usage; all randomness from per-bot RNGs derived from config.rng_seed |

## SHOULD list status

| SHOULD | status |
|---|---|
| Shortcut ramp | DONE — plank branch across the left cap, launch slab with chevron + trestle, real ballistic jump (`JUMP t=..` lines), saves ~1s; entry needs deliberate infield steering (racing-line traffic is not captured) |
| Windmill hazard | DONE — two candy-striped booms sweep the pinches (`KNOCK` lines, sideways shove + spin visual, 0.9s re-hit grace, non-lethal); Par's windmill.glb stands at each pinch, blades turning |
| Crown on leader | DONE — spinning gold crown + sparkle + gold ground halo on the unfinished leader; "X LEADS — AIM AT THE CROWN" event on lead change |

## Feel targets (the numbers I settled on)

Track: ~90u lap, 5.4u wide (3.7u at pinches), rubber rails. Kart:
TOP_SPEED 5.0, full-stick turn 2.55 rad/s -> ~2.0u turning circle
(you can U-turn inside the pinch), steering low-passed at 13/s for
chunk, velocity-direction grip 9.5/s normal vs 3.0/s in drift (the lag
IS the drift), wall bounce restitution 0.5 with a 2.0 minimum kept
speed (rails never stick), boom knock 7.0. Full-throttle screen
crossing ~7s; bot laps ~15s; humans ~20-30s -> 60-90s races, so the
40s golden spawn lands mid-race.

## Screenshot annotations (seed 11 unless noted)

- `shotsec_02` (t≈13s) — SWAPPED! MINT <-> BLUE: dual teleport beams in
  both colors on the bottom straight, tags flashing white, banner names
  in player colors, hit-stop frame.
- `shotsec_03` (t≈24.5s) — swap DURING a shortcut run: beams at the ramp,
  two karts queued on the launch slab, LAP 2/3.
- `shotsec_05` (t≈43.3s) — THE money shot: "GOLDEN SWAP! RED ROBS BLUE",
  four karts bunched at the bottom pinch, both beam pairs visible, boom
  arm crossing above.
- `shotsec_07` (t≈47s) — "RED WINS THE SWAP MEET!", all rows FIN,
  finished karts parading in a line past the checkered strip.
- moment-test `shotsec_02` — parked-kart scripted swap: freeze + beams +
  banner, captured 0.1s after impact.
- Kart closeup (crop of shotsec_05) — KayKit chars seated
  (Sit_Chair_Idle) on chunky bumper karts: Knight's sword out, Mage hat,
  crown + sparkles on the leader, identity rings readable from above.
- Whole-track readability: every full-view shot frames the complete
  circuit at 1280x720 from the fixed 3/4 camera — both pinches, ramp,
  gates, finish and all four name tags legible.

## Design decisions worth flagging

- **Leaders can't claim the golden orb.** In tight packs the leader
  reaches any spawn first and a leader-held golden is a dead item (it
  targets the leader). The pickup ignores P1 (announced in the spawn
  event text); if a swap hands its holder the lead, the holder spends it
  as a normal lob instead of hoarding.
- **Gate points are monotone through swaps**: being swapped forward
  fast-forwards your gate counter WITHOUT points; swapped backward, you
  re-drive the stretch without double-earning.
- **Shortcut = earned, announced catch-up**: bots pick it
  position-weighted (P1 20% .. P4 90%); no hidden speed compensation
  anywhere.

## Known issues / notes

- Lap splits are positional (see above) — a feature of true position
  swaps, noted so nobody reads 0.1s laps as a bug.
- Swap-orb throws are forward-arc only; the leader mostly cannot hit
  anyone (everyone is behind) — intended: first place is a target, not
  a shooter.
- The two ping-pongiest bots can trade 6-8 swaps across a race
  (immunity + 3s cd keep it from degenerating further); reads as party
  chaos in practice.
- `--fast` runs mute the master bus; frame-indexed `--shots` captures
  are fps-dependent (VerifyCapture counts rendered frames) — the
  `--shotsec` wall-clock variant was added for precisely-timed swap
  frames and is what the annotations use.
- Windmill blade decor at high scale can visually clip the entry apron
  planks from some angles; cosmetic only.

## Wishes (assets_raw not available in worktrees)

- Kenney particle sprites for drift sparks / teleport bursts (currently
  unshaded sphere meshes).
- A dedicated whoosh + teleport "zap" sound; currently sink/bumper/putt
  from assets/audio stand in (they read fine, but a signature zap would
  sell the trade harder).
- Kenney UI 9-slice panel for the score rows.
- A proper toy kart model (karts are boxes/torus/cylinders in player
  colors; they read well from the party camera but a modeled kart would
  be lovelier).
