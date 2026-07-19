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

## v1.1 — TUNING PASS: better stingers + credible mugger bots (playtest)

Friend playtest note verbatim: *"Awful noise for getting the gold. Awful
winning noise. AI really suck."* Two independent fixes, no new audio assets.

### 1. SFX swap — existing-sample audition, no new audio (`greed.gd`)

Audited the house Sfx bank (`scripts/sfx.gd`) against the two complaints:

- **"Getting the gold"** — grab, floor-coin pickup, and the pot's automatic
  growth tick all reused `"card"` (Kenney `click_00x` — a flat UI click) or
  `"confirm"` (a generic confirmation chime). Neither reads as coins/treasure.
  Swapped all three to **`"bell_small"`** (3 round-robin variants, source
  "OGA bell_01/02 + Kenney bell" per `docs/design/21-sfx-overhaul.md` — a
  proper bell, not a gong) — a bright chime that suits "the pot fills with
  gold forever" and, on the automatic growth tick specifically, now reads as
  a pleasant continuous coin-counting sound.
- **"Awful winning noise"** — the mid-round BANK ceremony (`_bank_ceremony`,
  fires every time anyone banks — several times a match) was reusing
  `"match_win"` (`jingles_NES13`), the EXACT SAME jingle as the true
  match-ending fanfare (`_finish_match`, unchanged). Repeating the "you won
  the whole game" jingle on every routine bank both got old fast and
  cheapened the real victory. Swapped the bank ceremony to **`"stinger_win"`**
  (Kenney forceField swell, 0.88s — the house's own "deciding moment" cue
  per doc 21 §3, "abstract SFX cues... your music lane," previously
  earmarked for exactly this kind of mid-match high point and otherwise
  unused by this game). `match_win` at the true match end is untouched — it
  now reads as genuinely special again, distinct from every mid-match bank.
- Mirror-side event-juice functions (`_mir_event_juice`, `_net_apply`'s coin
  sync) updated in lockstep so online guests hear the identical swap.
- Left `_leak_burst`'s `"card"` alone on purpose — that's the carrier's dash
  LEAKING 2 coins (a loss, the "-2" flash), and a plain click reads as a
  fitting negative/neutral contrast against the new warm pickup chime.

Zero gameplay/logic change — purely which sample name each `Sfx.play()` call
references. No receipt impact (verified: `--greedtest=intercept` unaffected,
see below).

### 2. Bot balance — credible interception + contest (`greed_bots.gd`)

Known issue on file: *"Pure-mugger bots can score 0. A bot seeded as a heavy
mugger with a high grab threshold may hunt all match and never bank."*
Root-caused two compounding gaps in `decide()`:

1. **Never gave up a cold chase.** A heavy mugger (`mugger[p] > 0.6`) always
   preferred chasing the carrier over grabbing, with no fallback if it kept
   whiffing tackles (dash-evasion, distance, bad luck). Added
   `chase_frustration[p]`, incremented while actively chasing; at
   `FRUSTRATION_LIMIT` (6.0s) of continuous fruitless pursuit, the bot gives
   up FOR THIS TARGET and enters an `eager_t` window (5.0s) during which its
   effective grab threshold drops to `EAGER_THRESHOLD` (9.0, well under the
   normal 11-32 range) — a real hunter doesn't chase a cold trail forever,
   and takes the sure thing instead.
2. **Held out for a fat pot before engaging at all.** `worth_it` (the
   pot-value floor to even bother chasing) was a flat `>= 7` for every bot
   personality. A heavy mugger's whole identity is denial, not the haul —
   holding out for a fat pot before it would even move meant it could sit
   out entire matches with a low-value pot cycling past it. Heavy muggers
   (`mugger[p] > 0.6`) now engage at `>= 4` instead.

