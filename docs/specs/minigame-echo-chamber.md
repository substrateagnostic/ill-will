# ECHO CHAMBER — minigame spec (v1)

*Read anthology-module-contract.md first. Folder: `minigames/echo_chamber/`.*

## One line

Top-down arena brawl where **every previous round replays as ghosts**: by
round 5 the arena teems with everyone's recorded past selves, still fighting
— and your echoes earn YOU points when they land hits in the present.

## Loop

5 rounds × 45 seconds. 2–4 players, simultaneous (PlayerInput move + A + B).

- Arena: one circular platform (~16m), simple pillars for cover. Camera:
  fixed overhead-tilted, whole arena visible.
- Player: capsule-bot or KayKit character (Running_A anim while moving),
  move via `get_move`, **A = swing** (short-range 120° melee arc, 0.5s
  cooldown, knockback + 1 damage), **B = dash** (0.25s burst, 1.2s cooldown,
  i-frames during dash).
- 3 HP per life. Death: respawn after 2s at arena edge (never eliminated).
- **The twist**: every round, record every player's inputs+transform at 30Hz.
  Next round, ALL prior rounds replay simultaneously as translucent ghosts
  in their owner's color (shader: 55% transparency + color tint). Ghosts
  deal damage with their recorded swings. Ghosts CANNOT be damaged (they
  already happened).
- **Bounty**: when YOUR ghost (any round) damages a live player, you earn
  +1 point NOW and the banner credits it: "PAST BLUE STRIKES AGAIN".
- Round score: +2 per live hit, +1 per ghost hit credited, +3 round survival
  bonus if you died zero times that round.
- Round 5: arena shrinks 30% (outer ring falls away, fall = death+respawn
  center at half HP).

## Scoring → results

- placements: total points desc. points: raw totals.
- currency_events: royalty +1 per ghost-hit ("your past worked for you"),
  grudge +1 per round in which a player died 2+ times.
- highlights: best ghost moment ("ROUND-2 GOLD killed present GOLD").

## Feel targets (verify with screenshots + a movie clip)

- Move speed 5 m/s, dash 11 m/s. Swing must feel INSTANT (<50ms to hitbox).
- Ghost density readable: max 12 ghosts on screen at round 5 with 4 players
  — if unreadable, thin oldest rounds to 60% playback opacity and no trails.
- Recording playback must be deterministic: replay transforms directly
  (don't re-simulate physics).

## v1 scope

MUST: recording/replay, melee+dash, HP/respawn, bounty credits, 5 rounds,
banners, results contract, self-play hook (bots that wander+swing on a seed).
SHOULD: shrink round, hit-pause (0.05s freeze on hit), KayKit avatars.
WON'T (v1): weapons/pickups, arena variety, online.

## Risks & tests

- Replay drift: assert ghost position at round end == recorded final ±0.01.
- Perf: 12 animated ghosts + 4 players — use MultiMesh or disable ghost
  shadows if frame time >8ms (verify with --shots during a 4-player round 5).
