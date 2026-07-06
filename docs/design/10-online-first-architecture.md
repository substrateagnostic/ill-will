# Online-First Architecture (2026-07-06)

*Systems blueprint for taking ILL WILL online. Owner's strategic call: online
co-op is the primary play mode (90%+ of 2026 party play); couch is the loved
second option. Every seat gets a full control surface (gamepad or KB+MOUSE).
This doc decides the authority model, designs the input relay, maps the
estate-as-lobby, buries lockstep, and lays the phased plan for one build day
plus the following evening. Written from a full audit of the codebase on this
date — file/line citations are real.*

---

## 0. The decision in one breath

**Host-authoritative input relay behind PlayerInput.** The host runs the
ENTIRE simulation exactly as couch does today — bots, physics, RNG, scoring,
all of it. Remote clients sample their own devices through the existing
PlayerInput code paths, stream compact input states (including *pre-computed
aim vectors*, never raw mice) to the host at 30 Hz, and the host injects them
into a new `_remote` seam inside `core/player_input.gd` — the exact pattern
the `_dbg_aim` verification hooks already prove works. Clients render a
mirror of the match: same scene, same seed (static world builds itself),
dynamic actors and HUD facts replicated back at 20–30 Hz with interpolation.
**Zero minigame code changes for input. Per-game work is only the render
mirror.** Steam Remote Play Together ships as the tier-0 fallback the whole
time. Rollback/prediction and lockstep determinism are rejected below, with
numbers.

---

## 1. Ground truth: the input audit (verified 2026-07-06)

### 1.1 The gift is real

Every contract minigame polls PlayerInput by player index. Better: almost all
of them collapse each seat's input into a per-tick **intent dictionary**
before it touches the sim — a ready-made interception boundary:

| Game | Intent collection point | Shape |
|---|---|---|
| tilt | `tilt.gd:396 _input_for(p)` | `{move, a, b}` |
| orbital | `orbital.gd:509-517` | `{move, a, b, aim}` (aim = `get_aim_screen`) |
| swap_meet | `swap_meet.gd:525` | `{move, a}` → `kart.step(dt, mv, b_down)` |
| mower | `mower.gd:566` | `{move, a, b}` |
| greed | `greed.gd:712` | `{move, grab, tackle, dash}` + `get_aim_dir` (:498) |
| dead_weight | `dead_weight.gd:782-813` | move/aim/fling per fighter+ghost |
| last_will | `last_will.gd:954-980` | move/aim/gust per pawn+ghost |
| throne | `throne.gd:302 _apply_intent(i, ...)` | move + a + b edges |
| seance | `seance.gd:784-786` | move + tap + surge |
| understudy | `understudy.gd:537-627` | `just_pressed` per phase |
| echo_chamber | `fighter.gd:216-366` | polls per-fighter (still 100% PlayerInput) |
| estate walkers | `estate.gd:1051-1070` | move + a/b per seat |

Bots are the same shape (`bots.decide(p, ...)` returns the same dict). A
remote human is architecturally identical to a bot: **another source feeding
the same intent pipe on the host.**

### 1.2 Violators (direct Input / InputEvent usage)

Graded by how much they matter online:

1. **PAR — the one real violator.** `scripts/putt_controller.gd:83` and
   `scripts/placement_controller.gd:42` are fully mouse-event-driven
   (`_unhandled_input`, drag/release, `InputEventMouseMotion`), device `-3`
   shared mouse by design. Par's entire control surface bypasses PlayerInput.
   Consequence: par is NOT the phase-1 online game (see §6); it gets a
   dedicated refactor lane in phase 3 (relay drag-vector + fire intents,
   which its `debug_show_aim`/`debug_putt` hooks at :169-183 already model).
2. **Killcam skip** — `scripts/killcam.gd:240` skips on ANY mouse click /
   `ui_accept`. Online: host-side input skips everyone's replay. Needs a
   gate (host or victim skips; or per-viewer local skip since the killcam is
   cosmetic). Small phase-2 chore.
