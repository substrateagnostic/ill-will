# ORBITAL THREAT LADDER — verification evidence

AAA-gap queue item #7. Module: `minigames/orbital/` only. All work is
**presentation only** — orbit physics, damage, kill credit, spawn schedule and
bot behaviour are untouched, and same-seed `KILL_EVENTS` are proven
byte-identical (see Determinism). Engine: Godot 4.6.2 (Windows). Commands run
from the worktree root; screenshots land in `verify_out/` (gitignored) and were
read + art-directed by the builder during the session.

## What shipped

A speed-tier danger ladder layered over the existing dodgeball sim:

1. **Escalating speed-tier audio** — every deadly ball near a living player
   emits a pitched tone from the existing Sfx bank asset
   (`impactPlate_light_000`), PITCH-SCALED and CADENCE-scaled by heat: a spaced
   low hum at the deadly floor tightening into a high whistle at top speed.
2. **Danger vignette** — a subtle full-screen red edge-tint that ramps up as a
   top-tier ball screams past a living player (proximity x heat), capped subtle
   (≤ 0.5 edge alpha) and softened under reduced motion.
3. **Ball visual heat** — emission brightens (~1.0x → ~2.7x) and the ball +
   trail hue bleed toward molten orange / hot-white up the tiers; the trail also
   thickens. Owner identity stays readable at low/mid tiers.
4. **Speed-scaled kill freeze** — the sim's own slow-mo beat is left
   byte-identical; a VISUAL kill punch (camera FOV punch-in + shake, decaying)
   is layered on top, scaled so a **faster ball = deeper + shorter** hit and a
   slow lob = softer + longer. Motion-gated.

## Speed tiers (velocity thresholds)

`OrbBall.DEADLY_SPEED = 4.0`, `OrbBall.SPEED_CAP = 13.0`. Heat factor
`hf = clamp((speed - 4) / 8, 0, 1)` → 0 at the deadly threshold, 1 at ~12 m/s.

| band | speed | hf | audio | heat | vignette |
|---|---|---|---|---|---|
| not deadly | < 4.0 | — | silent | base glow 0.25 | none |
| low deadly | 4–6 | 0–0.25 | low hum, wide spacing, silent < 5 m/s | dim | none (hf < 0.45) |
| mid | 7–9 | 0.4–0.65 | rising pitch, tighter cadence | orange bleed | begins near a player |
| top | 10–13 | 0.8–1.0 | high whistle flutter | white-hot, fat trail | strong near a player |

Audio: `pitch 0.85 → 2.15`, cadence period `0.26 s → 0.07 s`, volume by
`proximity(9→2 m) x lerp(0.15,1.0,hf)`. Vignette: proximity ramps within 4 m of
a living pawn, only for `hf ≥ 0.45`.

## Reduced-motion (the HIT KIT pattern)

Games read `PartySetup.pref("screen_shake", true)` (the ACCESS-tab toggle). When
**off**, the camera shake, the kill FOV punch, and the vignette are suppressed /
softened (vignette to 45%). Audio and ball heat are NOT motion effects, so they
stay on. Previously orbital applied camera shake unconditionally; it now honours
the pref too.

## Commands run

```sh
# import pass (required after adding res:// files)
godot --headless --editor --import --quit --path .

# threat-ladder staged demo (windowed) — pawn 0 stands still on the small
# planet, a 12 m/s top-tier ball is launched across the front of it at a ~1.1 m
# near miss; a bracket of PNGs is captured around closest approach.
godot --path . res://minigames/orbital/orbital.tscn -- --orbtest=threat --autoquit

# determinism proof: full seeded bot matches at 12x, KILL_EVENTS captured
for S in 1 2 7 11; do
  godot --headless --path . res://minigames/orbital/orbital.tscn -- \
    --orbbots --seed=$S --fast=12 --autoquit | grep '^KILL_EVENTS'
done
```

## Determinism (the load-bearing guarantee)

The existing slow-mo scales the **sim's own timestep** (`sdt = delta * 0.3` for a
tick-counted budget) and is therefore baked into the deterministic trajectory —
changing its depth/duration WOULD shift ball ages, the spawn schedule and
`time_left`, and thus `KILL_EVENTS`. So the sim slow-mo is left **exactly as
is**, and the speed-scaled "freeze" is realised purely as a VISUAL layer
(`_kill_impact` → `_impact_amp`/`_shake`, consumed only in `_process`). All
threat presentation runs in `_process` / the ball's `_process` (visual frames)
or in `_do_kill`'s presentation tail, using no sim RNG and mutating no sim state
(`OrbBall._threat_phase` is written/read only in the visual path).

Proof — baseline (pre-change) vs after, seeds 1/2/7/11:

```
diff baseline_kills.txt after_kills.txt
→ (no output) : KILL_EVENTS byte-for-byte identical across all seeds
```

`ORBITAL_ASSERT max_flight_age=46.4s (<75s): PASS` for seed 7 (unchanged from
the original orbital VERIFY table). No SCRIPT ERROR / null-instance output on a
full match with all threat presentation active.

## Screenshots (read + art-directed during the build)

- `orbital_threat_b.png` — the money frame. A top-tier ball (speed 12.3, hf 1.0)
  screams across the front of the small purple planet at a **1.09 m near miss**
  past the living RED player (who survives). The ball runs incandescent with a
  molten orange-white core and a fat hot trail; the **red danger vignette**
  strongly frames the screen edges. `THREAT_STATE tag=b speed=12.26 hf=1.00
  nearest_pawn=1.09 vig=0.88 alive0=true`.
- `orbital_threat_reducedmotion_b.png` — the SAME staged moment with
  `screen_shake=false`. The ball heat + trail are identical (heat is not
  motion), but the vignette is visibly softened to a faint dark-red edge
  (~0.45x). Confirms the reduced-motion gate.

The staged `--orbtest=threat` path is isolated (sets `_test_mode`), so it never
runs during a real match and cannot affect `KILL_EVENTS`.

## Notes

- Threat audio plays on the SFX bus during live/windowed play (only `--fast`
  mutes the master bus). Audible hum→whistle escalation is a human ear-check;
  the pitch/cadence/volume ramps are exercised every frame and logged staging
  shows the top tier firing continuously near the player.
- The prior orbital VERIFY "wish" for "a low sci-fi hum for ghost balls / a
  whoosh" is now met via the pitched-bank threat tone.
- `verify_out/` PNGs and the ObjectDB-leak-at-exit line are the usual
  headless-harness artefacts; the shell never quits that way.
