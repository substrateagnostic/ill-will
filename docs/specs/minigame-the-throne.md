# THE THRONE — minigame spec (v1)

*Contract: docs/specs/anthology-module-contract.md. Folder: `minigames/throne/`.
NOTE: balance-sensitive — build to spec, then expect a director tuning pass.*

## One line

One throne, four tyrants-in-waiting: whoever sits SCORES and wields court
powers but cannot move — everyone else must ally to drag them off, then
instantly betray each other for the empty seat.

## Loop

One continuous 2.5-min match. 2-4 players simultaneous (move + A + B).

- Arena: throne room diorama ~12x12m: central dais (3 steps) with THE
  THRONE, four pillars, red carpet, torch lighting (warm house style).
- Challengers (not seated): move freely, **A = shove** (Par-family
  knockback, 0.7s cd), **B = dash**.
- **Sitting**: touch the empty throne = seated (0.4s ceremony, crown
  appears). Seated player: score +1/second (the ONLY way to score),
  CANNOT move, and gets court powers:
  - **A = DECREE BLAST**: radial shockwave from the dais knocking
    challengers down the steps (1.8s cd, gets 0.2s slower each use while
    seated — tyranny fatigue, transparent bar).
  - **B = SUMMON GUARD**: drops a temporary barrier wall segment on one
    dais approach (one at a time, 6s life, 4s cd).
- Dethroning: the seated player has a visible GRIP meter (3 hits). Each
  challenger shove that connects with the seated player drains 1 grip.
  At 0: they're LAUNCHED off the dais (big ragdoll-ish fling + crown
  drops), 2s cooldown before they may re-sit. Grip regens 1 per 8s.
- The social engine: throne-seconds tick loudly (coin counter sound);
  everyone can SEE the leader's total climbing, so alliances form against
  whoever's ahead — and dissolve at the moment of vacancy.
- Last 30s: throne scores +2/second ("succession crisis"), announced.

## Results contract

Placements by throne-seconds. currency_events: royalty +1 per dethroning
blow (the shove that empties the seat), grudge +1 per full minute with 0
throne time (announced: "the court pities X"). highlights: longest reign,
kingslayer count. Monument "The Usurper" for 3+ dethronings.

## Feel targets

- Reign must feel POWERFUL but doomed: decree blast is huge and satisfying
  but the fatigue bar tells everyone the walls are closing in.
- Dethrone fling: slow-mo beat + crown physically bounces down the steps.
- Readability: seated scoring = golden particle stream rising from throne.

## v1 scope

MUST: sit/score/powers, grip + dethrone fling, shove/dash, fatigue,
succession crisis, results, seeded bots (challengers gang the seat, then
scramble). SHOULD: guard barriers, crown physics, pity grudge. WON'T:
multiple thrones, items, room variants.

## Risks & tests

- Turtling with guards: barrier cannot fully enclose (min one approach
  always open — assert in placement logic).
- Bot fairness probe: 4 bots, 5 seeds — no single bot exceeds 55% of total
  throne time (else fatigue/grip numbers need tuning; print shares).
