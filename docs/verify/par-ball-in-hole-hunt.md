# PAR — "ball visibly enters the hole without registering" — REPRO HUNT (miss)

Oldest open playtest item, tracked in `docs/verify/playtest-bugs-VERIFY.md` §BUG 4b
("I put the ball in but it made me go again" — INVESTIGATED, OPEN ITEM). This
lane's job: reproduce it deterministically headless, root-cause it, fix in the
DETECTION layer only. **Result: NOT reproduced after ~200 scripted putts across
a hypothesis-driven grid.** Documented here so the next hunt starts warm. Zero
source files were touched (see §6) — this is a pure investigation.

Engine: Godot 4.6.2 (Windows), worktree
`.claude/worktrees/agent-a54762d51bb28b475`. Cold-worktree import gate run
twice per protocol (first pass crashed mid font-reimport as expected, second
pass clean — zero SCRIPT ERROR/Parse Error; the only `ERROR:` lines are
pre-existing `assets/models/meshy/cosmetics/*.jpg` load failures and the
already-documented `grounds.gd` CSG-normals warning, both unrelated to Par and
present before this lane touched anything).

## 1. The geometry, read before any shot was fired

Frozen invariants (`VERIFY-PARV3.md`, `scripts/course.gd`, `scripts/ball.gd`,
untouched):
- `Course.MAGNET_RADIUS = 0.36`, `MAGNET_MAX_SPEED = 5.0`, `MAGNET_FORCE = 26.0`
  — applies `apply_central_force` toward (cup.x, ball.y-0.5, cup.z) whenever
  flat XZ distance < 0.36 **and** speed < 5.0 **and** `ball.y > -0.2`.
- `CupArea` trigger: `CylinderShape3D` **radius 0.27**, height 0.3, centered
  0.32 below the local green surface — confirmed **identical across all five
  courses** (fairway/dogleg/green/the_gauntlet/widows_walk all declare
  `radius = 0.27` for `cup_shape`).
- The physical hole (what the ball can actually fall through): a
  `CSGCylinder3D` subtraction, **radius 0.3**, cut clean through the green's
  full floor thickness on every course (verified in all five `.tscn` files —
  fairway/dogleg/green/the_gauntlet use `operation=2 radius=0.3` at y=-0.2
  through a 0.4-thick floor; widows_walk's elevated green uses the same 0.3
  radius at height 0.8 through its 0.7-thick raised `GreenPlate`, still a
  clean through-cut).
- `Ball` sphere radius 0.15; `STOP_SPEED = 0.12`; `linear_damp = 0.5`.

So there are **three different radii in play** (0.27 trigger / 0.30 physical
hole / 0.36 magnet capture) plus a `y > -0.2` cutoff on the magnet — exactly
the kind of mismatch that could hide a "looks in, isn't in" seam. The prior
investigation's suspects were: (a) a ball resting on the lip inside magnet
range but never crossing the 0.27 trigger, (b) a gutter-delivered ball placed
too close to the cup, (c) a turn-advance/sink-registration race.

## 2. Method — deterministic, controlled putts without touching shared state

No `--user-data-dir` CLI flag exists in this Godot 4.6.2 build (checked
`--help`; not listed), so the shared `%APPDATA%\Godot\app_userdata\ILL WILL\
party_setup.json` (seat 0 = human, seats 1-3 = bot, per the existing
VERIFY-BOTMIX config) could not be safely sandboxed per-process without
risking a concurrent sibling worktree's run — **that file was never modified**
(read-only checked, confirmed byte-identical before/after this whole hunt).

Instead: `--rounds=1` puts a 2-player match straight into the CHAOS round
(`GameState.is_chaos_round()` is true whenever `round_num == rounds_total`,
and `rounds_total=1` → chaos-only, per `game_state.gd`). Chaos's
`round_manager.notify_stroke()` resets `_rest_timer` on every stroke and only
advances the turn once `CHAOS_TURN_GAP` (1.5s / 90 physics ticks) has elapsed
**since the last stroke** — so firing a fresh `--physputt=power,angle,tick`
on the SAME ball within 90 ticks of the previous one keeps `current_player()`
pinned to seat 0 indefinitely (`putt_controller.ball` never reassigns to the
bot seat), letting a rough shot + a precisely-calibrated fine approach both
land on seat 0's ball with full determinism and zero bot interference. Seat 1
(bot) plays its own game in the background once its turn actually opens; it
never touches seat 0's ball on fairway's 8m-wide course.

Calibration: `Ball.putt()` is a straight velocity **override**, not additive,
so a second `debug_putt` mid-flight cleanly redirects the ball from wherever
it currently sits — no need to wait for full rest between shots. `--traceall`
(PTRACE, 0.1mm/tick) gave exact position + a `SUNK`/`DEAD`/etc. state marker
per ball per physics tick, so every test's fate is legible line-by-line: does
`b.y` dip negative (real fall) and does `BALL_SUNK p=0` print, or does the
ball stay at `y=0.15` (clean miss) or bounce (lip-out) without ever printing
`BALL_SUNK`.

