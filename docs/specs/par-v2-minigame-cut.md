# PAR FOR THE CURSE v2 — "minigame cut" spec

*Changes from live playtest feedback (Alex, 2026-07-04). Modifies the
existing game in scenes/ + scripts/. Keep standalone playability AND the
module contract. Putt feel is APPROVED — do not touch ball physics,
damping, cup magnet, or putt controller mapping.*

## 1. Round structure: 3 + CHAOS

Match = 3 normal rounds (draft → build → putt) + a 4th **CHAOS ROUND**:

- No draft/build in chaos — you play the fully-accreted course as-is.
- **No rest-waiting**: turn rotation continues but the next player may putt
  the moment the PREVIOUS player's stroke is 1.5s old (balls still rolling,
  all live, collisions everywhere). 10s shot clock per stroke (auto-skip).
- All powered traps run at 1.6× speed (windmill spin, crusher cycle, fan
  push). Visual shift: warm golden hour lighting + "CHAOS ROUND" banner +
  faster music sting (reuse jingles).
- Double points: 10/6/4/2 finish order (2P: 6/2). Royalties unchanged.
- Stroke cap 6 still applies; round also hard-ends at 75s (unsunk = DNF).

GameState.rounds_total semantics change: total INCLUDES chaos (default 4).
`--rounds=N` still works: N-1 normal + 1 chaos (N=1 → chaos only, fine for
testing).

## 2. Double hazard density

Each build phase, every player drafts and places **2 traps** (pick 1 of 3,
place it, immediately pick 1 of 3 again, place again — same flow twice;
grudge/cursed rules apply to the first pick only). Build shot clock (25s)
covers EACH placement. This doubles accretion speed: ~24 traps by chaos
round with 4 players. Add a balancing knob: `TRAPS_PER_BUILD := 2` const.
If placement validity fails everywhere (saturated), auto-skip silently.

## 3. Course variety: 3 shapes, random per match

Three course scenes, picked by seeded RNG at match start (equal odds):

1. **The Fairway** — the current straight lane (rename course.tscn →
   courses/fairway.tscn, keep geometry).
2. **The Dogleg** — L-shape: 6m-wide lane runs 10m north, turns 90° right,
   runs 8m east to the cup. Tee at the south end. The corner is prime trap
   real estate; a diagonal bank wall sits at the inside corner. Cup NOT
   visible in a straight line from tee (bank shots mandatory).
3. **The Green** — open 12×12m plaza; tee SW corner, cup NE corner; two
   fixed obstacle humps (use Kenney minigolf ramp/hill GLBs) breaking the
   diagonal. Feels wide-open until it accretes shut.

Implementation requirements:
- Extract placement bounds from placement_controller constants into the
  course: each course scene exposes `is_point_on_green(p: Vector3) -> bool`
  (v1: union of AABBs is fine), `tee_positions() -> Array[Vector3]`,
  `cup_position() -> Vector3`, no-build zones list. PlacementController and
  main query the course. Camera: each course exposes `camera_home()`
  transform + `course_center` so the diorama frames any shape (Dogleg needs
  a wider/rotated frame).
- Gravestone clamping + cup magnet + CupArea wiring must come from course
  data, not hardcoded constants.
- VerifyCapture --autoputt angles are course-relative already (player aims);
  add `--course=fairway|dogleg|green` CLI override for deterministic tests.

## 4. Results contract

Unchanged shape. Chaos-round points flow into the same totals. Add
highlight if chaos round produced a death: "CHAOS CLAIMED {name}".

## Verification exit criteria (VERIFY.md + screenshots required)

- Each course: aim-shot screenshot + a sunk putt via autoplay + a full
  4-round match sim reaching MATCH_OVER with no SCRIPT ERROR.
- Chaos round screenshot showing golden lighting + banner + ≥2 balls
  simultaneously in motion (use --shots timing).
- Dogleg: prove a bank-shot sink is possible via autoplay (document angles).
- Density: screenshot of round-3 course with ≥12 traps placed.
