# TILT — verification record

Spec: `docs/specs/minigame-tilt.md`. All commands run from the repo root
(Godot 4.6.2, Windows). `--fixed-fps 60` pins the render-frame ↔ game-time
mapping so the frame numbers passed to `--shots=` land on the logged events
(the game sim itself is physics-tick deterministic per seed either way —
the same seed reproduces the same falls/kills to the hundredth of a second
headless or headed).

## Commands run

### 1. Import (after adding files)

```
godot --headless --editor --import --quit --path .
```
Clean; TiltPlatter/TiltPawn/TiltSeagull/TiltBots registered, no script errors.

### 2. Spec "Risks & tests" — tilt stability (idle)

```
godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=idle --seed=1
```
4 symmetric pawns, zero input, 30 s. Also injects a tilt-velocity impulse at
t=5 s to prove the spring-damper settles instead of ringing (grace window
t=5–9 s). Sampled every second; criterion |tilt| < 3°.
**RESULT: PASS** (tilt 0.000° throughout; impulse peaks 0.23° at the t=6
sample and decays to 0.004° by t=8). Exit code 0 (1 on fail).

### 3. Spec "Risks & tests" — edge slide

```
godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=edge --seed=1
```
Pawn 0 placed at r=6.55 (rim), platter force-tilted to 20° toward it, zero
input. The manual slide model (never floor friction) must carry it off.
**RESULT: PASS** — slid off at t=0.83 s (r 6.55 → 6.61 with slide 0.49 m/s at
the 0.5 s sample, overboard at 0.85 s as the forced tilt finished ramping).

### 4. Full seeded self-play match (headless soak)

```
godot --headless --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- --tiltbots --seed=7 --roundtime=30 --rounds=3 --quitafter=7400
```
Event log (`TILT_EVT`) shows per round-1: shove-kill with royalty credit at
t=11.0 (17° tilt), gull spawn + 3 guano direct hits, slide-death at max tilt
22.3°, sudden death at 23.9 (pin rises, limit 30°), last-stand round end.
Round 2: timeout split with 4 survivors riding a 30° sudden-death platter.
Round 3: second royalty kill + timeout. `match_end` emits the full results
contract (placements incl. a 13-13 tie broken by earlier index, points,
6 currency_events, 3 highlights). 2-player smoke (`--players=2 --seed=3
--roundtime=15 --rounds=1`) also completes with valid results.

### 5. Screenshot run (headed) + art pass

```
godot --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- --tiltbots --seed=7 --roundtime=30 --rounds=3 --shots=90,420,695,750,875,1335,1400,1495,1655,1680,2255,3455,4800,5490,5850,6100
```
PNGs land in `verify_out/` (gitignored). What each shows (all inspected):

| Shot | Shows |
|---|---|
| 0090 | Round-1 intro: platter target-rings + dark hub, 4 KayKit pawns at color-marked spawn quadrants, ROUND banner, timer, scoreboard, controls hint |
| 0420 | Early play: pawns converging, emissive identity rings (red/gold/mint/blue) readable, platter shadow on the ocean |
| 0695 | "RED SHOVED BLUE OVERBOARD!" banner, BLUE mid-air past the rim (royalty kill) |
| 0750 | BLUE's ocean splash |
| 0875 | BLUE reborn as seagull (white gull, blue wingtips) + white guano slip-splat on the disc under GOLD |
| 1335 | 17.6° tilt: disc visibly pitched, rim glow hot, red warning lamp at the low side, red timer |
| 1400 | MINT sliding off at 22.3° (max tilt, no shove — pure physics death) |
| 1495 | "SUDDEN DEATH / THE PIN RISES" banner; gull with bomb falling mid-air; floating gold coins near hub |
| 1655 | 30° sudden death: risen pin visible, two survivors clinging near the rim over the pulsing lamp, gull shadow cast on the disc |
| 1680 | Round-end banner "+4", scoreboard updated (GULL tags) |
| 2255 | Round 2 at 14.7°: warning-lamp puddle, mid-shove Hit reaction pose |
| 3455 | The money shot: all four survivors piled on the low rim at 30°, brace ring glowing, coin stacks on backs |
| 4800 | "GOLD SHOVED MINT OVERBOARD!" — MINT ejected across the lamp zone |
| 5490 | Round-3 sudden death with gull harassment (guano_hit logged at 5484) |
| 5850 | Round-3 timeout split banner |
| 6100 | "RED WINS TILT!" match banner; timer hidden; survivors held on the disc |

