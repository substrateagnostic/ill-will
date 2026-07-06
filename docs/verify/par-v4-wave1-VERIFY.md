# PAR v4 WAVE 1 — EMBODIED GOLF — VERIFICATION

Engine: Godot 4.6.2 (Windows). Commands run from the worktree root. Spec:
`docs/superpowers/specs/2026-07-06-par-v4-embodied-golf-design.md` (wave 1 only:
embodied third-person shots; chaos still plays the v3 way, no griefing).
Screenshots live in `verify_out/parv4/` (gitignored) and were read + critiqued
inline. Import pass after adding scripts — **zero script/parse errors**:

```
godot --headless --editor --import --quit --path .
```

Owner camera correction applied mid-build (binding over the spec's camera
section): the shot camera is a **SMITE-style skill-shot frame**, not a TPS
over-shoulder cam — high pitch (~53 deg), golfer as bottom-edge reference, aim
line + lane + traps + cup readable in one glance.

---

## 0. What shipped

- `scripts/player_avatar.gd` — Caddy promoted to `PlayerAvatar`
  (CharacterBody3D, capsule r 0.35 h 1.4, KayKit rig per echo_chamber/fighter,
  identity ring, `Walking_A`/`Running_A`/`2H_Melee_Idle` loops). Layer 2 +
  collision exceptions against every ball = **the sim never sees avatars**
  (wave-2 griefers will selectively re-enable ball contact).
- `scripts/avatar_shot.gd` — per-turn state machine: WALK (3.0 m/s, `WALK_CAP`
  1.4 s then teleport-dolly the remainder, `ARRIVE_DIST` 0.8) → ADDRESS
  (`2H_Melee_Idle`, avatar orbits the ball to `ball - aim*0.55` as aim turns) →
  CHARGE (hold-release, 1.2→13 m/s over 1.1 s ping-pong, on-screen POWER meter)
  → SWING (`2H_Melee_Attack_Slice`, **`debug_putt(power, angle)` fired exactly
  11 physics ticks in = the 0.18 s contact frame**). Angle formula
  `rad_to_deg(atan2(-dir.x, -dir.z))` (spec, = bot formula).
- Per-device aim (spec §1): `-3` cursor-on-plane + LMB; `-4`
  `PlayerInput.get_aim_dir` + A/LMB; pads + keyboard halves `get_move` heading
  (camera-relative) + A. No new PlayerInput API.
- `scripts/camera_rig.gd` — `Mode.{DIORAMA, SHOT}`; SHOT = 2 m back / 11.5 m up
  / look 6 m down the aim line; walk phase anchors on the striding golfer and
  hands off to the ball anchor at address (no pop); blends 0.6 s in / 0.5 s out
  at contact; near-DoF disabled in SHOT. Chaos rounds stay DIORAMA (overlap
  readability). shake/focus_on/flyover untouched.
- Bots: same seeded `(power, angle)` per stroke (rng draw parity), gated on
  arrival, fired through the swing. `--autoplay`/`--autoputt` default path
  bypasses the walk entirely (unchanged v3 semantics).
- v3 drag putt intact behind `putt_controller.drag_enabled`
  (`PartySetup.pref("par_drag_putt", false)`); `--v3putt` restores the whole v3
  interface. DRAFT/BUILD/placement untouched.
- New inert verify flags: `--swingplay` (route autoplay through the embodied
  swing), `--walkprobe` (`AVATAR_ARRIVED p= dist=`), `--traceall` (PTRACE every
  physics tick, 0.1 mm resolution, state markers for sunk/dead/petrified/
  transit), `--physputt=p,a,tick,...` (fire debug_putt at exact physics ticks),
  `--swingsnap` (event-driven screenshots).

## 1. FROZEN PUTT — byte-identical physics receipts (make-or-break)

Ball paths extracted from `--traceall` PTRACE (one line per physics tick, all
balls, %.4f) by deduping consecutive positions per ball, then byte-diffed:

```
awk '$1=="PTRACE"{p=$(2+COL); if(p!=last){print p; last=p}}'   # COL = ball index+1
```

