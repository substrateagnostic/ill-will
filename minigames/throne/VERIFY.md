# THE THRONE — verification

One throne, four tyrants-in-waiting. Whoever SITS scores every second and wields
court powers (DECREE BLAST, SUMMON GUARD) but CANNOT move; everyone else gangs up
to drain the king's GRIP and fling them down the steps, then instantly betrays
each other in a scramble for the empty seat. One continuous 2.5-min match; the
last 30s is a "succession crisis" worth double. Placements by throne-seconds.

Root scene: `minigames/throne/throne.tscn` (extends `Minigame`).
Self-starts standalone 0.5s after `_ready` with a default 4-player config
(KayKit chars, colors/names from `GameState` consts, seed from `--seed=N` or 1).
When the shell calls `begin(config)` first, the self-start is skipped.

Files: `throne.gd` (controller), `royal.gd` (the avatar — challenger AND king),
`throne_bots.gd` (seeded self-play AI). No `project.godot` edits; committed
assets only (KayKit GLBs, house fonts, Kenney audio via the `Sfx` autoload).

## How to run

Standalone (real players; gamepads / keyboard halves via PlayerInput, empty
seats filled by bots):
```
godot --path . minigames/throne/throne.tscn
```

All-bot demo (seeded self-play — gang the seat, then scramble):
```
godot --path . minigames/throne/throne.tscn -- --thronebots --seed=1
```

Fewer players:
```
godot --path . minigames/throne/throne.tscn -- --thronebots --players=3 --seed=3
```

Screenshots (global `--shots` harness; PNGs land in the `--outdir`). FPS is
capped to 60 so a shot frame maps to game-time (frame ≈ game_seconds*60 + 30):
```
godot --path . minigames/throne/throne.tscn -- --thronebots --seed=2 --shots=90,760,880 --outdir=verify_out/hero
```

Balance probe (all bots, real gameplay incl. slow-mo, prints per-player
throne-time shares + the guard-enclosure assertion, then quits):
```
godot --headless --path . minigames/throne/throne.tscn -- --thronebalance --seed=1
```

Import pass after adding files (runs, exits clean):
```
godot --headless --editor --import --quit --path .
```

CLI args (after `--`): `--thronebots`, `--players=N` (2-4), `--seed=N`,
`--matchtime=S` (min 20), `--thronebalance` (FX-on probe), `--thronebalancefast`
(reproducible no-FX variant), `--thronescale=N` (fast-sim time scale for the
fast variant only), plus the global `--shots` / `--outdir` / `--quitafter`.

## Input (contract: move + A + B per player)

- CHALLENGER (not seated): move, **A = shove** (Par-family knockback that scales
  with your speed, 1.9m range, front arc, 0.7s cd), **B = dash** (forward burst,
  1.4s cd).
- KING (seated): cannot move, scores every second, and A/B become court powers:
  **A = DECREE BLAST** (radial shockwave, 3.6m, 1.8s cd + 0.2s slower each use —
  tyranny fatigue), **B = SUMMON GUARD** (barrier on the most-threatened open
  approach, one at a time, 6s life, 4s cd, auto-aimed).

## MANDATORY BALANCE PROBE (spec Risk) — 4 bots, 5 seeds — PASS

`no bot may exceed 55% of total throne time`. Measured on **real gameplay**
(`--thronebalance`: all FX + slow-mo ON, `time_scale = 1`), full 150s match each.

| seed | RED | BLUE | GOLD | MINT | max share | throne occupied |
|-----:|----:|-----:|-----:|-----:|----------:|----------------:|
| 1 | 26.4% | 25.1% | 23.3% | 25.3% | **26.4%** | 120.2 / 150s |
| 2 | 27.1% | 23.1% | 20.8% | 29.0% | **29.0%** | 119.2 / 150s |
| 3 | 27.3% | 22.8% | 20.3% | 29.5% | **29.5%** | 120.1 / 150s |
| 4 | 15.9% | 29.3% | 23.7% | 31.1% | **31.1%** | 118.6 / 150s |
| 5 | 24.9% | 20.5% | 30.3% | 24.3% | **30.3%** | 120.0 / 150s |

**Worst single-bot share across all 5 seeds = 31.1% (seed 4, MINT) << 55% cap.
All 5 seeds PASS.** The throne is contested constantly (occupied ~79-80% of the
match; 40-55 dethronings per match spread across all four bots — e.g. seed 1:
RED 13 / BLUE 13 / GOLD 15 / MINT 13). Shares are tight (15.9%-31.1%); no bot
comes close to dominating.

(Earlier probe runs showed one starved outlier per seed — e.g. seed 1 GOLD at
6.7% — which turned out to be a *bug*, not balance: a hard dethrone launch could
fling a body clean over the old 2.6m walls into the void, permanently removing
that player. Raising the walls to 3.4m + the launch/rescue changes below fixed
it; the outlier recovered to 23.3% and the table tightened.)

Reproduce:
```
for s in 1 2 3 4 5; do godot --headless --path . minigames/throne/throne.tscn -- --thronebalance --seed=$s; done
```

