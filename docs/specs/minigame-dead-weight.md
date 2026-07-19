# DEAD WEIGHT — minigame spec (v1)

*Read anthology-module-contract.md first. Folder: `minigames/dead_weight/`.*

## One line

Sumo-brawl elimination where **the dead become poltergeists** who possess
the furniture — the genre's "dead = bored" sin inverted: the dead are the
most dangerous people in the room.

## Loop

Best-of-3 rounds, ~75s each. 2–4 players simultaneous (move + A + B).

- Arena: a cozy attic/den diorama (fits house style): a 12×12m room floor
  with PHYSICS PROPS scattered — crates, chairs, a wardrobe, lamps (simple
  box/cylinder RigidBodies, 8–14 of them; Kenney/KayKit props welcome).
- Living players: KayKit chars, move 5 m/s, **A = push** (short shove,
  knockback scales with your speed, 0.7s cd), **B = hop** (small jump over
  low props, 1.5s cd). No HP: you die by being knocked into the
  **hazard ring** — the room's edge is a glowing void gutter (fell = dead).
- On death you become a **poltergeist**: free-fly camera-light ghost in your
  color. Hover any physics prop, hold A to POSSESS it (prop glows your
  color, spooky wobble), then you CONTROL the prop: move applies force
  (throw yourself at the living!), B = drop possession (4s possession
  cooldown). Possessed props hitting a living player at speed knock them
  back hard.
- Living can shove props back; a prop that kills someone displays its
  possessor's name: "THE WARDROBE (RED) CLAIMS BLUE".
- Round ends when one living player remains. They earn +4; elimination
  order 2/1/0. Poltergeist kills: +2 each to the ghost.
- Between rounds everyone revives; props reset with accumulated dents
  (visual tint darkening only, v1).

## Scoring → results

- placements: total points. currency_events: royalty +2 per poltergeist
  kill ("dead and still winning"), grudge +1 per death.
- highlights: best prop kill line, longest survivor streak.

## Feel targets

- Poltergeist possession must feel POWERFUL but heavy: prop force scales
  with prop mass; a lamp is a dart, the wardrobe is a slow freight train.
- Living movement snappy; shove has 0.05s hit-pause + screenshake.
- Readability: possessed props glow + hover 5cm + emit trailing wisps in
  ghost color.

## v1 scope

MUST: shove/hop sumo core, edge-void deaths, poltergeist possession with
force control, kill credits, best-of-3, results contract, seeded bots
(living: wander+shove; ghosts: possess nearest prop and ram).
SHOULD: prop variety mass tiers, "CLAIMS" banners, wisp trails.
WON'T (v1): destructible props, room variants, item pickups.

## M4 addendum — BRACE / DASH / SUPER SMASH (playtest-requested, producer-ruled)

Living players kept `move + A + B` (no third button — the anthology's own
hard budget) but gained tap/hold escalation, same shape as Echo Chamber's:
**A** hold ~1.7-1.9s charges a **SUPER SMASH** (radial shove, no facing gate,
long cooldown, dropped if hit while charging); **B** hold ≥0.15s **BRACES**
(rooted, resists knockback, stamina-capped, briefly MORE vulnerable right
after release); a quick double-tap of a MOVE direction **DASH**es (short
burst, no i-frames, no phase-through). The ghost furniture-fling is
unchanged — these are counterweight tools for the living, not a nerf to the
dead. Full spec + receipts: `minigames/dead_weight/VERIFY.md` §"M4 MOVESET".

## Risks & tests

- Balance: ghost force tuned so 1 ghost ≈ 60% threat of 1 living player
  (test: 1v1+1ghost bot sim — living should win ~65%).
- Possession griefing (camping spawn): props cannot be possessed within 2m
  of a revival spawn during first 3s of a round.
