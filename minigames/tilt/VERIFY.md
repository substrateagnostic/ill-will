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

## v1.1 — SHOVE CLASH (skill counter)

One mechanic added: shoves now have a **0.12s windup** (avatar 1.06x scale
pulse + punch anim starts early + quiet card-flick tell; total time-to-hit
0.12s, under the 0.2s budget). If two pawns shove EACH OTHER within a
**0.25s window** — each inside the other's 55°/2.05m cone at the moment of
landing — the shoves **CLASH** instead of resolving: both take **40%
knockback** pushed apart along the line between them, both staggered
**0.3s** (no instant re-shove), **no royalty for either** (`last_shover`
untouched), gold spark burst + expanding white shock ring at the midpoint,
`Sfx.play("bumper")` clang, rising "CLASH!" Label3D floaty (Luckiest Guy).
Blindside shoves stay uncounterable — a defender's cone can't contain an
attacker behind them, so the mutual-cone requirement is itself the
backstab rule. Bots got a matching *occasional* counter-reflex: if they see
a windup aimed at them (attacker within 105° of their facing), they square
up and answer ~25–35% of the time (~50% when cornered past r=4.6), with a
rare last-ditch brace at the rim when their shove is on cooldown.

### Verification commands (all re-run on final code)

```
godot --headless --editor --import --quit --path .                                   # clean
godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=idle --seed=1  # PASS (exit 0)
godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=edge --seed=1  # PASS, off at t=0.83s (same as v1)
godot --headless --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- --tiltbots --seed=N --roundtime=30 --rounds=3 --quitafter=7400
godot --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- --tiltbots --seed=5 --roundtime=30 --rounds=3 --shots=2450,2451,2452,2456
godot --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- --tiltbots --seed=7 --roundtime=30 --rounds=3 --outdir=verify_out/s7 --shots=4796,4836,4845,4900
```

### Event-log evidence (TILT_EVT)

Clash lines carry both radii so rim context is auditable:

```
TILT_EVT t=39.99 frame=2442 | shove_windup p0
TILT_EVT t=39.99 frame=2442 | shove_windup p3
TILT_EVT t=40.03 frame=2444 | shove_windup p1
TILT_EVT t=40.11 frame=2449 | clash p3<->p1 kb=0.4 r=[4.6,4.3]     (seed 5, tilt 22.2°)
```

Headless and headed runs hit the identical frame numbers (seed 5 clash at
frame 2449 in both), so determinism per seed survives the new mechanic.

### The rim-save round (seed 7, round 3 — screenshots in verify_out/s7/)

```
t=79.04 frame=4797 | shove p0 -> p1 r=2.5 out=1.00    RED punches BLUE dead-outward from the hub
t=79.67 frame=4835 | shove_windup p1                  BLUE, carried to r≈4.8, answers…
t=79.72 frame=4838 | shove_windup p0                  …as RED winds up the finisher
t=79.79 frame=4842 | clash p1<->p0 kb=0.4 r=[4.8,4.0] CLASH — the kill is defused
t=80.67 frame=4895 | status tilt=13.1 standing=4 radii=[0.5, 4.9, 3.1, 2.5]   BLUE alive at the rim
```

| Shot | Shows |
|---|---|
| `verify_out/shot_2451.png` | Seed-5 clash at 22° tilt: gold sparks, CLASH! floaty, both duelists over the low-side warning lamp |
| `verify_out/s7/shot_4796.png` | RED lining up the blindside hub punch on BLUE (uncounterable, lands normally) |
| `verify_out/s7/shot_4836.png` | Both wound up at the blue rim marker — the tell, one beat before contact |
| `verify_out/s7/shot_4845.png` | The rim clash: sparks + CLASH! at the edge, rim glow hot |
| `verify_out/s7/shot_4900.png` | Aftermath: BLUE still standing at the rim, RED bounced inward — and a second clash (GOLD/MINT) firing across the disc |

### Balance work (measured, not guessed)