Reference command shape used for ~all 100 runs (fairway, seed 1, players 2,
tee0 → cup line = angle **-1.1839°**, computed from `tee_slots[1]=(-0.5,1.6)`
and `cup_position()=(0,-22.6)`):

```
godot --headless --path . -- --skipmenu --course=fairway --seed=1 --players=2 \
  --rounds=1 --physputt=15,-1.1839,40,<P2>,<A2>,120 --traceall --quitafter=1300
```

Shot 1 (fixed: power 15, angle -1.1839, tick 40) reliably parks the ball at
`(-0.27, 0.15, -9.44)` by tick 120 — ~13.16m short of the cup. Shot 2 (`P2`,
`A2`, tick 120) is the swept variable: `P2` controls arrival speed at the cup,
`A2 = -1.185 + delta` controls lateral offset (delta° × 13.16m ≈ offset in
meters — e.g. 1.567° ≈ the 0.36m magnet radius, 1.306° ≈ the 0.30m hole
radius).

## 3. What was swept (~200 scripted putts, ~100 distinct final-approach configs)

| Sweep | Axis | Range | Result |
|---|---|---|---|
| Dead-center power | P2 (offset 0) | 5.0 → 15.0 m/s (17 values, incl. 0.05-1.0 step near threshold) | Clean binary: **<6.75 → stops short at y=0.15** (never dips); **≥6.75 → always sinks**, at EVERY speed up to 15 m/s (well above `MAGNET_MAX_SPEED`). No missed-sink at any speed dead-center. |
| Off-center, slow (magnet-eligible) | angle delta | -2.0° → +2.0° (0.15-0.3° steps), P2 ∈ {6.9, 7.2} | Sinks for \|delta\| ≤ ~1.55° (offset ≤ ~0.35m, i.e. inside `MAGNET_RADIUS`); clean miss (never dips, y stays 0.15) for \|delta\| ≥ 1.6° (offset ≥ ~0.37m). Transition tracks the magnet radius almost exactly. |
| Off-center, fast (magnet-disabled, speed>5) | angle delta | 0° → 1.57° (0.2-0.25° steps), P2=13 | Sinks reliably for delta ≤ 0.85°; **delta=1.0-1.2° produced a visible lip-out bounce** (see §4) but not a missed-sink; delta ≥1.4° is a genuine graze that gets curved by the magnet mid-roll and continues past (still never dips below y=0.12, so not a "looks sunk" case) or is redirected far off-green and legitimately teleported home by the existing "WENT EXPLORING — RETURNED" mechanic (also not a bug — that's the intended OOB-recovery path, just triggered from an unusual angle). |
| Hole-radius chord boundary | angle delta | 1.15°, 1.25°, 1.28°, 1.29°, 1.30°, 1.31°, 1.32°, 1.35°, 1.40°, 1.42°, 1.44° (offset 0.26-0.33m, straddling the 0.30 hole radius) | P2=5.5 (below reach threshold): all clean short-misses. **P2 ∈ {7, 9}: sinks at every single delta tested**, including 0.01-0.02° resolution steps right at the theoretical hole-radius edge. No gap found. |
| Magnet-radius boundary, fine | angle delta | 1.6°, 1.7°, 1.8°, 1.9° both signs (offset 0.37-0.44m) | All: clean miss, `minY=0.15` (never dips at all) — ball passes just outside the hole with zero interaction, consistent with offset > hole radius (0.3) meaning the ball's own contact point never loses floor support. |

Every "sunk=1" case printed `BALL_SUNK p=0 round=1` and showed `SUNK` in the
very next PTRACE tick after `y` crossed roughly -0.02 to -0.03 (the CupArea's
overlap threshold) — the signal never lagged by more than the expected single
physics tick, and it never failed to fire once the ball was actually falling.

## 4. The one interesting near-miss found (not the bug)

At `P2=13` (fast), `delta≈1.0-1.2°` (offset ≈0.29-0.31m, right at the hole's
physical rim), the ball's `y` **did dip below 0.15 twice** (down to 0.121,
0.132, 0.121) as it crossed the rim, then **bounced up to 0.158-0.173** —
clearly above resting height — before settling back to 0.15 and rolling away,
deflected sideways, never sinking:

```
t=248 y=0.1492  t=250 y=0.1207  t=253 y=0.1210 (second dip)
t=255 y=0.1585  t=259 y=0.1729 (bounce, ABOVE normal rest height)
t=266 y=0.1500  (settled, rolling away, no BALL_SUNK)
```

