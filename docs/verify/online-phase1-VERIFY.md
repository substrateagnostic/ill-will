# ONLINE PHASE 1 — network core + shared estate lobby (verification)

*Built to `docs/design/10-online-first-architecture.md` (the spec is law):
host-authoritative input relay behind PlayerInput, the estate as the shared
lobby, spectate posture for unported games. Files touched: `core/net_session.gd`
(new autoload), `core/player_input.gd` (additive `_remote` seam only),
`estate/estate.gd`, `project.godot` (autoload line only). Nothing in
`minigames/**`, `scripts/`, or `scenes/` was touched.*

## What was built

### 1. `core/net_session.gd` — autoload NetSession
- **ENet host/join.** CLI (`--net=host [--port=N]`, `--net=join=IP:PORT`,
  `--net=join=CODE`, spec-form `--net=join --addr=...`) and programmatic API
  (`host_night()`, `join_night(target)`, `leave()`). Role flags `is_online() /
  is_host() / is_client()`, seat map (`is_seat_remote / seat_of_peer /
  peer_of_seat / my_seat`), per-peer RTT (`rtt_of_seat`, 2 s ping).
- **Transport-agnostic on purpose:** every message rides `@rpc` on the
  high-level MultiplayerAPI, all RPCs live in this one autoload, and the shell
  only ever calls `host_night()/join_night()`. Phase 3 swaps
  `ENetMultiplayerPeer` for GodotSteam's `SteamMultiplayerPeer` inside those
  two functions and nothing above this file changes.
- **Connection lifecycle signals:** `session_opened/closed`, `seat_requested`
  (host — the ESTATE owns seat policy and answers with `grant_seat`),
  `seat_claimed`, `peer_left_seat`, `seat_granted` (client), plus the estate
  mirror pipes (`lobby_state_received`, `walker_state_received`,
  `panel_intent_received`).
- **30 Hz input relay.** Client samples its own devices through the SAME
  PlayerInput per-index API, streams packets to the host
  (`unreliable_ordered`, channel 1, latest-seq wins with u16 wrap handling);
  the host validates the sending peer owns the seat and injects via
  `PlayerInput.set_remote_state`. An `set_aim_provider(Callable)` hook lets
  phase-2 game mirrors supply locally-computed aim vectors.
- **6-char INVITE CODE** (Crockford base32, I/L/O/U forgiven on entry):
  30 bits = 2-bit range tag + 28-bit payload encoding **private-range
  IPv4 + port** — loopback (any port), `192.168.x.x` (ports 8000–12095),
  `10.x.x.x` (8910–8925), `172.16-31.x.x` (8910–9165). Public IPv4 does not
  fit in 6 chars by information theory (48 bits); those hosts share raw
  `IP:PORT`, which the join box also accepts. Steam-lobby code lookup replaces
  this entirely in phase 3.

### 2. `core/player_input.gd` — the `_remote` seam (spec §4.2, additive)
Every query (`get_move`, `is_down`, `get_aim_dir`, `get_aim_screen`,
`get_aim_stick`, `describe_binding`) consults `_remote` FIRST — the `_dbg_aim`
injection pattern, networked. `just_pressed` is untouched: the existing
edge detector snapshots `is_down`, which now reads remote state, so edges
fall out for free. **Dropped-tap rescue:** monotonic `presses_a/presses_b`
counters; a natural rising edge credits one press; each still-owed press
synthesizes a one-tick hold from a released state so the edge detector fires
exactly once (backlog capped at 3 so a stall cannot burst-fire). The seam is
empty in couch play — offline behavior is byte-identical (all existing
CLI hooks pass, below).

