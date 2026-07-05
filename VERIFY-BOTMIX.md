# VERIFY-BOTMIX — per-player bot support across the anthology

Goal: let Alex play as ONE human with the other seats bot-driven, in every
minigame **and** Par. Previously each game activated bots all-or-nothing via a
CLI flag; when the estate shell passed `roster[i].bot`, the games **ignored it**
(they only checked device `-3/-99` while `_standalone`, which is false under the
shell). Now every game reads the per-seat flag.

## The rule (implemented everywhere)

A seat `i` is bot-driven iff:

```
legacy_all_bots_flag  OR  roster[i].get("bot", false)
```

- The **legacy flag** (`--tiltbots`, `--mowbots`, `--greedbots`, `--echobots`,
  `--orbbots`, `--swapbots`, `--dwbots`/`--dwbalance`, `--covtest`, and new
  `--parbots`) forces **ALL** seats to bots — preserved so every existing
  verification command still works.
- **Shell launch:** `estate.gd` already sets `roster[i].bot = _is_bot(i)`
  (`estatebots-flag OR PlayerInput.is_bot(i)`). The games now honor it.
- **Standalone self-start:** each game's `_default_config()` fills
  `roster[i].bot = PlayerInput.standalone_bot_default(i)` — a new helper in
  `core/player_input.gd`:
  ```gdscript
  func standalone_bot_default(p) -> bool:
      return is_bot(p) or not has_setup()   # has_setup() = party_setup.json exists
  ```
  With no saved PartySetup the scene self-plays (all bots); once seats are
  configured in the ESC overlay, it honors each HUMAN/BOT choice via
  `PlayerInput.is_bot(i)`.
- Bot/human gating is decided **at `begin()` from roster data only** — never
  from runtime `Input` reads inside sim code — so tick-deterministic games stay
  reproducible. **Par** uses `PlayerInput.is_bot(i)` directly (it has no shell
  roster — gamestate module) and does **not** default to all-bots when there is
  no setup file (it is human-first, launched from the menu).

## The mixed roster used for verification

The machine already had `user://party_setup.json` (left untouched):

```json
{"devices":{"0":-3,"1":0,"2":-1,"3":-2},"bots":{"0":false,"1":true,"2":true,"3":true}}
```

i.e. **player 0 (RED) = HUMAN, players 1–3 (BLUE/GOLD/MINT) = BOT** — exactly the
acceptance case. So each mixed run below is simply the standalone scene launched
with **no** legacy bot flag; the game reads `is_bot` and drives seats 1–3 as bots
while seat 0 stands idle. Every game that logs its gate printed
`bots=[false, true, true, true]`.

Screenshots landed under `verify_out/botmix/<game>/` (gitignored). Absolute base:
`C:\Users\agall\projects\un_party_game\.claude\worktrees\agent-a7b3ac189386eb297\verify_out\botmix\`

Import pass after edits (clean, no script errors):
`godot --headless --editor --import --quit --path .`

---

## Per-game results

### echo_chamber (tick-deterministic ghost replay)
- **Changed:** `f.is_bot = _bots or bool(pl.get("bot", false))` in `_spawn_fighters`; `_default_config` now assigns real devices + `bot`.
- **Legacy / determinism:** `godot --headless --path . res://minigames/echo_chamber/echo_chamber.tscn -- --echobots --echofast=5 --seed=1 --echocap --outdir=verify_out` → `bots=true`, `ECHO_DETERMINISM round=1..4 max_err=0.000000 OK` (**unchanged, 0.000000**).
- **Mixed:** `godot --path . --fixed-fps 60 res://minigames/echo_chamber/echo_chamber.tscn -- --echofast=10 --seed=1 --shots=320,760 --quitafter=820 --outdir=verify_out/botmix/echo` → runs clean; `ECHO_BOUNTY_KILL` from bots; determinism still `0.000000`. **Screenshot:** `verify_out/botmix/echo/shot_0760.png`.

