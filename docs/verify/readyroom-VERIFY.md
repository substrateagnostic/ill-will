# READY ROOM v2 — verification & design conformance

*The remaining Ready Room items from `docs/design/04-menu-ux-research-digest.md`
(join flow + selector sections), built on the already-shipped press-A-to-join
and How-to-Play cards. All work is in `estate/estate.gd` only; verify artifacts
in `docs/verify/`. Nothing in `core/`, `scripts/`, `minigames/`, `scenes/`, or
`project.godot` was touched.*

## What was built

### 1. Pre-game GET READY card in the night flow (highest value)
When the auction resolves and a game is chosen (`CHOOSING -> _launch_game`),
the chosen game's How-to card is shown in a GET READY skin **before** the module
launches: goal + live per-seat controls (from `PlayerInput.describe_binding`, so
the card can't lie about bindings) + a per-human READY chip. Each human presses
their A to flip their chip green; the module launches when **every** human is
ready, or after a **15s countdown**, whichever comes first.

- `_launch_game(id, practice)` is now a thin gate: `if not exhibition and not
  _all_bots(): _show_get_ready(...)` else it falls straight through to
  `_do_launch_game(...)` (the old launch body, unchanged).
- **All-bot soaks skip the card entirely** — `_all_bots()` is true so the gate
  is bypassed and the soak never stalls (proven below: GREED launches straight
  out of the auction in an `--estatebots` night).
- **Exhibition/practice from the selector skip it** — those set `exhibition =
  true` and already showed the How-to card, so no double-show.
- A shared/mouse (-3) human seat has no discrete A, so it's counted ready on
  arrival and the countdown covers it; KB+MOUSE (-4) readies via its left mouse
  button (the card has no buttons, so there's no click conflict).

### 2. Ready Room seats — tri-state + READY chips
Lobby seat rows now read **HUMAN / BOT / EMPTY** (`_seat_status`). EMPTY =
device unassigned **and** not a bot; the row renders dim and its device shows
UNASSIGNED. The seat button cycles HUMAN -> BOT -> EMPTY -> HUMAN. An EMPTY seat
**auto-fills as a BOT** at night start (`_fill_empty_seats_with_bots`, called
from both `_start_night_from_lobby` and the `--estate` boot path).

Seated humans on a pad or keyboard half toggle a green **READY** chip with their
A (`_poll_lobby_ready`, via `PlayerInput.just_pressed` which respects
`binding_of`). **START THE NIGHT stays enabled always** (the host can force the
night) but its label grows a live waiting list — `START THE NIGHT (waiting:
GOLD)` — while any human is unready (`_start_btn_text`, refreshed every frame).

### 3. Keyboard join
An unassigned keyboard half joins exactly like a pad: `_poll_kb_join` polls the
**default** A-keys — Space for device -1, Enter for device -2 — via
`Input.is_physical_key_pressed`, but **only when that device id is not seated**.
On a rising edge it claims the first BOT/EMPTY seat as a HUMAN on that device
(`_claim_seat_for_device`, shared with pad join). The still-held join press is
swallowed by `_join_ready_lock` so one press joins without also flipping READY —
"A again = READY", per the lobby hint. KB+MOUSE stays button-driven (its A is
the left mouse button, which collides with clicking the lobby's own buttons);
the hint says so.

### 4. Pad disconnect
`Input.joy_connection_changed` is connected in `_ready`. If a **seated** pad
disconnects during **LOBBY or GROUNDS**, that seat flips to BOT and its device is
freed, with an Executor-register flash: `GAMEPAD 3 LOST — BLUE PLAYS ITSELF
UNTIL FURTHER NOTICE` (no exclamation marks, Saki voice). On reconnect during
LOBBY a `GAMEPAD n RESTORED — PRESS A TO TAKE A SEAT` flash invites a fresh
press-A claim (the freed pad can retake any open seat). **Mid-minigame
disconnects are out of scope** — the modules own their own input loops; this is
a later item (see Open items).

## Style conformance
The GET READY card is `_show_howto`'s exact layout (same goal Label, same
`— CONTROLS TONIGHT —` header, same per-seat `PlayerBadge.make` rows, same live
`describe_binding` lines) with the READY chips added. Rows are the estate's
plain Label/Button/HBox idiom; the chip is a plain green Label (no stylebox
surgery). Cues reuse `Sfx.play("confirm"/"card"/"grudge")`. All Executor text is
dry and exclamation-free.

## Regression safety
The gate must never break the E2E auction proof. `--auctiontest` bids as a human
P0, so the CHOOSING seat is human and the gate shows — the 15s countdown then
auto-passes with no input, so the flow still reaches GAME:

```
AUCTIONTEST bid placed as P0, high_bid=1 bidder=0
AUCTIONTEST clicking game button: DEAD WEIGHT
AUCTIONTEST PASS: game launched via clicked button
```

All named boot modes were smoke-tested clean (no script errors, no leaks):
`--estate --estatebots` (all-bot night — GREED launched straight out of the
auction, gate skipped), `--exhibtest=orbital` (exhibition, gate skipped),
`--strolltest`, `--howtotest`. `--wardrobetest` is untouched.

## Commands run

```
godot --headless --editor --import --quit --path .
# E2E auction proof (gate auto-passes on the 15s countdown, reaches GAME):
godot --headless --path . -- --estate --auctiontest
# all-bot night soak: gate is skipped, GREED launches out of the auction:
godot --headless --path . -- --estate --estatebots --quitafter=3200
# boot-mode smoke (no script errors):
godot --headless --path . -- --strolltest
godot --headless --path . -- --howtotest
godot --headless --path . -- --exhibtest=orbital
# windowed screenshot runs (self-back-up/restore party_setup.json, self-quit):
godot --path . -- --readytest       --outdir=docs/verify/shots --quitafter=6000
godot --path . -- --readylobbytest  --outdir=docs/verify/shots --quitafter=6000
```

## Save discipline
Every windowed run backs up `user://party_setup.json` -> `.rrbak` on entry and
restores it on exit inside the test hook itself (the `--wardrobetest` pattern),
because the join/ready flows persist seats via `PlayerInput.save_setup`. Verified
after the runs: `party_setup.json` and `cosmetics.json` byte-identical to their
pre-run state, no stray `.rrbak` files. `estate_save.json` is only ever written
at `end_night`; the bounded soaks quit mid-first-game and never touched it (the
owner's live night-2 progress was left exactly as found).

## Screenshots (`docs/verify/shots/`)
- `snap_readyroom_getready_0062.png` — the GET READY card for ORBITAL
  DODGEBALL: goal, live per-seat controls (RED on WASD/Space, BLUE on
  arrows/Enter, GOLD/MINT "bot, needs no manual"), BLUE's green READY chip,
  RED's amber PRESS A chip, and `waiting on RED · begins in 15s`.
- `snap_readyroom_lobby_0062.png` — the lobby: RED HUMAN + green READY chip,
  BLUE an EMPTY chair (dimmed, UNASSIGNED), GOLD HUMAN unready, MINT BOT, and
  `START THE NIGHT (waiting: GOLD)` with the join hint line.

## Open items (later)
- **Mid-minigame pad disconnect** — modules own their input loops; a shared
  drop-to-bot + rejoin-at-boundary pass (Mario Party Superstars pattern from the
  digest's Online section) belongs there, not in the shell.
- KB+MOUSE / SHARED (-3) seats can't ready via A in the lobby by design; if they
  ever need a diegetic ready, it should be a per-seat on-screen button.
- The tri-state seat button and the ESC-overlay SEATS tab (PartySetup) now
  express overlapping ideas; a later pass could unify them.