**Packet schema (exactly the spec's §4.2):**

```
{ seq:u16, seat:int, move:Vector2, a:bool, b:bool,
  presses_a:int, presses_b:int,          # monotonic tap counters
  aim:Vector3, aim_screen:Vector2,       # PRE-COMPUTED unit vectors, never raw mice
  stick:Vector2 }                        # raw right-stick passthrough
```

≈40 bytes @ 30 Hz ≈ 1.2 kB/s per client. Estate phase sends zero aim vectors
(walkers do not aim); the fields ride along for phase-2 game mirrors.

### 3. `estate/estate.gd` — the estate IS the lobby (spec §5)
- **Title row:** HOST NIGHT (opens the session, enters the lobby with an
  `OPEN NIGHT — CODE XXXXXX · ip:port · N guest(s)` card) and JOIN NIGHT
  (code/IP entry panel, "KNOCK").
- **Remote seat claim:** a joining peer takes the first BOT/EMPTY chair —
  `%s JOINS FROM AFAR` flash; seat status becomes **REMOTE** (`REMOTE LINK ·
  N ms` ping readout, host cannot cycle or reassign it). Couch press-A joins
  and network joins coexist: seats are just indices.
- **Relay-transparent flows:** the remote walker strolls the host's grounds
  and the lobby READY chip + GET READY gate poll `PlayerInput.just_pressed`
  as ever — zero changes to those code paths beyond letting REMOTE seats
  through the device filter. The GET READY card lists remote seats as
  `REMOTE — readies from their own estate`, and CONTINUE/START stay
  host-authoritative.
- **Panel intents (spec §5.3):** clients send `{kind:"ready_toggle"}`; the
  host runs the seat-parameterized handler. Auction raise/bets/tiles buttons
  are DISABLED for remote seats host-side (the host's cursor never spends a
  guest's grudge) — their intents arrive in phase 2.
- **Disconnect → BOT:** peer drop flips the seat to BOT on the existing
  Executor register — `THE WIRE TO %s WENT DEAD — %s PLAYS ITSELF UNTIL
  FURTHER NOTICE`. Mid-game the relay already feeds neutral input (pawn
  idles), and the latched bot flag takes over at the boundary — exactly the
  couch pad-unplug behavior. Rejoin-at-boundary seat reclaim is phase 3.
- **Client mirror (estate only, phase 1):** the client renders lobby FACTS
  (5 Hz reliable dict: phase, seats, ready chips, gate goal/waiting/countdown,
  standings, code) and walker snapshots (15 Hz `unreliable_ordered`,
  interpolated `pos/rot/anim`); its own walkers' physics is disabled (mirror
  puppets). During a minigame the client shows the **spectate placeholder
  card** — "NIGHT n — GAME · played on the host's screen, your inputs still
  reach your pawn" + live ladder — the spec's always-shippable posture; full
  game mirrors are phase 2. The reckoning mirrors the settled ladder.

## Two-instance NETPROBE evidence (one machine, spec §7)

```
godot --path . --position 0,60   -- --net=host --netprobe=host --seed=7 --quitafter=200000 --outdir=docs/verify/netshots_host
godot --path . --position 660,120 -- --net=join=127.0.0.1:8910 --nettape --netprobe=join --quitafter=200000 --outdir=docs/verify/netshots_join
```

Scripted end-to-end: client connects → requests a seat → host grants seat 1 →
the deterministic input tape streams over the wire (square stroll, one A press
for READY, later A pulses to answer the gate) → host starts the night →
free-roam → auction (bots bid) → GET READY gate (remote readies via relayed A)
→ mock game → reckoning → both quit. Full logs:
`online-phase1-host.log`, `online-phase1-client.log`, `online-phase1-couch.log`.

**Screenshots (all read by eye, windowed):**
- `online_host_claim.png` — host lobby: `BLUE JOINS FROM AFAR`, BLUE = REMOTE
  + `REMOTE LINK · 0 ms`, `OPEN NIGHT — CODE 80CMWE · 192.168.0.101:8910 ·
  1 guest(s)`.
- `online_host_ready.png` — BLUE's green READY chip lit by the relayed A;
  START label live: `START THE NIGHT (waiting: RED)`.
- `online_host_gate.png` — GET READY card: `BLUE — REMOTE — readies from
  their own estate`, `waiting on BLUE · begins in 15s`.
- `online_host_game.png` — mock night's game running on the host.
- `online_host_reckoning.png` — reckoning ticker + updated top bar.
- `online_client_lobby.png` — client's `AN ONLINE NIGHT` panel, `BLUE (you)
  REMOTE`, READY/LEAVE buttons, mirrored walkers strolling behind it.
- `online_client_ready.png` — client sees its own READY chip via the mirror.
- `online_client_gate.png` — mirrored gate facts (goal, waiting list, 15 s).
- `online_client_spectate.png` — the phase-1 spectate card + live ladder.
- `online_client_reckoning.png` — mirrored settled ladder
  (GOLD 5♠2 / BLUE 3♠3 / MINT 2♠1 / RED 1♠4).

### Input-tape determinism (spec §7.2 — "the sim is provably untouched")

The SAME tape runs through the SAME injector two ways: `--netprobe=couch`
(direct `set_remote_state`, no wire) and the two-instance relay.

1. **Couch A vs couch B (seed 7): byte-identical** — all 11 `NETPROBE_TRACE`
   lines and `NETPROBE_RESULTS` match exactly. The sim + seam are
   deterministic.
2. **Couch vs relay (seed 7): `NETPROBE_RESULTS` IDENTICAL** —
   `RED:pts=1,grudge=4 BLUE:pts=3,grudge=3 GOLD:pts=5,grudge=2
   MINT:pts=2,grudge=1` in every run. Same seed + same tape through the wire
   produced the same night: auction, choice, mock placements, grudge — the
   transport did not perturb the simulation. (This is the estate's
   TALLY-equivalent; `--seancetally` etc. join the harness when those games
   port in phase 2.)
3. **Position traces, honestly:** relay traces match couch within **1–2
   physics ticks of packet-arrival jitter** (max offset ≈ 0.11 m at
   direction-change corners; straightaways byte-equal). One run showed a
   transient ~0.4 m drift when window-focus contention stalled packets for
   ~7 ticks — the designed latest-state-wins degradation (stale input
   persists briefly); the results line was still identical. Walker positions
   are host-authoritative cosmetics; nothing resimulates.

### NETHASH mirror integrity (spec §7.3)

Host prints a digest of every 15th walker snapshot at send; client prints the
digest of the same snapshot at apply, keyed by seq (never wall clock).
**27/27 pairs identical** in the final run (and 24/24, 27/27 in earlier runs).

### Invite-code selftest (printed by every probe run)

```
NETCODE 127.0.0.1:8910 -> 0008PE -> 127.0.0.1:8910 PASS
NETCODE 192.168.1.42:8910 -> 8158WE -> 192.168.1.42:8910 PASS
NETCODE 10.0.7.200:8912 -> G00Z42 -> 10.0.7.200:8912 PASS
NETCODE 172.20.3.9:9000 -> T062AT -> 172.20.3.9:9000 PASS
NETCODE 192.168.240.17:11999 -> FG27WZ -> 192.168.240.17:11999 PASS
NETCODE 203.0.113.5:8910 -> '' (public IPv4 shares raw IP:PORT; Steam-code rendezvous is phase 3)
```

## Latent couch bugs found BY the rig (fixed at the root)

1. **READY double-toggle at high fps** — `_poll_lobby_ready` runs in
   `_process`; when render fps outruns the 60 Hz physics tick, two frames see
   the same `just_pressed` edge and toggle READY twice (net zero). Invisible
   on a vsynced couch, immediate with two windows on one GPU. Fixed: each
   edge is consumed once, keyed by `Engine.get_physics_frames()`.
2. **Panel rebuild name-mangling** — `_clear_panel` queue_free'd children
   keep their names until end of frame, so a same-frame rebuild got its
   `SeatRow%d`/`ReadyChip` nodes auto-renamed (`@SeatRow1@...`) and every
   later `get_node_or_null` chip update silently missed. Fixed:
   `remove_child` before `queue_free`. Benefits every panel flow, couch
   included.
3. **START waiting-list never updated live** — `_update_lobby_start_btn`
   looked for `StartBtn` as a DIRECT child of the panel box, but it lives
   inside a button row; the label only refreshed on full rebuilds. Fixed
   with `find_child`.

## Regressions (all pass, offline behavior untouched)

```
godot --headless --editor --import --quit --path .
godot --headless --path . -- --estate --auctiontest            # AUCTIONTEST PASS: game launched
godot --headless --path . -- --estate --estatebots --quitafter=3200   # clean, no script errors
godot --headless --path . -- --strolltest                      # clean
godot --headless --path . -- --wardrobetest                    # output identical to main checkout baseline
godot --path . -- --readytest --quitafter=6000                 # GET READY card verified by screenshot
```

## Save discipline

`user://party_setup.json` + `prefs.json` are backed up/restored by the probe
itself (`.npbak`, the `--readytest` pattern). The `--estate` regression hooks
save seats by design (pre-existing behavior); the owner's real
`party_setup.json` was restored byte-identical from an external pre-run
backup and verified by hash, along with `prefs.json`, `estate_save.json`,
`cosmetics.json`, `saves/slot_1.json` (all untouched — the bounded runs never
reached `end_night`).

## Honest limitations / notes for the owner

- **Reach:** phase 1 is loopback/LAN/port-forward only. To host for friends
  over the internet tonight: forward UDP **8910** (or run Steam Remote Play
  Together, which needs nothing). The real fix is the phase-3
  `SteamMultiplayerPeer` swap — NAT traversal + relay + overlay invites for
  free; the NetSession API was shaped so that swap touches one file.
- **6-char codes cover private ranges only** (see above); public-IP hosts
  read out `IP:PORT` instead. No checksum in the code — a typo usually just
  fails to connect (decode-to-garbage connects nowhere); acceptable for a
  friends lobby, gone entirely with Steam codes.
- **Remote latency feel:** remote walker motion is host-authoritative and
  arrives RTT late (spec tier-1 posture, ~RTT+50–80 ms motion-to-photon).
  On loopback it is imperceptible; judge real feel at 40–120 ms with clumsy
  per the spec's latency rig once a realtime game mirror lands (phase 2).
- **Client renders lobby FACTS, not the host's pixels** — auction/bet/tile
  panels are not yet mirrored for interaction (buttons for remote seats are
  disabled host-side; `ready_toggle` is the only intent wired). Remote seats
  cannot yet bid, bet, buy tiles, shop the wardrobe, or trigger stroll
  landmarks — phase-2 panel intents on the pipe that already exists.
- **Mid-game join is declined** ("knock again between games"); rejoin/seat
  reclaim at the boundary is phase 3 per spec §5.4.
- **ESC SEATS tab** (PartySetup overlay) doesn't know about REMOTE seats yet;
  the host could reassign a remote seat's device there (harmless — the relay
  overrides — but the UI should grow the REMOTE glyph in phase 2).
