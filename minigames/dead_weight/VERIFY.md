# DEAD WEIGHT — verification

Sumo brawl in a cozy attic. Knocked-out players become POLTERGEISTS who possess
the furniture and hurl it at the living. Best-of-3.

Root scene: `minigames/dead_weight/dead_weight.tscn` (extends `Minigame`).
Self-starts standalone 0.5s after `_ready` with a default 4-player config
(KayKit chars, colors/names from `GameState` consts, seed from `--seed=N` or 1).
When the shell calls `begin(config)` first, the self-start is skipped.

## How to run

Standalone (real players, gamepads / keyboard halves via PlayerInput):
```
godot --path . minigames/dead_weight/dead_weight.tscn
```

Bot demo (all AI — living: hunt + shove outward + dodge props; ghosts:
possess nearest useful prop and ram victims toward the void):
```
godot --path . minigames/dead_weight/dead_weight.tscn -- --dwbots --seed=5
```

Start the last N roster players as permanent ghosts (possession demo):
```
godot --path . minigames/dead_weight/dead_weight.tscn -- --dwbots --dwghosts=2 --seed=3
```

Screenshots (global harness `--shots` works; PNGs land in `verify_out/`):
```
godot --path . minigames/dead_weight/dead_weight.tscn -- --dwbots --dwghosts=2 --seed=3 --shots=380,560,740 --outdir=verify_out/dw
```

Balance sim (headless, 6x time_scale, prints tally, quits):
```
godot --headless --path . minigames/dead_weight/dead_weight.tscn -- --dwbalance=20 --seed=1
```

CLI args (after `--`): `--dwbots`, `--dwghosts=N`, `--dwbalance=N`,
`--dwrounds=N`, `--players=N`, `--seed=N`, plus global `--shots` / `--outdir`
/ `--quitafter`.

Import pass after adding files (run, exits clean):
```
godot --headless --editor --import --quit --path .
```

## Balance test (spec Risk: 1v1 + 1 ghost; living should win ~65%)