3. **Standalone-only restarts** — `greed.gd:1422`, `echo_chamber.gd:1149`,
   `main.gd:365` (guarded by `_standalone`/`_selfstarted`/menu scene).
   Benign: never fire under the shell. No action.
4. **Estate shell couch-isms** — `estate.gd:613` + `:1083` scan raw
   keyboards/pads for press-A-to-join (lobby-level, by design — remote join
   replaces this with a network join, §5); `estate.gd:993` LMB click during
   stroll; **all shared panels (auction raise, side bets, trap tiles,
   freeroam desk, wardrobe, selector) are Buttons clicked by whoever holds
   the one mouse.** Mitigating grace: the handlers are already
   seat-parameterized (`_on_bid.bind(i)` at `estate.gd:1376`, per-seat tile
   buttons at :1216) — remote seats can invoke them via semantic intents
   without touching the handler logic. §5.3.
5. **party_setup.gd `_input`** (rebind listener) — inherently local
   (rebinding YOUR keyboard), stays local per client. No action.
6. **player_input.gd itself** reads Input — that's the backend. It is the
   one file that changes.

### 1.3 The aim functions are the subtle trap — and the codebase already solved it

`get_aim_dir(p, from_pos, cam)` (`player_input.gd:206`) needs the cursor +
camera **of the aiming player's machine**. On the host, a remote player's
cursor does not exist. Relaying raw mouse coordinates would also be wrong
(different resolutions, different interp state).

The fix is already designed into the file: `_dbg_aim` / `_dbg_aim_screen`
(`player_input.gd:40-44, 206-238`) inject synthetic **world-space and
screen-space unit vectors** ahead of the cursor math, byte-identically to
real input. The network seam is the same seam. Remote clients compute
`get_aim_dir`/`get_aim_screen` locally against their own mirrored render
(their camera is the same shared game camera; their pawn position lags one
snapshot, but aim is a direction — sub-degree error) and relay **unit
vectors**. `get_aim_stick` relays the raw right-stick Vector2.

---

## 2. Authority model — the three tiers

### Tier 0: Steam Remote Play Together (zero code, ships tonight)