### orbital (tick-deterministic, per-index bots array)
- **Changed:** added `bot_enabled[]`; `bots` is now a fixed-size array with **null** for human seats; think-loop and `_input_for` skip nulls; bots only built when `_test_mode == ""`. Same per-index seeds → all-bots path bit-identical.
- **Legacy:** `... -- --orbbots --seed=7 --fast=10 --autoquit` → `ORBITAL_ASSERT max_flight_age=46.4s (<75s): PASS`, `throws=55 hops=46` (**identical to the prior VERIFY record**).
- **Mixed:** `godot --path . --fixed-fps 60 res://minigames/orbital/orbital.tscn -- --seed=11 --matchsec=60 --shots=400,1200 --outdir=verify_out/botmix/orbital` → only `THROW p=1/2/3` (bots); p0 (RED) never throws. **Screenshot:** `verify_out/botmix/orbital/shot_1200.png`.

### swap_meet (tick-deterministic, per-index bots array)
- **Changed:** same shape as orbital (`bot_enabled[]`, null-slotted `bots`, null-safe think/input, test-mode skip). `_input_for` now checks `_test_mode` before the per-seat bot slot.
- **Legacy:** `... -- --swapbots --seed=1 --fast=8 --autoquit` → `SWAPMEET_ASSERT all_finished=true race_t=48.1s(<180) swaps=20(>=3): PASS` (**identical to prior record**).
- **Mixed:** `godot --path . --fixed-fps 60 res://minigames/swap_meet/swap_meet.tscn -- --seed=11 --shots=400,1000 --outdir=verify_out/botmix/swap` → `THROW/SWAP` from bots p1/p3; human RED auto-throttles but doesn't steer/throw, trailing. **Screenshot:** `verify_out/botmix/swap/shot_1000.png`.

### tilt (tick-deterministic, per-seat `bot_enabled`)
- **Changed:** `bot_enabled.append(_bots_all or _test_mode != "" or bool(roster[i].get("bot", false)))`; `_default_config` adds `bot`.
- **Legacy:** `... -- --tilttest=idle --seed=1` → `PASS`; `... -- --tiltbots --seed=7 --roundtime=20 --rounds=2 --quitafter=3000` → `bots=[true, true, true, true]`.
- **Mixed:** `godot --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- --seed=7 --roundtime=20 --rounds=1 --shots=200,430 --outdir=verify_out/botmix/tilt` → `bots=[false, true, true, true]`; 3 bots fight on the platter, idle RED slides off (expected for an uncontrolled seat on a tilting disc) and becomes a gull. **Screenshot:** `verify_out/botmix/tilt/shot_0430.png`.

### mower (tick-deterministic, per-seat `bot_enabled`)
- **Changed:** `bot_enabled.append(_bots_all or _covtest or bool(roster[i].get("bot", false)))`; `_default_config` adds `bot`.
- **Legacy:** `... -- --covtest --seed=5` → `MOWER_COVERAGE_ASSERT sum=100.0000% -> PASS`.
- **Mixed:** `godot --path . --fixed-fps 60 res://minigames/mower/mower.tscn -- --seed=7 --roundtime=30 --shots=300,700 --outdir=verify_out/botmix/mower` → `bots=[false, true, true, true]`; bots GOLD/MINT/BLUE mow 18–21% and ram, human RED drifts (auto-drive, no steering) at 9% and gets SPUN. **Screenshot:** `verify_out/botmix/mower/shot_0700.png`.

### greed (per-seat `bot_enabled`)
- **Changed:** `bot_enabled.append(_bots_all or bool(roster[i].get("bot", false)))`; `_default_config` adds `bot`.
- **Legacy:** `... -- --greedtest=intercept --seed=1` → `GREED_INTERCEPT rate=0.80 (bar>=0.60) PASS` (**identical to prior record**).
- **Mixed:** `godot --path . --fixed-fps 60 res://minigames/greed/greed.tscn -- --seed=3 --rounds=1 --roundtime=40 --shots=320,760 --outdir=verify_out/botmix/greed` → `bots=[false, true, true, true]`; bots grab/hunt the pot, human RED idle. **Screenshot:** `verify_out/botmix/greed/shot_0760.png`.

