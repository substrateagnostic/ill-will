# PAR FOR THE CURSE v3 — VERIFICATION

Engine: Godot 4.6.2 (Windows). All commands run from the worktree root. Frozen
invariants respected: **ball putt physics / damping / cup magnet / putt-drag
mapping untouched** (only runtime `linear_damp` toggles, same technique the sand
pit already used, and position-driven AnimatableBody motion). Screenshots live in
`verify_out/parv3/` (gitignored) and were read + critiqued inline.

Import pass after adding files — zero script/parse errors:
```
godot --headless --editor --import --quit --path .
```

Playtest verdict honored: **TRAPS_PER_BUILD stays 1** (density comes from TYPES +
BIGGER COURSES, not more placements).

---

## 1. Eight new trap TYPES (+3 cursed variants)

Catalog `scripts/trap_catalog.gd`; scripts `scripts/traps/*_trap.gd`; scenes
`scenes/traps/*.tscn`. All follow the house pattern (Trap base, `Accent*` meshes
for author color, ghost/solidify, `speed_scale` where powered). Per-trap
screenshot (4 copies each forced onto the fairway):
```
godot --path . -- --skipmenu --course=fairway --seed=2 --players=4 --rounds=2 \
      --autobuild --forcetrap=<id> --shots=760 --outdir=verify_out/parv3/trap_<id>
```

| id | scene | behavior | screenshot |
|----|-------|----------|-----------|
| `portal_pair` | portal.tscn | two linked rings, enter one/exit other keeping speed; **two-click placement** (locks A, then B) | `trap_portal_pair/shot_0760.png` |
| `ice_patch` | ice.tscn | near-zero friction disc (runtime `linear_damp=0.02`, restored on exit) | `trap_ice_patch/shot_0760.png` |
| `boost_pad` | boost.tscn | directional speed strip, scrolling chevron arrows show the shove dir | `trap_boost_pad/shot_0760.png` |
| `magnet_post` | magnet.tscn | non-kill attractor pole with a visible ground pull-ring | `trap_magnet_post/shot_0760.png` |
| `tunnel` | tunnel.tscn | Kenney `tunnel-narrow` GLB + side-walls/roof collision: passes a ball through the bore, blocks putts over/into the sides | `trap_tunnel/shot_0760.png` |
| `moving_wall` | moving_wall.tscn | AnimatableBody (`sync_to_physics`) sliding on a visible track; ghost-disable rule from trap_base | `trap_moving_wall/shot_0760.png` |
| `trampoline` | trampoline.tscn | flings the ball up + forward on contact (per-ball cooldown) | `trap_trampoline/shot_0760.png` |
| `spinner` | spinner.tscn | flat AnimatableBody cross at ground level, swats rolling balls | `trap_spinner/shot_0760.png` |

Cursed variants (params only, drafted via the last-place / grudge path):
`express_wall` (rate 3.1, travel 1.5), `mega_magnet` (pull 13, radius 3.4),
`buzzsaw_spinner` (spin 6.5). All three place cleanly (`--forcetrap=<id>`),
confirmed 2 placements each in a round-1 build.

Multi-endpoint placement is generic: `Trap.endpoint_count`,
`active_placement_pos()`, `move_placement()`, `advance_placement()`,
`footprint_points()`. `PlacementController` (mouse click, `debug_place_scan` for
bots/autobuild, `has_valid_placement`) all honor it, so portals place headless in
`--autobuild`/`--parbots` runs with no errors.

## 2. Bigger courses + the_gauntlet

Three existing courses enlarged ~40-49% in play area (retuned
`play_rects`/`tee`/`cup`/walls/camera via the Course interface):
- fairway: 5.7×16.7 → 6.6×20.6 (+43%), added two dark chicane banks.
- dogleg: legs widened to ~6.8 and lengthened, cup at (6.3,-5.9); bank shot still
  mandatory (WallEV blocks the tee→cup sightline).
- green: 12×12 → 14.4×14.4 (+44%), two bigger Kenney humps on the diagonal.

New large course **the_gauntlet** (`scenes/courses/the_gauntlet.tscn`): a winding
S / staircase (south leg → middle riser → north leg to the cup), built from the
committed Kenney GLBs — `castle` (backstop by the cup), `structure-windmill`
(landmark), two `tunnel-narrow` covered passages (bore collision), and
`obstacle-block`/`obstacle-diamond` humps. Added to `COURSE_IDS`, so the seeded
per-match pick includes it and `--course=the_gauntlet` works:
```
for S in 1 2 4 5 6 7 8 10 13 17 20 25; do godot --headless --path . -- --skipmenu \
  --seed=$S --players=2 --rounds=1 --quitafter=40 | grep "COURSE selected"; done
# -> S2/S4 = the_gauntlet, plus fairway/dogleg/green. All four reachable.
```
DOF far distance raised 19→34 in `scenes/main.tscn` so the larger courses render
sharp (content was falling past the diorama blur plane).

