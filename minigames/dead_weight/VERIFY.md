# DEAD WEIGHT — verification

Sumo brawl in a cozy attic. Knocked-out players become POLTERGEISTS who possess
the furniture and hurl it at the living. Best-of-3.

Root scene: `minigames/dead_weight/dead_weight.tscn` (extends `Minigame`).
Self-starts standalone 0.5s after `_ready` with a default 4-player config
(KayKit chars, colors/names from `GameState` consts, seed from `--seed` or 1).

## How to run

Standalone (real players, gamepad/keyboard halves via PlayerInput):
```
godot --path . minigames/dead_weight/dead_weight.tscn
```

Bot demo (all AI: living wander+shove, ghosts possess nearest prop and ram):
```
godot --path . minigames/dead_weight/dead_weight.tscn -- --dwbots --seed=5
```
Start N players as ghosts immediately (for possession shots):
```
godot --path . minigames/dead_weight/dead_weight.tscn -- --dwbots --dwghosts=2 --seed=5
```

Screenshots (global harness arg; PNGs land in `verify_out/`):
```
godot --path . minigames/dead_weight/dead_weight.tscn -- --dwbots --dwghosts=2 --seed=5 --shots=120,220,340,460,600
```

Balance sim (headless, prints tally then quits):
```
godot --headless --path . minigames/dead_weight/dead_weight.tscn -- --dwbalance=20 --seed=1
```

CLI args (after `--`): `--dwbots`, `--dwghosts=N`, `--dwbalance=N`, `--dwrounds=N`,
`--players=N`, `--seed=N`, plus the global `--shots=...` / `--outdir=...`.

Import pass after adding files:
```
godot --headless --editor --import --quit --path .
```

## Balance test (spec Risk: "1 living vs 1 living + 1 ghost; living should win ~65%")

Harness: 2 living bots + 1 permanent ghost bot, N rounds, one process.
A round is "ghost-decided" if the poltergeist landed the kill that left one
survivor; otherwise it is "living-decided" (living shove) or an accident.
"Living win %" = the ghost did NOT land the decisive kill.

RESULT (filled in after tuning): <PENDING>

## MUST (v1 scope)

- [ ] shove/hop sumo core (5 m/s, A shove w/ speed-scaled knockback, B hop)
- [ ] edge-void deaths (glowing gutter, fall = death, slow-mo + Sfx)
- [ ] poltergeist possession with force control (hold A possess, move = force, B release 4s cd)
- [ ] kill credits ("X (COLOR) CLAIMS Y" banner + royalty +2)
- [ ] best-of-3 rounds, revive + darkened props between
- [ ] results contract (placements/points/currency_events/highlights/monuments)
- [ ] seeded bots behind CLI arg

## SHOULD

- [ ] prop mass tiers (lamp dart / crate / wardrobe freight train)
- [ ] CLAIMS banners
- [ ] wisp trails on possessed props

## Anti-grief

- [ ] props within 2m of a revival spawn unpossessable for first 3s of a round

## Screenshots

(annotations added after capture)

## Known issues / wishes

(filled in at the end)