This is a real physical interaction with the CSG hole's collision rim (the
`Geo` CSGCombiner3D has `use_collision=true`, so the boolean-subtracted rim
is an actual collision surface a fast ball can clip and deflect off) — a
**lip-out**, the expected minigolf outcome for a ball hit too hard to catch
the edge. It never came close to the depth needed to enter `CupArea`'s
vertical band (needs `y ≤ ~-0.02`; this bottomed out at `y=0.121`, a 0.03m dip
against gravity) and it never visually reads as "in the hole" (the visible
black cup liner sits at `y=-0.47`). Logged here as the sweep's most
interesting artifact, not a repro.

## 5. What was NOT covered (honest gaps)

- **Steep-angle / elevation drops.** `widows_walk`'s cup sits on a raised
  green (`cup_height()=0.3`); its hole geometry was read and confirmed to be
  a clean through-cut (same pattern as the flat courses), but **no shot was
  actually fired there** — a fresh tee/cup calibration for that course's
  ramp+bridge layout would cost real time and wasn't reached this run.
- **Gutter delivery (`the_gauntlet` only).** Both authored gutters
  (`GutterA`→(5.8,-4.6), `GutterB`→(6.0,-5.4)) deliver 1.5-1.75m from that
  course's cup (7.5,-5) — not "atop" it, so the specific suspicion from BUG
  4b's writeup doesn't fire with current course data. **Latent risk noted for
  the record:** `course.gd:_ready()` defaults an untagged gutter's target to
  `cup_position()` verbatim (`area.get_meta("target", cup_position())`) — a
  future gutter authored without an explicit `target` metadata would deliver
  a ball to the exact cup XZ, which is untested territory. No shot fired
  through an actual gutter this run.
- **Trap-cup proximity.** A powered trap (spinner/boost/moving_wall) placed
  near the cup could in principle re-strike the ball at the exact moment it's
  crossing the rim, altering the fall in a way a clean rim doesn't. Not
  tested — this run used `--physputt` with no `--autobuild`, so no traps
  existed on the course at all.
- **True online/multiplayer timing.** The "frame-window race between the
  sink check and scoring state" was reasoned through (`Ball._physics_process`
  zeroing velocity and emitting `came_to_rest` vs. `CupArea.body_entered`
  landing on a different tick) but never observed to matter in ~100 configs:
  `BALL_SUNK` consistently printed the tick after the ball's `y` crossed the
  overlap threshold, and the ball was still visibly moving (not yet
  `is_stopped()`) at that instant in every logged case, so
  `round_manager._all_at_rest()` never had a window to fire early. This
  reasoning was not stress-tested against actual host/guest network latency
  (`estate/procession/... `net_session.gd` etc.) — out of scope for a single
  headless process.
- **Human input feel.** Same limit already on file for every other Par hunt
  in this repo (`par-v4-wave1-VERIFY.md` §7/§8): no headless harness injects
  a real mouse drag or analog stick, so a genuinely mis-timed human release
  (e.g. releasing mid-drag exactly as the ball crosses the rim, or a
  double-click racing two putts) cannot be ruled out from this machine.

## 6. Repo state

Zero `.gd`/`.tscn` files touched — `git status --short` shows only the
expected `.import` cache churn from the mandated cold-worktree import gate
(run twice per protocol), no tracked script/scene diffs, no new untracked
files. `tools/run_receipts.ps1 -Quick` → **PASS (2/2)**: topology
`BOARDGRAPH checksum=b269c570` + `BOARDGRAPH_OK`, and the canonical seed-7
3-night match md5 `ccd25c2c82ad7e744595837ca949a8df` matching
`VERIFY-BOARD.md`'s frozen value exactly — confirming nothing shared drifted
during this investigation, as expected since no code was changed. No PARV3
receipt diff is applicable for the same reason: nothing frozen was touched.

## 7. Verdict

**Did not reproduce headless.** The cup-detection layer (CupArea trigger +
magnet + `mark_sunk`/`on_ball_sunk` + `round_manager` turn resolution) held
up across a fine, hypothesis-driven sweep of the exact geometry seams that
looked most likely to hide this bug (magnet-radius boundary, hole-radius
boundary, fast vs. slow arrival, dead-center vs. every fractional degree of
offset out to a clean miss). The boundaries are sharp — either the ball
never dips below `y=0.15` (clean miss) or it sinks correctly on the very next
tick after crossing into the fall — with the single exception of a physically
plausible lip-out bounce (§4) that never reads as "entered the hole."

This is consistent with the prior investigation's own framing: the remaining
plausible vectors (gutter delivery without a target, a trap re-striking the
ball at the rim, elevated-green geometry, or genuine network jitter) all sit
outside what a fairway-course, no-traps, single-process headless harness can
exercise. **Recommend the couch**: next time Andrew (or Alex) sees this live,
capture the course id, seed if known, and — ideally — a `--traceall` log from
that exact session (or at minimum the approximate stroke count / whether
traps were on the board / whether it was a gutter-assisted approach). Any one
of those would let the next hunt replay the exact conditions deterministically
instead of searching the whole parameter space cold again.
