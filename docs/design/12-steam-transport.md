# Steam Transport Prep (2026-07-07)

*Phase-3 transport seam per `docs/design/10-online-first-architecture.md` §5.1
and §7-phase-3: GodotSteam vendored, `NetSession` grows a `transport =
"enet" | "steam"` seam, everything above the MultiplayerPeer proven
transport-agnostic. Steam is NOT installed on the build machine, so tonight's
receipts prove the enet paths bit-for-bit unchanged and the graceful-absence
posture; the steam-present smoke is on the owner (checklist below). Files
touched: `core/net_session.gd` (additive), `addons/godotsteam/**` (new),
`steam_appid.txt` (new), this doc. `project.godot` needed ZERO lines — Godot
4.6 discovers `.gdextension` files at import and registers them in
`.godot/extension_list.cfg` (verified: it lists
`res://addons/godotsteam/godotsteam.gdextension` after the import pass).*

---

## 1. Research (verified against upstream, 2026-07-07)

| Claim | Verified fact | Source |
|---|---|---|
| Current GDExtension release | **GodotSteam GDExtension 4.20**, tag `v4.20-gde`, published 2026-06-24, single asset `godotsteam-4.20-gdextension-plugin-4.4.zip` (27,416,154 bytes) | codeberg.org/godotsteam/godotsteam releases API |
| Engine support | compatibility_minimum **4.4** — one zip covers Godot 4.4+ including our 4.6.2 (Asset Library entry: "Godot 4.6, 4.6.1, 4.6.2, 4.6.3") | zip's `godotsteam.gdextension`; godotengine.org/asset-library/asset/2445 |
| Steamworks SDK | **1.64** (bundled `steam_api64.dll` / `libsteam_api.so` — Valve's redistributable rides inside the extension zip) | release name "Godot 4.4+ - Steamworks 1.64 - GodotSteam GDExtension 4.20" |
| SteamMultiplayerPeer | **Merged into mainline GodotSteam.** The standalone `GodotSteam/MultiplayerPeer` repo is ARCHIVED (last push 2025-11-13, final standalone release 4.16.2-mp). The gdextension branch registers `Steam` (CORE-level Engine singleton), `SteamMultiplayerPeer` + `SteamPacketPeer` (SCENE-level classes) | `register_types.cpp` on the `gdextension` branch; MultiplayerPeer repo metadata |
| Auto-init | `steam/initialization/processes/initialize_on_startup` defaults **false** — vendoring the extension does NOT touch the Steam API until we call `steamInitEx` | `godotsteam_project_settings.cpp` |
| License / size | MIT (`license.md` vendored). Full zip ~93 MB unpacked across 7 platforms; our trim is **18 MB** (win64 + linux64) | zip inspection |
| API shapes used | `steamInitEx(app_id := 0, embed_callbacks := false) -> Dictionary` (status 0 = OK, 2 = "client probably isn't running"); `createLobby(lobby_type, max_members)` → `lobby_created(connect, lobby_id)` (connect 1 = OK); `joinLobby(id)` → `lobby_joined(lobby, perms, locked, response)` (response 1 = success); `join_requested(lobby_id, steam_id)` fires on overlay-invite accept; `SteamMultiplayerPeer.host_with_lobby(lobby_id)` / `connect_to_lobby(lobby_id)`; `isSteamRunning()` valid pre-init; `run_callbacks()` must pump every frame; `initRelayNetworkAccess()` warms SDR early (Valve-recommended) | `doc_classes/Steam.xml` + `doc_classes/SteamMultiplayerPeer.xml`, godot4 branch |
| appid 480 reality | SpaceWar (480) initializes for ANY dev build **only when a Steam client is installed + running + logged in on the machine**. `steam_appid.txt` beside the exe/CWD identifies the app when not launched through Steam. Overlay invites from a 480 build read "Spacewar" in friends' clients and the friend must run a 480 build too — fine for our own two-machine tests, useless for real distribution | Steamworks SDK docs; standard GodotSteam workflow |

Two-instance-one-machine testing does NOT work over Steam transport (one
Steam client = one SteamID = you cannot lobby with yourself). ENet keeps that
rig forever — another reason the seam keeps both transports live.

## 2. What is vendored

```
addons/godotsteam/
  godotsteam.gdextension      entry symbol godotsteam_init, compat-min 4.4 —
                              TRIMMED to the two vendored platforms
  license.md                  MIT (kept per license terms)
  readme.md                   upstream readme (pinned-version reference)
  win64/   libgodotsteam.windows.template_{debug,release}.x86_64.dll + steam_api64.dll
  linux64/ libgodotsteam.linux.template_{debug,release}.x86_64.so + libsteam_api.so
steam_appid.txt               "480" at project root — DEV ONLY (see §5)
```

- Provenance: `godotsteam-4.20-gdextension-plugin-4.4.zip` from
  https://codeberg.org/godotsteam/godotsteam/releases tag `v4.20-gde`,
  SHA-256 `555659526e3416db8616319b915c987eccd08e420b11ae0938e08a7b81efb033`.
- Deliberately NOT vendored: `plugin.cfg` + `godotsteam_plugin.gd` +
  `editor/` (an editor updater dock that checks Codeberg for new versions —
  we pin by hand, nothing phones home), and the win32 / osx / linux32 /
  linuxarm64 / androidarm64 binaries (~75 MB we don't ship; re-extract from
  the upstream zip if a platform ever lands). The `.gdextension` file lists
  only vendored libs so nothing dangles.
- The GDExtension loads on every run (including headless receipts) and is
  SILENT: class registration only, zero Steam API calls until a steam
  host/join is requested. Proven by the soak receipt (§4).

## 3. The seam (`core/net_session.gd`, additive)

`NetSession.transport` reads `"enet"` or `"steam"` for the CURRENT session;
every `@rpc` (input relay ch.1, walker ch.2, ping ch.3, module state ch.4,
lobby facts, panel intents, private cards) rides the high-level
MultiplayerAPI and never asks which peer carries it. That is the whole
seam: **the transport swap is one `multiplayer.multiplayer_peer` assignment.**

New surface (everything else in the file is byte-path identical):

| API | Behavior |
|---|---|
| `steam_available()` | extension classes present (duck-typed: `Engine.has_singleton("Steam")` + `ClassDB.class_exists("SteamMultiplayerPeer")` — the file never names Steam types, so it parses on platforms without the libs) |
| `steam_running()` | Steam client alive on this machine (`isSteamRunning`, valid pre-init) |
| `steam_status()` | `"absent"` / `"offline"` / `"ready"` / `"up"` — one word for logs + estate UI |
| `preferred_transport()` | explicit `--transport=` wins, else `"steam"` when status is `ready`, else `"enet"` — what the estate HOST NIGHT flow should OFFER (estate wiring is the phase-3 estate pass, not tonight) |
| `host_night_steam()` | lazy `steamInitEx(480)` → `createLobby(FRIENDS_ONLY, 8)` → on `lobby_created`: `SteamMultiplayerPeer.host_with_lobby()`, `session_opened` fires exactly like the enet path |
| `join_night_steam(lobby_id)` | `joinLobby` → on `lobby_joined`: `connect_to_lobby()` → `connected_to_server` → the EXISTING seat-request RPC — roster, grants, relay all unchanged |
| `join_night(target)` | now also accepts `steam:LOBBYID` and bare 15+ digit lobby ids; codes/IP:PORT/bare-IP behavior untouched |
| `open_steam_invite_overlay()` | `activateGameOverlayInviteDialog(lobby)` — the real ship flow (no codes needed) |
| overlay accept | `join_requested` → auto `join_night_steam()` when OFFLINE |
| `steam_lobby_id()` | current lobby (0 = none) |
| CLI | `--transport=enet\|steam`; steam-host failure falls back to enet with one line; `invite_code()`/`listen_addr()` answer `steam:<lobby>` / `steam lobby <id>` under steam transport |
| callbacks | `run_callbacks()` pumped in `_process` only after a successful init |
| teardown | `leave()` / disconnect / connection-failure all `leaveLobby` + reset to enet posture |

Design decision, recorded: **CLI `--net=host` without `--transport=` stays
ENet forever.** Auto-detect *offers* steam (`preferred_transport()` for the
UI); it never silently switches the CLI, because every receipt in
`docs/verify/online-phase1-VERIFY.md` and the séance rig depends on
`--net=host` + `--net=join=127.0.0.1:8910` meaning loopback ENet on one
machine. Graceful presence, not surprise presence.

## 4. Receipts (all rerun tonight, this machine, Steam absent)

1. **Import pass** — clean, `.godot/extension_list.cfg` gained the extension.
   (First-ever import in this fresh worktree segfaulted once mid-batch and
   converged on rerun — one-off; runs 2-3 exit 0, cache stable at 237 files.)
2. **Invite-code selftest** — 5/5 `NETCODE ... PASS` + the public-IPv4 note,
   printed by every probe run, unchanged.
3. **NETPROBE couch tape A/B** (`--netprobe=couch --seed=7`, headless): all
   traces + results **byte-identical A vs B**, and byte-identical to the same
   run on master (`d0a1f18`) — the sim is untouched by the seam.
4. **Two-instance ENet handshake** (`--net=host --netprobe=host --seed=7` +
   `--net=join=127.0.0.1:8910 --nettape --netprobe=join`): full night — claim
   seat 1 → relayed READY → gate → game → reckoning → `NETPROBE_RESULTS
   RED:pts=3,grudge=3 BLUE:pts=5,grudge=3 GOLD:pts=2,grudge=1
   MINT:pts=1,grudge=5` — **identical to couch A/B AND to the master-baseline
   relay run**. NETHASH 27/27 host/client pairs identical. Both instances
   self-quit, saves restored, no orphan `.npbak`.
5. **Estate soak smoke** (`--estate --estatebots --quitafter=3200`, headless):
   exit 0, zero script errors, **zero Steam output** — the vendored DLL is
   loaded and silent. Exit-time "7 resources still in use"/ObjectDB warnings
   are byte-identical on master — pre-existing, not the addon.
6. **Graceful absence** (`--transport=steam --net=host`, Steam not installed):
   ```
   NET transports: enet ready · steam offline
   NET steam host unavailable (err=2) — hosting on enet instead
   NET host port=8910 err=0 code=80CMWE addr=192.168.0.101:8910
   ```
   exit 0, zero errors. Offline runs print nothing at all (the transports
   line only appears when a `--net=`/`--transport=` flag is in play).

**Rig hazard found while receipting (pre-existing, estate lane, NOT fixed
tonight — estate.gd is out of lanes):** when a two-instance run is killed
mid-flight (or the join instance lingers past the host), the surviving
client writes its remote-seat residue into the shared `user://
party_setup.json` (`device -99, bot false` on the claimed seat) AFTER the
host restored its backup. The NEXT two-instance run then grants the remote
knock seat 2 and the rig FAILs on "no remote claim on seat 1". Tonight's
first divergent-results run traced to exactly this dirty starting state.
Antidote until fixed: before a netprobe session, ensure seat 1 is a bot in
`party_setup.json`; take an external backup of `user://` first (the phase-1
crew did; do it every time). Candidate root fix for the estate pass: netprobe
join flow should skip `PartySetup.save()` entirely.

## 5. Publish-day checklist (when ILL WILL lists on Steam)

1. **Steamworks account**: partner.steamgames.com, $100 app fee (Steam
   Direct), recoupable at $1k gross. Company/tax/bank onboarding takes days —
   start early.
2. **Real appid**: swap ONE constant — `STEAM_APP_ID` in
   `core/net_session.gd`. Nothing else in code references 480.
3. **steam_appid.txt**: dev convenience only. It is NOT exported into the
   PCK (plain .txt, not a resource), but NEVER copy it next to a shipped
   exe — with it present, the build runs without Steam ownership checks.
   Publish builds launch through Steam, which injects the appid itself.
4. **Depot upload**: `steamcmd +login <builder> +run_app_build
   app_build_<appid>.vdf` — one depot for win64 (game exe + PCK +
   `steam_api64.dll` next to the exe), optional linux64 depot. The
   GodotSteam docs' export guide applies verbatim.
5. **Steamworks settings**: enable "Steam Networking" (SDR) for the app;
   set launch options; overlay works only in release-ish builds launched
   via Steam (dev overlay under 480 is flaky on Windows — known).
6. **RTM toggles**: set default branch live, mark the depot public, test
   with a beta branch + a second account first.
7. **Estate pass** (separate lane): HOST NIGHT button calls
   `preferred_transport()` — offers "HOST VIA STEAM (friends join from the
   overlay)" when `steam_status() == "ready"`; lobby card shows the friends
   list button (`open_steam_invite_overlay()`) instead of a code; SEATS tab
   REMOTE glyph reads persona names via `Steam.getFriendPersonaName`.