### Guard-enclosure assertion (spec Risk: "barrier cannot fully enclose the dais")

There are 4 dais approaches and only ONE guard may exist at a time, so at least
3 stay open. `_try_guard()` computes the open count and `assert`s it is ≥ 1
before every placement, printing the check. Sample (from the probe logs):
```
THRONE_GUARD king=BLUE approach=1 blocked=1/4 open=3 (>=1 OK)
THRONE_GUARD king=RED  approach=2 blocked=1/4 open=3 (>=1 OK)
THRONE_GUARD king=MINT approach=0 blocked=1/4 open=3 (>=1 OK)
```
Across full matches, `open` is 3 on every single placement — the dais can never
be sealed.

## Tuning-knob history (spec: expect a director tuning pass)

The mandated dethrone knobs (grip regen / decree fatigue / blast force) were
balanced on the first pass and did **not** need adjusting to clear the cap. The
two changes that actually mattered were a *measurement* fix and a *robustness*
fix — both documented here because they are load-bearing:

1. **`time_scale` is NOT a free fast-forward (measurement fix).** Godot scales
   the `_physics_process` delta by `Engine.time_scale`, so a "fast sim" at
   `time_scale=8` integrates movement in coarse 8x steps and is a *different
   game* (first coronation at 2.8s vs the true 7.8s). Early probe numbers taken
   at `scale=8` were therefore invalid. The probe now runs at `time_scale=1`
   (faithful) and parallelises across seeds for wall-clock.
2. **Slow-mo exposed a seating jam (robustness fix).** With four bots all
   beelining dead-centre, they could form a stable ring *outside* the seat
   radius and stall the throne — a 17s dead-throne appeared once the slow-mo
   beat perturbed positions into that basin (3 coronations in 30s vs a healthy
   8). Fix: **only the closest challenger commits to the empty seat; the rest
   hold a standoff ring, poised to gang the instant someone sits** — and the
   seat radius went 1.45 → 1.70. Post-fix: 10-14 coronations per 40s at every
   seed, no stalls.

