# PAR FOR THE CURSE v4 — "EMBODIED GOLF" design spec

*2026-07-06. Alex's sketch (docs/design/05-director-notes-2026-07-05.md §"Par
v4: EMBODIED GOLF"), sequenced by the director. Modifies the live v3 game in
scenes/ + scripts/. Par is the only game where the character models don't do
the playing — v4 makes them play. FROZEN: ball physics, damping, cup magnet,
and the putt IMPULSE. The interface changes, not the sim.*

## One line

Your KayKit character walks to their ball, addresses it, and swings — a
third-person shot that funnels into the exact same `ball.putt(dir, speed)` the
mouse-drag fires today — and in the CHAOS round the players who aren't shooting
walk the course as their characters and grief the ones who are, in real time.

## The frozen core (read this first)

The whole point of v4 is that the SIM is untouched. Every shot, human or bot,
KB+mouse or gamepad or hotseat, resolves through the one entry point that
already exists:

- `putt_controller.debug_putt(power: float, angle_deg: float)` →
  `dir = Vector3(0,0,-1).rotated(UP, deg_to_rad(angle_deg))` →
  `ball.putt(dir, power)` (`scripts/putt_controller.gd:177`, `scripts/ball.gd:81`).
  `angle 0 = -Z` (toward the fairway cup); `power` is m/s, clamped 0..`MAX_SPEED`(15),
  usable band 1.2..13.
- **v4 rule: the embodied aim/power UI computes exactly `(power, angle)` and
  calls `debug_putt(power, angle)`.** Nothing else. No new impulse, no new
  damping, no touch to `Ball.putt`, `STOP_SPEED`, cup `MAGNET_*`, or the drag
  constants (`MIN_SPEED/MAX_SPEED/MAX_DRAG/GRAB_RADIUS`). The swing animation's
  contact frame is the trigger; the numbers are the frozen ones.
- **Byte-identical receipt (the make-or-break test):** the same `--seed` +
  `--autoplay` list, played once through today's `debug_putt` and once through
  the v4 swing, must produce identical `--tracepos` ball paths. Same (dir, speed)
  in = same roll out. If the traces diverge, the interface leaked into the sim
  and the wave is rejected.

## Players & input (device map is unchanged — v3's `core/player_input.gd`)

Par is a `-3` (mouse/shared) game today. v4 keeps `-3` first-class and adds the
aiming devices. Per-device shot control:

| Device | Aim | Power | Walk-to-ball (normal round) | Grief-walk (chaos) |
|---|---|---|---|---|
| `-3` mouse/shared (hotseat default) | cursor on ground plane (reuse `putt_controller._mouse_on_plane`) | LMB hold→release charge | **auto** (character walks itself) | auto seek-bot (see OQ1) |
| `-4` KB+MOUSE | cursor via `PlayerInput.get_aim_dir(p, ball_pos, cam)` | A/LMB hold→release | auto | `get_move` (WASD) direct-control |
| pad `0..7` | left-stick heading (`get_move`) | A/button hold→release | auto | `get_move` (stick) direct-control |