## 6. Cannot be tested until the owner has Steam running (+ second machine/account)

- `steamInitEx` success path, persona-name line, `run_callbacks` pump under load.
- Lobby create/join, overlay invite dialog, `join_requested` auto-join.
- SteamMultiplayerPeer handshake → seat grant → 30 Hz relay over Steam
  sockets, NETHASH mirror parity under SDR latency.
- Two-account end-to-end night (one machine cannot lobby with itself).
- What IS already proven without Steam: every enet receipt bit-for-bit, the
  fallback ladder, and that the extension's presence changes nothing.

**Owner smoke, 5 minutes, single machine, once Steam is installed+logged
in:** `godot --path . -- --transport=steam --net=host` → expect `NET steam
up as '<persona>' (appid 480)` then `NET steam lobby <id> open`. Then
shift+tab: overlay should render. That alone validates init, lobby, and
callbacks; the relay is transport-blind (receipt 4).

## 7. Sources

- Codeberg releases API (`godotsteam/godotsteam`): v4.20-gde asset list, dates
- https://godotengine.org/asset-library/asset/2445 (GDExtension 4.4+, MIT,
  4.20 current, Godot 4.6.x supported)
- `gdextension` branch `register_types.cpp` (class/singleton registration),
  `godotsteam_project_settings.cpp` (auto-init default false)
- `godot4` branch `doc_classes/Steam.xml` + `SteamMultiplayerPeer.xml`
  (every signature/signal used, quoted in §1)
- github.com/GodotSteam/MultiplayerPeer — archived 2025-11-13, merged mainline
- godotsteam.com blogs 2026-03-27 / 2026-06-24 (release cadence; site 403s
  robots, facts cross-checked via repo + asset library)