3. **Launch strength vs the walls (the seed-1 GOLD "starve").** `LAUNCH_FORCE`
   went 13 → 17 for drama, but at 17 a body could sail over the 2.6m walls into
   the void and be lost — that was the real cause of the lopsided outliers. Fix:
   **walls raised 2.6 → 3.4m**, `LAUNCH_FORCE` settled at **15** (a "down the
   steps" tumble, per spec, rather than a room-crossing launch), plus a
   **rescue safety net** in `royal.gd` that snaps any escapee back inside. With
   3.4m walls the net now fires **zero times across all 5x150s probe matches** —
   it is pure belt-and-suspenders — and every player stays in play (see the
   tightened table above).

Other deliberate values: slow-mo beat `time_scale 0.2 for 0.6s` on each dethrone.

Final knobs (printed by the probe): `GRIP_MAX=3  GRIP_REGEN=8.0s  DECREE_CD_BASE=1.8s
DECREE_FATIGUE=0.20  DECREE_FORCE=11  LAUNCH=15  RE_SIT=2.0s  SEAT_RADIUS=1.7`;
arena walls 3.4m; rescue net at `|x|,|z|>7` or `y<-2`.

## Results contract — verified for 2 / 3 / 4 players (no validation warnings)

```
4p: THRONE_MATCH_OVER champ=RED placements=[0, 2, 3, 1] points={0:11,1:3,2:7,3:7} currency=5 highlights=3
2p: THRONE_MATCH_OVER champ=RED placements=[0, 1]       points={0:14,1:7}
3p: THRONE_MATCH_OVER champ=GOLD placements=[2, 1, 0]   points={0:3,1:12,2:16}
```
- `placements`: every roster player, best→worst by throne-seconds; ties break to
  the earlier index (4p above: 2 and 3 both 7 pts → 2 placed first). ✓
- `points`: int throne-seconds per player (crisis seconds count double). ✓
- `currency_events`: **royalty +1** per dethroning blow (to the kingslayer);
  **grudge +1** per full minute a player holds 0 throne time ("the court pities
  X", announced at the 60s/120s marks). ✓
- `highlights`: longest single reign + top kingslayer count. ✓
- `monuments`: **"X, The Usurper"** at 3+ dethronings (routinely earned — the
  probe shows 7-19 dethronings per player over a full match). ✓
- Emitted via `report_finished()`; zero "Minigame results problem" warnings in
  headless full-match runs.

## Screenshots (committed in `shots/`, Godot-ignored via `.gdignore`; regenerate via the commands above)

- `shots/screen_seize.png` — establishing: warm throne room, 4 pillars + flickering
  torches, red carpet + runner, the grand gold throne, four KayKit challengers
  spread around the dais, "SEIZE THE THRONE" Luckiest Guy banner.
- `shots/screen_enthroned.png` — **the readability hero shot**: MINT enthroned,
  the GOLDEN SCORE-STREAM rising from the seat, crown on the throne, the floating
  GRIP pips + orange "TYRANNY" fatigue bar above the king, a mint-colored GUARD
  WALL planted on one approach, and RED dash-charging in to gang the seat.
- `shots/screen_decree_blast.png` — DECREE BLAST: the big blue shockwave ring
  expanding off the dais as the king knocks challengers back down the steps.
  (Captured before the wall-height bump — the ring/mechanic are unchanged; only
  the back walls are shorter than in the other shots.)
- `shots/screen_dethrone_fling.png` — **the make-or-break fling**: the dethroned
  BLUE ragdolls down the dais steps during the slow-mo beat, the crown popped off
  and airborne above the throne, while GOLD is instantly crowned in the same
  breath — the "betray each other for the empty seat" moment made literal.
- `shots/screen_coronation_banner.png` — "GOLD TAKES THE THRONE" coronation banner
  as the seat changes hands.
- `shots/screen_succession_crisis.png` — the last-30s crisis: red timer, persistent
  "SUCCESSION CRISIS — THRONE PAYS DOUBLE" sub-label, and the big red banner.

## MUST (v1 scope) — all done

- [x] Sit / score / powers — touch within 1.7m of the empty seat to be crowned
      (0.4s ceremony, crown appears); seated = +1/s (the only way to score),
      cannot move; A = decree blast, B = summon guard.
- [x] Grip + dethrone fling — visible 3-pip GRIP meter; each connecting
      challenger shove drains 1; at 0 the king is LAUNCHED (force 17, ragdoll
      tumble + crown drops as its own physics body that bounces down the steps),
      2s re-sit cooldown, grip regens 1 / 8s while seated.
- [x] Shove / dash — Par-family shove (0.7s cd) and dash (1.4s cd) for
      challengers, 0.05s-class hit feedback + screenshake on landed shoves.
- [x] Fatigue — decree cooldown grows 0.2s per use while seated; "TYRANNY" bar
      above the king fills as the reign burns decrees (the walls closing in).
- [x] Succession crisis — last 30s throne scores +2/s, announced with banner +
      persistent red sub-label + red timer.
- [x] Results — placements/points/currency_events/highlights/monuments via
      `report_finished`; validated for 2/3/4 players, no warnings.
- [x] Seeded bots — `--thronebots` (and per-player roster `bot` flag); gang the
      current king, then scramble for the empty seat; all RNG from
      `config.rng_seed`; decisions on the physics tick for reproducibility.

## SHOULD — all done

- [x] Guard barriers — real StaticBody wall on the most-threatened OPEN approach,
      auto-aimed, 6s life / 4s cd, one at a time, with the enclosure assertion.
- [x] Crown physics — the crown detaches on a dethrone into a bouncing RigidBody
      that arcs and tumbles on the dais steps, then fades.
- [x] Pity grudge — "the court pities X" + grudge currency at each 60s mark for
      anyone still locked out of the throne.

## WON'T (v1) — as specced: no multiple thrones, no items, no room variants.

## Per-player bots (fleet convention)

`begin(config)` reads each roster entry: explicit `"bot": true/false` wins
(so a human seat with `"bot": false` is never bot-driven); `--thronebots` forces
all seats to bots; otherwise standalone fills unassigned/shared devices (-99/-3)
with bots. `PlayerInput` is used for all human control; devices are never read
directly.

## Known issues

- Headed (FX) runs are not frame-identical to the reproducible `--thronebalancefast`
  variant: the slow-mo beat scales the physics delta for 0.6s per dethrone, which
  shifts physics alignment slightly (this is real gameplay, and is exactly why the
  official probe measures *with* FX rather than the faster no-FX sim). Fairness
  holds either way; only exact timing drifts.
- The seated king uses a standing KayKit Idle pose (no sit animation in the
  CC0 set) framed in front of the throne; the crown + gold stream + throne behind
  sell the "king" read. A real seated pose would need a new anim (see Wishes).
- All-bot matches rarely trigger the pity grudge because the four bots rotate the
  throne so evenly that everyone banks *some* seconds within the first minute;
  it is designed for a human who never engages, and fires correctly when a player
  holds 0 throne time at a 60s mark.
- Bot king vs a full mob still averages ~2-4s reigns (dramatic and "doomed" by
  design, and what keeps the shares fair). A director may want to lengthen reigns
  for feel by lowering grip-regen cost / raising decree force — the numbers have
  headroom under the 55% cap to do so.
- Because turnover is so high, the spec-literal **Usurper monument (3+ dethronings)
  is commonly earned by most/all players** in a full match (a 65s bot match minted
  4 Usurpers). Kept at 3+ per the spec; a director may raise the threshold (e.g.
  most-dethronings-and-≥5) if the monument should stay rare. The single standout is
  already captured in `highlights` ("X: N kingslaying(s)").

## Wishes (for the anthology maintainers)

- A KayKit **sit / enthroned pose** (or a "Sit" clip) so the king visibly sits.
- A CC0 **throne / crown GLB** (the box-built throne + torus crown are on-style
  but a real gilded throne silhouette would sell the grandeur).
- A dedicated **coin-counter loop Sfx** for throne-seconds (currently a soft
  "card" click per second) and a **regal fanfare** for coronations.
- Torch **flame particle** assets (Kenney particles) for the pillar sconces
  instead of the emissive sphere + flicker.