Aim screenshots (arrow + light accretion), one per course:
```
godot --path . -- --skipmenu --course=<C> --seed=3 --players=4 --rounds=2 \
      --autobuild --aimshow=2.6,0,900 --shots=905 --outdir=verify_out/parv3/aim_<C>
```
`aim_fairway/…`, `aim_dogleg/…`, `aim2_green/…`, `aim2_the_gauntlet/shot_0905.png`
— all read clearly, sharp, well framed, new traps visible.

### Aim + sink via autoplay (all four)
Full `--parbots` matches (bots aim at the cup, sink over strokes):
```
godot --headless --path . -- --skipmenu --course=<C> --seed=4 --players=4 \
      --rounds=4 --parbots --quitafter=90000
```
| course | sinks | deaths | errors | MATCH_OVER |
|--------|-------|--------|--------|-----------|
| fairway | 8 | 3 | 0 | champ=BLUE, FLYOVER_DONE |
| dogleg | 8 | 3 | 0 | (rounds 1-2 fully sunk; slow) |
| green | 7 | 2 | 0 | (rounds 1-2 fully sunk; slow) |
| the_gauntlet | via gutter | 4 | 0 | **champ=BLUE, FLYOVER_DONE** |

The winding gauntlet is not straight-sinkable, so its intended sink is the gutter
shortcut — proven deterministically:
```
godot --headless --path . -- --skipmenu --course=the_gauntlet --seed=1 --players=2 \
      --rounds=1 --autoplay="13:-90,13:-90,5:-77,5:-77,4:-76,4:-76,4:-78,4:-78,3:-75,3:-75"
# GUTTER: RED took the channel -> near cup
# GUTTER_DONE: delivered near cup at 5.8,-4.6
# BALL_SUNK p=0 round=1
```

## 3. Chaos round — TRUE overlap

`RoundManager.is_turn_ready()` in chaos no longer waits for the ball to settle;
`main._bot_tick` fires ~0.2s after a turn opens in chaos (vs 1.5s + rest in
normal). Turns rotate every `CHAOS_TURN_GAP` (1.5s) while balls keep rolling, so
2-4 balls are commonly live at once. A per-frame counter logs peaks:
```
# bots:     godot --headless … --course=fairway --seed=11 --players=4 --rounds=1 --parbots
#           CHAOS_CONCURRENT_PEAK movers=3 frame=402  (sustained 405-444)
# autoplay: godot --headless … --course=fairway --seed=8 --players=4 --rounds=1 \
#             --autoplay="11:-3,11:3,11:-6,11:6,10:-4,10:4,12:-5,12:5,11:0,11:2"
#           CHAOS_CONCURRENT_PEAK movers=4 frame=429
```
Screenshot proof — **`verify_out/parv3/chaos2/shot_0412.png`**: golden-hour
CHAOS ROUND, `movers=3` at that exact frame, RED/BLUE/GOLD balls all mid-lane with
motion trails, no banner. Both the bot driver AND the autoplay harness overlap.

## 4. OOB as mechanic — adventure gutters (the_gauntlet only)

`Course` gained a `ball_entered_gutter(body, target)` signal wired from any
`Gutters/` Area3D (with a `target` metadata point). the_gauntlet ships **two**
marked gutter mouths at overshoot spots (east off the south leg; north off the
riser), each with a gap in the wall + a cyan chute. `main._on_ball_gutter` freezes
the ball, sweeps it along a two-hop detour tween, and drops it back on the green
near the cup (`ball.enter_gutter`/`exit_gutter`, `in_transit` guard). Everywhere
else the existing return-home behavior is unchanged.

Round-trip proof (log + screenshot `verify_out/parv3/gutter/shot_0175.png`,
"RED HIT THE ADVENTURE GUTTER!"): a hard east putt from the tee overshoots the
junction at x≈-0.6, enters gutter A, and is delivered to (5.8,-4.6) ~1.7 m from the
cup — then a short putt sinks (see §2).

## 5. Existing CLI args still work

`--skipmenu --seed --rounds --players --course --forcetrap --autobuild --autoplay
--aimshow --shots --tracepos --parbots --outdir` all exercised above. `--placetest`
also still drives placement end-to-end (`PLACETEST drag t=0.25…1.00` →
`PLACETEST confirmed`) — but only when the driven seat isn't a saved bot: the
machine's `user://party_setup.json` marks seats 1-3 as bots (per VERIFY-BOTMIX), so
in a default run the first builder (a bot) auto-places before the placetest drag
finishes. That is pre-existing environment behavior, not a v3 change; with
party_setup set aside (all-human) placetest confirms cleanly.

## Exit-criteria checklist
- [x] Eight new trap types, per-trap screenshot on a course, house patterns + 3 cursed.
- [x] All four courses: aim screenshot + sink via autoplay.
- [x] Chaos true overlap: screenshot with 3+ balls mid-motion + concurrency log (peak 4).
- [x] Gauntlet adventure-gutter round-trip proof (log + screenshot + resulting sink).
- [x] Full 4-round match to MATCH_OVER on the_gauntlet, zero SCRIPT ERROR.
- [x] Import pass clean; frozen putt-feel constants untouched.