| # | Setup | v3 side | v4 side | Verdict |
|---|-------|---------|---------|---------|
| A/A control | fairway seed 11, empty course, 2 strokes | same cmd twice | — | **identical** (baseline determinism; sink tween masked by SUNK marker) |
| R1 | fairway `--seed=11 --players=2 --rounds=1 --autoplay="6:-10,6:10"` | `--v3putt` direct | `--swingplay` walk→charge→contact | **both balls byte-identical** |
| R2 | fairway `--seed=23 ... --autoplay="8:-18,8:18"` (all-human seats) | `--v3putt` | `--swingplay` | **both balls byte-identical** |
| R3 | fairway `--seed=7 --rounds=2 --autobuild` (TRAPS on course), 4 strokes | `--v3putt --autoplay` | `--swingplay` | diverges at sample 482 — see R3b |
| R3b | same, **tick-aligned**: v4 run logged `SWING_FIRE ... phys=92/369/740/1095`; v3 run fired the same numbers at those exact ticks via `--physputt=5,-6,92,5,6,369,7,-2,740,7,3,1095` | physputt | swingplay | **both balls byte-identical, traps included** |

R3/R3b interpretation: powered traps advance by physics tick from solidify, so
a stroke fired at a different absolute time meets a different trap phase —
course state, not putt physics. When the stroke enters the sim at the same tick
with the same numbers, the roll is identical to 0.1 mm through the whole trap
field. **The interface does not leak into the sim.** (R1's run also had a saved
bot seat firing extra seeded strokes through both paths — rng parity held and
those rolls matched too.)

Post-deadlock-fix re-run of R1: still byte-identical (see §5).

## 2. WALK → SWING gate

```
godot --headless --path . -- --skipmenu --course=fairway --seed=5 --players=4 \
      --rounds=4 --parbots --parquit --walkprobe --quitafter=200000
```
- `MATCH_OVER champ=MINT`, 0 errors; 63 `AVATAR_ARRIVED`, 62 `SWING_FIRE`.
- Ordering check (awk state machine over the log): **0 violations** — every
  `SWING_FIRE p=X` is preceded by a fresh `AVATAR_ARRIVED p=X`.

## 3. Screenshots (windowed, read + critiqued)

`--swingsnap` run: fairway seed 12, `--swingplay --autobuild`, snaps once per
tag (`verify_out/parv4/snap1/`):

| snap | what I saw |
|------|-----------|
| `snap_address` | Skill-shot frame from the tee: WHOLE lane + cup/flag at top, trampoline, both banks, crusher; yellow aim arrow under the golfer, dotted line up the lane; POWER meter filling (yellow); RED golfer bottom-edge in `2H_Melee_Idle` over the ball. Owner acceptance ("lane in one glance") **passes**. |
| `snap_charge` | Same frame 1 tick earlier, meter ~30% green — ramp + green→red lerp visible. |
| `snap_contact` | Stroke counter ticked 1/6→2/6 at the contact frame; ball away; swing pose. |
| `snap_blend` | Mid 0.5 s blend to overhead: RED ball mid-lane with trail, barbarian in follow-through with axe up — mid-`2H_Melee_Attack_Slice` receipt. |
| `snap_diorama` | Fully back to the v3 leaned diorama for the roll. |
| `snap_walk` | RED mid-stride down the lane toward its mid-course lie, camera tracking behind — the embodied walk reads. |

Bot layer (`verify_out/parv4/bots/`, windowed `--parbots` on green seed 15):
address/walk/contact/blend/diorama all captured; `snap_walk` shows a bot
mid-walk to a mid-course ball with the "MINT WENT EXPLORING — RETURNED" banner
(off-green return logic alive); `snap_diorama` shows the full plaza back in
diorama. KILLCAM verified live in windowed bot matches: `KILLCAM play ... 
botonly=true` → `KILLCAM done held_ms=359/392` (auto-skip).

## 4. Regression — full matches, all four courses

`--parbots --parquit`, headless:

