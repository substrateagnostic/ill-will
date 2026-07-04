# THE ESTATE — anthology meta-layer design

*2026-07-04. Approved direction (Alex): The Estate, absorbing the show
format's simultaneous-phase mechanics, with Classic-plus scoreboard clarity
in the UI. Research basis: docs/design/03-board-research-digest.md.*

## One line

The board, hub, menu, and trophy room are ONE place: a shared estate the
players build, scar, and monument as they play — and it persists between
game nights.

## Design pillars

1. **Legible deviousness.** Every trap has an author's color, every effect
   is announced, every win condition is visible from minute one (the
   Pro-Rules lesson). Nothing hidden ever decides anything.
2. **Nobody ever waits.** Between-game phases are SIMULTANEOUS (everyone
   shops/places/bets at once, own cursor... hotseat v1: 20s timed stations,
   see Input note). Downtime is the genre's unsolved sin; we solve it.
3. **Suffering is capital.** Grudge accrues from deaths and losses and is
   the ONLY currency for auctions and sabotage. The player doing worst
   holds the most dangerous purse (nobody has built this formally).
4. **The estate remembers — across nights.** Monuments, gravestones,
   graffiti, and placed structures persist in a save file. Unshipped
   anywhere in the genre (Legacy games proved the appetite on tabletop).
5. **Classic scoreboard clarity.** One always-visible ladder: POINTS.
   No bonus-star ambushes. The winner was never a surprise, only a drama.

## The night loop (one session = one "night", 3/5/7 games)

1. **THE GROUNDS** (~90s, simultaneous): free-walk your KayKit character
   around the estate. Stations: the STALL (spend grudge: seeded trap tiles
   for the grounds paths, one-shot minigame items when minigames support
   them, cosmetic hats via handslot/head attachments), the BOOKMAKER (bet
   grudge on next game's winner, 2:1; house never profits — losing bets
   fund the pot), the SEEDBED (place your bought trap tile on a walkway —
   author-colored, fully visible, triggers on walkers in later Grounds
   phases: slip, launch, coin-scatter). Physics toys scattered (balls,
   a windmill). Shoving works. Returning after a lost game always yields
   something: +1 grudge minimum (the Hades lesson).
2. **THE AUCTION** (~20s): next minigame goes to grudge auction — open
   ascending bid at a podium; winner picks the game from 3 seeded options
   and putts... pays their bid into the pot. Tie/no-bid: trailing player
   chooses free (ROUNDS principle).
3. **THE GAME**: chosen minigame module runs via the contract. Estate pot
   (from bets/bids) pays out per placements.
4. **THE RECKONING** (~25s): results engrave the estate — points ladder
   animates (classic clarity), currency_events pay grudge/royalties,
   `monuments` from results get PLACED as statues by their owners,
   highlights get carved into the graffiti wall, minigame gravestones
   transplant to the memorial garden. Then back to The Grounds.

Night end: most POINTS wins the night → their VICTORY MONUMENT is erected
large (winner chooses spot + inscription, 24 chars). Estate save written.

## Persistence (the Legacy move)

`user://estate_save.json`: placed structures/monuments/graffiti/gravestone
records {kind, owner_name, color, transform, label, night_id, date}, night
history ledger. Next session loads it: last week's scars greet the players.
Cap visual clutter: oldest cosmetic scars fade to "weathered" tint after 3
nights; monuments never fade. `--fresh-estate` CLI for testing.

## Input (hotseat v1 honesty)

True simultaneity needs per-player devices (PlayerInput ready). Hotseat v1:
The Grounds runs as ONE shared 90s timer with all four characters walkable
by whoever holds a device; mouse player gets click-to-walk. Stations are
per-player gated (your character at the stall = your purse). If only a
mouse exists: 20s rotating station turns, keep the clock visible. Gamepads
make it fully simultaneous with zero design change.

## UI (Classic-plus clarity)

Persistent top bar: POINTS ladder (rank order, big), grudge purses (♠),
night progress (GAME 2 OF 5), pot size. The Reckoning shows one screen:
placements → points animation, currency events as ticker lines, no hidden
adjustments, ever.

## v1 scope

MUST: estate scene (small + dense: one lawn, stall, podium, memorial
garden, graffiti wall, monument plinths), night loop driving Par v2 +
any finished minigames via contract, grudge economy + auction + betting,
reckoning screen, persistence save/load, hotseat input plan above.
SHOULD: seeded trap tiles on walkways, physics toys, cosmetic hats,
weathering.
WON'T (v1): online, estate expansion/tiles beyond fixed plinth slots,
narrative events, spectator/audience play.

## Build ownership

The Estate is the anthology's heart — Fable-tier work (me or a directed
Fable subagent), built against the contract with mock minigame results
first (a debug "instant minigame" that returns canned results) so the loop
is testable before all minigames land.
