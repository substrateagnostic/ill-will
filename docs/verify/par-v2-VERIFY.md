# PAR FOR THE CURSE v2 — "minigame cut" VERIFICATION

Spec: `docs/specs/par-v2-minigame-cut.md`. Engine: Godot 4.6.2 (Windows).
All commands run from the worktree root. Screenshots live in `verify_out/`
and were read + critiqued (notes inline). Every headless run reported
`err=0` for `SCRIPT ERROR / Invalid call / null instance / Nil`.

Import pass (required after adding files), zero script/parse errors:

```
godot --headless --editor --import --quit --path .
```

Dev harness note: `verify_capture.gd` gained one inert dev flag, `--tracepos`
(prints every ball's position each 6 frames headless) used to tune the
bank/route geometry. All pre-existing args still work: `--autoplay`,
`--autobuild`, `--shots`, `--placetest`, `--forcetrap`, `--seed`, `--rounds`
(new semantics below), plus the new `--course=fairway|dogleg|green`.

---

## 1. The three courses exist and are picked by seeded RNG

`GameState.course_id` is chosen once per match from `["fairway","dogleg",
"green"]` via the seeded RNG, overridable with `--course=`. main instantiates
the chosen scene at runtime (`scenes/courses/<id>.tscn`); placement, camera,
tee spawns, gravestone clamping and the cup magnet all query the `Course`
base class (`scripts/course.gd`) — no hardcoded single-course constants remain.

```
for S in 1 2 3 5 7 11; do
  godot --headless --path . -- --skipmenu --seed=$S --players=2 --rounds=1 --quitafter=40 | grep "COURSE selected"
done
```
Result: seed 1/2/3 -> fairway, seed 5/7 -> dogleg, seed 11 -> green. All three
reachable; `randi_range(0,2)` is uniform.

### Aim-shot screenshots (course shape + aim arrow, light accretion)
Command pattern (per course, 4 players, round-1 build via `--autobuild`):
```
godot --path . -- --skipmenu --course=<C> --seed=3 --players=4 --rounds=2 \
      --autobuild --aimshow=2.6,<angle>,760 --shots=765,820 --outdir=verify_out/aim_<C>
```
- `verify_out/aim_fairway/shot_0765.png` — straight lane, aim arrow up the
  fairway toward the flag; traps (windmill/ramps/sand/bumper) placed. Good.
- `verify_out/aim_dogleg/shot_0765.png` — L-shape reads clearly: tee at south,
  aim arrow pointing straight north, the purple 45° **corner bank** at the
  elbow, flag on the east leg. Camera frames the whole L. Good.
- `verify_out/aim_green/shot_0765.png` — 12x12 plaza, tee SW / flag NE, the two
  raised **humps** (Kenney `obstacle-block` / `obstacle-diamond` GLBs) breaking
  the SW–NE diagonal. Critique: the flat Kenney tiles are scaled into low
  slabs to act as humps (see design note §5); they read as obstacles, not
  literal "hills", because no ramp/hill GLB ships in-repo.

### Sunk putt via autoplay (per course) — `BALL_SUNK` = ball fell in the cup
- **Fairway** (13m straight): `--autoputt=13,-1.5,20` -> `BALL_SUNK p=0 round=1`.
  The lane needs near-max power; angle -1.5 corrects the tee-slot x offset so
  the ball centers the cup instead of rimming out. Screenshot (post-sink, RED
  removed from lane): `verify_out/fw_sink/shot_0470.png`.
- **Dogleg** (bank mandatory): `--autoputt=13,0,20` (straight north) ->
  `BALL_SUNK p=0 round=1`. Trajectory trace (`--tracepos`) shows the ball run
  north at x≈-0.3 to z≈-3.5, **bank east off the 45° wall**, then roll along to
  the cup at (4.5,-4.5) and drop (y -> -0.58). The cup is NOT visible in a
  straight line from the tee (blocked by the vertical-leg east wall), so this
  is a genuine bank sink. Screenshot: `verify_out/dl_sink/shot_0235.png`
  (RED rounding the corner toward the cup).
- **Green** (12x12, humps): one putt can't cross 14m through the humps, so a
  **2-shot L-route** sinks: shot 1 north up the west edge (`12,0`) rests RED at
  (-4.8,-4.2); shot 2 aimed at the cup (`12,-85.5`) -> `BALL_SUNK p=0 round=1`.
  Command:
  ```
  godot --headless --path . -- --skipmenu --course=green --seed=2 --players=2 \
    --rounds=2 --autobuild --autoplay="12:0,12:0,12:-85.5,12:-85.5,11.5:-86,11.5:-86,12.5:-84.5,12.5:-84.5" --quitafter=2600
  ```
  Screenshot (green in play, routing to NE cup): `verify_out/gr_sink/shot_1080.png`.

### Full 4-round match sim per course -> MATCH_OVER, zero SCRIPT ERROR
```
godot --headless --path . -- --skipmenu --course=<C> --seed=4 --players=4 \
      --rounds=4 --autobuild --autoplay="<180-shot varied list>" --quitafter=30000
```
| Course  | Result       | Deaths | Chaos-round deaths | Errors |
|---------|--------------|--------|--------------------|--------|
| fairway | MATCH_OVER champ=MINT | 9  | 3 | 0 |
| dogleg  | MATCH_OVER champ=GOLD | 15 | 3 | 0 |
| green   | MATCH_OVER champ=RED  | 13 | (round-4 deaths present) | 0 |
All three complete the 3 normal rounds + chaos round and emit the module
`finished(results)` dictionary after the victory flyover (`FLYOVER_DONE`).

---

## 2. Round structure: 3 + CHAOS

`GameState.rounds_total` default is now **4** (3 normal + chaos); the final
round (`round_num == rounds_total`) is always chaos. `--rounds=N` still works:
N-1 normal + 1 chaos (`--rounds=1` = chaos only, used by the clean-course
tests above). Chaos round:
- No draft/build — the accreted course is played as-is.
- No rest-waiting: `RoundManager` chaos mode advances the turn 1.5s after each
  stroke (`CHAOS_TURN_GAP`), 10s shot clock per turn (`CHAOS_SHOT_CLOCK`,
  auto-skip), 75s round hard cap (`CHAOS_ROUND_TIME`, unsunk = DNF).
- Powered traps (windmill/crusher/fan) run at 1.6x via `Trap.speed_scale`
  (`course.set_trap_speed_scale(1.6)`).
- Golden-hour lighting shift + "CHAOS ROUND" banner + jingle sting.
- Double points `10/6/4/2` (2P `6/2`) via `CHAOS_POINTS_TABLE`.
- Chaos deaths add a "CHAOS CLAIMED {name}" highlight.

### Chaos screenshot: golden light + banner + >=2 balls moving
```
godot --path . -- --skipmenu --course=fairway --seed=8 --players=4 --rounds=1 \
      --autoplay="11:-2,11:2,11:-5,11:5" --shots=234,258,282,306,330 --outdir=verify_out/chaos3
```
`verify_out/chaos3/shot_0258.png` — warm golden-hour lighting, the
"CHAOS ROUND — NO WAITING — ALL LIVE" banner + "CHAOS ROUND" label, and **two
balls simultaneously in motion**: RED near the cup and BLUE mid-lane, each
trailing motion particles. Confirmed with `--tracepos`: frames ~234–420 have
>=2 balls with per-sample displacement > 0.12m. Critique: the render loop runs
faster than the 60Hz physics tick, so the multi-ball overlap window is short;
frame 258 lands squarely inside it. `shot_0282.png` is an equally-good alt.

---

## 3. Double hazard density

`TRAPS_PER_BUILD = 2`: each player drafts+places two traps per build phase
(pick-1-of-3, place, pick-1-of-3, place). Cursed-luck and grudge picks apply to
the **first** pick only. Each placement gets its own 25s build clock. If the
course is saturated (no legal spot for the footprint anywhere,
`PlacementController.has_valid_placement()`), the placement is auto-skipped
silently.

### Density screenshot: round-3 course, >=12 traps
```
godot --path . -- --skipmenu --course=fairway --seed=6 --players=4 --rounds=4 \
      --autobuild --autoplay="<120-shot list>" --shots=3500,4500,5500,6500,7500,8500 --outdir=verify_out/density
```
`verify_out/density/shot_5500.png` — label reads **ROUND 3 / 4**; the fairway
is packed with well over 12 hazards (wall, spike strip, black hole, ~3 sand
pits, crusher, 2 ramps, 2 bumpers, windmill) plus death gravestones, and the
scoreboard shows accumulating royalties (RED/BLUE †6). By round 3 the two prior
build phases alone placed 4 players x 2 traps x 2 rounds = 16.
`shot_6500.png` corroborates from the diorama's leaned angle.

---

## 4. Results contract

Unchanged shape; chaos points flow into the same totals; chaos death adds the
"CHAOS CLAIMED {name}" highlight. `finished(results)` still emits placements,
points, currency_events (royalty/grudge), highlights, monuments. Standalone
menu->game flow preserved (`--skipmenu` exercises `menu._start()` ->
`main.tscn` -> runtime course instantiation).

---

## Frozen invariants respected
- Ball physics / damping / cup magnet values / putt drag mapping: untouched
  (only the cup-magnet code MOVED verbatim into the `Course` base class).
- `trap_base.gd` AnimatableBody3D `sync_to_physics` fix preserved (disabled on
  ghostify, re-enabled on solidify) — not regressed.
- GDScript: no `:=` inference from untyped Array/Dict elements; physics-callback
  state changes still deferred.

## Exit-criteria checklist
- [x] Each course: aim screenshot + autoplay sunk putt + full 4-round match to
      MATCH_OVER, zero SCRIPT ERROR.
- [x] Chaos screenshot: golden lighting + banner + >=2 balls moving.
- [x] Dogleg bank-shot sink via autoplay (power 13, angle 0; documented above).
- [x] Round-3 density screenshot with >=12 traps.