| course | seed | result |
|--------|------|--------|
| fairway | 5 | `MATCH_OVER champ=MINT`, 0 errors |
| fairway | 9 | `MATCH_OVER champ=GOLD`, 0 errors |
| dogleg | 6 | `MATCH_OVER champ=BLUE`, 0 errors (post-fix, see §5) |
| green | 6 | `MATCH_OVER champ=RED`, 0 errors |
| the_gauntlet | 6 | `MATCH_OVER champ=GOLD`, 0 errors (gutter kill_event logged) |

Chaos still overlaps: `CHAOS_CONCURRENT` lines fire throughout (465-678 per
match, peaks >= 2 movers) with the persistent chaos banner path untouched.
`finished(results)` shape unchanged (placements/points/currency_events/
kill_events/highlights/monuments all present in FINAL_RESULT runs).

## 5. Deadlock found + fixed (pre-existing hole, exposed by the walk gate)

Deterministic hang: dogleg seed 6, round 2. Diagnosis (windowed screenshots +
temporary RM_TICK probe): a black hole near the tees **killed resting balls
during the next round's BUILD phase**, while `round_manager._round_over` was
still true from the previous round — `on_ball_died` no-ops, so the putt phase
started with dead balls unresolved. v3 masked this by letting bots no-op-stroke
dead balls to the DNF cap; the v4 arrival gate waited forever for an address
that can never come.

Fix (both directions):
- `RoundManager.start_round` books already-dead/sunk balls as resolved up
  front (their death drama already played when they died).
- `AvatarShot.is_pending()` + main's bot gate: only wait for arrival while the
  embodied machine is actually running the shot; otherwise fall through to the
  v3 direct path — the turn always advances.

Receipts: dogleg seed 6 to `MATCH_OVER champ=BLUE` 0 errors; R1 trace receipt
re-run post-fix still byte-identical; green seed 6 re-run post-fix to
MATCH_OVER.

## 6. Frozen-invariants checklist

- [x] `Ball.putt`, `STOP_SPEED`, `MAX_SPEED`, damping, low-speed brake — untouched.
- [x] Cup `MAGNET_RADIUS/MAX_SPEED/FORCE` — untouched.
- [x] `putt_controller.debug_putt` — byte-identical (only entry point for every
      shot: human swing, bot swing, autoplay, physputt).
- [x] Drag constants `MIN_SPEED/MAX_SPEED/MAX_DRAG/GRAB_RADIUS` — untouched;
      drag path intact behind `drag_enabled`.
- [x] `TRAPS_PER_BUILD = 1`; DRAFT/BUILD/placement_controller — untouched.
- [x] Killcam, chaos banner, badges, gutters, gravestones, royalties — alive in
      receipts above.
- [x] `--autobuild/--autoplay/--autoputt/--aimshow/--shots/--tracepos/--parbots`
      all still drive matches headlessly (bypassing the walk by default).
- [x] Avatars physically isolated from balls (layer 2 + exceptions) — proven by
      the byte-identical traces with avatars walking during the v3-path runs.

## 7. Known limits / notes for waves 2-3

- **Bot-match outcome reproducibility is wall-clock-limited (pre-existing v3):**
  `_bot_think_t` accumulates real `_process` deltas, so the tick a bot fires on
  varies run-to-run, and tick-phased powered traps then diverge outcomes.
  Verified pre-existing: two identical `--v3putt --parbots` runs of fairway
  seed 5 give different points. Wave 2's "reproducible --parbots chaos" exit
  will want bot cadence moved to physics ticks.
- **Human input paths** (`-3` cursor/LMB, `-4`, pad stick) share the state
  machine with the harness-driven paths but the device reads themselves need
  Alex's hands-on playtest (no headless harness injects real mouse/pad state —
  same as v1-v3 drag verification).
- Dogleg full bot matches are slow in real time (bank-shot misses + walk
  cadence) — same note as the v3 receipts.
- Avatar may clip trap meshes visually in dense fields (spec OQ5 accepts;
  revisit with NavMesh only if flagship screenshots demand).
- Wave 2 hooks ready: `PlayerAvatar` collision exceptions are per-ball (easy to
  drop for griefers), `is_pending/is_addressed` expose machine state, chaos
  already runs embodied turn-based shots under the DIORAMA camera.
