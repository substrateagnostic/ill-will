# SWAP MEET — minigame spec (v1)

*Contract: docs/specs/anthology-module-contract.md. Folder: `minigames/swap_meet/`.*

## One line

A bumper-kart race where NOTHING does damage — every hit SWAPS your
position with the victim's. First place is a bullseye you wear.

## Loop

One race, 3 laps, ~2.5 min. 2-4 players simultaneous (move + A + B).

- Track: wide toy-scale circuit (fits our diorama style: table-top race
  track, cream rails, striped-felt infield), one shortcut ramp, two
  pinch-point hazards (windmill from Par's library welcome, non-lethal:
  knocks you sideways). Fixed overhead-3/4 camera showing the WHOLE track
  (party readability > chase cam).
- Karts: move.x steers, auto-throttle forward (party-simple), move.y
  brakes/reverses at low speed. **B = drift-boost** (hold to drift, release
  for a boost proportional to drift time, 2s cd).
- **A = throw SWAP ORB**: lobbed forward-arc projectile (1.2s flight,
  generous 0.6m radius). Hit -> you and the victim INSTANTLY trade
  positions+velocities with a teleport flash + "SWAPPED!" banner showing
  both names. 3s cooldown. Orbs can hit ANYONE including 4th hitting 1st
  from across a pinch point.
- **GOLDEN ORB**: one pickup spawns mid-track every 40s: next throw swaps
  you with the CURRENT LEADER wherever they are. The comeback verb.
- Checkpoint gates award +1 point each (transparent running score), finish
  order 5/3/2/1 on top.

## Results contract

Placements by finish (DNF by distance). currency_events: royalty +1 per
swap that gained you >=1 position, grudge +1 each time you got swapped OUT
of 1st. highlights: cruelest swap (biggest position delta), golden orb
victims. Monument "The Pickpocket" for 5+ gaining swaps.

## Feel targets

- Swap must read INSTANTLY: freeze 0.08s, dual teleport beams in both
  players' colors, camera shake, both name tags flash at swap points.
- Kart feel: forgiving — low top speed, high steering authority, rubber
  rails (bounce, never stick). A 6-year-old should finish laps.
- Leader dread: 1st place kart gets a subtle golden crown + trailing
  sparkle so everyone knows who to shoot.

## v1 scope

MUST: 3-lap circuit, auto-throttle karts, drift-boost, swap orbs with true
position+velocity exchange, golden orb, checkpoints/scoring, results,
seeded bots (racing line + opportunistic throws). SHOULD: shortcut ramp,
windmill hazard, crown on leader. WON'T: multiple tracks, items beyond the
two orbs, damage of any kind.

## Risks & tests

- Swap-chain chaos (A swaps B mid-air etc.): swaps are atomic; 1s swap
  immunity after being swapped (prevents ping-pong).
- Bot race must complete: 5 seeds, all bots finish 3 laps < 3min, print
  lap times; at least 3 swaps occur per race on average.
