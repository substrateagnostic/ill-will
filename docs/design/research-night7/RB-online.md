# R-B: Multiplayer Without Port Forwarding / Without Steam (2026-07-18)

*Research lane, read-only. Question from the producer: "Possible to make
multiplayer without needing to forward ports / use Steam?" Answer: **yes** —
and the cheapest path (Tailscale, zero code) can ship to the friend group
tonight. A proper in-game fix (noray NAT punchthrough) is a half-day of work
against a transport seam that is already built for exactly this swap.*

---

## STEP 1 — existing netcode inventory (ground truth, read-only)

Transport today lives entirely in **`core/net_session.gd`** (927 lines, one
autoload, every RPC funnels through it). Confirmed by direct read, not
grep-guess:

- **Host-authoritative input relay behind PlayerInput** — the host runs the
  whole sim; remote clients sample their own devices, stream ~40-byte
  packets at 30 Hz (`unreliable_ordered`, ch.1, latest-seq-wins), host
  injects via `PlayerInput.set_remote_state`. Design doc:
  `docs/design/10-online-first-architecture.md`.
- **Two transports already wired, both live behind one seam:**
  - `transport = "enet"` (default) — `host_night()` / `join_night()`
    (`net_session.gd:188-236`) call raw `ENetMultiplayerPeer.create_server` /
    `.create_client()` directly. **This is the one that needs a forwarded
    port** — nothing punches or relays for it today.
  - `transport = "steam"` — `host_night_steam()` / `join_night_steam()`
    (`net_session.gd:393-472`) swap in `SteamMultiplayerPeer` from the
    vendored `addons/godotsteam/` GDExtension (GodotSteam 4.20, Steamworks
    1.64, MIT, win64+linux64, 18 MB). Rides Steam Datagram Relay — NAT
    traversal and relay fallback for free — but the producer's question
    explicitly excludes it.
  - **The seam is real, not aspirational:** every `@rpc` (input, lobby facts,
    walker snapshots, module state, private cards, ceremony media, ping,
    host-pause) lives in this one file and rides the high-level
    `MultiplayerAPI` — it never asks which `MultiplayerPeer` is underneath.
    `docs/design/12-steam-transport.md` proves this bit-for-bit: swapping
    `enet` → `steam` touched **one file, additively**, zero changes to
    `estate.gd`, `player_input.gd`, or any of the 15 game mirrors. The exact
    same shape of change is what a NAT-punchthrough option needs (§2c below).
  - `preferred_transport()` already exists as the auto-detect hook the shell
    would call to offer steam-or-enet; nothing analogous exists yet for a
    third transport, but the pattern to add one is proven.
- **Invite codes**: 6-char Crockford base32 encodes *private-range* IPv4 +
  port only (loopback / `192.168.x.x` / `10.x.x.x` / `172.16-31.x.x`).
  Public IPv4 doesn't fit in 30 bits — those hosts fall back to raw
  `IP:PORT` in the join box. This matters for §2: whatever NAT solution we
  pick, either it hands back a private-range address (codes keep working) or
  the join UI needs to accept whatever address form the new path returns
  (already does, for public IP:PORT).
- **CLI**: `--net=host [--port=N]`, `--net=join=IP:PORT|CODE`,
  `--transport=enet|steam`. `host_night(port)` / `join_night(target)` are the
  two functions any new transport plugs into.
- **Mirror-readiness — much further along than doc 10 (2026-07-06) assumed:**
  grep confirms **15 of ~16 minigames now carry `_net_state()`/`_net_apply()`**
  (dead_weight, echo_chamber, greed, last_will, masked_ball, mower, orbital,
  pallbearers, seance, swap_meet, throne, tilt, understudy, widows_gaze, plus
  fighter.gd). PAR is the deliberate holdout (mouse-driven, phase-3 lane per
  doc 10 §1.2). This means the "is the game mirror-ready" question is
  basically answered — the open question really is transport-only, which is
  the producer's exact framing.

**Bottom line: the game does not care what carries the bytes.** The question
is 100% "what sits inside `host_night()`/`join_night()`," and the codebase
already proves that swap is cheap (Steam did it in one additive pass).

---

## STEP 2 — options for no-port-forward play, ranked by effort against OUR transport

### (a) UPnP auto-open — Godot's built-in `UPNP` class

Doc 10 already evaluated and rejected this as "the plan" (§5.1, written
2026-07-06): a coin-flip on router support, and **worthless behind CGNAT**
(carrier-grade NAT) — increasingly common on cellular/some cable home
internet, and the router the guest is behind (not the host) is what fails
silently. `discover()` blocks for seconds and must run threaded. It only
ever helps the HOST's router (opens a port on the host's WAN side); it does
nothing for a guest's NAT and nothing at all if either side is behind CGNAT.
**Verdict unchanged: fine as a "try it" checkbox next to raw ENet, never the
plan.** Effort to wire: ~half a day (threaded discover, add-port-mapping
call, UI toggle) — cheap, but low payoff given the CGNAT dead end.

