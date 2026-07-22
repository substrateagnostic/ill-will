extends Node
## Autoload NetSession — ONLINE PHASE 1 (spec: docs/design/10-online-first-architecture.md).
## Host-authoritative input relay behind PlayerInput. The host runs the ENTIRE
## simulation exactly as couch does; remote clients sample their own devices,
## stream compact input states at 30 Hz, and the host injects them into the
## PlayerInput `_remote` seam (the `_dbg_aim` pattern, networked).
##
## Transport phase 1: raw ENetMultiplayerPeer — localhost / LAN / port-forward.
## Transport phase 3 (THIS SEAM, docs/design/12-steam-transport.md): GodotSteam
## GDExtension 4.20 vendored in addons/godotsteam — SteamMultiplayerPeer rides
## the SAME high-level MultiplayerAPI, so every @rpc, the seat map, the roster
## and the 30 Hz relay below are transport-agnostic: nothing above the two
## host/join entry points changes. Steam is duck-typed via Engine.get_singleton
## / ClassDB (never a hard identifier), so this file parses and runs bit-for-bit
## on machines with no Steam client and on platforms with no vendored libs.
##
## CLI:  --net=host [--port=N]           host on N (default 8910)
##       --net=join=IP:PORT              join a direct address
##       --net=join --addr=IP:PORT       spec §7 form, same thing
##       --net=join=CODE                 join a 6-char invite code
##       --net=join=steam:LOBBYID        join a Steam lobby (or bare 15+ digits)
##       --net=join=noray:OID            join via a noray relay (needs --relay=)
##       --net=join=norayrelay:OID       same, but skip punchthrough (relay only)
##       --relay=HOST[:PORT]             the noray relay to use (default port 8890)
##       --transport=enet|steam|noray    explicit transport pick (default enet;
##                                       steam/noray fall back to enet when absent)
##       --nettape                       NETPROBE: drive the claimed seat from
##                                       the built-in deterministic input tape
##
## INPUT PACKET (spec §4.2), client -> host @ 30 Hz, unreliable_ordered ch.1:
##   { seq:int(u16), seat:int, move:Vector2, a:bool, b:bool, jump:bool,
##     plan:bool, plan_y:bool,             # LB tray + Y face while planning
##     presses_a:int, presses_b:int,      # monotonic tap counters (edge rescue)
##     presses_jump:int, presses_plan:int, presses_plan_y:int,
##     aim:Vector3, aim_screen:Vector2,   # PRE-COMPUTED unit vectors, never raw mice
##     stick:Vector2 }                    # raw right-stick for pad aim
## ~45 bytes @ 30 Hz ≈ 1.4 kB/s per client. Latest-seq wins; stale drops.
## The jump fields are additive: dict packets are shape-tolerant, so an old
## build simply reads/sends jump=false — no protocol constant exists or breaks.

signal session_opened(role: int)
signal session_closed(reason: String)
signal seat_requested(peer_id: int)              # host: estate decides + grants
signal seat_claimed(seat: int, peer_id: int)     # host: mapping recorded
signal peer_left_seat(seat: int, peer_id: int)   # host: estate flips seat to BOT
signal seat_granted(seat: int, reason: String)   # client: my seat (or -1 + reason)
signal lobby_state_received(state: Dictionary)   # client: estate mirror facts
signal walker_state_received(state: Dictionary)  # client: walker snapshot @15Hz
signal panel_intent_received(seat: int, intent: Dictionary)  # host: semantic UI intent
signal probe_first_input(seat: int)              # host, NETPROBE only: tape landed
# --- PHASE 2: game mirrors (docs/design/10 §4.3; first game: THE SÉANCE) ---
signal module_state_received(state: Dictionary)  # client: running game's _net_state()
signal module_private_received(data: Dictionary) # client: THIS seat's hidden info only
## The host stepped into its ESC/settings overlay (or lost a local controller):
## the whole shared simulation is frozen on the host until it resumes. The 20 Hz
## state pump lives in the estate's (pausable) _process, so it stops the instant
## the host pauses — but THIS autoload is PROCESS_MODE_ALWAYS and the ENet socket
## keeps being serviced, so this one fact still crosses the wire. The guest shows
## "the estate holds its breath" instead of freezing with no explanation.
signal host_pause_changed(paused: bool)          # client: host paused / resumed