Iterations made from reading the shots: coins enlarged + floated + brightened
(were invisible sunk into the ring layers), identity rings enlarged/emissive,
warning lamp enlarged and pulled inside the rim, pawn separation widened,
stale HUD timer hidden outside rounds, and a real bug: pawns kept sliding
during ROUND_END banners and walked off into thin air past the rim (match-end
screenshot showed an empty tilted platter) — non-PLAY phases now freeze slide
and clamp to the disc.

Gameplay tuning driven by the soak logs: the first build produced a
zero-death center mosh pit (knockback decayed before it carried anyone
anywhere). Fixes: 0.5 s stagger on being shoved (knock carries, breaks
instant-retaliation duels), shove power 7.5, slide decay 1.5→0.9 so max tilt
is genuinely inescapable without brace, tilt gain 2.9°/torque, sudden-death
gain 1.6×.

## MUST checklist (spec v1)

- [x] Tilt-from-weight model — torque sum of players+loose coins → 2nd-order
      spring-damper (ω=4.2 → ~0.4 s lag, ζ=0.55 → slight overshoot), max 22°
      (30° sudden death), applied kinematically (platter.gd)
- [x] Move / shove / brace — 4.5 m/s ± sin(tilt) slope; A shove 0.8 s cd,
      forward cone 1.7 m/55°, stagger+knockback; B brace 2 s / 3 s cd,
      no slide but rooted (0.35× shove resistance)
- [x] Coins = mass = points — +8% mass, +1 point at pickup, visible back
      stack, worse footing (decay & static threshold shrink per coin)
- [x] Falls — platter-local kinematics, overboard past r=6.9, ballistic drop,
      splash, slow-mo + shake + banner
- [x] Seagull mode — fallen players fly freely, A = 1 guano per 4 s, slip
      zones (4 s, friction≈0) + direct-hit stagger; dead players stay dangerous
      (logs: BLUE's gull scored 4 direct hits in the soak match)
- [x] Best-of-5 — 5 rounds × 60 s default (config.rounds clamps 1–5;
      practice → 1; `--rounds/--roundtime` for verification)
- [x] Results contract — placements (all roster, ties by index), points,
      currency_events (grudge per fall, royalty within 1.5 s of shove
      contact), highlights, optional monument; emitted via report_finished()
- [x] Seeded self-play bots — TiltBots, personalities + decisions from
      rng_seed-derived streams; deterministic (verified: identical event
      timeline headless vs headed for seed 7)

## SHOULD checklist

- [x] Sudden death at 75% of round (45 s of 60) — pin rises 1.2 m, tilt limit
      +8°, gain 1.6×, coins stop spawning
- [x] Guano slip zones
- [x] Coin back-stacks
- [x] House juice: Sfx bank (bumper=coin bell, invalid=klaxon >14°, splat/
      death/round_over/match_win/confirm/grudge), screenshake, slow-mo beat,
      Luckiest Guy banners, confetti, camera roll ≤3° with the platter

## Standalone / shell behavior

- Root scene `minigames/tilt/tilt.tscn` extends Minigame; shell calls
  `begin(config)`; double-begin guarded.
- Standalone: if begin() not called 0.5 s after _ready, self-starts with
  4 players (GameState.PLAYER_COLORS/NAMES, KayKit Barbarian/Knight/Mage/
  Rogue), `--seed=N` or 1, PlayerInput.auto_assign; players landing on
  device -3/-99 get bots automatically so nobody is a statue.
- No writes to GameState, no scene changes, no randomize()/Date — all RNG
  from config.rng_seed (game / fx / bot streams).

## Known issues

- Center-huddling is a strong defensive strategy for bots between coin runs;
  coins, guano and shove-stagger counter it, but two max-cautious bots can
  still turtle to a timeout split round (by design the split pays less than
  a win: 3/3 vs 4).
- Pawns lean with the platter (transform composed from the disc basis) but
  do not counter-lean; at 30° it reads as "clinging", which is the joke.
- Falling pawns keep a generic tumble + Jump_Idle flail; no ragdoll.
- Wizard hats (Mage) partially occlude that player's coin back-stack from
  the fixed camera; the scoreboard carries the same info.
- Camera frame numbers for `--shots` require `--fixed-fps 60` to be exactly
  reproducible; without it Windows vsync may drift between 60/144 Hz.

## Wishes (assets that would elevate it)

- A real seagull model + flap animation (gull is primitives; reads fine at
  distance but a KayKit-style bird would be lovely).
- A "splash" water sfx (using impactPunch as splat) and a wind/creak loop for
  high tilt; a proper klaxon (error_004 is serviceable).
- Kenney coin-pickup jingle distinct from impactBell.
- A crown prop for the match winner (especially when the winner is a gull).