### (b) Tailscale / ZeroTier friend-group VPN — zero code changes

Every device joins a private mesh (Tailscale: WireGuard-based; ZeroTier
similar) and gets a stable virtual IP (Tailscale's is a `100.x.x.x`
address). Once everyone's on the tailnet, the game just... works — the host
runs `host_night()` bound to their Tailscale IP, guests `join_night()` to
that IP, and it's LAN-shaped traffic from the game's point of view. **Zero
lines of code.** Tailscale in particular does its own NAT traversal
(DERP relay fallback when direct P2P fails) so it beats raw UPnP in exactly
the cases UPnP can't touch (CGNAT, symmetric NAT).

Friction for a non-technical friend group: everyone installs the Tailscale
app, logs into a shared "tailnet" (free tier: 6 users / unlimited devices —
plenty for a 4-player night), and admits each other's device once. That's a
5-minute one-time setup per friend, not per session. After that, hosting is
"tell them my Tailscale IP" instead of "tell them my public IP and hope the
port's open." **This is the cheapest possible answer to the producer's
literal question tonight — it needs nothing from us.**

### (c) Self-hosted relay — noray (Foxssake/netfox family)

**Fits the producer's stated situation exactly** (always-on home Linux box,
technical). Verified by direct fetch of the noray repo and netfox.noray
docs, not guessed:

- **What it is:** `foxssake/noray` — a connection orchestrator + relay,
  written in **TypeScript, runs on Bun ≥1.3**. Self-host via `bun start`,
  Docker image, or `docker compose` (all three provided). Needs TCP
  8890-8891 open on the relay box plus a UDP port range (49152-51200 by
  default) for the relay-fallback path — i.e., the producer forwards ports
  **on their own always-on box once**, and every player behind it never
  forwards anything again.
- **Maturity, honestly:** 108 stars / 27 forks / 70 commits, actively
  developed, **no tagged releases** (pin a commit SHA if self-hosting) — a
  real but small-team project, not enterprise-grade. No free public instance
  documented; self-hosting is the expected model (which is exactly what's on
  offer here).
- **How it plugs into OUR code — this is the key finding:** `netfox.noray`
  does **not** replace `ENetMultiplayerPeer` with a custom peer type. It runs
  a punchthrough negotiation (host and guest each register with noray, noray
  coordinates simultaneous UDP sends so both routers punch a hole) and hands
  back **a plain address string + port**. That address is what you feed into
  the exact same `ENetMultiplayerPeer.create_server()` /
  `.create_client(ip, port)` calls already sitting in `net_session.gd:191-192`
  and `:229-230`. When punchthrough fails (symmetric NAT / hostile router on
  either side), it falls back to relaying UDP through the noray box itself —
  adds one hop of latency but "should work reliably no matter the router
  setup" per the docs, since it only depends on the relay's own reachability.
- **Effort against our codebase:** this is the same shape of change as the
  Steam seam that already shipped — add `transport = "noray"`, a
  `host_night_noray()` / `join_night_noray()` pair that does the punchthrough
  handshake then calls the SAME `ENetMultiplayerPeer.create_server/client`,
  wrapped in the SAME duck-typed graceful-absence pattern already proven for
  Steam (`Engine.has_singleton` style checks, or here: a small vendored
  addon + a reachability check to the configured relay host). Realistic
  estimate: **half a day** — most of it is the punchthrough handshake and
  wiring a `--relay=host:port` CLI/config knob, not touching `estate.gd`,
  `player_input.gd`, or any of the 15 already-mirrored games at all, exactly
  as the Steam precedent shows.
- **Godot version compat:** not explicitly pinned to 4.6.2 in the docs I
  could pull; netfox itself tracks current stable Godot 4.x, and since the
  integration surface is "an address string into stock ENetMultiplayerPeer,"
  engine-version risk is low even if the addon lags a point release.

### (d) WebRTC (Godot WebRTC peer + small signaling server) — determinism implications

Godot's WebRTC classes are native on HTML5 but need an external GDExtension
on desktop (`webrtc-native`) — another vendored binary, same shape of ask as
GodotSteam but for a transport with **no relay fallback of its own**:
symmetric NAT still needs a TURN server, which is separate infrastructure
from the signaling server. Doc 10 already flagged this (§5.1): "you end up
running relay infrastructure to reach parity with what Steam gives us free."
The signaling server itself is cheap (Godot ships a demo GDScript WebSocket
signaling server), but TURN is not — it's either a paid service (Twilio,
Cloudflare) or another box to run, on top of the box already running.