enum Role { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT := 8910
const MAX_GUESTS := 7
const INPUT_SEND_EVERY := 2       # physics ticks between packets: 60/2 = 30 Hz
const PING_INTERVAL := 2.0
## Crockford base32 (no I L O U): 6 chars = 30 bits = 2-bit range tag + 28-bit
## payload. Private IPv4 ranges + port fit; public IPv4 does not (those hosts
## share raw IP:PORT until the Steam-code rendezvous lands in phase 3).
const CODE_ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

var role: int = Role.OFFLINE
## "enet" | "steam" | "noray" — which transport carries the CURRENT session.
## Meaningless while OFFLINE (reads "enet", the default). Note "noray" still
## RIDES an ENetMultiplayerPeer — the value records how the wire was opened.
var transport := "enet"
var _listen_port := DEFAULT_PORT
var _seat_by_peer := {}   # peer_id -> seat  (peer 0 = the local couch-probe tape)
var _peer_by_seat := {}   # seat -> peer_id
var _my_seat := -1        # client: seat granted by the host
var _last_seq := {}       # host: seat -> last accepted packet seq
var _rtt_ms := {}         # host: peer_id -> measured round trip
var _ping_accum := 0.0
## True while the shared sim is frozen by the host's pause. On the HOST this is
## set from PartySetup when the settings/disconnect overlay opens; on a CLIENT it
## mirrors the host's state via _rpc_host_pause. Guests stop streaming input and
## raise the "held breath" overlay while it is true.
var _host_paused := false

# --- client input sampling state
var _send_gap := 0
var _seq := 0
var _presses_a := 0
var _presses_b := 0
var _presses_jump := 0
var _presses_plan: int = 0
var _presses_plan_y: int = 0
var _aim_provider := Callable()   # phase-2 game mirrors install {aim, aim_screen}

# --- CLI
var _cli_mode := ""
var _cli_target := ""
var _cli_transport := ""          # "" = default (enet) | "enet" | "steam"
var _join_retries := 0
var _probe := false

# --- STEAM transport seam (phase 3, docs/design/12-steam-transport.md)
## SpaceWar dev appid. PUBLISH DAY: replace with the real appid (one constant).
const STEAM_APP_ID := 480
const STEAM_LOBBY_FRIENDS_ONLY := 1   # Steam.LobbyType FRIENDS_ONLY
var _steam: Object = null             # the Steam singleton, when the extension is present
var _steam_inited := false            # steamInitEx succeeded this process
var _steam_lobby_id := 0              # the lobby the current session rides (0 = none)
var _steam_pending := ""              # "" | "host" | "join:<lobby>" (lobby callback in flight)

# --- NETPROBE deterministic input tape (see docs/verify/online-phase1-VERIFY.md)
# Steps hold until the next entry. After the lobby window the tape pulses A
# periodically so a mirrored minigame can exercise edge delivery.
const TAPE := [
	{"t": 0, "move": Vector2(-1, 0), "a": false},
	{"t": 60, "move": Vector2(0, -1), "a": false},
	{"t": 120, "move": Vector2(1, 0), "a": false},
	{"t": 180, "move": Vector2(0, 1), "a": false},
	{"t": 240, "move": Vector2.ZERO, "a": false},
	{"t": 300, "move": Vector2.ZERO, "a": true},    # single A press: lobby READY
	{"t": 306, "move": Vector2.ZERO, "a": false},
]
const TAPE_PULSE_FROM := 1200
const TAPE_PULSE_EVERY := 90
const TAPE_PULSE_WIDTH := 6
## 13500 ticks = 225 s: long enough to reach the Séance chant window and VOTE
## lock (~tick 12700) in the long-form network probe.
const TAPE_END := 13500

var _tape_requested := false
var _tape_active := false
var _tape_local := false          # couch probe: inject directly, no wire
var _tape_seat := -1
var _tape_tick := -1
var _tape_prev_a := false
var _tape_pa := 0
var _tape_seq := 0
var _tape_a_edge := false         # one-tick flag: the tape pressed A this tick
var _trace_tick := -1             # NETPROBE trace clock (estate prints positions)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	for arg in OS.get_cmdline_user_args():
		if arg == "--net=host":
			_cli_mode = "host"
		elif arg.begins_with("--net=join="):
			_cli_mode = "join"
			_cli_target = arg.trim_prefix("--net=join=")
		elif arg == "--net=join":
			_cli_mode = "join"
		elif arg.begins_with("--addr="):
			_cli_target = arg.trim_prefix("--addr=")
		elif arg.begins_with("--port="):
			_listen_port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--transport="):
			_cli_transport = arg.trim_prefix("--transport=")
		elif arg.begins_with("--relay="):
			set_relay(arg.trim_prefix("--relay="))
		elif arg == "--nettape":
			_tape_requested = true
		elif arg.begins_with("--netprobe="):
			_probe = true
	if _cli_mode != "" or _cli_transport != "":
		print("NET transports: enet ready · steam %s" % steam_status())
	if _cli_mode == "host":
		if _cli_transport == "steam":
			var serr := host_night_steam()
			if serr == OK:
				print("NET steam host: lobby create in flight (appid %d)" % STEAM_APP_ID)
			else:
				print("NET steam host unavailable (err=%d) — hosting on enet instead" % serr)
		elif _cli_transport == "noray":
			var nerr := host_night_noray()
			if nerr == OK:
				print("NET noray host: registering with relay %s:%d" % [_relay_host, _relay_port])
			else:
				print("NET noray host unavailable (err=%d) — hosting on enet instead" % nerr)
		if role == Role.OFFLINE and _steam_pending == "" and _noray_stage == "":
			var err := host_night(_listen_port)
			print("NET host port=%d err=%d code=%s addr=%s" % [_listen_port, err, invite_code(), listen_addr()])
	elif _cli_mode == "join":
		_join_retries = 20
		call_deferred("_try_cli_join")

## ----- session lifecycle -----

func host_night(port := DEFAULT_PORT) -> int:
	# A pending async transport (steam lobby / noray registration) has already
	# spoken for the wire — opening plain ENet under it would double-host.
	if role != Role.OFFLINE or _steam_pending != "" or _noray_stage != "":
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_GUESTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_listen_port = port
	transport = "enet"
	role = Role.HOST
	session_opened.emit(role)
	return OK

## Accepts a 6-char invite code, "IP:PORT", a bare IP (default port),
## "steam:LOBBYID", or a bare Steam lobby id (15+ digits — no collision with
## ports or 6-char codes by length alone).
func join_night(target: String) -> int:
	if role != Role.OFFLINE:
		return ERR_ALREADY_IN_USE
	var ip := ""
	var port := DEFAULT_PORT
	var t := target.strip_edges()
	if t == "":
		return ERR_INVALID_PARAMETER
	if t.begins_with("steam:"):
		return join_night_steam(int(t.trim_prefix("steam:")))
	if t.begins_with("noray:"):
		return join_night_noray(t.trim_prefix("noray:"))
	if t.begins_with("norayrelay:"):
		return join_night_noray(t.trim_prefix("norayrelay:"), true)
	if t.is_valid_int() and t.length() >= 15:
		return join_night_steam(int(t))
	if t.contains(":"):
		var pr := t.rsplit(":", false, 1)
		ip = pr[0]
		port = int(pr[1])
	elif t.contains("."):
		ip = t
	else:
		var d := decode_code(t)
		if d.is_empty():
			return ERR_INVALID_PARAMETER
		ip = String(d.ip)
		port = int(d.port)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	transport = "enet"
	role = Role.CLIENT
	return OK

func leave(reason := "left the night") -> void:
	if role == Role.OFFLINE and _steam_pending == "":
		return
	for seat in _peer_by_seat.keys():
		PlayerInput.clear_remote(int(seat))
	_seat_by_peer.clear()
	_peer_by_seat.clear()
	_last_seq.clear()
	_rtt_ms.clear()
	_my_seat = -1
	_tape_active = false
	_trace_tick = -1
	_clear_host_pause()
	role = Role.OFFLINE
	_steam_pending = ""
	_steam_drop_lobby()
	_noray_teardown()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_closed.emit(reason)

func is_online() -> bool:
	return role != Role.OFFLINE

func is_host() -> bool:
	return role == Role.HOST

func is_client() -> bool:
	return role == Role.CLIENT

func my_seat() -> int:
	return _my_seat

func is_seat_remote(seat: int) -> bool:
	return _peer_by_seat.has(seat)

func seat_of_peer(peer_id: int) -> int:
	return int(_seat_by_peer.get(peer_id, -1))

func peer_of_seat(seat: int) -> int:
	return int(_peer_by_seat.get(seat, -1))

func guest_count() -> int:
	var n := 0
	for pid in _seat_by_peer:
		if int(pid) != 0:
			n += 1
	return n

func has_guests() -> bool:
	return role == Role.HOST and multiplayer.get_peers().size() > 0

func rtt_of_seat(seat: int) -> int:
	return int(_rtt_ms.get(int(_peer_by_seat.get(seat, -1)), 0))

func tape_mode() -> bool:
	return _tape_requested

## NETPROBE: mirrors treat a tape A-edge as a local press (e.g. the séance
## beat-stamp), so the probe exercises the exact path a human client uses.
func tape_pressed_a() -> bool:
	return _tape_a_edge

func trace_tick() -> int:
	return _trace_tick

## Phase-2 hook: a game mirror installs a Callable returning
## {"aim": Vector3, "aim_screen": Vector2} computed against its own render.
func set_aim_provider(cb: Callable) -> void:
	_aim_provider = cb

func listen_addr() -> String:
	if transport == "steam" and _steam_lobby_id != 0:
		return "steam lobby %d" % _steam_lobby_id
	if transport == "noray" and _noray_oid != "":
		return "noray:%s via %s:%d" % [_noray_oid, _relay_host, _relay_port]
	return "%s:%d" % [_best_lan_ip(), _listen_port]

## Host grants (seat >= 0) or declines (seat == -1) a requested chair.
## Called by the estate from its seat_requested handler — the shell owns
## seat policy, the session only owns the mapping and the wire.
func grant_seat(peer_id: int, seat: int, reason := "") -> void:
	if role != Role.HOST:
		return
	if seat >= 0:
		_seat_by_peer[peer_id] = seat
		_peer_by_seat[seat] = peer_id
		_last_seq[seat] = -1
		seat_claimed.emit(seat, peer_id)
	_rpc_seat_granted.rpc_id(peer_id, seat, reason)

## ----- STEAM transport (phase 3 seam — docs/design/12-steam-transport.md) -----
## Everything here is duck-typed (Engine.get_singleton / ClassDB.instantiate /
## Object.call) so the file parses on machines without the extension and runs
## bit-for-bit on machines without a Steam client. The SteamMultiplayerPeer is
## a drop-in MultiplayerPeer: once multiplayer.multiplayer_peer is set, every
## @rpc above (input relay, lobby facts, module state, private cards) and the
## whole seat/roster machinery run UNCHANGED — that is the point of the seam.

## The GDExtension is vendored and registered (classes exist on win64/linux64).
func steam_available() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")

## The Steam client is installed and running on this machine (cheap SDK check,
## valid before init). Says nothing about being logged in — init decides that.
func steam_running() -> bool:
	if not steam_available():
		return false
	return bool(Engine.get_singleton("Steam").call("isSteamRunning"))

## One-word answer for logs and the estate UI:
##   "absent"  — extension classes not present (non-vendored platform)
##   "offline" — vendored, but no Steam client running on this machine
##   "ready"   — Steam client detected; steam transport can be offered
##   "up"      — steamInitEx succeeded this process
func steam_status() -> String:
	if _steam_inited:
		return "up"
	if not steam_available():
		return "absent"
	return "ready" if steam_running() else "offline"

## What the estate's HOST NIGHT flow should offer (spec 12 §auto-detect):
## explicit --transport= wins; otherwise steam only when genuinely present.
func preferred_transport() -> String:
	if _cli_transport != "":
		return _cli_transport
	return "steam" if steam_status() == "ready" else "enet"

func steam_lobby_id() -> int:
	return _steam_lobby_id

## Lazy init — called only when a steam host/join is actually requested, so
## couch and enet runs never touch the Steam API at all (graceful absence).
func _steam_init() -> bool:
	if _steam_inited:
		return true
	if not steam_available():
		return false
	_steam = Engine.get_singleton("Steam")
	if not bool(_steam.call("isSteamRunning")):
		return false
	var res: Dictionary = _steam.call("steamInitEx", STEAM_APP_ID, false)
	if int(res.get("status", 1)) != 0:
		print("NET steam init failed: %s" % str(res.get("verbal", res)))
		return false
	_steam_inited = true
	# Warm the Steam Datagram Relay path early so NAT fallback is ready by the
	# time a guest connects (Valve's recommended pattern).
	_steam.call("initRelayNetworkAccess")
	if not _steam.is_connected("lobby_created", _on_steam_lobby_created):
		_steam.connect("lobby_created", _on_steam_lobby_created)
		_steam.connect("lobby_joined", _on_steam_lobby_joined)
		_steam.connect("join_requested", _on_steam_join_requested)
	print("NET steam up as '%s' (appid %d)" % [str(_steam.call("getPersonaName")), STEAM_APP_ID])
	return true

## HOST via Steam: create a friends-only lobby; the peer opens on lobby_created
## (async — session_opened fires then, exactly like the enet path's sync emit).
func host_night_steam() -> int:
	if role != Role.OFFLINE or _steam_pending != "":
		return ERR_ALREADY_IN_USE
	if not _steam_init():
		return ERR_UNAVAILABLE
	_steam_pending = "host"
	_steam.call("createLobby", STEAM_LOBBY_FRIENDS_ONLY, MAX_GUESTS + 1)
	return OK

## JOIN via Steam lobby id (from an overlay invite, the friends list, or a
## pasted "steam:LOBBYID" target). Async: the peer connects on lobby_joined.
func join_night_steam(lobby_id: int) -> int:
	if role != Role.OFFLINE or _steam_pending != "":
		return ERR_ALREADY_IN_USE
	if lobby_id <= 0:
		return ERR_INVALID_PARAMETER
	if not _steam_init():
		return ERR_UNAVAILABLE
	_steam_pending = "join:%d" % lobby_id
	_steam.call("joinLobby", lobby_id)
	return OK

## Pop the Steam overlay's invite dialog for the current lobby (host only).
func open_steam_invite_overlay() -> void:
	if _steam_inited and _steam_lobby_id != 0:
		_steam.call("activateGameOverlayInviteDialog", _steam_lobby_id)

func _on_steam_lobby_created(connect_res: int, lobby_id: int) -> void:
	if _steam_pending != "host":
		return
	_steam_pending = ""
	if connect_res != 1:  # 1 = k_EResultOK
		session_closed.emit("steam lobby creation failed (%d)" % connect_res)
		return
	_steam.call("setLobbyData", lobby_id, "game", "illwill")
	_steam.call("setLobbyJoinable", lobby_id, true)
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err := int(peer.call("host_with_lobby", lobby_id))
	if err != OK:
		_steam.call("leaveLobby", lobby_id)
		session_closed.emit("steam host socket failed (%d)" % err)
		return
	_steam_lobby_id = lobby_id
	multiplayer.multiplayer_peer = peer
	transport = "steam"
	role = Role.HOST
	session_opened.emit(role)
	print("NET steam lobby %d open — invite via overlay or share steam:%d" % [lobby_id, lobby_id])

func _on_steam_lobby_joined(lobby: int, _perms: int, _locked: bool, response: int) -> void:
	# createLobby also fires lobby_joined for the host — only act on OUR join.
	if not _steam_pending.begins_with("join:"):
		return
	_steam_pending = ""
	if response != 1:  # 1 = k_EChatRoomEnterResponseSuccess
		session_closed.emit("steam lobby join refused (%d)" % response)
		return
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err := int(peer.call("connect_to_lobby", lobby))
	if err != OK:
		_steam.call("leaveLobby", lobby)
		session_closed.emit("steam connect failed (%d)" % err)
		return
	_steam_lobby_id = lobby
	multiplayer.multiplayer_peer = peer
	transport = "steam"
	role = Role.CLIENT
	print("NET steam joined lobby %d — requesting a seat" % lobby)
	# connected_to_server fires through MultiplayerAPI exactly as with ENet;
	# _on_connected_to_server then requests the seat. Nothing else changes.

## A friend accepted our overlay invite (or clicked JOIN GAME in the friends
## list). Steam hands us the lobby — walk straight into the join flow.
func _on_steam_join_requested(lobby_id: int, _friend_id: int) -> void:
	if role != Role.OFFLINE or _steam_pending != "":
		print("NET steam invite ignored — already in a session")
		return
	print("NET steam invite accepted -> lobby %d" % lobby_id)
	join_night_steam(lobby_id)

## ----- NORAY transport seam (ONLINE ERA #91 — docs/design/39-noray-deploy.md) -----
## Self-hosted NAT punchthrough + relay via foxssake/noray. No addon and no
## vendored binary: noray's whole client surface is four line-based TCP verbs
## plus a UDP registrar, implemented here directly against the documented flow
## (netfox.noray is the reference client; wire-compatible $-status punches).
## The Steam lesson repeats: whatever the negotiation, the result is an
## address:port fed into the SAME ENetMultiplayerPeer calls — every @rpc above
## rides unchanged, and the sim never learns which transport carries it.
##
## HOST:  TCP "register-host" -> "set-oid"/"set-pid" -> UDP registrar (send the
##        PID until "OK"; that socket's local port is THE port noray routes) ->
##        ENet create_server(local_port). For every guest the relay announces
##        ("connect <ip>:<port>" / "connect-relay <port>"), punch outward
##        through the live server socket (ENetConnection.socket_send).
## GUEST: same registration, then "connect <oid>" -> on the "connect" answer
##        run the $-status handshake from local_port -> ENet create_client(ip,
##        port, ..., local_port). Punch failure falls back to "connect-relay".
## Graceful absence: with no --relay configured the seam stays dark — enet and
## steam paths are untouched, and every receipt runs bit-for-bit as before.
const NORAY_DEFAULT_PORT := 8890       # noray TCP command port
const NORAY_REGISTRAR_PORT := 8809     # noray UDP address registrar
const NORAY_TCP_TIMEOUT := 6.0
const NORAY_REGISTER_TIMEOUT := 8.0
const NORAY_CONNECT_TIMEOUT := 10.0
const NORAY_PUNCH_TIMEOUT := 6.0
const NORAY_SEND_EVERY := 0.1          # registrar resend / punch cadence (netfox's)
const NORAY_HOST_PUNCHES := 24         # outward punches per announced guest (~2.4 s)

var _relay_host := ""                  # --relay=HOST[:PORT]; "" = seam dark
var _relay_port := NORAY_DEFAULT_PORT
var _relay_ip := ""                    # resolved once per attempt
var _noray_tcp: StreamPeerTCP = null
var _noray_buf := ""
var _noray_oid := ""
var _noray_pid := ""
var _noray_local_port := 0             # the one port noray knows us by
var _noray_udp: PacketPeerUDP = null   # registrar, then punch socket
var _noray_stage := ""                 # "" | "tcp" | "register" | "registrar" | "await" | "punch"
var _noray_pending := ""               # "" | "host" | "join" | "join-relay"
var _noray_join_oid := ""
var _noray_timer := 0.0
var _noray_accum := 0.0
var _noray_punch_ip := ""
var _noray_punch_port := 0
var _noray_punch_read := false         # we have heard the far side
var _noray_punch_ack := false          # the far side has heard us
var _noray_relay_fallback := false     # join: relay retry already fired
var _noray_out_punches: Array = []     # host: [{ip: String, port: int, left: int}]

## Configure (or clear, with "") the relay address. CLI --relay= wins at boot;
## the estate settings pass may call this from a UI knob later.
func set_relay(addr: String) -> void:
	var t := addr.strip_edges()
	if t == "":
		_relay_host = ""
		_relay_port = NORAY_DEFAULT_PORT
		return
	if t.contains(":"):
		var pr := t.rsplit(":", false, 1)
		_relay_host = pr[0]
		_relay_port = int(pr[1])
	else:
		_relay_host = t
		_relay_port = NORAY_DEFAULT_PORT

func noray_available() -> bool:
	return _relay_host != ""

## One-word answer for logs and the estate UI:
##   "dark"  — no relay configured (seam inert)
##   "ready" — relay configured, nothing in flight
##   "busy"  — registration / punchthrough in progress
##   "up"    — a noray-opened session is live this process
func noray_status() -> String:
	if transport == "noray" and role != Role.OFFLINE:
		return "up"
	if _noray_stage != "":
		return "busy"
	return "ready" if noray_available() else "dark"

func noray_oid() -> String:
	return _noray_oid

## HOST via noray: async like the Steam path — OK means the registration flow
## is in flight; session_opened fires when the ENet server stands on the port
## noray registered. Requires a configured relay (--relay= / set_relay).
func host_night_noray() -> int:
	if role != Role.OFFLINE or _noray_stage != "":
		return ERR_ALREADY_IN_USE
	if not noray_available():
		return ERR_UNCONFIGURED
	_noray_pending = "host"
	return _noray_begin()

## JOIN via noray OID (the host's shareable "noray:OID" code). `use_relay`
## skips punchthrough and rides the relay from the start (probe/dev use).
func join_night_noray(oid: String, use_relay := false) -> int:
	if role != Role.OFFLINE or _noray_stage != "":
		return ERR_ALREADY_IN_USE
	if not noray_available():
		return ERR_UNCONFIGURED
	var t := oid.strip_edges()
	if t == "":
		return ERR_INVALID_PARAMETER
	_noray_join_oid = t
	_noray_pending = "join-relay" if use_relay else "join"
	return _noray_begin()

func _noray_begin() -> int:
	_noray_relay_fallback = false
	_noray_oid = ""
	_noray_pid = ""
	_noray_local_port = 0
	_noray_buf = ""
	_noray_out_punches.clear()
	_relay_ip = _relay_host if _relay_host.is_valid_ip_address() \
		else IP.resolve_hostname(_relay_host)
	if _relay_ip == "":
		_noray_pending = ""
		print("NET noray: cannot resolve relay host '%s'" % _relay_host)
		return ERR_CANT_RESOLVE
	_noray_tcp = StreamPeerTCP.new()
	var err := _noray_tcp.connect_to_host(_relay_ip, _relay_port)
	if err != OK:
		_noray_pending = ""
		_noray_tcp = null
		return err
	_noray_stage = "tcp"
	_noray_timer = NORAY_TCP_TIMEOUT
	print("NET noray: dialing relay %s:%d (%s)" % [_relay_host, _relay_port, _noray_pending])
	return OK

## The whole client state machine, driven from _process. Stages are linear;
## a live noray HOST parks in "await" forever, reading guest announcements.
func _noray_poll(delta: float) -> void:
	if _noray_stage == "":
		return
	if _noray_tcp != null:
		_noray_tcp.poll()
	_noray_timer -= delta
	match _noray_stage:
		"tcp":
			var st := _noray_tcp.get_status()
			if st == StreamPeerTCP.STATUS_CONNECTED:
				_noray_tcp.put_data("register-host\n".to_utf8_buffer())
				_noray_stage = "register"
				_noray_timer = NORAY_REGISTER_TIMEOUT
			elif st == StreamPeerTCP.STATUS_ERROR or _noray_timer <= 0.0:
				_noray_fail("the relay did not answer")
		"register":
			_noray_read_lines()
			if _noray_oid != "" and _noray_pid != "":
				_noray_udp = PacketPeerUDP.new()
				if _noray_udp.bind(0) != OK:
					_noray_fail("could not open a UDP socket")
					return
				_noray_udp.set_dest_address(_relay_ip, NORAY_REGISTRAR_PORT)
				_noray_stage = "registrar"
				_noray_timer = NORAY_REGISTER_TIMEOUT
				_noray_accum = NORAY_SEND_EVERY
			elif _noray_timer <= 0.0:
				_noray_fail("the relay never assigned an id")
		"registrar":
			_noray_accum += delta
			if _noray_accum >= NORAY_SEND_EVERY:
				_noray_accum = 0.0
				_noray_udp.put_packet(_noray_pid.to_utf8_buffer())
			var confirmed := false
			while _noray_udp.get_available_packet_count() > 0:
				var pkt := _noray_udp.get_packet()
				if pkt.get_string_from_utf8().strip_edges().begins_with("OK"):
					confirmed = true
			if confirmed:
				_noray_local_port = _noray_udp.get_local_port()
				_noray_udp.close()
				_noray_udp = null
				_noray_registered()
			elif _noray_timer <= 0.0:
				_noray_fail("the relay never confirmed our address")
		"await":
			var ast := _noray_tcp.get_status() if _noray_tcp != null else StreamPeerTCP.STATUS_NONE
			if ast != StreamPeerTCP.STATUS_CONNECTED:
				if _noray_pending == "host":
					# The night is NOT the relay's hostage: current guests ride
					# the already-punched ENet wire; only NEW joins need a rehost.
					print("NET noray: relay link lost — current guests unaffected; new joins need a rehost")
					_noray_tcp = null
					_noray_stage = ""
				else:
					_noray_fail("the relay dropped the line")
				return
			_noray_read_lines()
			if _noray_pending == "host":
				if not _noray_out_punches.is_empty():
					_noray_accum += delta
					if _noray_accum >= NORAY_SEND_EVERY:
						_noray_accum = 0.0
						_noray_send_out_punches()
			elif _noray_timer <= 0.0:
				_noray_fail("no answer to the join request")
		"punch":
			_noray_punch_step(delta)

## Registration done — the local port is the one noray routes. Host: stand the
## ENet server on it. Guest: ask the relay for an introduction.
func _noray_registered() -> void:
	if _noray_pending == "host":
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(_noray_local_port, MAX_GUESTS)
		if err != OK:
			_noray_fail("could not stand the estate on port %d (err=%d)" % [
				_noray_local_port, err])
			return
		multiplayer.multiplayer_peer = peer
		_listen_port = _noray_local_port
		transport = "noray"
		role = Role.HOST
		_noray_stage = "await"
		_noray_accum = 0.0
		session_opened.emit(role)
		print("NET noray host up: guests join with  noray:%s  (relay %s:%d, local port %d)" % [
			_noray_oid, _relay_host, _relay_port, _noray_local_port])
	else:
		var verb := "connect-relay" if _noray_pending == "join-relay" else "connect"
		_noray_tcp.put_data(("%s %s\n" % [verb, _noray_join_oid]).to_utf8_buffer())
		_noray_stage = "await"
		_noray_timer = NORAY_CONNECT_TIMEOUT
		print("NET noray: asked the relay to %s us to %s" % [verb, _noray_join_oid])

func _noray_read_lines() -> void:
	if _noray_tcp == null:
		return
	var avail := _noray_tcp.get_available_bytes()
	if avail > 0:
		var res: Array = _noray_tcp.get_partial_data(avail)
		if int(res[0]) == OK:
			_noray_buf += (res[1] as PackedByteArray).get_string_from_utf8()
	while _noray_buf.contains("\n"):
		var nl := _noray_buf.find("\n")
		var line := _noray_buf.substr(0, nl).strip_edges()
		_noray_buf = _noray_buf.substr(nl + 1)
		if line != "":
			_noray_command(line)

## noray's line protocol: "<command> <data>". Only four commands matter to a
## client; anything else is ignored (forward-compatible).
func _noray_command(line: String) -> void:
	var sp := line.find(" ")
	var cmd := line if sp < 0 else line.substr(0, sp)
	var data := "" if sp < 0 else line.substr(sp + 1).strip_edges()
	match cmd:
		"set-oid":
			_noray_oid = data
		"set-pid":
			_noray_pid = data
		"connect":
			var pr := data.rsplit(":", false, 1)
			if pr.size() != 2:
				return
			var ip := String(pr[0])
			var port := int(pr[1])
			if role == Role.HOST and transport == "noray":
				# A guest is punching toward us: punch back through the live
				# server socket so their inbound path opens. Send-only — ENet
				# ignores the stray $-packets (netfox's over_enet pattern).
				_noray_out_punches.append({"ip": ip, "port": port, "left": NORAY_HOST_PUNCHES})
				print("NET noray: punching toward guest %s:%d" % [ip, port])
			elif _noray_pending == "join":
				_noray_start_punch(ip, port)
		"connect-relay":
			var rport := int(data)
			if role == Role.HOST and transport == "noray":
				_noray_out_punches.append({"ip": _relay_ip, "port": rport, "left": NORAY_HOST_PUNCHES})
				print("NET noray: punching toward relay port %d" % rport)
			elif _noray_pending == "join" or _noray_pending == "join-relay":
				# Relay endpoints are directly reachable; ride stock ENet
				# through them from our registered local port.
				print("NET noray: relay endpoint %s:%d" % [_relay_ip, rport])
				_noray_finish_join(_relay_ip, rport)

func _noray_start_punch(ip: String, port: int) -> void:
	_noray_udp = PacketPeerUDP.new()
	if _noray_udp.bind(_noray_local_port) != OK:
		_noray_fail("could not rebind local port %d for the punch" % _noray_local_port)
		return
	_noray_udp.set_dest_address(ip, port)
	_noray_punch_ip = ip
	_noray_punch_port = port
	_noray_punch_read = false
	_noray_punch_ack = false
	_noray_stage = "punch"
	_noray_timer = NORAY_PUNCH_TIMEOUT
	_noray_accum = NORAY_SEND_EVERY
	print("NET noray: punchthrough handshake with %s:%d" % [ip, port])

## netfox-compatible $-status packets: '$' + r(ead) + w(rite) + x(handshake),
## '-' for unset. Success = we hear them AND they report hearing us.
func _noray_punch_step(delta: float) -> void:
	_noray_accum += delta
	if _noray_accum >= NORAY_SEND_EVERY:
		_noray_accum = 0.0
		var flags := "$%sw%s" % [
			"r" if _noray_punch_read else "-",
			"x" if _noray_punch_read and _noray_punch_ack else "-"]
		_noray_udp.put_packet(flags.to_utf8_buffer())
	while _noray_udp.get_available_packet_count() > 0:
		var txt := _noray_udp.get_packet().get_string_from_utf8()
		if txt.begins_with("$"):
			_noray_punch_read = true
			if txt.contains("r") or txt.contains("x"):
				_noray_punch_ack = true
	if _noray_punch_read and _noray_punch_ack:
		var ip := _noray_punch_ip
		var port := _noray_punch_port
		_noray_udp.close()
		_noray_udp = null
		print("NET noray: punchthrough OK — %s:%d answers" % [ip, port])
		_noray_finish_join(ip, port)
		return
	if _noray_timer <= 0.0:
		_noray_udp.close()
		_noray_udp = null
		if not _noray_relay_fallback and _noray_tcp != null:
			_noray_relay_fallback = true
			print("NET noray: punchthrough failed — falling back to the relay")
			_noray_tcp.put_data(("connect-relay %s\n" % _noray_join_oid).to_utf8_buffer())
			_noray_stage = "await"
			_noray_timer = NORAY_CONNECT_TIMEOUT
		else:
			_noray_fail("punchthrough and relay both failed")

## The last noray step: a stock ENet client BOUND TO OUR REGISTERED LOCAL PORT
## (noray only routes that port — an ephemeral bind would break connectivity).
## From here the normal MultiplayerAPI signals own the outcome.
func _noray_finish_join(ip: String, port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, 0, 0, 0, _noray_local_port)
	if err != OK:
		_noray_fail("could not open the wire to %s:%d (err=%d)" % [ip, port, err])
		return
	multiplayer.multiplayer_peer = peer
	transport = "noray"
	role = Role.CLIENT
	print("NET noray: ENet client -> %s:%d (local port %d)" % [ip, port, _noray_local_port])
	# The control line has served its purpose for a guest.
	if _noray_tcp != null:
		_noray_tcp.disconnect_from_host()
		_noray_tcp = null
	_noray_stage = ""
	_noray_pending = ""
	_noray_buf = ""

## Outward punches ride the LIVE server socket so the reply path maps through
## the same NAT pinhole ENet will use. Raw sends; ENet peers ignore them.
func _noray_send_out_punches() -> void:
	var mp: MultiplayerPeer = multiplayer.multiplayer_peer
	if not (mp is ENetMultiplayerPeer):
		_noray_out_punches.clear()
		return
	var conn: ENetConnection = (mp as ENetMultiplayerPeer).host
	if conn == null:
		return
	var keep: Array = []
	for p in _noray_out_punches:
		var entry: Dictionary = p
		conn.socket_send(String(entry.ip), int(entry.port), "$rwx".to_utf8_buffer())
		entry.left = int(entry.left) - 1
		if int(entry.left) > 0:
			keep.append(entry)
	_noray_out_punches = keep

func _noray_fail(reason: String) -> void:
	var was_pending := _noray_pending
	print("NET noray %s failed: %s" % [was_pending if was_pending != "" else "session", reason])
	var was_joining := was_pending == "join" or was_pending == "join-relay"
	_noray_teardown()
	if role == Role.OFFLINE and was_joining:
		# Same retry ladder as a refused ENet join: a CLI join keeps knocking
		# (the host may register with the relay a beat after our first try).
		if _join_retries > 0:
			_join_retries -= 1
			get_tree().create_timer(1.5).timeout.connect(_try_cli_join)
			return
		session_closed.emit("noray: %s" % reason)

## Close the control plane and scratch state. Safe no-op in every enet/steam
## flow — nothing here is ever non-null unless a noray attempt ran.
func _noray_teardown() -> void:
	if _noray_udp != null:
		_noray_udp.close()
		_noray_udp = null
	if _noray_tcp != null:
		_noray_tcp.disconnect_from_host()
		_noray_tcp = null
	_noray_stage = ""
	_noray_pending = ""
	_noray_buf = ""
	_noray_oid = ""
	_noray_pid = ""
	_noray_local_port = 0
	_noray_out_punches.clear()

## ----- connection plumbing -----

func _try_cli_join() -> void:
	var target := _cli_target if _cli_target != "" else "127.0.0.1:%d" % DEFAULT_PORT
	var err := join_night(target)
	print("NET join target=%s err=%d (retries left %d)" % [target, err, _join_retries])

func _on_connected_to_server() -> void:
	print("NET connected to host as peer %d" % multiplayer.get_unique_id())
	session_opened.emit(role)
	_rpc_request_seat.rpc_id(1)

func _on_connection_failed() -> void:
	_clear_host_pause()
	role = Role.OFFLINE
	_steam_drop_lobby()
	_noray_teardown()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _join_retries > 0:
		_join_retries -= 1
		get_tree().create_timer(1.5).timeout.connect(_try_cli_join)
		return
	session_closed.emit("the estate did not answer")

func _on_server_disconnected() -> void:
	var was_seated := _my_seat >= 0
	_my_seat = -1
	_tape_active = false
	_clear_host_pause()
	role = Role.OFFLINE
	_steam_drop_lobby()
	_noray_teardown()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_closed.emit("the host closed the night" if was_seated else "connection lost")

## Leave the Steam lobby (if any) and fall back to the enet default posture.
## Safe no-op in every enet/couch flow — _steam_lobby_id is only ever nonzero
## after a successful steam host/join.
func _steam_drop_lobby() -> void:
	if _steam_lobby_id != 0 and _steam_inited:
		_steam.call("leaveLobby", _steam_lobby_id)
	_steam_lobby_id = 0
	transport = "enet"

func _on_peer_connected(peer_id: int) -> void:
	if role == Role.HOST:
		print("NET peer %d connected" % peer_id)
		# A guest that knocks while the host is already in its settings would
		# otherwise land on a live-looking-but-frozen estate: hand it the pause
		# fact immediately so it opens straight into the "held breath" overlay.
		if _host_paused:
			_rpc_host_pause.rpc_id(peer_id, true)

func _on_peer_disconnected(peer_id: int) -> void:
	if role != Role.HOST:
		return
	var seat := int(_seat_by_peer.get(peer_id, -1))
	_seat_by_peer.erase(peer_id)
	_rtt_ms.erase(peer_id)
	if seat >= 0:
		_peer_by_seat.erase(seat)
		_last_seq.erase(seat)
		PlayerInput.clear_remote(seat)
		peer_left_seat.emit(seat, peer_id)
	print("NET peer %d left (seat %d)" % [peer_id, seat])

## ----- RPCs (all network traffic funnels through this one autoload) -----

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_seat() -> void:
	if role != Role.HOST:
		return
	var pid := multiplayer.get_remote_sender_id()
	if _seat_by_peer.has(pid):
		_rpc_seat_granted.rpc_id(pid, int(_seat_by_peer[pid]), "already seated")
		return
	seat_requested.emit(pid)

@rpc("authority", "call_remote", "reliable")
func _rpc_seat_granted(seat: int, reason: String) -> void:
	_my_seat = seat
	_seq = 0
	_send_gap = 0
	_presses_a = 0
	_presses_b = 0
	_presses_jump = 0
	_presses_plan = 0
	_presses_plan_y = 0
	if seat >= 0 and _tape_requested:
		start_net_tape(seat)
	seat_granted.emit(seat, reason)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_input(pkt: Dictionary) -> void:
	if role != Role.HOST:
		return
	var pid := multiplayer.get_remote_sender_id()
	var seat := int(_seat_by_peer.get(pid, -1))
	if seat < 0 or int(pkt.get("seat", -1)) != seat:
		return
	var seq := int(pkt.get("seq", 0))
	var last := int(_last_seq.get(seat, -1))
	if last >= 0:
		var delta := (seq - last) & 0xFFFF
		if delta == 0 or delta > 32768:
			return  # stale or duplicate: latest-seq wins
	_last_seq[seat] = seq
	PlayerInput.set_remote_state(seat, pkt)
	if _probe and not _trace_armed:
		_arm_trace()
		probe_first_input.emit(seat)

@rpc("authority", "call_remote", "reliable")
func _rpc_lobby_state(state: Dictionary) -> void:
	lobby_state_received.emit(state)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_walker_state(state: Dictionary) -> void:
	walker_state_received.emit(state)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_panel_intent(intent: Dictionary) -> void:
	if role != Role.HOST:
		return
	var seat := int(_seat_by_peer.get(multiplayer.get_remote_sender_id(), -1))
	if seat >= 0:
		panel_intent_received.emit(seat, intent)

@rpc("any_peer", "call_remote", "unreliable", 3)
func _rpc_ping(t_ms: int, back: bool) -> void:
	if back:
		if role == Role.HOST:
			_rtt_ms[multiplayer.get_remote_sender_id()] = Time.get_ticks_msec() - t_ms
	else:
		_rpc_ping.rpc_id(1, t_ms, true)

## Host -> all guests. Estate calls these; games get the same pipe in phase 2.
func send_lobby_state(state: Dictionary) -> void:
	if role == Role.HOST and has_guests():
		_rpc_lobby_state.rpc(state)

func send_walker_state(state: Dictionary) -> void:
	if role == Role.HOST and has_guests():
		_rpc_walker_state.rpc(state)

## Client -> host semantic UI intent (spec §5.3): {"kind": "ready_toggle"} etc.
## Games ride this too (séance chant beat-stamps: {"kind":"seance_chant"}).
func send_panel_intent(intent: Dictionary) -> void:
	if role == Role.CLIENT and _my_seat >= 0:
		_rpc_panel_intent.rpc_id(1, intent)

## ----- PHASE 2: the generic module-state pipe (game mirrors) -----
## THE HOUSE PATTERN: the estate pumps the running module's `_net_state()`
## dict to every guest at 20 Hz (unreliable_ordered, channel 4, latest wins);
## each client boots the SAME module scene in mirror mode and feeds the dict
## to `_net_apply()`. Hidden information NEVER rides this fan-out — it goes
## through send_module_private (reliable, rpc_id: the seat's peer and nobody
## else). This is the spec's "hidden info gets BETTER online" claim in code.

func send_module_state(state: Dictionary) -> void:
	if role == Role.HOST and has_guests():
		_rpc_module_state.rpc(state)

## Host -> ONE peer: the private card for `seat` (charlatan flash, role card,
## summons). Peer 0 is the couch-probe tape — local, nothing to deliver.
func send_module_private(seat: int, data: Dictionary) -> void:
	if role != Role.HOST:
		return
	var pid := int(_peer_by_seat.get(seat, -1))
	if pid > 0:
		_rpc_module_private.rpc_id(pid, data)

@rpc("authority", "call_remote", "unreliable_ordered", 4)
func _rpc_module_state(state: Dictionary) -> void:
	module_state_received.emit(state)

@rpc("authority", "call_remote", "reliable")
func _rpc_module_private(data: Dictionary) -> void:
	module_private_received.emit(data)

## ----- host pause (the estate holds its breath) -----
## The estate's state pump rides the host's (pausable) _process, so it stops the
## instant the host opens settings — but the ENet socket keeps being serviced
## (this autoload is PROCESS_MODE_ALWAYS and MultiplayerAPI.poll() is not gated
## by SceneTree.paused), so a guest stays CONNECTED, it just stops hearing the
## world. Rather than let it freeze with no explanation, the host announces the
## pause as one reliable fact; the guest renders an overlay and resumes cleanly
## when the matching resume fact arrives. Host-only: a guest's own ESC pauses
## only its local tree and never reaches here, so it can never freeze the table.

func is_host_paused() -> bool:
	return _host_paused

## HOST -> every guest: the shared sim just froze / resumed. Safe to call while
## get_tree().paused is true — the reliable RPC flushes on the next poll, which
## keeps running through the pause.
func set_host_paused(paused: bool) -> void:
	if role != Role.HOST or _host_paused == paused:
		return
	_host_paused = paused
	if has_guests():
		_rpc_host_pause.rpc(paused)

@rpc("authority", "call_remote", "reliable")
func _rpc_host_pause(paused: bool) -> void:
	if _host_paused == paused:
		return
	_host_paused = paused
	host_pause_changed.emit(paused)

## Session teardown from any side: drop the flag and make sure a guest's "held
## breath" overlay clears rather than sticking after the wire goes dark.
func _clear_host_pause() -> void:
	if _host_paused:
		_host_paused = false
		host_pause_changed.emit(false)

## Stable digest of a snapshot dict — both ends print NETHASH lines keyed by
## seq (spec §7.3: compare by seq, never wall clock).
static func snapshot_hash(state: Dictionary) -> String:
	return "%08x" % (hash(JSON.stringify(state)) & 0xFFFFFFFF)

## ----- input sampling / tape (client side of the relay) -----

func _physics_process(_delta: float) -> void:
	if _trace_armed and role == Role.HOST:
		_trace_tick += 1
	if _tape_active:
		_step_tape()
	elif role == Role.CLIENT and _my_seat >= 0:
		# Swallow this guest's input while it sits in its OWN settings overlay
		# (get_tree().paused — local to this client) or while the HOST has the
		# whole table paused (_host_paused): either way the pawn must not creep
		# on the host's or anyone else's screen. Raw device reads (PlayerInput)
		# are not gated by SceneTree.paused, so this is the seam that stops them.
		if not get_tree().paused and not _host_paused:
			_sample_and_send()

var _trace_armed := false

func _arm_trace() -> void:
	_trace_armed = true
	_trace_tick = -1

func _sample_and_send() -> void:
	if PlayerInput.just_pressed(_my_seat, "a"):
		_presses_a += 1
	if PlayerInput.just_pressed(_my_seat, "b"):
		_presses_b += 1
	if PlayerInput.just_pressed(_my_seat, "jump"):
		_presses_jump += 1
	if PlayerInput.just_pressed(_my_seat, "plan"):
		_presses_plan += 1
	if PlayerInput.just_pressed(_my_seat, "plan_y"):
		_presses_plan_y += 1
	_send_gap += 1
	if _send_gap < INPUT_SEND_EVERY:
		return
	_send_gap = 0
	_seq = (_seq + 1) & 0xFFFF
	var aim := Vector3.ZERO
	var aim_screen := Vector2.ZERO
	if _aim_provider.is_valid():
		var d: Dictionary = _aim_provider.call()
		aim = d.get("aim", Vector3.ZERO)
		aim_screen = d.get("aim_screen", Vector2.ZERO)
	_rpc_input.rpc_id(1, {
		"seq": _seq, "seat": _my_seat,
		"move": PlayerInput.get_move(_my_seat),
		"a": PlayerInput.is_down(_my_seat, "a"),
		"b": PlayerInput.is_down(_my_seat, "b"),
		"jump": PlayerInput.is_down(_my_seat, "jump"),
		"plan": PlayerInput.is_down(_my_seat, "plan"),
		"plan_y": PlayerInput.is_down(_my_seat, "plan_y"),
		"presses_a": _presses_a, "presses_b": _presses_b,
		"presses_jump": _presses_jump, "presses_plan": _presses_plan,
		"presses_plan_y": _presses_plan_y,
		"aim": aim, "aim_screen": aim_screen,
		"stick": PlayerInput.get_aim_stick(_my_seat),
	})

## NETPROBE: relay path — the joined client streams the tape over the wire.
func start_net_tape(seat: int) -> void:
	_tape_seat = seat
	_tape_local = false
	_tape_active = true
	_tape_tick = -1
	_tape_prev_a = false
	_tape_pa = 0
	_tape_seq = 0
	print("NETPROBE tape start (net) seat=%d" % seat)

## NETPROBE: couch path — same tape, same packets, same injector, no wire.
## Binds the seat to fake peer 0 so the estate sees it as REMOTE.
func start_local_tape(seat: int) -> void:
	_peer_by_seat[seat] = 0
	_seat_by_peer[0] = seat
	_last_seq[seat] = -1
	_tape_seat = seat
	_tape_local = true
	_tape_active = true
	_tape_tick = -1
	_tape_prev_a = false
	_tape_pa = 0
	_tape_seq = 0
	print("NETPROBE tape start (couch) seat=%d" % seat)

func _tape_state(tick: int) -> Dictionary:
	var move := Vector2.ZERO
	var a := false
	for step in TAPE:
		if tick >= int(step.t):
			move = step.move
			a = bool(step.a)
		else:
			break
	if tick >= TAPE_PULSE_FROM and (tick - TAPE_PULSE_FROM) % TAPE_PULSE_EVERY < TAPE_PULSE_WIDTH:
		a = true
	return {"move": move, "a": a}

func _step_tape() -> void:
	_tape_tick += 1
	if _tape_local:
		_trace_tick = _tape_tick
	if _tape_tick > TAPE_END:
		_tape_active = false
		print("NETPROBE tape end")
		return
	var st := _tape_state(_tape_tick)
	var a := bool(st.a)
	_tape_a_edge = a and not _tape_prev_a   # game mirrors read this as "my press"
	if a and not _tape_prev_a:
		_tape_pa += 1
	_tape_prev_a = a
	if _tape_tick % INPUT_SEND_EVERY != 0:
		return
	_tape_seq = (_tape_seq + 1) & 0xFFFF
	var pkt := {
		"seq": _tape_seq, "seat": _tape_seat,
		"move": st.move, "a": a, "b": false, "jump": false,
		"plan": false, "plan_y": false,
		"presses_a": _tape_pa, "presses_b": 0, "presses_jump": 0,
		"presses_plan": 0, "presses_plan_y": 0,
		"aim": Vector3.ZERO, "aim_screen": Vector2.ZERO, "stick": Vector2.ZERO,
	}
	if _tape_local:
		_last_seq[_tape_seat] = int(pkt.seq)
		PlayerInput.set_remote_state(_tape_seat, pkt)
	elif role == Role.CLIENT:
		_rpc_input.rpc_id(1, pkt)

func _process(delta: float) -> void:
	if _steam_inited:
		_steam.call("run_callbacks")   # lobby/overlay callbacks + socket pump
	_noray_poll(delta)                 # inert unless a noray flow is in flight
	if role != Role.HOST:
		return
	_ping_accum += delta
	if _ping_accum < PING_INTERVAL:
		return
	_ping_accum = 0.0
	var now := Time.get_ticks_msec()
	for pid in multiplayer.get_peers():
		_rpc_ping.rpc_id(pid, now, false)

## ----- invite codes (6-char Crockford base32; LAN/direct only, phase 1) -----

func invite_code() -> String:
	if role != Role.HOST:
		return ""
	if transport == "steam":
		return "steam:%d" % _steam_lobby_id   # overlay invites are the real flow
	if transport == "noray":
		return "noray:%s" % _noray_oid        # the OID is the shareable code
	return encode_code(_best_lan_ip(), _listen_port)

static func _best_lan_ip() -> String:
	var fallback := ""
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.count(".") != 3:
			continue  # IPv6: out of scope phase 1
		if s.begins_with("192.168."):
			return s
		if fallback == "" and s.begins_with("10."):
			fallback = s
		elif fallback == "" and s.begins_with("172."):
			var o1 := int(s.split(".")[1])
			if o1 >= 16 and o1 <= 31:
				fallback = s
	return fallback if fallback != "" else "127.0.0.1"

## 30 bits: tag(2) + payload(28). Returns "" when the address/port cannot be
## encoded (public IPv4, exotic port) — the lobby card then shows raw IP:PORT.
static func encode_code(ip: String, port: int) -> String:
	var o := ip.split(".")
	if o.size() != 4:
		return ""
	var a := int(o[0])
	var b := int(o[1])
	var c := int(o[2])
	var d := int(o[3])
	var tag := -1
	var payload := 0
	if a == 127:
		tag = 0
		payload = port & 0xFFFF
	elif a == 192 and b == 168 and port >= 8000 and port <= 12095:
		tag = 1
		payload = (c << 20) | (d << 12) | (port - 8000)
	elif a == 10 and port >= DEFAULT_PORT and port <= DEFAULT_PORT + 15:
		tag = 2
		payload = (b << 20) | (c << 12) | (d << 4) | (port - DEFAULT_PORT)
	elif a == 172 and b >= 16 and b <= 31 and port >= DEFAULT_PORT and port <= DEFAULT_PORT + 255:
		tag = 3
		payload = ((b - 16) << 24) | (c << 16) | (d << 8) | (port - DEFAULT_PORT)
	else:
		return ""
	var v := (tag << 28) | payload
	var out := ""
	for _i in 6:
		out = CODE_ALPHABET[v & 31] + out
		v >>= 5
	return out

static func decode_code(code: String) -> Dictionary:
	var s := code.strip_edges().to_upper().replace("O", "0").replace("I", "1").replace("L", "1").replace("U", "V")
	if s.length() != 6:
		return {}
	var v := 0
	for ch in s:
		var idx := CODE_ALPHABET.find(ch)
		if idx < 0:
			return {}
		v = (v << 5) | idx
	var tag := (v >> 28) & 3
	var p := v & 0xFFFFFFF
	match tag:
		0:
			return {"ip": "127.0.0.1", "port": p & 0xFFFF}
		1:
			return {"ip": "192.168.%d.%d" % [(p >> 20) & 255, (p >> 12) & 255], "port": 8000 + (p & 0xFFF)}
		2:
			return {"ip": "10.%d.%d.%d" % [(p >> 20) & 255, (p >> 12) & 255, (p >> 4) & 255], "port": DEFAULT_PORT + (p & 15)}
		3:
			return {"ip": "172.%d.%d.%d" % [16 + ((p >> 24) & 15), (p >> 16) & 255, (p >> 8) & 255], "port": DEFAULT_PORT + (p & 255)}
	return {}

static func code_selftest() -> void:
	var cases := [["127.0.0.1", 8910], ["192.168.1.42", 8910], ["10.0.7.200", 8912], ["172.20.3.9", 9000], ["192.168.240.17", 11999]]
	for case in cases:
		var ip := String(case[0])
		var port := int(case[1])
		var code := encode_code(ip, port)
		var back := decode_code(code)
		var ok: bool = not back.is_empty() and String(back.ip) == ip and int(back.port) == port
		print("NETCODE %s:%d -> %s -> %s:%s %s" % [ip, port, code, String(back.get("ip", "?")), str(back.get("port", "?")), "PASS" if ok else "FAIL"])
	print("NETCODE 203.0.113.5:8910 -> '%s' (public IPv4 shares raw IP:PORT; Steam-code rendezvous is phase 3)" % encode_code("203.0.113.5", 8910))
