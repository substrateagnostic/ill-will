# LAST WILL — minigame spec (v1)

*Contract: docs/specs/anthology-module-contract.md. Folder: `minigames/last_will/`.*

## One line

Survival gauntlet over the void where dying is a POWER: every eliminated
player drafts a will — a blessing bequeathed to one survivor and a curse
to another. The dead decide who wins; the living audition for their favor.

## Loop

Best-of-3 rounds, ~60s each. 2-4 players simultaneous (move + A + B).

- Arena: floating chapel-yard platform over dusk void (house style, stone
  + lanterns), shrinking in 2 rings as the round progresses. Hazard waves
  telegraph then sweep (a windmill-blade pendulum, a rolling boulder
  spawner alternating sides).
- Living: **A = shove**, **B = hop** (gap-hop over the boulder). No HP:
  void or squish = eliminated for the round.
- **THE WILL (the twist)**: on elimination the game PAUSES 6s for the
  deceased (their pick, everyone watches — theater!): they draft from 3
  cards, then choose targets:
  - BLESS one survivor: shield (1 hit), swiftness (+20% 10s), or a coin
    (+1 point) — card-dependent.
  - CURSE another: sluggish (-20% 8s), butterfingers (shove disabled 6s),
    or haunted (a wisp chases them 8s, contact = stumble).
- After willing, the dead linger as spectral onlookers at the platform
  edge (Lie/Sit idle poses) and every 10s may send a GUST (small nudge,
  A to aim-release) — never out of the game.
- Round scoring: survival order 4/2/1/0 (2P: 3/0). **Puppetmaster bonus**:
  if the player YOU blessed wins the round, you get +2 ("your champion").

## Results contract

Placements by total. currency_events: royalty +2 per puppetmaster bonus
("the dead hand moves the world"), grudge +1 per elimination. highlights:
decisive curses, champion outcomes. Monument "Kingmaker" for 2+
puppetmaster bonuses in one match.

## Feel targets

- The will-drafting pause is the SHOW: dramatic vignette, deceased's
  portrait+color frames the screen, card choice big and readable, target
  selection with a pointing skeletal hand cursor. Sfx: bong + quill
  scratch (use grudge/card bank sounds).
- Blessings/curses must be LOUD when they land: full banners ("RED BLESSES
  MINT — SWIFTNESS", "AND CURSES GOLD — BUTTERFINGERS").

## v1 scope

MUST: shrinking platform + 2 hazard types, shove/hop, elimination -> will
draft (3 cards, bless+curse targeting), effects listed above, ghost gusts,
best-of-3, puppetmaster bonus, results, seeded bots (survive; will-draft
random-but-spiteful: curse the leader). SHOULD: spectral onlooker poses,
haunted wisp. WON'T: more card types, arena variants, team wills.

## Risks & tests

- 2P degenerate case (one death = round over before will matters): in 2P,
  the will still fires (bless the survivor or curse them for next round —
  curses may carry into next round's first 8s; implement carry-over).
- Kingmaking salt is the POINT, but cap: each player may receive max 1
  active blessing + 1 active curse simultaneously (newest replaces).
- Bot round must produce >=2 wills per round on average across 5 seeds
  (print tally) or hazards need more teeth.