### dead_weight (per-seat `players[i].is_bot`)
- **Changed:** `"is_bot": _all_bots or bool(r.get("bot", false))`; `_default_config` adds `bot`.
- **Legacy:** `... -- --dwbalance=5 --seed=1` → `LIVING WIN % = 60.0%` (within the 55–75% band).
- **Mixed:** `godot --path . --fixed-fps 60 res://minigames/dead_weight/dead_weight.tscn -- --dwrounds=1 --seed=3 --shots=250,520 --outdir=verify_out/botmix/dw` → 3 bots hunt; headless log of the same config shows `MINT BOOTS RED INTO THE VOID (player)` — a bot shoving the idle human off. **Screenshot:** `verify_out/botmix/dw/shot_0250.png`.

### Par — `scripts/main.gd` (NEW minimal turn-based bot)
- **Changed:** added `_is_bot(i) = _par_bot_all or PlayerInput.is_bot(i)`, a `--parbots` force-all flag, a `_bot_rng` seeded from `GameState.rng` (reads `.seed`, does **not** draw, so draft/course/trap RNG is untouched), and a `_bot_tick(delta)` in `_process` that drives the current turn's seat **only if it is a bot**:
  - **DRAFT** → `debug_pick_card(0)` after ~1s.
  - **BUILD** → `placement.debug_place_scan(random_rot, GameState.rng)` after ~1s (random rotation from `_bot_rng`).
  - **PUTT** → aim ball→`course.cup_position()` with ±4° noise, `power = clamp(dist/2 + rng[0,1], 2, 13)`, via existing `putt_controller.debug_putt(power, angle)` after ~1.5s. **No putt physics/feel constants touched.**
  - Mouse putting is disabled on a bot's turn. Human seats are untouched (mouse drives their draft/build/putt).
- **All-bots:** `godot --headless --fixed-fps 120 --path . res://scenes/main.tscn -- --parbots --players=2 --rounds=2 --seed=1` → both bots draft, build, and sink balls in round 1 (normal) and round 2 (chaos): `BALL_SUNK p=1/p=0 round=1`, `... round=2`, `MATCH_OVER champ=BLUE` (proves the aim-at-cup angle math is correct — balls actually sink).
- **Mixed:** `godot --path . --fixed-fps 60 res://scenes/main.tscn -- --players=4 --rounds=2 --seed=1 --shots=820,1140 --outdir=verify_out/botmix/par` → draft order `[3,2,1,0]`, so bots BLUE/GOLD/MINT auto-draft and place all 6 of their traps, then the game correctly **waits** on human RED's "RED — DRAFT YOUR TRAP" panel (bot does not act for the human seat). **Screenshot:** `verify_out/botmix/par/shot_1140.png`.

---

## Deliberately not touched / notes

- **`estate.gd`** — already produced `roster[i].bot` correctly; no change needed. The bug was purely on the receiving (minigame) side.
- **`VerifyCapture` (`--autobuild`/`--autoplay`/`--shots`)** — the existing Par verify harness is independent of the new par bot and is left intact.
- **Putt physics / feel constants** — untouched; the par bot routes through the existing `debug_putt` entry point only.
- **`.import` files** — the import pass regenerated ~48 of them in this fresh worktree; reverted, as they are unrelated churn.
- **Standalone default behavior change (documented):** with **no** `party_setup.json`, a bare `godot … <minigame>.tscn` now self-plays **all-bots** (previously tilt/mower/greed drove only shared/unassigned seats, and echo/orbital/swap/dead_weight idled). This matches the "all four bot=true by default" intent; once the ESC overlay saves seat choices, `is_bot` is honored exactly. Par is exempt (human-first).
- **Auto-driving games (mower/swap):** an idle human seat still auto-throttles forward (game design), so "idle" reads as "drifts without steering/acting", not a frozen statue — visible in the screenshots as the human seat lagging far behind the bots.
