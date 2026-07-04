# GREED INC. — verification

A gilded pot in the centre of a vault fills with coins forever. Anyone can GRAB
it (hold A near the pot, 0.6s) and run for their own colour-coded corner chute
to BANK the value as points — but carrying makes you SLOW (-20%), GLOWING, coin-
LEAKING, and the most hunted person in the room (every rival's edge-arrow points
at you). TACKLE the carrier (tap A in reach) to DROP the pot: 20% scatters as
floor coins and you pocket a royalty. DASH (B) to escape — a carrier's dash
bleeds 2 pot coins. 3 rounds x 90s, 2-4 players, seeded self-play bots.

Root scene: `minigames/greed/greed.tscn` (root extends `Minigame`). Files:
`greed.gd` (controller), `greed_player.gd` (KayKit avatar), `greed_pot.gd` (pot
+ huge value label + geyser), `greed_bots.gd` (seeded bots), `edge_arrows.gd`
(the "everyone points at you" overlay).

---

## Commands actually run

Import pass (required after adding files):
```
godot --headless --editor --import --quit --path .
```

Seeded self-play with event-based screenshots (windowed — see Screenshots note),
captures the full arc grab -> hunt -> drop -> bank then quits:
```
godot --path . res://minigames/greed/greed.tscn -- \
  --greedbots --seed=3 --greedcap --rounds=1 --roundtime=50 --outdir=verify_out
```
Writes `verify_out/greed_{arena,grab,drop,bank}.png`.

House-standard frame-indexed capture (module contract `--shots`, VerifyCapture
autoload) also works, windowed:
```
godot --path . res://minigames/greed/greed.tscn -- \
  --greedbots --seed=3 --shots=200,500 --quitafter=560 --outdir=verify_out
```

Standalone self-start (NO `begin()` call — proves the 0.5s auto-start with a
default 4-player roster from GameState + KayKit chars; empty/shared seats are
bot-driven so it plays itself):
```
godot --headless --path . res://minigames/greed/greed.tscn -- --seed=2 --rounds=1 --roundtime=12
```
Logged: `begin players=4 seed=2 ... bots=[false, false, true, true]` -> a bot
grabs and banks -> `round_end`.

Pursuit-tuning test (spec Risk), prints a tally and exits 0/1 on pass/fail:
```
godot --headless --path . res://minigames/greed/greed.tscn -- --greedtest=intercept --seed=1
```

### CLI args this game understands (after `--`)
- `--greedbots` — all players are seeded self-play bots. Deterministic per seed.
- `--seed=N`, `--players=N` — standalone default config (players 2..4).
- `--rounds=N` (1..3), `--roundtime=S` — shorten the match for verification.
- `--greedcap` — event/state screenshots at game beats; quits when the arc is on
  film (or after a safety timeout). `--outdir=DIR` sets the folder.
- `--greedtest=intercept` — the pursuit-tuning test below.
- `--shots=…`, `--quitafter=…` — handled by the house VerifyCapture autoload.

---

## Screenshots (verify_out/, from seed=3 --greedbots --greedcap)

- **greed_arena.png** — Baseline. Warm-wood vault, gold-trim walls, green "money-
  pit" felt inlay, four crates for cover, a pedestal holding the golden pot with
  its value ("7") shown HUGE above it. Four colour-coded corner chute pads glow
  in each player's colour (RED / BLUE / GOLD / MINT). HUD: round, big centre
  countdown, scoreboard, hint line. Four KayKit bodies with identity rings.
- **greed_grab.png** — THE make-or-break feel shot. MINT has grabbed the pot and
  is running for its chute: golden AURA + brightened ring + omni glow, a COIN-
  LEAK particle trail streaming behind, the pot value ("6") riding above their
  head. Three edge chevrons — RED, BLUE, GOLD — sit on the screen border and
  point straight at the carrier ("everyone is looking at you"). "-2" pot-flash =
  a carrier dash just bled 2 coins.
- **greed_drop.png** — Tackle/mug. "BLUE MUGGED MINT!" banner (blue), a coin-
  scatter burst at the drop point, the loose pot ("7") sitting where it fell,
  scoreboard already updated (MINT 6, BLUE +1 royalty).
- **greed_bank.png** — Payout ceremony. "MINT BANKS 6!" banner (mint), the mint
  chute pad flares bright, coins rain, the pot has reset to gold on the pedestal.

Note on screenshots: framerate is uncapped/load-dependent, so frame-indexed
`--shots` can't reliably land on a specific game beat. `--greedcap` fires
captures off GAME EVENTS (first grab / first drop / first bank), so the carrier-
glow and mug shots are guaranteed. Both paths use the same viewport image grab,
so run them **windowed** — under `--headless` there is no `frame_post_draw`, so
the PNG save is skipped (logged `GREED_CAP_SKIP_HEADLESS`) and only the logic is
exercised. The four PNGs above were produced windowed.

---

## Risks & tests (spec)

### Turtle-camping / interception is possible from any chute
`--greedtest=intercept` is a kinematic model of the make-or-break chase built
from the REAL movement constants (carry speed 5.2·0.8, dash 12 m/s / 0.22s /
1.4s cd / 0.2s i-frames, clumsy carry-dash ×0.6, tackle range 1.95, chute
geometry). A carrier grabs at centre and runs to its OWN (farthest) chute; a
dashing chaser starts at an ADJACENT chute and pursues with lead prediction.
Both may dash. Bar: the chaser lands a tackle before the bank in >=60% of runs.
```
seed=1  trials=80 catches=64 rate=0.80 PASS
seed=4  trials=80 catches=54 rate=0.68 PASS
seed=9  trials=80 catches=58 rate=0.72 PASS
seed=13 trials=80 catches=58 rate=0.72 PASS
```
Turtling next to your own chute is NOT a guaranteed win — an adjacent hunter
intercepts ~70-80% of the time. Anti-turtle geometry is also structural: the pot
spawns dead-centre, EQUIDISTANT from all four chutes.