**Determinism implications for our lockstep-ish mirrors: none, actually** —
our transport is host-authoritative state-mirror, never lockstep (doc 10 §3
rejects lockstep outright on Jolt cross-platform-float grounds, unrelated to
transport choice). Swapping ENet for a `WebRTCMultiplayerPeer` is
transport-agnostic to the sim exactly like the noray/Steam swaps are — the
RPCs don't care. The real cost is infra (TURN), not code. **Net effort is
higher than (c) for no reliability upside** — noray already provides its own
relay fallback in the one server we're already standing up; WebRTC would
need that PLUS a signaling layer PLUS TURN. Skip.

### (e) Epic Online Services (EOS) free relay via a Godot plugin

Verified: mature-enough plugins exist — `3ddelano/epic-online-services-godot`
(EOSG, Godot 4.2+, actively maintained through mid-2026, Windows/Linux/Mac/
iOS/Android) and `Flying-Rat/GodotEOS`, both GDExtension wrappers around the
EOS C SDK with a documented "P2P + NAT relay" surface analogous to Steam's
SDR. Requires: an Epic Developer account (free) + registering the game as an
EOS product (free tier exists, meant for exactly this — indie NAT relay
without Steam). Real cost is integration labor, not money: EOS's P2P
interface is its own peer/socket abstraction, not a drop-in
`MultiplayerPeer` the way GodotSteam's `SteamMultiplayerPeer` is — meaning
this is NOT a one-file swap like Steam/noray; it likely needs a custom
`MultiplayerPeerExtension` wrapper around EOS's P2P calls to look like a
`MultiplayerPeer` to Godot's high-level API, since neither plugin appears to
ship one out of the box. **Estimate: multi-day, closer to (d) than (c) in
effort, for a benefit (identity/overlay/free relay) the producer didn't ask
for.** Worth a future look if the game ever needs cross-platform accounts;
overkill for "four friends, no port forwarding."

### (f) Newer / other 2026-era offerings — W4 Cloud

Checked live: **W4 Games ("W4 Cloud")** launched an open-source Godot-native
multiplayer backend in 2026 (`docs.w4.gd`). But it's architected as
**dedicated-server-authoritative**, not peer-hosted: integration means
adding the `W4GD` addon, wiring auth + lobbies, exporting a **headless Linux
server build** ("Strip Visuals"), and uploading that build to their cloud to
run on their infrastructure. That's a materially different model from "one
of the four friends' machines is the host" — it would mean re-architecting
who runs the sim, not just what carries the bytes. It does solve NAT (players
connect outbound to W4's servers, nobody accepts inbound) but at the cost of
abandoning the host-authoritative-on-a-friend's-PC model this whole codebase
(`docs/design/10-online-first-architecture.md`) is built around, plus an
undisclosed pricing tier once past free-tier limits. **Not a fit for a
4-friends-at-home anthology game — shelve unless the game ever goes
dedicated-server.**

---

## STEP 3 — recommendation ladder

| When | Pick | Effort | Why |
|---|---|---|---|
| **Tonight** | **(b) Tailscale** | **Zero code** | Everyone installs it once (free tier covers 6 people), host shares their Tailscale IP instead of a public IP, `--net=host`/`--net=join=<tailscale-ip>:8910` work completely unmodified. Solves CGNAT, symmetric NAT, and "which router forwards what" in one move. The 5-minute per-friend setup is a one-time tax, not a per-session one. |
| **Next week (low-code)** | **(c) noray, self-hosted on the producer's box** | **~half a day**, one new transport branch in `net_session.gd` (mirrors the Steam pattern exactly: `transport="noray"`, punchthrough handshake, then the SAME `ENetMultiplayerPeer.create_server/client` calls) | Removes the "everyone installs a VPN client" friction entirely — guests just run the game and enter a code, like Steam-transport already feels, but without Steam. The producer's own always-on Linux box is the natural home for the relay; noray's Docker deploy makes that a same-evening chore. Graceful-absence pattern (proven in doc 12) means the enet-direct and Steam paths stay untouched if the relay box is down. |
| **Proper long-term** | **(same c, hardened) + keep Steam as the ship-day option** | Incremental hardening: pin a noray commit/release, add a `--relay=` config knob + estate UI toggle next to HOST NIGHT (mirrors the existing `preferred_transport()` UI hook), add retry/backoff around the punchthrough handshake, document the producer's relay's public address in team docs. Steam transport (already fully built, `docs/design/12-steam-transport.md`) remains the zero-maintenance answer the day this ships publicly — it was excluded from THIS question but nothing here contradicts using it later. |

**My call, for a 4-friends-at-home audience specifically: ship Tailscale
tonight, and only build (c) noray if playtests show the "everyone installs a
VPN app" step is actually friction for this friend group.** If the answer is
"they're all reasonably technical and already tolerate a Discord call," (b)
is genuinely good enough forever and (c) never needs to get built. If the
target audience widens past this specific group (playtesters, a future
public release) before Steam ships, THEN (c) is the right half-day
investment — it's real in-game "paste a code, click join" UX with no
VPN app for guests, it reuses 100% of the existing invite-code/join-box UI,
and it's the same shape of change the codebase already proved out once.

No code was written or modified for this research pass.