- **Both instances share one `user://`** on a single dev machine — fine for
  the probe (bounded, restored), just don't run two instances while a real
  night is being saved.
- **Ping readout** shows 0 ms on loopback (true); it updates every 2 s.
- The `--nettape` probe tape lives in `net_session.gd` (`TAPE`); its A-pulses
  begin at tick 1200 so they answer the GET READY gate without fighting the
  lobby READY window.

## Phase-2 handoff (for the minigame-mirror wave)

- Input arrives for free: any game polling PlayerInput by index already
  receives remote seats on the host. Per game, add the client guard +
  `_net_state()/_net_apply()` snapshot per spec §4.3, shipped over
  `NetSession.send_walker_state`-style RPCs (add game channels or reuse the
  lobby/walker pattern; `send_panel_intent` is live for UI games).
- `NetSession.set_aim_provider(cb)` is the client-side hook for aiming games:
  return `{aim: Vector3, aim_screen: Vector2}` computed against the mirrored
  render; the host injects them through the seam (`get_aim_dir` prefers
  remote vectors ahead of the cursor math).
- Killcam-skip gating (spec §1.2.2) still open; séance beat-stamp chant
  (spec §4.3) specced for the séance port.
- NETPROBE pattern to copy: `--netprobe=couch` (headless determinism diff),
  `--netprobe=host/join` (two windowed instances, paired snaps via separate
  `--outdir`), `NETPROBE_TRACE`/`NETHASH`/`NETPROBE_RESULTS` lines.