**Receipt — deliberate-change doctrine.** `--greedtest=intercept` (the
kinematic pursuit-tuning model) is a SEPARATE simplified simulation, not
`GreedBots.decide()` — confirmed byte-identical to the documented baseline
after this change (seed 1 rate=0.80, seed 4 rate=0.68, seed 9 rate=0.72,
seed 13 rate=0.72, all still PASS). The actual `decide()` behavior change is
demonstrated on a real match instead — same seed, old vs new
(`godot --headless --path . res://minigames/greed/greed.tscn -- --greedbots --seed=7 --rounds=1 --roundtime=30`):

| | OLD (pre-tune) | NEW (v1.1, both fixes) |
|---|---|---|
| Final scores | `RED=0 BLUE=18 GOLD=12 MINT=0` | `RED=2 BLUE=7 GOLD=19 MINT=0` |
| RED (forced heavy mugger, mugger=0.9) activity | sat out — 0 currency events, never contested | 2 successful mugs, mugged back twice, 2 royalty events, banked-nothing grudge still fires but RED is no longer inert |

RED (the forced "hangs back and hunts" heavy-mugger archetype the known
issue names specifically) went from fully inert (0 events, 0 points) to
actively contesting and scoring. MINT (an unforced, randomly-seeded
personality this particular seed happened to make both low-mugger and
high-threshold) still ends at 0 in this sample — a different, more general
"passive personality combo" than the "pure mugger" case the playtest note
and the known-issue text specifically named; addressing every possible
passive combination was out of scope for this tuning pass. Import pass
clean, 0 script/parse errors.

### Screenshots (`verify_out/greed_m3_final/`, seed=3, `--greedcap --roundtime=50`)

`greed_arena.png` / `greed_grab.png` / `greed_bank.png` / `greed_drop.png` —
all four capture beats still land cleanly with the new Sfx keys wired
(confirmed via the event log: `grab p3 pot=8`, `bank p3 amount=6`,
`drop victim=3 tackler=1`); `greed_bank.png` shows the "MINT BANKS 6!"
ceremony now firing on `stinger_win`.

---

## Known issues / notes

- **Bot grab/drop grieflock (fixed).** Early bot tuning made every bot camp the
  pedestal and instantly re-mug any grab, pinning the pot at value 2 forever with
  zero banks. Fixed with: 0.5s post-grab grace immunity; muggers only engage pots
  worth >=7 (small pots are let through to bank and reset the cycle); guard bots
  loiter on their own side rather than swarming dead-centre.
- **Pure-mugger bots can score 0 (SOFTENED — see v1.1 tuning section below).**
  A bot seeded as a heavy mugger with a high grab threshold may still hunt all
  match without ever banking a huge pot outright, but it no longer sits at a
  literal 0: it engages thinner pots and, if a chase keeps whiffing, gives up
  and grabs directly instead of hunting forever for nothing.
- **Standalone without `--greedbots`** drives only the shared/unassigned seats
  (device -3/-99) as bots, matching the house pattern (Tilt). Keyboard-half seats
  (-1/-2) idle until a human plays. Pass `--greedbots` for a fully self-playing demo.
- **Headless captures are skipped** (`GREED_CAP_SKIP_HEADLESS`) — no
  `frame_post_draw` without a display. Run capture commands windowed.
- After `finished` is emitted the scene idles (the shell owns teardown).
  Standalone runs can press R to reload.

## Asset wishes (committed assets only; this worktree has no assets_raw)

- ~~A dedicated **coin-shimmer / cha-ching** SFX for grabs, floor-coin pickups
  and the growth tick~~ — addressed in v1.1 below via an EXISTING-sample swap
  (`bell_small`), not new audio.
- A **"you are the carrier" heartbeat / tension loop** that ducks in while
  someone carries — would amplify the hunted feel beyond the visual glow.
- A proper **coin-pile / treasure-heap mesh** (Kenney) for the pot instead of the
  procedural bowl + sphere, and a **chute/funnel prop** for the corners.
- A **crowd-roar or klaxon** on the +5 burst geyser to make greed even louder.
- Ground **decal shadows** under coins/pot for extra grounding.