### Stun-lock
A dropped carrier is stunned 1s AND gets 1s tackle immunity (`get_stunned()` sets
both), so they can't be perma-chained off the pot the instant they touch it.
Additionally a fresh grab grants 0.5s of grace immunity (`immune_t`) so a mugger
camped on the pedestal can't re-mug in the same frame — this closed a grab/drop
grieflock found in bot testing (see Known issues).

---

## MUST checklist (v1 scope)

- [x] Pot growth — +1 / 1.2s while on the pedestal, +5 burst / 15s with a coin
      geyser + bell fanfare + "+5!" flash. Value shown huge above the pot.
- [x] Grab — hold A within 1.95m of the pot for 0.6s (progress ring fills). You
      become the carrier: -20% speed, gold aura/glow, coin-leak trail; value freezes.
- [x] Carry / Bank — reach your OWN colour chute (1.75m) -> value -> your points,
      payout ceremony (banner + coin rain + chute flare + `match_win` sting),
      pot resets to 5.
- [x] Tackle — non-carrier taps A in reach -> carrier DROPS. Pot lands loose,
      20% scatters as floor coins, carrier stunned 1s, tackler +1 royalty; hit-
      pause + screenshake + coin burst.
- [x] Dash — B, 12 m/s / 0.22s burst, 1.4s cd, 0.2s i-frames (dodge a tackle).
      Carrier dash costs 2 pot coins (leak burst + "-2" flash) and is a clumsy ×0.6 lurch.
- [x] Floor-coin pickup — any player walking over a scattered coin banks +1.
- [x] 3 rounds x 90s (knobs `--rounds` / `--roundtime`). Pot fills continuously
      across rounds; if NOBODY banks in a round the whole pot scatters, unscored
      ("GREED PUNISHED", `punished=true`).
- [x] Results contract — placements (all roster, ties -> lower index), points,
      currency_events (royalty +1 per forced drop, grudge +1 per 0-bank round &
      per mugging), highlights (biggest bank, most drops caused), monuments
      ("The Banker" for a 30+ single bank). No validation warnings.
- [x] Seeded bots — greedy (grab at a seeded pot-value threshold) + mugger
      (chase & tackle the carrier). Deterministic per seed; roster seeded so at
      least one mugger and one grabber always exist.

## SHOULD checklist

- [x] Burst geysers — +5 every 15s fires `GreedPot.geyser()`.
- [x] Edge arrows — one chevron per non-carrier, in that player's colour, pinned
      to the screen border pointing at the carrier.
- [x] Crates — four wooden cover boxes.
- [x] KayKit avatars — roster `char_scene` (Barbarian/Knight/Mage/Rogue), anims
      Idle / Running_A / Dodge_Forward (dash) / Unarmed_Melee_Attack_Punch_A
      (tackle) / Hit_A (dropped) / Cheer (bank/win).

## WON'T (per spec)
Items, multiple pots, arena variants.

## Scoring
Points = coins banked + floor coins picked up + royalties. Placements by total
points. currency: royalty +1 per forced drop (tackler); grudge +1 per round a
player banked nothing, +1 when mugged off the pot.

---

## Known issues / notes

- **Bot grab/drop grieflock (fixed).** Early bot tuning made every bot camp the
  pedestal and instantly re-mug any grab, pinning the pot at value 2 forever with
  zero banks. Fixed with: 0.5s post-grab grace immunity; muggers only engage pots
  worth >=7 (small pots are let through to bank and reset the cycle); guard bots
  loiter on their own side rather than swarming dead-centre.
- **Pure-mugger bots can score 0.** A bot seeded as a heavy mugger with a high
  grab threshold may hunt all match and never bank (it still participates —
  guarding, chasing, landing royalties). Human play distributes scores far better;
  not a code issue. Nobody is ever eliminated, so no dead air.
- **Standalone without `--greedbots`** drives only the shared/unassigned seats
  (device -3/-99) as bots, matching the house pattern (Tilt). Keyboard-half seats
  (-1/-2) idle until a human plays. Pass `--greedbots` for a fully self-playing demo.
- **Headless captures are skipped** (`GREED_CAP_SKIP_HEADLESS`) — no
  `frame_post_draw` without a display. Run capture commands windowed.
- After `finished` is emitted the scene idles (the shell owns teardown).
  Standalone runs can press R to reload.

## Asset wishes (committed assets only; this worktree has no assets_raw)

- A dedicated **coin-shimmer / cha-ching** SFX for grabs, floor-coin pickups and
  the growth tick (currently reuse Kenney `click`/`confirmation`/`impactBell`).
- A **"you are the carrier" heartbeat / tension loop** that ducks in while
  someone carries — would amplify the hunted feel beyond the visual glow.
- A proper **coin-pile / treasure-heap mesh** (Kenney) for the pot instead of the
  procedural bowl + sphere, and a **chute/funnel prop** for the corners.
- A **crowd-roar or klaxon** on the +5 burst geyser to make greed even louder.
- Ground **decal shadows** under coins/pot for extra grounding.