The naive windup gutted the game: first soak showed a **43% whiff rate**
(targets walk ~0.54m during 0.12s) and near-certain bot counters converted
every would-be royalty kill into a clash — 5-seed soak: ~0 royalty vs v1's
1–2/match (v1 baseline re-measured by checking out the v1 files and running
seeds 3/11/13: falls 6/4/5, royalty 2/1/2). Fixes, in order:
1. **Reach 1.7 → 2.05** — the windup telegraphs *when*, it shouldn't
   make you miss what you aimed at.
2. **Release aim-tracking** — at landing, facing swings up to 25° toward
   the nearest in-range target (fighting-game startup tracking). Whiffs
   fell to ~25%.
3. **Counter rate cut to "occasionally"** (~25–35%, desperate ~50%) and the
   reflex no longer hijacks a helpless bot's flee (v1 behavior kept when it
   can't answer); bots also value position more (less center shove spam,
   more pressure past mid-radius).

Final 5-seed profile (30s rounds ×3): 10–16 clashes, 42–66 landed hits,
falls 1–7/match. At the shipping 60s roundtime (seed 9): all three rounds
end in **last_stand**, 9 falls incl. a royalty kill, 10 clashes (~1 per 18s
— present, not spammy). Royalty is structurally rarer than v1: mutual
face-to-face duels — v1's main royalty source — now clash by design.
Blindside and cooldown-punish kills still credit royalty.

### Feel verdict on the windup

0.12s windup + 2.05m reach + 25° release tracking nets out feel-neutral:
the tell is readable (scale pulse + early punch anim + card flick) but a
buffered A-press still connects on anything you were actually aiming at.
0.12s was also the first number tried — it sits in the sweet spot where
7 physics ticks are enough for a human to answer a seen windup but never
long enough to read as input lag. The 0.2s budget was never approached.

## v1.3 — TUNING PASS: telegraphed sudden-death grace (playtest)

Friend playtest note verbatim: *"Sudden death... comes on way too quickly,
give the player like 5 seconds to realign."* Previously the 75%-of-round
trigger fired `_start_sudden_death()` directly — pin rise, +8° tilt limit,
1.6x gain, and the "SUDDEN DEATH / THE PIN RISES" banner all landed on the
exact same frame the timer crossed 75%, with zero warning.

**What changed** (`tilt.gd`): the 75% trigger now calls `_start_sd_telegraph()`
instead of `_start_sudden_death()` directly. That arms a `SD_GRACE_TIME`
(5.0s) countdown ticked by `_tick_sd_telegraph()`:
- Every whole-second edge (5, 4, 3, 2, 1) shows a hot-orange "SUDDEN DEATH IN
  N / REALIGN NOW" banner and fires the existing low-tilt klaxon cue
  (`Sfx.play("invalid")`), plus a tiny screenshake — a telegraphed warning,
  not a silent clock.
- `FinalStretch.escalate()` (music_light -> music_tense + red vignette nudge)
  now fires at the START of the telegraph instead of at physics-engage, so
  the tension cue arrives alongside the countdown.
- Only once the 5s grace fully elapses does `_start_sudden_death()` run —
  same function as before, unchanged: pin rise, tilt-limit/gain increase,
  the original red "SUDDEN DEATH / THE PIN RISES" banner, grudge sting, shake.
- Safety nets: `_sd_telegraph_t` resets on `_start_round()` (no stale
  countdown carrying into the next round) and inside `_start_sudden_death()`
  itself (the short-`--roundtime` overtime fallback, which can call
  `_start_sudden_death()` directly if the round clock runs out before a
  telegraph completes, cleanly cancels any pending countdown so it can't
  double-fire later — see the 2-player smoke receipt below).

**Bug found + fixed during verification:** the first cut reused the general
`_flash_banner()` helper for each per-second countdown update. That helper
schedules its own one-shot auto-hide tween on every call; firing it every
~1s with a ~1.05s duration meant each call's hide-tween landed ~0.05s after
the *next* second's text update, blanking the banner almost immediately —
the countdown was only readable for a ~50ms flicker per digit. Fixed with a
dedicated `_show_sd_countdown()` that leaves `banner.visible` continuously
true for the whole grace window (only punching the scale on each digit
change); `_start_sudden_death()`'s own `_flash_banner()` call cleanly takes
over with a fresh show+hide cycle once the grace empties. Confirmed by
screenshot (see below) — the "IN 3" and "IN 1" digits both render solidly,
not as a flicker.