- **Aim → angle:** face the ball toward the aim direction; the fired `angle_deg`
  is `rad_to_deg(atan2(-dir.x, -dir.z))` (the inverse of `debug_putt`'s
  rotation, i.e. the bot's existing formula at `main.gd:701`). The aim arrow +
  first-bounce dot preview (`putt_controller._update_arrow/_update_dots`) stay
  exactly as-is — they already render from a `dir` and a `speed`.
- **Power → hold-release:** press starts a power meter that ramps 1.2→13 m/s
  over `POWER_CHARGE_T` (default 1.1s, ping-pong so you can hold for a mid
  value); release fires. Maps to `power` directly. `-3` keeps the *option* of
  today's drag-release under a settings toggle (OQ2) but the shipped default is
  hold-release for every device, so onboarding is one verb.
- No new `PlayerInput` API is required for shots. Grief-walk reuses `get_move`.
  `describe_binding` already narrates a/b/move for the How-to-Play cards.

## Turn flow & camera (normal round)

Sequence per stroke (drives `main._on_turn_started` → new `AvatarShot` state):

1. **T0 — hand off.** `camera_rig` begins `DIORAMA → OVER_SHOULDER` dolly
   (`CAM_TO_SHOULDER` 0.6s). Acting avatar plays `Walking_A` and `move_toward`s
   its ball at `WALK_SPEED` 3.0 m/s.
2. **Arrive (≤ `WALK_CAP` 1.4s; teleport-dolly the remainder if farther).**
   Within `ARRIVE_DIST` 0.8m of the ball the avatar plays `2H_Melee_Idle`
   (address stance, club held two-handed). Aim + power input enable
   (`putt_controller.enabled = true`), over-shoulder framing behind the avatar
   (`CAM_SHOULDER_BACK` 3.2m, `CAM_SHOULDER_UP` 1.8m, look at ball).
3. **Aim + charge.** Over-shoulder. Arrow + dots preview as today.
4. **Release → swing.** Play `2H_Melee_Attack_Slice`. At `SWING_CONTACT_T`
   0.18s into the clip, call `debug_putt(power, angle)` (the frozen impulse).
   Camera blends `OVER_SHOULDER → DIORAMA` (`CAM_TO_DIORAMA` 0.5s) so the roll
   and trap-dodging read from the overview — exactly the readability the v1 spec
   demanded for putting.
5. **Roll / rest / sink / death.** Untouched: `RoundManager`, cup magnet,
   OOB-return, gutters, gravestones, royalties all run as v3. Between strokes
   the avatar `Idle`s where it stands (no walk-back needed).

Pace budget: `WALK_CAP` 1.4 + charge (self-paced, capped by the existing 25s
build / stroke-rotation cadence) keeps a stroke near the ~20s target. Stroke
cap 6 and DNF petrify unchanged.

**Camera implementation:** add a `mode` enum to `scripts/camera_rig.gd`
(`DIORAMA` = today's leaned overhead, `OVER_SHOULDER`, `BLEND`). `OVER_SHOULDER`
target = `avatar.global_position - facing*CAM_SHOULDER_BACK + UP*CAM_SHOULDER_UP`,
look at `ball`. `BLEND` lerps transforms over the named times. Shake / focus_on /
start_flyover keep working (they act on `cam`, mode-agnostic). Per-course
`camera_position/fov/course_extent` still frame the DIORAMA pose.

## Avatars (the caddy becomes the player)

`scripts/caddy.gd` today spawns a KayKit char at the tee that reacts but never
moves. v4 promotes it to `PlayerAvatar`:

- Body: `CharacterBody3D` + capsule (r 0.35, h 1.4) — mirror
  `minigames/echo_chamber/fighter.gd`'s proven KayKit rig (`MODEL_YAW_OFFSET =
  PI`, identity ring = player color, `_pivot` for yaw). Scale 0.7 as today.
- Movement: **direct `move_toward` / `velocity`** (no NavServer in wave 1 — see
  OQ5). Capsule collides with course walls and trap bodies so it slides, not
  clips. Collision layer separate from balls; ball collision governed by the
  block rules below.
- Anim vocabulary (all CONFIRMED present in `assets/models/kaykit/*.glb`, dumped
  via `minigames/tilt/dev_dump_anims.gd`):
  | Beat | Clip |
  |---|---|
  | walk / run to ball | `Walking_A` / `Running_A` |
  | address the ball | `2H_Melee_Idle` |
  | **drive swing** | `2H_Melee_Attack_Slice` (two-handed horizontal — reads as a golf swing) |
  | big/power swing (optional variant) | `2H_Melee_Attack_Chop` |
  | putter tap (short shots) | `1H_Melee_Attack_Slice_Horizontal` |
  | grief shove | `Unarmed_Melee_Attack_Punch_A` (already the tilt shove) |
  | grief body-block stance | `Blocking` |
  | grief trap-trigger | `Interact` |
  | sink cheer / death / hit | `Cheer` / `Death_A` / `Hit_A` |
  | dodge | `Dodge_Forward/Left/Right` |
- No club mesh required for wave 1 — the bare 2H swing sells it. A club prop
  (primitive or Meshy) attached to the right-hand bone is a wave-3 polish item
  (OQ3).

## Top-down hazard placement — UNCHANGED

DRAFT and BUILD are untouched. `scripts/placement_controller.gd` still runs the
overhead ghost-preview, wheel/R rotate, validity + saturation checks, all
querying the `Course` geometry interface. `TRAPS_PER_BUILD = 1`, MORE TRAP TYPES
(the v3 verdict). The overhead build camera is the DIORAMA pose; v4 only touches
the PUTT camera. The two halves — top-down authoring, third-person execution —
are the whole design tension and they stay cleanly split.

## Live griefing (CHAOS round only)

Normal rounds are turn-based embodied shots, no interference. The CHAOS round
(`GameState.is_chaos_round()`, still last round, `CHAOS_TURN_GAP` 1.5s / no
rest-waiting / 1.6× powered traps / 75s cap) gains live griefing: **the
non-stroking players direct-control their avatars in real time** and interfere
with whoever the shot clock is on.

Three verbs, all inside the existing 2-button budget:

1. **Body-block.** The griefer's capsule collides with balls. Avatar mass is
   light: a block nudges a rolling ball, it never launches it. Implement as a
   capped restitution — clamp any impulse the avatar imparts so the ball's speed
   delta ≤ `GRIEF_BLOCK_DV` 1.5 m/s (well under a putt). Standing still in a
   ball's path = a wall it must go around; no button needed.
2. **Shove ball.** Press A within `GRIEF_REACH` 1.1m of a ball → capped central
   impulse toward the avatar's facing, ball speed delta ≤ `GRIEF_SHOVE_DV`
   2.0 m/s, `GRIEF_SHOVE_CD` 0.8s cooldown. Anim `Unarmed_Melee_Attack_Punch_A`.
   Applied as `ball.apply_central_impulse` sized to the cap — it perturbs the
   sim's inputs, it does not alter `Ball.putt` or the physics constants.
3. **Trigger a trap early.** Press B (Interact) while standing in a powered
   trap's new `GriefTrigger` Area → snap that trap to its strike phase now:
   crusher slams (`_t → 1.5`), fan fires a gust, bumper kicks, windmill lurches
   a quarter-turn. `GRIEF_TRIGGER_CD` 2.0s per trap. **The KILL rule is
   unchanged** — traps still only `kill_ball(ball)` on ball contact
   (`trap_base.gd:47`); the griefer changes trap TIMING/state, never who or how
   it kills. Add a shared `grief_trigger()` hook on `Trap` (default no-op;
   crusher/fan/bumper/windmill override); one small `GriefTrigger` Area per
   powered trap scene.

**Anti-frustration rules (non-negotiable):**

- **Cup exclusion.** No griefer avatar may enter a disc of radius
  `CUP_EXCLUDE_R` (= `course.cup_no_build_radius`, 1.3m) around the cup — soft
  radial pushback at the boundary. Kills cup-camping dead. (The stroking player's
  own avatar is exempt near its own ball but is never *at* the cup anyway.)
- **Shove/trigger cooldowns** above prevent volley-spam and machine-gun traps.
- **Impulse caps** (`GRIEF_BLOCK_DV`, `GRIEF_SHOVE_DV`) keep balls on the course
  — a grief can steer or stall a ball, never yeet it off the table.
- **Griefing earns GRUDGE, not points.** A shove/block/trigger that directly
  precedes an enemy death or DNF logs a `_currency_log` entry
  `{type:"grudge", player: griefer, reason:"griefed <victim>"}` + a
  `"<GRIEFER> GRIEFED <VICTIM>"` highlight and +1 grudge — **zero score**.
  This is the estate's social ledger (the Executor greets "THE SNAKE" by it);
  it is deliberately not on the scoreboard. Since chaos is the last round, grudge
  here is reputation, not a draft resource — that's intended.

## Bigger courses

v4 scales the courses up to Super-Battle-Golf size and gives them walkable
perimeters. The `Course` geometry interface (`play_rects`, `tee_slots`,
`cup_position`, `no_build_zones`, `clamp_gravestone`, camera fields) already
abstracts shape, so scaling is data + camera, not new code.

Existing four (current → v4):

| Course | v3 footprint | v4 change |
|---|---|---|
| **fairway** | 6.6×20.6 lane | ×1.4 length, widen to 8m; add 1.5m walk aprons outside each wall so griefers flank the lane. `camera_position.y` 15.5→20, fov 54→58. |
| **dogleg** | L, legs ~10/8m | ×1.4; widen the elbow apron so a griefer can cut the corner on foot. Camera y 17→21. |
| **green** | 12×12 plaza | ×1.3 (→16×16); the open plaza is already walk-friendly. Camera y 22→26, fov 58→62. |
| **the_gauntlet** | 3-leg + gutters | keep gutters; add a raised catwalk `play_rect` skirting the outer wall as the griefer highway. Camera y 15→19. |

Adaptation rules for all four:
- **Walk paths:** avatars auto-walk to their ball along the existing `play_rects`
  (they're the floor). No authored paths needed — `move_toward` + capsule slide.
  Add a thin `apron` `play_rect` (non-buildable, tag it out of `has_valid_placement`
  by keeping it off `play_rects` but adding a parallel `walk_rects` list the
  avatar may stand on) so griefers can flank without standing in the fairway. Do
  NOT add apron rects to `play_rects` (that would let traps spill onto them).
- **Camera scale:** bump each course's `camera_position`/`fov` per the table so
  the DIORAMA still frames the larger footprint; `course_extent` drives the
  victory flyover, scale it to match.
- **No-build:** existing `extra_no_build` discs scale with the course.

### New v4-flagship course — "THE WIDOW'S WALK"

A long, tiered, par-4-scale course built for walking and griefing:

- **Shape:** ~9m×30m spine, three tiers stepping down toward the cup:
  1. *Tee meadow* (south, ~9×8): wide, four tee slots, a low decorative
     mausoleum as a fixed `extra_no_build` monument mid-meadow.
  2. *The chasm crossing* (middle): a 3m OOB gutter splits the spine; a 2.5m
     land bridge (buildable) is the safe line, or bank across. Reuse the
     `Gutters` Area pattern from `the_gauntlet` — a miss drops you to a side
     channel that delivers near, but not at, the green (risk/reward).
  3. *The switchback green* (north): the spine doglegs around a second monument
     to an elevated green ringed by a knee-high wall (bank-in required).
- **Walk furniture:** a continuous 1.5m perimeter `walk_rect` catwalk down both
  flanks — the griefer highway — with cup-exclusion at the green.
- **No-build monuments:** two 1.6m discs (the mausoleums) + the standard tee/cup
  zones + the chasm lip.
- **Camera:** `course_center` mid-spine, `camera_position ≈ (0, 24, 11)`, fov 60,
  `course_extent (9, 0, 15)`. The flyover crawls the whole spine tee→green — the
  closer the v1 spec wanted ("watch the hole grow"), now at scale.
- **Why flagship:** longest walk (sells the embodiment), a chasm that punishes
  griefer shoves near the bridge (a 2.0 m/s nudge into the gutter = a highlight),
  and two chokepoints that reward early trap-triggering in chaos.

## Bots

Bots already draft/place/putt via the debug paths (`--parbots`, seeded
`_bot_rng`, `main._bot_build/_bot_putt`). v4 adds the walking layer only:

- **Bot shot (normal + chaos):** on turn start the bot avatar walks to its ball
  (same `move_toward` as humans) BEFORE the swing fires. Gate `_bot_putt` on
  `avatar arrived` (log `AVATAR_ARRIVED p=.. dist=..`), then fire the frozen
  `debug_putt` — bot cadence (`_bot_think_t` ≥1.5 normal / ≥0.2 chaos) starts
  counting on arrival. Aim/power formula (`main.gd:694`) unchanged.
- **Bot griefing (chaos):** non-stroking bot avatars run a seeded seek-bot —
  walk toward the nearest live enemy ball (respecting cup-exclusion), then
  body-block / shove-on-cooldown / trigger a nearby trap, on a `_bot_rng`
  cadence. Mirror the deterministic bot loops in `echo_chamber/fighter.gd`
  (`_bot_tick`) and `tilt/tilt_pawn`. Every verb must fire at least once across
  a match so the receipts (and the Executor's ledger) show it. All randomness
  from `_bot_rng` → a `--parbots --seed=N` chaos round is reproducible.

## Verification plan (the house builds nothing without receipts)

Reuse `scripts/verify_capture.gd`: `--autoplay`, `--autobuild`, `--shots`,
`--tracepos`, `--parbots`, `--course=`, `--seed`, `--rounds`. New inert flags:

- `--walkprobe` — log `AVATAR_ARRIVED p=.. dist=..` each time an avatar reaches
  its ball, so the walk→swing gate is provable headless.
- `--griefprobe=verb,frame` — deterministically inject one griefer action
  (shove/block/trigger) at a frame and log its effect on the target ball.

Per-piece receipts:

| Piece | Command sketch | Passing evidence |
|---|---|---|
| **Frozen putt (byte-identical)** | same `--seed --autoplay --tracepos` through v3 `debug_putt` vs v4 swing | two `--tracepos` logs **diff-identical** ball paths |
| **Walk → swing** | `--parbots --walkprobe --shots` | `AVATAR_ARRIVED` precedes every `VERIFY_AUTOPLAY`; screenshot of avatar at ball mid-`2H_Melee_Attack_Slice` |
| **Over-shoulder → overhead cam** | `--course=fairway --autoplay --shots` around a release | shot at charge = over-shoulder behind avatar; shot +30f = overhead diorama watching the roll |
| **Live griefing** | `--parbots --rounds=1` (chaos-only) `--shots` + `--griefprobe` | screenshots of a body-block, a shove (log shows Δv ≤ cap), a grief-trigger death; `_currency_log` grudge entry + `GRIEFED` highlight in `finished()` |
| **Anti-frustration** | `--griefprobe` a bot into the cup disc | log shows pushback keeps it outside `CUP_EXCLUDE_R`; no cup-camp |
| **Bigger courses** | per course `--autobuild --autoplay --shots` | walk+shot screenshot per course; camera frames the larger footprint |
| **Flagship** | `--course=widows_walk --parbots --rounds=4 --quitafter=30000` | `MATCH_OVER`, zero SCRIPT ERROR; chasm-crossing + green screenshots; a griefer-shove-into-chasm highlight |
| **Regression** | full 4-round match each course, `--parbots` | `MATCH_OVER champ=..`, `err=0` for `SCRIPT ERROR/Invalid call/null instance/Nil`; `finished(results)` shape unchanged |

Import pass first: `godot --headless --editor --import --quit --path .` (zero
parse errors). Write it up in `docs/verify/par-v4-VERIFY.md` matching the v2
format (commands, read-and-critiqued screenshots, frozen-invariants checklist).

## Phasing — 2-3 waves, one agent each, Par never broken on master

Each wave build-checks, visual-verifies, commits, and leaves master shippable.

**Wave 1 — Embodied normal shots.** Promote caddy→`PlayerAvatar`; walk-to-ball
+ `2H_Melee_Attack_Slice` swing firing `debug_putt` at the contact frame;
over-shoulder↔overhead camera; aim/power for `-3`/`-4`/pad + hold-release meter;
bot walk layer. **Chaos still plays the v3 way** (turn-based, no live griefing)
so nothing regresses. Exit: byte-identical trace receipt, walk+swing+camera
screenshots, full 4-round `--parbots` match to `MATCH_OVER`.

**Wave 2 — Live griefing in chaos.** Direct-control non-stroking avatars;
body-block / capped shove / trap grief-trigger (`grief_trigger()` hook +
`GriefTrigger` Areas on powered traps); anti-frustration (cup exclusion,
cooldowns, impulse caps); grudge logging; bot griefing. Only the chaos round
changes; normal rounds and the results contract stay wave-1. Exit: the griefing
receipt row above, cup-camp-prevention log, reproducible `--parbots` chaos.

**Wave 3 — Bigger courses + flagship.** Scale the four existing courses (camera +
`walk_rects` aprons + no-build), add `scenes/courses/widows_walk.tscn` and
`"widows_walk"` to `COURSE_IDS`. Optional club-prop polish (OQ3). Exit:
per-course walk+shot screenshots, flagship full-match sim, all five reachable via
`--course=`.

Between waves: wave 1 ships with legacy chaos; wave 2 adds griefing behind the
chaos gate; wave 3 adds content. Any wave can sit on master alone and Par plays.

## Non-goals (v4)

Online co-op (separate sequenced item), NavServer pathing (direct move_toward is
enough — OQ5), per-avatar cosmetics beyond player color, manual walk in NORMAL
rounds (auto-walk only; free-roam is a chaos-only privilege), club-swing
physics (the swing is cosmetic; the impulse is frozen).

## Open questions for Alex (each with the director's default so nothing blocks)

1. **`-3` (pure mouse) griefing in chaos** — it has no analog move. **Default:**
   a `-3` seat's griefer is auto-walked by the seek-bot (spectate + auto-nudge)
   while its OWN shots keep mouse aim. Alt: give `-3` click-to-move.
2. **Shot power input** — **Default:** hold-release charge meter for *all*
   devices (one onboarding verb, per the brief). Keep v3 mouse drag-release as a
   SEATS/CONTROLS toggle for anyone who prefers the proven feel.
3. **Club prop** — **Default:** ship the bare-hand `2H_Melee_Attack_Slice`
   (reads fine); add a primitive/Meshy club on the hand bone as wave-3 polish.
4. **Own-avatar vs. own-ball collision** — could you body-block your own shot?
   **Default:** the acting avatar's capsule ignores balls for 0.5s post-swing and
   steps back a pace; griefers always collide.
5. **Auto-walk pathing in dense trap fields** — **Default:** direct `move_toward`
   + capsule slide in wave 1; only add a NavMesh if avatars visibly clip through
   trap clusters on the flagship. Revisit after the wave-1 screenshots.