Honest assessment for a Godot indie: RPT streams the host's video/audio to up
to 4 guests (more in ideal conditions) and forwards their controllers as
local devices; only the host owns the game
([store.steampowered.com/remoteplay](https://store.steampowered.com/remoteplay)).
Because PlayerInput reads joypads by id, **four pads over RPT work today with
zero changes.** Two quirks land in our favor: keyboard halves (-1/-2) mean a
guest on arrows + host on WASD genuinely coexist, and par's shared-mouse
model (-3) is exactly RPT's shared-cursor model — par over RPT is already
correct. Costs: guests watch a compressed stream, added input latency ≈
40–80 ms on good connections (capture+encode+network+decode), no drop-in/
rejoin story, everyone needs Steam running, and only ONE real KBM surface
exists — the full-surface-per-player policy dies at the stream boundary.
**Verdict: it is the launch-week fallback and the demo path, not the
product.** It also stays as the safety net for any game not yet ported to
tier 1.

### Tier 1: host-authoritative input relay (CHOSEN)

- Host = one player's machine, runs the party shell + entire sim, exactly
  the couch build. Remote clients = renderers + input samplers.
- Transport: Godot high-level multiplayer (`ENetMultiplayerPeer`, UDP) with
  `@rpc` reliability per message class — reliable for events/facts,
  `unreliable_ordered` for input and snapshot streams
  ([docs: high-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)).
- What `MultiplayerSynchronizer`/`SceneReplicationConfig` buy: declarative
  per-property replication with configurable `replication_interval`,
  delta-on-change, and visibility filtering
  ([class doc](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html)).
  They require matching NodePaths on both peers — which the mirror-scene
  pattern (§4) provides for free, since both sides instantiate the same
  module scene. Assessment: useful for clean pawn arrays, but across 12
  heterogeneous dynamically-built scenes the editor plumbing multiplies.
  **House standard: one custom `_net_state()` dict → RPC → `_net_apply()`
  per game** — a single pattern every fleet agent can copy, trivially
  hashable for verification (§7). Synchronizers stay permitted where a game
  is literally "N pawns with transforms."
- Latency: remote player's motion-to-photon ≈ ½RTT up + host tick + ½RTT
  down + interp buffer ≈ **RTT + 50–80 ms** → at friend-group pings
  (30–80 ms RTT) that's ~80–160 ms, versus ~50 ms couch. Cloud gaming
  ships whole genres at 80–150 ms; a chunky party anthology lives here
  comfortably. Per-game feel audit in §6.
- Bots cost nothing: they already run host-side inside each game. A dropped
  remote seat degrades to neutral input, then to a bot at the next boundary
  (§5.4). No bot state ever crosses the wire.

### Tier 2: rollback / client prediction (REJECTED — numbers)

GGPO-style rollback needs, every tick: full sim state save, and on each late
remote input a restore + resimulate of up to RTT worth of ticks (80 ms =
5 ticks @60 Hz). Requirements we cannot meet: (a) bit-deterministic
resimulation — dead on arrival across machines, §3; (b) full state
serialization including physics bodies — Godot exposes **no Jolt state
save/restore API** (`PhysicsServer3D` has no snapshot surface); (c) each of
12 heterogeneous sims rearchitected into a pure state-struct core — 1–2
weeks per game by any honest estimate, **3–6 months total, against a
one-build-day budget, to improve feel in exactly two games (swap karts, echo
clashes).** If swap steering ever truly hurts at 80 ms, the surgical answer
is client-side visual-only prediction of *your own kart* with reconciliation
— one game, phase 4+, not now. Buried.

---

## 3. Determinism audit: lockstep is dead, determinism still pays

**Can we send only inputs and have all clients simulate (lockstep)? No.**

- Jolt is deterministic only for the **same binary on the same CPU
  architecture**; the Jolt project itself does not guarantee cross-platform /
  cross-compiler determinism (differences in instruction selection, FMA
  contraction, and libm) — [github.com/jrouwe/JoltPhysics README,
  "Deterministic simulation"]. A Windows host and a Linux/Steam Deck client
  are different binaries by definition.
- GDScript float math routes through platform libm for transcendentals
  (`sin/cos/exp` are everywhere in our sims — kart steering alone:
  `swap_kart.gd:155-195`); ULP differences compound through feedback loops.
- Godot makes no cross-machine float-determinism promise anywhere in its
  networking docs; the official recommendation for its high-level stack is
  server-authoritative state replication
  ([docs: high-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)).
- One divergence under lockstep = a silent permanent fork with no recovery
  path except the state sync you were trying to avoid.

**What our seed-determinism (module contract: no `randomize()`, seed from
`config.rng_seed`) still buys online — a lot:**

1. **Free static worlds.** Clients instantiate the same module scene with the
   same config; layout generation draws from the same seeded stream at t=0
   with no physics in the loop → identical courses, arenas, decks, plays.
   Only *dynamic* actors need replication. (Authoritative collision stays
   host-side, so a stray ULP in a decorative transform is cosmetic.)
2. **Free bots.** Host-side only, as today.
3. **A transport regression suite.** The existing tally/receipt harnesses
   (`--seancetally`, `--ustally`, `--thronebalance`, ...) become the proof
   that networking didn't perturb the sim: same seed + same input tape
   through the couch path and through the relay path must print identical
   TALLY lines. §7.

---

## 4. The design: NetworkedInput relay + mirror scenes

### 4.1 New pieces (core lane)

```
core/net/net_session.gd   autoload NetSession — peer lifecycle, seat map,
                          host/join, invite code, role flags:
                          is_online(), is_host(), is_client(), seat_of_peer()
core/net/net_relay.gd     the two ends of the input pipe:
                          client: sample -> pack -> send @30Hz
                          host:   receive -> PlayerInput.set_remote_state()
```

### 4.2 The PlayerInput seam (~50 lines, the ONLY core edit)

```
var _remote := {}   # seat -> {move:Vector2, a:bool, b:bool, presses_a:int,
                    #          presses_b:int, aim:Vector3, aim_screen:Vector2,
                    #          stick:Vector2, seq:int}

get_move(p)        -> _remote[p].move when seat is remote
is_down(p, act)    -> _remote down-state OR a synthesized press-tick (below)
get_aim_dir(...)   -> _remote[p].aim        (mirrors _dbg_aim, line 209)
get_aim_screen(..) -> _remote[p].aim_screen (mirrors _dbg_aim_screen, :231)
get_aim_stick(p)   -> _remote[p].stick
just_pressed(p,a)  -> UNCHANGED — the existing _physics_process edge
                      detector (:274-278) snapshots is_down, which now
                      reads remote state. Edges fall out for free.
```

**Dropped-tap robustness (edge counters).** A 60 ms tap can fall between
30 Hz packets or die with a dropped datagram. The packet carries monotonic
`presses_a/presses_b` counters; the host injector compares against the last
credited count and, per uncredited press, holds the button down for exactly
one physics tick so the edge detector fires once. Standard technique; ~15
lines in the injector.

**Packet.** `{seq:u16, seat, move, a, b, presses_a, presses_b, aim,
aim_screen, stick}` ≈ 40 bytes @ 30 Hz ≈ **1.2 kB/s per client**. Latest-seq
wins; stale packets dropped. Bandwidth is a non-issue; don't spend build-day
time on quantization.

**Local echo.** v1: none for pawn motion — remote players' characters are
host-authoritative and arrive RTT late; that is the accepted tier-1 feel.
Cosmetic acknowledgment only (client-local SFX tick / button flash / their
own aim cursor rendered locally, which costs nothing and hides half the
latency perceptually). True motion prediction is explicitly out of scope.

### 4.3 Mirror scenes (the per-game work, honestly priced)

Client-side, `estate` launches the same module scene with the same config.
One guard, house-standardized:

```
# top of _physics_process in each ported game:
if NetSession.is_client():
    _net_apply_interp(delta)   # lerp actors toward last snapshot
    return                     # sim, bots, input sampling: host only
```

Host collects `_net_state() -> Dictionary` (pawn transforms + anim tags +
game globals + HUD facts) at 20–30 Hz on `unreliable_ordered`, plus discrete
**events** (banner text, sfx cue, kill_event, phase change) reliable. The
client's juice stays local and full-fat: particles, screenshake, music, and
fanfares fire from events, not from streamed video.

Sync surface by genre (this is where the radical difference lives):

| Genre | Games | Snapshot contents | Effort |
|---|---|---|---|
| UI / turn phase | understudy, last_will (will phases), par (phase 3), séance vote/talk | phase enum, texts, votes, chip positions | ~½ agent-day each |
| Hidden-info theater | seance, understudy | as above **plus a private-facts channel**: role/word flashes sent `rpc_id()` to the owning peer only. Online is *better* than couch here — no eyes-closed honor system. TALK stays on Discord (no in-game VOIP v1). | +~20 lines |
| Kinematic realtime | seance planchette, throne, mower, tilt | N pawn transforms + a few globals (platter tilt vector, focus meter, mow-grid **cell-diff events**, coins as spawn/despawn + live transforms) | ~1 agent-day each |
| Jolt-heavy realtime | greed, dead_weight, last_will, echo, orbital, swap | pawn/kart/orb transforms + velocities (for extrapolation) + state tags (drifting, parrying, carried) | ~1 agent-day each |

One timing special-case: **séance chant is rhythm-judged** (on-beat vs
off-beat against the candle pulse). Host-side judgment of a delayed press
makes remote sitters systematically late. The beat schedule is deterministic
and shared, so the client stamps each chant press with its local beat-phase
and the host scores from the stamp inside a ±150 ms trust window (friends
lobby; not an anti-cheat surface). ~30 lines, phase 1.

---

## 5. Estate as the shared lobby ("the hub IS the lobby" — design digest §Online)

### 5.1 Transport & NAT reality → the relay ladder

- **Now (build day):** raw `ENetMultiplayerPeer` — localhost, LAN,
  port-forwarded friends. Perfect for development and the two-instance
  verification rig.
- **Ship:** **Steam sockets via GodotSteam's `SteamMultiplayerPeer`** — a
  drop-in `MultiplayerPeer`, so the high-level API and every `@rpc` stay
  identical ([godotsteam.com](https://godotsteam.com)). Buys NAT traversal +
  free Steam Datagram Relay fallback, identity, and overlay invites. We are
  already Steam-committed (tier 0), so this is the obvious spine.
- **UPnP** (`class_upnp` — [docs](https://docs.godotengine.org/en/stable/classes/class_upnp.html),
  note: run `discover()` threaded, it blocks for seconds): a coin-flip on
  router support and worthless behind CGNAT (increasingly common on cellular
  home internet). Offer as a checkbox for the raw-ENet path; never the plan.
- **WebRTC + rendezvous server**: needs hosted signaling *plus* TURN relay
  for symmetric NAT ([docs: WebRTC](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html))
  — i.e., you end up running relay infrastructure to reach parity with what
  Steam gives us free. Only revisit for a non-Steam/web build. Skipped.

### 5.2 Invite flow (menu digest: friends-only + copy-paste code, no browser)

Host: title/ESC → **HOST NIGHT** → NetSession opens (ENet listen / Steam
lobby) → a 6-char code appears on the lobby card (phase 1: `IP:port` typed
directly; ship: code ↔ Steam lobby-data lookup). Joiner: **JOIN NIGHT** →
paste/enter code → peer connects → NetSession assigns the next free seat →
their walker spawns at the estate gate. Seat cards (Ready Room) grow a
REMOTE glyph + ping readout. Couch press-A-to-join and network join coexist:
a night can be 2 couch + 2 remote — seats don't care, they're just indices.

### 5.3 Four remote clients sharing one shell (the auction problem)

The estate is UI-driven and mouse-clicked today. The saving grace, verified:
**every shared-panel handler is already seat-parameterized** —
`_on_bid.bind(i)` (`estate.gd:1376`), per-seat trap-tile buttons (:1216),
per-seat bets, the ready gate polls `PlayerInput.just_pressed` per human
seat, stroll walkers poll per seat (:1051-1070). Design:

- **Relay-transparent (free once the seam lands):** stroll/free-roam
  walking, ready gate (`GET READY` card), lobby ready chips, séance/vote
  style A/B interactions. These already poll PlayerInput per seat.
- **Panel intents (small, explicit):** remote seat presses A on their
  mirrored panel → client sends `{seat, intent}` (`"raise"`, `"bet:2"`,
  `"buy_tile"`, `"continue"`) → host calls the existing handler with that
  seat index. The host's mouse keeps working for the host's own seat;
  buttons belonging to remote/bot seats are disabled for the host cursor
  (nobody spends another player's grudge).
- **Estate mirror state:** walker transforms (15 Hz), phase enum, panel
  facts (title + rows + button states as a small dict), banner/ticker
  lines, top-bar standings. The reckoning is a text ticker — trivially a
  fact stream.
- **CONTINUE authority:** host-authoritative, exactly as the digest
  prescribes — CONTINUE launches only on the host, gated by the *existing*
  ready check (`_ready_gate_needed` human seats, `estate.gd:1121`), which
  now naturally includes remote seats because it polls PlayerInput.
- **Wardrobe/selector:** per-seat where they matter (wardrobe purchases are
  seat-scoped already); selector browsing is host-driven with remote
  highlight mirroring in v1.

### 5.4 Drop → bot takeover → rejoin (the differentiator, digest §Online)

- **Drop mid-game (v1 honest behavior):** peer disconnect → relay feeds
  neutral input → the pawn idles; at the next boundary (module `finished` →
  estate) the seat flips to BOT via the existing couch machinery — estate
  already does exactly this for unplugged pads
  (`_on_joy_connection_changed` → `set_bot(i, true)` + `assign(i, -99)`,
  `estate.gd:1107-1109`).
- **Drop mid-game (v2, phase 3):** games latch bot flags at `begin()`
  (e.g. tilt's `bot_enabled[p]`); a one-line-per-game change to re-poll the
  seat's bot flag each tick makes takeover instant mid-round. Fleet-able
  chore across 11 files.
- **Rejoin at the boundary** (Mario Party Superstars pattern): the seat
  remembers its profile/peer identity; a reconnecting peer with the code
  reclaims its seat while the estate is between games. Mid-game rejoin
  stays out of scope until the mirror handshake can fast-forward state.

---

## 6. Latency feel per game @ 30–80 ms RTT (remote seat ≈ 80–160 ms total)

| Game | Verdict | Why |
|---|---|---|
| par, understudy, last_will (wills), all vote/talk phases | **Imperceptible** | turn/UI cadence |
| seance | **Good** | kinematic shared-tug planchette is slow by design; chant fixed by beat-stamps (§4.3) |
| throne | **Good** | walk + intent verbs; 0.4 s coronation ceremony dwarfs RTT |
| tilt | **Good** | shove has a deliberate 0.12 s windup *tell*; platter physics is slow-consequence |
| mower | **Good** | slow vehicles, area-denial gameplay |
| dead_weight, last_will (realtime) | **Good** | aim cursor is client-local; only the release crosses the wire |
| greed | **Acceptable** | tackle/dash feel a beat late; party-tolerable |
| echo_chamber | **Watch** | most timing-sensitive; but parry is a *held stance* (≥0.15 s threshold, 0.8 s riposte window, 1.0 s CD — `fighter.gd:59-62`), not frame-perfect. Playable ≤80 ms. If clashes feel unfair, widen clash windows +60 ms for remote seats ("netfair windows") — later. |
| swap_meet | **Worst offender** | continuous steering hates delay; partially masked by the existing exponential steer smoothing + auto-throttle (`swap_kart.gd:155-183`). Fine ≤60 ms, floaty at 80+. The ONLY future prediction candidate (own-kart visual prediction, phase 4+). Ship it honest first. |

---

## 7. Phased build plan (one build day + the following evening)

**Sequencing law: the CORE lane lands and verifies before anything fans
out.** Every other lane touches disjoint files — safe for parallel agents.

### Phase 1 — the spine: two-client estate + SÉANCE online (build-day morning, ~4 h)

Why séance and not par: par is the codebase's one true PlayerInput violator
(§1.2) — porting it first means refactoring mouse controllers *and* proving
the transport simultaneously. Séance is 100% PlayerInput, kinematic,
deterministic by design (`seance.gd:49-51`), and showcases the private-facts
channel that makes hidden-info games *better* online. Understudy then rides
the identical pattern nearly free.

| Lane | Files | Work |
|---|---|---|
| CORE (first, sequential) | `core/net/net_session.gd` (new), `core/net/net_relay.gd` (new), `core/player_input.gd` (+~50), `project.godot` (autoload) | session/seat map, 30 Hz input pipe, `_remote` seam + edge counters |
| ESTATE | `estate/estate.gd`, lobby UI | HOST/JOIN + code entry, remote seat claim, walker mirror @15 Hz, panel-intent plumbing for ready gate + CONTINUE + auction basics |
| SEANCE | `minigames/seance/seance.gd` (+~120) | client guard, `_net_state()/_net_apply()` (planchette, focus, letters, candles), private cast flash via `rpc_id`, beat-stamped chant |

**Gate:** two instances on one machine complete a full night
(lobby → ready → séance → reckoning → grounds) with the client driving
seat 1.

### Phase 2 — input-relay realtime games (build-day afternoon, agent fleet)

One agent per game, one lane per game: `minigames/<g>/<g>.gd` + optional
`minigames/<g>/net_adapter.gd` + `VERIFY-NET.md`. Port order (rising sync
surface): **understudy → throne → tilt → mower → greed → dead_weight →
last_will → echo → orbital → swap.** Realistic day-one yield: the first
5–6. Anything unported stays couch/RPT-only — the shell simply greys it in
the online selector. Plus the killcam-skip gating chore (§1.2.2).

### Phase 3 — par, rejoin, resilience (following evening)

- PAR lane: route placement/putt through seat-attributed intents (drag
  vector + fire — the shape `debug_putt(power, angle)` already takes);
  couch behavior byte-identical.
- Rejoin-at-boundary + seat reclaim; mid-game dynamic bot takeover
  (one-line re-poll per game); disconnect UX dialogs (flat ESC overlay per
  the menu digest).
- Transport upgrade spike: GodotSteam `SteamMultiplayerPeer` behind
  NetSession (the API seam means zero changes above it); UPnP checkbox for
  raw ENet.

### Verification without a second human (every phase)

1. **Two instances, one machine:**
   `godot --path . --position 0,60 -- --net=host --seed=7` and
   `godot --path . --position 960,60 -- --net=join --addr=127.0.0.1:8910`.
   House CLI-args convention continues (`--` user args, VerifyCapture
   `--shots=` works on BOTH instances → paired PNGs prove the mirror).
2. **NETPROBE tapes:** the client replays a scripted input tape into the
   relay (reuse the bot-decide streams as tape generators). Host prints the
   existing TALLY lines (`--seancetally`, `--ustally`, ...). Same seed +
   same tape, couch vs relay ⇒ identical TALLY ⇒ **the sim is provably
   untouched by the transport.**
3. **NETHASH:** host logs a per-second digest of authoritative actor
   transforms keyed by snapshot seq; client logs the digest of each applied
   snapshot at the same seq. Log diff catches ordering/staleness bugs
   (compare by seq, not wall clock — interpolation makes wall-clock
   comparison meaningless).
4. **Latency rig:** loopback UDP shaped with clumsy (Windows netem) at
   40/80/120 ms — feel-test swap and echo specifically, pad in one hand,
   KBM in the other.

---

## 8. The single biggest risk

**Not input — state.** The relay makes input free, but the render mirror is
per-game bespoke work, and it can silently eat the whole build day (12
heterogeneous scenes, dynamic spawns, HUD facts, juice events). Held in
check by: the one house pattern (`_net_state()/_net_apply()` + events),
strict phase gates (spine proven on séance before any fan-out), lanes that
never overlap, and Steam Remote Play Together as the always-shippable
fallback for whatever isn't ported yet. Second-order risks, named: NAT
pain before the Steam-sockets spike lands (mitigation: it's a dev-phase
problem; friends test via RPT meanwhile), and swap-kart feel at 80 ms+
(mitigation: ship honest, prediction is a scoped one-game follow-up).

---

## Appendix: source list

- Godot high-level multiplayer (ENet peer, `@rpc` reliability/channels,
  authority): https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- `MultiplayerSynchronizer` / `SceneReplicationConfig` / `MultiplayerSpawner`:
  https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html
- WebRTC in Godot (signaling required; TURN for symmetric NAT):
  https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html
- UPnP class (threaded discover, router-dependent):
  https://docs.godotengine.org/en/stable/classes/class_upnp.html
- Jolt Physics determinism scope (same binary/arch only):
  https://github.com/jrouwe/JoltPhysics (README, "Deterministic simulation")
- Steam Remote Play Together (streamed guests, device forwarding):
  https://store.steampowered.com/remoteplay
- GodotSteam `SteamMultiplayerPeer` (drop-in MultiplayerPeer, SDR relay):
  https://godotsteam.com
- In-repo ground truth: `core/player_input.gd` (the seam),
  `core/minigame.gd` (contract), `docs/specs/anthology-module-contract.md`
  (input policy 2026-07-04), `docs/design/04-menu-ux-research-digest.md`
  (online UX: invite codes, bot takeover, hub-is-the-lobby),
  `estate/estate.gd` (shell flow, seat-parameterized handlers).
