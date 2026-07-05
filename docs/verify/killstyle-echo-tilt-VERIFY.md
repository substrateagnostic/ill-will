# KILL_EVENTS + WARM-STYLE retrofit — echo_chamber & tilt — VERIFY

Scope touched (only these): `minigames/echo_chamber/`, `minigames/tilt/`,
`docs/specs/anthology-module-contract.md`, `docs/verify/`. No `estate/`,
`core/`, `scripts/`, `scenes/`, `project.godot`, or other minigames were
modified.

Godot 4.6.2.stable. All screenshots windowed (headless cannot render) and read
back by eye before sign-off.

---

## Part 1 — Contract: optional `kill_events` results field

`docs/specs/anthology-module-contract.md` gained an **Optional results field**
section documenting:

```
kill_events: Array of { killer: int, victim: int, cause: String }
```

- `killer` = player index, or `-1` for environment / self-inflicted.
- `victim` = player index.
- `cause` = short lowercase slug (`"shatter"`, `"ring_out"`, `"crush"`, …).
- Exactly one entry per elimination/KO/death, appended in event order, included
  in the finished results dict. **Pure reporting** — must not alter behavior.
  Games without discrete deaths omit it.

`core/minigame.gd` is out of scope (untouched); the field is additive and the
shell's `validate_results` ignores unknown keys, so nothing else needs changing.

---

## Part 2 — kill_events wired into the two games (reporting only)

### echo_chamber

Every death funnels through the single sink `_on_death(victim, is_fall, killer,
cause)`; the two call sites now pass killer + cause:

| Detection site | killer | cause |
|---|---|---|
| `resolve_swing` hit that returns `"kill"` (live **or** ghost swing) | attacking `owner` (a player index — ghosts credit their owner, matching the royalty already awarded there) | `"crush"` if heavy, else `"shatter"` |
| `on_fall_death(idx)` (walked/knocked off the platform, no attacker credited) | `-1` | `"ring_out"` |

`_kill_events` is match-scoped (same lifetime as `_currency`), added to the
results dict as `"kill_events"`, and printed at match end.

**Run** (headless, 5 rounds, seeded bots):
```
godot --headless --path . --fixed-fps 60 \
  res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=4 --seed=1 --quitafter=2700
```
**Output:**
```
ECHO_MATCH_OVER champ=GOLD placements=[2, 3, 0, 1]
KILL_EVENTS n=7 [{killer:2,victim:1,shatter},{killer:1,victim:0,crush},
 {killer:3,victim:2,shatter},{killer:1,victim:0,shatter},{killer:2,victim:1,crush},
 {killer:2,victim:3,crush},{killer:1,victim:2,shatter}]
```
Count cross-check: the log shows **4** `ECHO_BOUNTY_KILL` lines (ghost kills)
plus **3** live-swing kills = **7** eliminations = `n=7`. Every killer is a
valid player index (all combat kills this seed; no falls occurred), every cause
is `shatter`/`crush`. One entry per KO, no double-counting (a ghost kill fires
`_award_ghost_hit` for the note **and** `_on_death` for the respawn, but only
the single `_on_death` records a kill_event).

### tilt

The one elimination path is `_on_edge_fall(p)` (a pawn leaves the platter). It
already computes `shover` (the crediting attacker inside `ROYALTY_WINDOW`, else
`-1`) for the royalty award; the kill_event reuses that exact value:

```
_kill_events.append({"killer": shover, "victim": p, "cause": "ring_out"})
```

Water landing (`_on_water_death`) and shove **clashes** (mutual, "NO royalty")
are not eliminations and are correctly not recorded.

**Run** (headless, 3 rounds, seeded bots):
```
godot --headless --path . --fixed-fps 60 \
  res://minigames/tilt/tilt.tscn -- \
  --tiltbots --seed=7 --roundtime=30 --rounds=3 --quitafter=7400
```
**Output:**
```
TILT_EVT ... fall p2 shover=-1 tilt=30.0
TILT_EVT ... fall p1 shover=-1 tilt=30.0
TILT_EVT ... fall p1 shover=-1 tilt=30.0
TILT_EVT ... fall p3 shover=-1 tilt=30.0
KILL_EVENTS n=4 [{killer:-1,victim:2,ring_out},{killer:-1,victim:1,ring_out},
 {killer:-1,victim:1,ring_out},{killer:-1,victim:3,ring_out}]
```
Count cross-check: **4** logged `fall p…` events = **4** kill_events, victims
`2,1,1,3` matching the log line-for-line. All solo falls at max tilt (30°) in
sudden death → `shover=-1` → `killer=-1`. The 4 grudge `currency_events` (one
per fall) corroborate the count.

