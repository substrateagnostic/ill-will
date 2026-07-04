# MOWER MAYHEM — minigame spec (v1)

*Contract: docs/specs/anthology-module-contract.md. Folder: `minigames/mower/`.*

## One line

Riding mowers on the estate's own back lawn: mow stripes in your color,
ram rivals to steal their work — Splatoon coverage meets bumper cars,
in our own mow-stripe visual language.

## Loop

One round, 2 minutes. 2-4 players simultaneous (move + A + B).

- Arena: an unmowed 16x12m lawn (TALL grass texture/mesh blades),
  scattered obstacles (birdbath, flowerbeds = no-mow zones, the estate's
  gravestone props as bumpers — reuse gravestone.tscn, it's on-brand).
- Mowers: chunky ride-on mowers (box+cylinder build in house palette, one
  KayKit character seated per mower). move = steer+throttle (tank-simple:
  stick direction = desired heading, auto-forward). Your mower cuts a
  0.9m-wide stripe: cut cells convert to YOUR COLOR (tinted mowed texture).
- Coverage IS score: live % meter per player across the top (transparent,
  Splatoon-style). Re-mowing enemy cells steals them (slightly slower cut).
- **A = RAM horn**: short forward lunge (1.5s cd). Mower-to-mower contact
  during ram: victim spins out 1.2s AND 6 of their cells nearest impact
  flip to yours ("turf theft" burst). Royalty +1 per ram-spinout.
- **B = boost** (fuel gauge, drains, regens when not boosting). Boost
  mowing cuts a WIDER stripe (1.3m) — risk: less steering.
- Final 20s: "OVERTIME" — all cuts count double-width, music sting, meters
  pulse.

## Results contract

Placements by final coverage %. points = round(coverage% / 5).
currency_events: royalty per ram-spinout, grudge +1 if you finish last in
coverage. highlights: biggest turf theft, longest unbroken stripe.
Monument "Groundskeeper" for >40% coverage.

## Feel targets

- The lawn must READ as our estate: same green palette, mow-stripes
  aesthetic literally becoming gameplay. Cut vs uncut contrast strong;
  each player's mowed tint distinct but grass-plausible (tinted stripes,
  not paint).
- Mowing feel: constant satisfying particle spray of clippings + soft
  engine put-put per mower (pitch varies per player).
- Implementation guidance: grid-based coverage (e.g. 64x48 cells) driving
  one shader/texture — do NOT spawn per-cell nodes. Cell flips batched.

## v1 scope

MUST: grid coverage + tinted rendering, mow/steal, ram + turf theft,
boost, live meters, 2-min round + overtime, results, seeded bots (space-
filling paths + opportunistic rams). SHOULD: flowerbed no-mow zones,
gravestone bumpers, overtime double-width. WON'T: powerups, multi-round,
lawn variants.

## Risks & tests

- Perf: texture writes batched (Image.set_pixel into ImageTexture.update
  max once/frame). Bot soak: full 2-min, 4 mowers, no frame >12ms print.
- Coverage math: sum of all player % + unmowed % == 100 +/- 0.5 (assert,
  print at round end).