**Receipt — deliberate-change doctrine.** This tuning necessarily *moves* the
in-round timestamp at which sudden-death PHYSICS engage (that's the entire
point), which shifts everything downstream in a seeded bot soak (bots behave
differently under the extra 5s of gentler physics). Old vs new, same command:
```
godot --headless --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- \
  --tiltbots --seed=7 --roundtime=30 --rounds=3 --quitafter=7400
```
| | OLD (pre-tune) | NEW (v1.3) |
|---|---|---|
| Round-1 75% trigger reached | `sudden_death` fires at t=23.9 | `sd_telegraph_start` fires at t=23.90 (same trigger point) |
| Round-1 sudden-death PHYSICS engage | t=23.9 (instant) | `sudden_death` fires at t=28.90 (exactly +5.00s later) |
| Round-1 event narrative | shove-kill royalty ~t=11.0, gull spawn + 3 guano hits, slide-death at 22.3°, sudden death 23.9, last-stand end | shove-clash-heavy round (v1.1 clash mechanic dominates early trades), sudden death 28.90, overtime at 31.4 (4 survivors), last_stand end t=39.9 scores RED=7/BLUE=3/GOLD=3/MINT=3 |
| Full match (longer quitafter) | not previously receipted to completion in this doc | completes cleanly: `match_end` at t=127.60, valid `placements`/`points`/`currency_events`/`highlights`/`kill_events`, 0 SCRIPT ERROR |

The **trigger point** (when the game first notices 75% of the round has
elapsed) is unchanged to the hundredth of a second (t=23.90 both times) —
only the moment physics actually harden moved, by exactly `SD_GRACE_TIME`
(5.00s), confirming the telegraph adds pure lead-time rather than shifting
when the countdown starts.

**Edge case — short `--roundtime` (2-player smoke, `--players=2 --seed=3
--roundtime=15 --rounds=1`):** with a 15s round, 75%+5s (16.25s) lands past
the round's own 15s timeout. Verified the safety net handles this cleanly:
telegraph arms at t=12.65, the round's own timeout fires the OVERTIME
fallback at t=16.40 (which calls `_start_sudden_death()` directly since
`sudden_death` was still false), and the safety reset inside
`_start_sudden_death()` cancels the pending telegraph so it can't fire a
second time later. Old behavior: sudden death was instant at t≈12.65,
substantially earlier relative to the round timeout. Match still completes
cleanly either way (`match_end` with valid placements/points, 0 errors) —
this is a verification-convenience knob (very short custom round length),
not real gameplay pacing (default round_time=60s gives the 5s grace 15s of
headroom before the round's own horn).

**Self-tests unaffected** (`--tilttest=idle` / `--tilttest=edge`): both gate
on `_test_mode == ""` in the trigger condition (unchanged), so sudden death
— telegraphed or not — never arms during these tests. Both still PASS,
exit 0, identical to the pre-tune baseline (idle: 0.000° drift over 30s;
edge: slid off at t=0.83s).

**Screenshots** (`verify_out/tilt_tune_m3_final/`, seed=7 seeded bot soak,
`--roundtime=30 --rounds=3`):
- `tilt_sd_telegraph_countdown3.png` — "SUDDEN DEATH IN 3 / REALIGN NOW" in
  hot orange, platter still calm (pre-physics), t≈26.7s.
- `tilt_sd_telegraph_countdown1.png` — "SUDDEN DEATH IN 1 / REALIGN NOW",
  the last digit before handoff, t=28.90.
- `tilt_sd_physics_engaged.png` — the moment just after: "SUDDEN DEATH / THE
  PIN RISES" (the original, unchanged banner), rim glowing hot orange —
  physics have engaged, t≈28.98.

## Wishes (assets that would elevate it)

- A real seagull model + flap animation (gull is primitives; reads fine at
  distance but a KayKit-style bird would be lovely).
- A "splash" water sfx (using impactPunch as splat) and a wind/creak loop for
  high tilt; a proper klaxon (error_004 is serviceable).
- Kenney coin-pickup jingle distinct from impactBell.
- A crown prop for the match winner (especially when the winner is a gull).
