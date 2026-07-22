# SWAP MEET rebuild verification

Root scene: `res://minigames/swap_meet/swap_meet.tscn`

This rebuild remains a deterministic, hand-integrated race. Karts, rails,
projectiles, pickups, coffins, the ramp, bog surface, and windmill are stepped
without physics bodies. Godot was intentionally not launched in the build
sandbox; the director runs the receipt below in-house.

## Ratified design map

### Circuit and lap order

`swap_track.gd` samples a closed, height-aware Catmull-Rom route whose control
polygon is about 296 world units (the former lap was about 90) and whose
footprint is 83 x 60 units.

1. Start/finish straight with checker strip and glowing `SWAP MEET` gantry.
2. Tight left-right-left hedge-maze chicane, dressed with estate topiary.
3. Forest S-curves with estate dead trees placed as visible apex calls.
4. Bog pool: the 1.45-unit-wide center plank line stays at full speed; shallow
   water outside it sets `bog_speed_scale = 0.60` (about 40% slower).
5. One upgraded windmill timing gate. Its 7.8-unit candy-striped blade rotates
   through the whole road and retains the non-lethal knock/tumble presentation.
6. Graveyard climb and stone overpass. The late-lap deck rises to y=5.6 and
   crosses above the ground-level start straight, producing a real figure 8.
7. Bridge descent and home bend back to the line.

The forest shortcut remains a narrow risk/reward plank ramp with a real launch
gap. Normal swap-orb pickups and the golden comeback orb remain on-track verbs.
Emissive cyan, magenta, acid-green, and amber markers/item boxes provide the
required saturated pops against the moonlit estate palette.

### Cameras

`swap_meet.gd` creates no SubViewport directly. It instantiates `ViewportKit`,
calls `setup`, and adds only human-seat views through `add_view`. Each is posed
through `aim_view` as a behind/above chase camera; `view_camera` supplies a
small drift roll. Bots have no view. Layouts are:

- one human: one full-screen chase view;
- two humans: horizontal two-way split;
- three humans: three quadrants with the unused quadrant dark;
- four humans: four equal quadrants.

### Item boxes and position weighting

Colored item boxes draw on the seeded match RNG. First place is weighted toward
the defensive coffin; third/fourth receive sharply higher swap-shell, Bell,
and Crow Murder weights.

- **SWAP-SHELL** homes on the kart immediately ahead. A hit enters the existing
  atomic `soul()` exchange, dual ghost flash, hit-stop, and one-second immunity.
  The exchanged soul is the complete race position: transform/velocity,
  main/shortcut path hints, distance-along-track, checkpoint and lap high-water,
  current-lap clock, and recorded lap history move together. Inventory, score,
  debuffs, and finish identity remain with the driver.
- **PALLBEARER'S COFFIN** drops behind and persists until hit or race end. A hit
  causes an 0.85-second tumble. Oldest-first enforcement caps each seat at
  three live coffins.
- **THE BELL** applies a 0.65 speed multiplier to every other unfinished kart
  for 2.5 seconds.
- **CROW MURDER** targets the current leader for 3 seconds, applies a mild 0.78
  steering multiplier, and partially veils that leader's human viewport with
  translucent crow bands. It never stops the kart or fully blocks the view.

Normal swap-orb pickups grant one lob, independent of item boxes. Golden orb
spawn/claim/homing-leader behavior remains intact. Empty seats use `swap_bot.gd`
pure pursuit, seeded item use, drift/shortcut decisions, and a mild placement
speed scale from 0.98 (leader) to 1.08 (fourth). A progress watchdog ignores
intended coffin tumbles and ramp airtime; after 2.5 seconds without meaningful
forward track progress it reverses briefly, resamples the current next waypoint,
and logs exactly one `BOT_UNSTUCK p=N t=S.S` line per escape. Bog slowdown is
recomputed from the kart's current surface every tick and clears on the dry
plank/after leaving the water.

## Config dials

Swap Meet consumes these keys from the existing `begin(config)` dictionary:

| key | type / clamp | default | effect |
|---|---|---:|---|
| `laps` | int, 1..9 | 3 | laps required to finish |
| `item_density` | float, 0.25..2.0 | 1.0 | scales both item-box and normal-orb pickup counts |

Standalone equivalents are `--laps=N` and `--itemdensity=N`. No change to
`estate/procession/procession.gd` is required: its existing launch config merge
already carries arbitrary game-specific keys into `begin(config)`.

## Deterministic headless soak

Run from the repository root:

```sh
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swaptally --seed=17
```

`--swaptally` forces all roster seats to seeded bots, enables the established
8x tick-safe acceleration when no explicit `--fast` is supplied, auto-quits,
and still runs the configured three laps. The final receipt line has this
shape (values and digest depend on the seed):

```text
SWAPTALLY seed=17 laps=3 item_density=1.00 order=[...] swaps=N boxes=N shells=N coffins=N bells=N crows=N digest=12_hex_chars PASS
```

`PASS` requires every kart to finish plus at least one item-box claim and one
swap-shell use. `digest` hashes seed, dials, finishing order, swaps, and item
counts, making repeated same-seed runs directly diffable.

## Net mirror status

The online pattern is preserved and extended, not replaced. Host simulation
still publishes compact public facts at the estate's cadence and the client
still only interpolates/renders. The kart stride now includes held item, normal
orb charge, Bell, crow, and tumble facts. Projectile facts distinguish normal,
golden, and shell types; coffin ids/transforms, item/orb pickup visibility,
height-aware kart transforms, golden-orb y position, and the dynamic windmill
angle are mirrored. Existing swap/photo-finish/banner/crown counters remain.

## Static verification performed in this worktree

- all edited Swap Meet `.gd` files have balanced `()`, `[]`, and `{}` counts;
- no edited Swap Meet `.gd` contains `var name := expression`;
- mirror writer and reader both use `NET_KART_STRIDE = 17`;
- stale two-windmill/stride-12 symbols were removed;
- `git diff --check` is clean.