---

## Determinism proof (byte-identical sim — reporting only)

The two `.gd` files were `git stash`-ed to their pre-change baseline, re-run
with the same seeds, then restored. Output was **identical** in every scored
value:

| | baseline (stashed) | with kill_events + warm style |
|---|---|---|
| echo r1..r5 points | `{0:5,1:0,2:10,3:3}` … `{0:18,1:16,2:27,3:21}` | **same** |
| echo placements | `[2,3,0,1]` champ GOLD | **same** |
| echo ghost drift | `ECHO_DETERMINISM max_err=0.000000` every round | **same** |
| tilt falls | p2@3683, p1@3968, p1@5811, p3@6021 (same frames) | **same** |
| tilt placements / points | `[3,0,2,1]` / `{0:11,1:6,2:9,3:12}` | **same** |

The changes are additive only: an `Array.append` of a plain dict, two typed
optional params with defaults, and material/light/env values. No RNG draws, no
control-flow, scoring, or physics changes. `--fixed-fps 60` used so frame
indices are directly comparable.

---

## Part 3 — Warm-diorama style unification

Reference house look: `minigames/greed` (warm brown table, gold-trim walls,
warm sun + shadows, soft ambient, filmic, gentle glow). Both targets were cold
"void" arenas. **Environment / lighting / surround only** — no arena geometry,
gameplay dimensions, collision, or identity accents were touched.

### echo_chamber — `docs/verify/shots/style_echo_before.png` → `style_echo_after.png`

- **Before:** cool grey-purple disc floating in a blue-purple void, cold blue
  fill light.
- **After:** warm-dark vault sky, warm sun (`1.0,0.92,0.78`) + shadows, warm
  bounce fill, filmic + glow. Arena discs re-surfaced to warm brown/tan, pillars
  to warm carved wood. New `_build_surround()` drops the arena into a warm brown
  **well** (a `CULL_FRONT` cylinder ringing the play area, inner radius
  `ARENA_R+1.3`) over a warm tabletop floor — **both purely decorative
  (no collision) and below the `y < -3` fall-death line** (fighter.gd:297), so
  the fall gimmick and physics are untouched.
- **Identity accents preserved and improved:** the gold safe-ring stays
  emissive; the neon owner-tinted ghosts and parry flashes glow *harder* against
  the warmth — see `style_echo_r5_neon_on_warm.png` (round-5 "FLOOR FALLS AWAY",
  7 luminous ghosts over the warm well; the surround holds cleanly when the
  outer disc drops).

Windowed capture:
```
godot --path . --fixed-fps 60 res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=8 --seed=1 --shots=360 --quitafter=420 --outdir=verify_out/after_echo
# round-5 well check: … --echofast=5 --seed=1 --echocap --outdir=verify_out/echo_r5
```

### tilt — `docs/verify/shots/style_tilt_before.png` → `style_tilt_after.png`

- **Before:** flat bright cyan sky + cyan-teal sea, neutral-white sun — cold,
  hard, moodless.
- **After:** golden-hour re-light — warm low sun (`1.0,0.84,0.60`) with long
  warm shadows, warm peach sky horizon + soft ambient, filmic + glow so the
  platter's bright rings and gold coins bloom, gentle cool sea-bounce fill. The
  ocean is deepened to a warm evening sea-green and made mirror-calm so it
  catches the golden sky.
- **Identity accents preserved:** the platter's target-ring / rim materials are
  untouched (they are the game's accent). The result reads as the golden-hour
  beach game beside greed's vault and mower's lawn.

Windowed capture:
```
godot --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- \
  --tiltbots --seed=7 --roundtime=30 --rounds=3 --shots=420 --quitafter=480 --outdir=verify_out/after_tilt3
```

---

## Import pass (clean)

```
godot --headless --editor --import --quit --path .    # exit 0
```

## Shots in `docs/verify/shots/`
- `style_echo_before.png`, `style_echo_after.png`
- `style_tilt_before.png`, `style_tilt_after.png`
- `style_echo_r5_neon_on_warm.png` (bonus: neon ghosts over warm well, round 5)