Harness: 2 living bots + 1 permanent ghost bot, 20 rounds, one process.
A round is "ghost-decided" if the poltergeist landed the decisive kill;
otherwise the living side won it (shove kill or the victim's own accident).
Bot logic runs on the physics tick, so the 6x fast-forward does not change
behavior, only wall-clock.

FINAL RESULT (DRIVE_FORCE=38, KNOCK_SCALE=1.0, KNOCK_MAX=24, KILL_SPEED=3.0):

```
--- seed 1 ---                          --- seed 7 ---
living-shove=8 ghost-kill=7 void=5      living-shove=2 ghost-kill=9 void=9
LIVING WIN % = 65.0%   PASS             LIVING WIN % = 55.0%   PASS
possessions=33 ghost_hits=94            possessions=38 ghost_hits=69
avg_round=12.1s                         avg_round=14.0s
```

Both seeds inside the 55-75% band; seed 1 sits exactly on the spec's ~65%.
The ghost is a genuine menace (~3.5 prop possessions and ~4 prop hits per
round) without out-scaling the living.

Tuning history (20-round runs, seed 1): DRIVE 78/K1.7 -> 25% living (ghost
oppressive); 47/K1.15 -> 45%; 40/K1.0 -> 55%; 36/K1.0 -> 70% (seed 7: 85%);
38/K1.0 -> 65% / 55% across seeds. Lamp ~0.6kg darts, wardrobe 8kg freight
train (same drive force, mass does the talking).

Two physics bugs were CAUGHT by this harness (both fixed):
1. Props seated on spawn corners catapulted fighters into the void at round
   start -> props now nudge off spawn corners at layout + 1.5s spawn grace
   teleports a falling fighter back instead of killing them.
2. Jolt tunneled fighters DOWN through the 0.5m floor on hard rams (deaths
   at mid-floor coordinates, free-fall velocity) -> floor is a 3m slab and a
   hard clamp guarantees a fighter over the floor footprint is never below
   its surface. Since the fix, every death in the logs is a clean edge fall.

Plus one flow bug caught by screenshots: an awaited 3s SceneTreeTimer for
the between-rounds delay never resumed after a slow-mo beat (survivor then
wandered off the lip on stale bot input). The delay is now tick-driven in
`_physics_process` and survivors are halted when the round resolves.

## MUST (v1 scope) — all done

- [x] Shove/hop sumo core — 5 m/s move, A = shove with knockback scaling
      with attacker speed (SHOVE_BASE 8 + 1.5x speed, 0.7s cd), B = hop
      (1.5s cd). 0.05s hit-pause + screenshake on landed shoves.
- [x] Edge-void deaths — glowing cyan gutter bars ring the 12x12 floor lip;
      falling past y=-5 kills; slow-mo beat (time_scale 0.32 for 0.4s) +
      Sfx splat/death + color burst + banner on every death.
- [x] Poltergeist possession with force control — free-fly ghost orb + omni
      light + wisps in owner color; hold A near a prop to possess (glow in
      ghost color, 5cm hover, wobble, wisp trail); move = central force
      scaled by DRIVE_FORCE vs prop mass; B releases with 4s cooldown.
- [x] Kill credits — possessed prop hits stamp the victim; if the victim
      dies before recovering (grounded + unstunned + slow), banner reads
      "THE CRATE (GOLD) CLAIMS BLUE" and the ghost earns +2 royalty
      currency_event. Living boots credit "X BOOTS Y INTO THE VOID".
- [x] Best-of-3 — ROUND n/3 label, everyone revives between rounds, props
      reset with darkened tint (dent +0.22 lerp toward charcoal per round).
- [x] Results contract — placements (every roster player), points,
      currency_events (royalty per ghost kill, grudge per death),
      highlights (kill lines + survivor streak), monuments ("Dead and
      Still Winning" at 3+ ghost kills). Emitted via report_finished();
      zero validation warnings in headless full-match run.
- [x] Seeded bots behind CLI arg — `--dwbots`; all rng from config.rng_seed;
      gameplay state (ground checks, credit windows) on the physics tick
      for reproducibility.

## SHOULD — all done

- [x] Prop mass tiers — lamp 0.6 / chair 1.6 / crate 2.4 / wardrobe 8.0;
      knockback = momentum-scaled so the wardrobe hits like a freight train.
- [x] CLAIMS banners — and when the kill ends the round, the kill line keeps
      the banner spotlight above "X SURVIVES ROUND n".
- [x] Wisp trails on possessed props (plus wisps on the ghost orb itself).

## Anti-grief

- [x] `prop_locked_by_spawn()`: props within 2m of any revival spawn are
      unpossessable for the first 3s of every round (checked inside
      `DWProp.can_be_possessed()`, which ghost bots also respect).

## Screenshots (committed in shots/, Godot-ignored; regenerate via commands above)

- `shots/screen_round_start.png` — ROUND 1 FIGHT! Luckiest Guy banner, attic
  diorama with rug + 12 props, glowing void gutter, scoreboard with ghost
  skulls for GOLD/MINT (`--dwghosts=2`).
- `shots/screen_possession_charge.png` — THE key readability shot: GOLD's
  possessed crate glowing gold, hovering, wisp trail arcing across the rug
  as it charges BLUE at the east lip; MINT wisps hunting RED at the north.
- `shots/screen_lamp_slam.png` — GOLD's glowing lamp (the dart tier) slamming
  into the RED/BLUE scrum at center rug.
- `shots/screen_claims_banner.png` — "THE CRATE (GOLD) CLAIMS BLUE / RED
  SURVIVES ROUND 1" in gold; scoreboard shows GOLD 2 pts + †1 royalty; BLUE's
  fresh ghost orb rising at the south lip.
- `shots/screen_round2_revive.png` — ROUND 2 FIGHT!: fighters revived at
  corners, props reset with darkened tint, scores carried over.

## Evidence log lines (headless, seed 5, --dwghosts=2)

```
DW_ROUND_START 1/3 t=0.5 ts=1.000
DW_DEATH round=1 t=3.4s RED BOOTS BLUE INTO THE VOID (player)
DW_ROUND_START 2/3 t=6.9 ts=1.000
DW_DEATH round=2 t=3.8s THE CHAIR (MINT) CLAIMS BLUE (ghost)
DW_ROUND_START 3/3 t=13.7 ts=1.000
...
DW_MATCH_OVER champ=RED pts=4        (with --dwrounds=1; no contract warnings)
```

## Known issues

- Headed runs are not frame-identical to headless runs with the same seed:
  the hit-pause/slow-mo timers wait in real time, so wall-clock jitter
  shifts physics alignment slightly. Gameplay-state determinism holds per
  physics tick; only FX timing drifts. Balance mode disables FX so its
  numbers are reproducible.
- Bot duels can stalemate to the 75s round cap when both living bots circle
  cautiously; the cap resolves it (survivors split placement points).
  Humans will not have this problem.
- Possessed-prop kill credit requires the prop to be moving >= 3 m/s at
  contact; a very slow wardrobe nudge that tips someone over the lip counts
  as THE VOID (accident). Arguably correct, noted for tuning at integration.

## Wishes

- Kenney/KayKit furniture GLBs (a real wardrobe silhouette would sell the
  freight train); the box/cylinder tiers are chunky and on-style meanwhile.
- A dedicated possession loop Sfx (spooky hum) — used "grudge"/"card" bank
  sounds for possess/release.
- Poltergeist-vision vignette for dead players' screens in shell splitscreen.
- Round-time "sudden death" shrink (gutter creeps inward) instead of a cap.
