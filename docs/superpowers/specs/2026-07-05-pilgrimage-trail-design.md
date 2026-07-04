# THE PILGRIMAGE TRAIL — estate progression design

*2026-07-05, night shift. Response to Alex's ask: Mario-Party-style
board-as-progression, turn-based/asynchronous (bio-break friendly), with
visible gameplay/status — pushed through our own thesis.*

## The idea in one line

The leaderboard becomes literal terrain: a trail of stepping-stones winds
up the estate hill to the Manor, each player's pawn-statue physically
advances by the points they earn, and the whole room can read the state of
the night from across the couch — no numbers required.

## Why this shape (design reasoning)

Mario Party's board does three jobs: pacing (breather between games),
progression drama (positions change), and status (you can SEE who's
winning). Its failure mode is the fourth thing it does: dice-walk tedium
and luck resentment. The Trail keeps the three jobs and deletes the dice:
**movement is never rolled, it is earned** — stones advanced = points
scored in the last game (+ bonuses). Transparent, announced, zero luck.
The Reckoning becomes a watchable parade (pawns walking their stones one
by one with sfx ticks) — a natural bio-break moment that still rewards
watching. Asynchronous by construction: nobody inputs anything during
advancement.

## Structure

- **Trail**: ~26 stones spiraling up a raised hill to the MANOR (the
  castle folly, promoted). Win the night = first to the Manor gates, or
  furthest when the night's game cap hits.
- **Pawns**: per-player statuettes (player color, name plaque). Live on
  the trail all night; persist visually during Grounds (status is ambient).
- **Advancement** (during Reckoning): stones = points earned in the game
  just played (placement points + royalties). Announced line by line.
- **Stations** (every ~6 stones, landing on or passing):
  - **SHRINE**: choose one night-blessing (+1♠ per Reckoning, or bet
    payouts +1). One per night per player.
  - **TOLLGATE**: you now own it — every player who passes later pays you
    1♠ (the trail itself becomes a grudge engine).
  - **WORKSHOP**: your estate trap tiles are free for the rest of the night.
- **Summit persistence**: night champion's statue is erected AT the Manor
  gates permanently (replaces the generic plinth-row placement for
  champions; plinths remain for minigame monuments).

## Interaction with existing systems

- Points ladder stays in the top bar (Classic-plus clarity) — the trail is
  its spatial mirror, not a replacement.
- Grudge/auction/betting/tiles unchanged. Tollgates and shrines feed the
  same grudge economy.
- Night length: default becomes "first to Manor" with game-cap fallback
  (config --night=N still caps).

## THE SABOTEUR (separate, opt-in, LATER — sketch for discussion)

Alex's Among Us instinct, shaped to our bones: an optional toggle where
each Grounds phase one secret player is the Saboteur (rotating, seeded).
They receive a micro-task on the grounds ("brush past three lanterns",
"stand on a rival's trap tile for 2s") to complete UNSEEN. At Reckoning,
one communal accusation vote (we already have voting UI patterns):
caught -> saboteur pays the pot; wrong -> accusers pay the saboteur.
Deliberately small: one bluff, one vote, no elimination — a spice layer,
not a mode takeover. NOT building yet; needs Alex's read on whether social
deduction belongs in the same night or as a separate party mode.

## v1 build scope (tonight)

MUST: trail geometry + pawns, advancement parade in Reckoning, Manor win
condition (+ fallback cap), TOLLGATE stations (2 of them — proves station
teeth), champion statue at gates, save/load of champion statues.
SHOULD: SHRINE (one blessing type), advancement tick sfx, station banners.
LATER: WORKSHOP, Saboteur, trail weathering.
