# GREED INC. — minigame spec (v1)

*Contract: docs/specs/anthology-module-contract.md. Folder: `minigames/greed/`.*

## One line

A gilded pot in the center of a vault fills with coins forever; anyone can
grab it and run for their corner chute — but carrying it makes you slow,
glowing, and the most popular person in the room.

## Loop

3 rounds x 90s. 2-4 players simultaneous (move + A + B).

- Arena: vault/money-pit diorama ~14x14m, four color-coded exit chutes
  (one per player, in corners), a few crates for cover. House diorama
  style: warm wood, chunky props.
- The POT (center pedestal): value ticks up +1 coin/1.2s, plus a +5 burst
  every 15s (fanfare + coin geyser so greed is audible). Pot value shown
  huge above it.
- **A near pot (hold 0.6s) = GRAB.** You become the CARRIER: -20% speed,
  golden glow + coin-leak particle trail; pot value freezes.
- **Carrier reaches OWN chute = BANK**: pot value -> your points, big
  payout ceremony, pot resets to 5.
- **A = tackle** (non-carriers): hitting the carrier -> drop! Pot returns
  to a neutral spot where it landed, 20% of its value scatters as floor
  coins (anyone picks up, +1 each), carrier stunned 1s. Tackler gets +1
  royalty ("mugging pays").
- **B = dash** (everyone, 1.4s cd, i-frames 0.2s). Carrier dash costs 2
  pot coins (leak burst) — escape is possible but priced.
- The greed clock IS the game: grab early = safe crumbs; let it fatten =
  jackpot scramble. If nobody banks in a round, the pot value at whistle
  scatters entirely (nobody scores it — greed punished).

## Results contract

Placements by banked points. currency_events: royalty +1 per forced drop,
grudge +1 per round where you banked 0. highlights: biggest bank, most
drops caused. Monument "The Banker" for a 30+ single bank.

## Feel targets

- Carrier must FEEL hunted: glow, leak trail, distinct footstep audio, all
  player indicators point at them (small arrows at screen edge).
- Tackle: 0.05s hit-pause + screenshake + coin burst. Bank: rain of coins
  into the chute + chute lights up + Sfx match_win sting.

## v1 scope

MUST: pot growth/grab/carry/drop/bank, tackles, dash, floor-coin pickup,
3 rounds, results, seeded bots (greedy: grab at random thresholds; mugger:
chase carrier). SHOULD: burst geysers, edge arrows, crates. WON'T: items,
multiple pots, arena variants.

## Risks & tests

- Turtle camping own chute waiting: pot spawns EQUIDISTANT; carrier speed
  penalty tuned so interception is possible from any chute (bot test:
  carrier from grab to farthest chute must be catchable by a dashing
  chaser starting at an adjacent chute >=60% of runs; print tally).
- Stun-lock: 1s tackle immunity after being dropped.
