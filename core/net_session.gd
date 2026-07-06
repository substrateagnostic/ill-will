extends Node
## Autoload NetSession — ONLINE PHASE 1 (spec: docs/design/10-online-first-architecture.md).
## Host-authoritative input relay behind PlayerInput. The host runs the ENTIRE
## simulation exactly as couch does; remote clients sample their own devices,
## stream compact input states at 30 Hz, and the host injects them into the
## PlayerInput `_remote` seam (the `_dbg_aim` pattern, networked).
##
## Transport phase 1: raw ENetMultiplayerPeer — localhost / LAN / port-forward.
## The API below is transport-agnostic on purpose: phase 3 swaps in GodotSteam's
## SteamMultiplayerPeer behind host_night()/join_night() and nothing above this
## file changes (every @rpc rides the high-level MultiplayerAPI either way).
##
## CLI:  --net=host [--port=N]           host on N (default 8910)
##       --net=join=IP:PORT              join a direct address
##       --net=join --addr=IP:PORT       spec §7 form, same thing
##       --net=join=CODE                 join a 6-char invite code
##       --nettape                       NETPROBE: drive the claimed seat from
##                                       the built-in deterministic input tape
##
## INPUT PACKET (spec §4.2), client -> host @ 30 Hz, unreliable_ordered ch.1:
##   { seq:int(u16), seat:int, move:Vector2, a:bool, b:bool,
##     presses_a:int, presses_b:int,      # monotonic tap counters (edge rescue)
##     aim:Vector3, aim_screen:Vector2,   # PRE-COMPUTED unit vectors, never raw mice
##     stick:Vector2 }                    # raw right-stick for pad aim
## ~40 bytes @ 30 Hz ≈ 1.2 kB/s per client. Latest-seq wins; stale drops.

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
var _listen_port := DEFAULT_PORT
var _seat_by_peer := {}   # peer_id -> seat  (peer 0 = the local couch-probe tape)
var _peer_by_seat := {}   # seat -> peer_id
var _my_seat := -1        # client: seat granted by the host
var _last_seq := {}       # host: seat -> last accepted packet seq
var _rtt_ms := {}         # host: peer_id -> measured round trip
var _ping_accum := 0.0

# --- client input sampling state
var _send_gap := 0
var _seq := 0
var _presses_a := 0
var _presses_b := 0
var _aim_provider := Callable()   # phase-2 game mirrors install {aim, aim_screen}

# --- CLI
var _cli_mode := ""
var _cli_target := ""
var _join_retries := 0
var _probe := false

# --- NETPROBE deterministic input tape (see docs/verify/online-phase1-VERIFY.md)
# Steps hold until the next entry; from PULSE_FROM the tape pulses A every 90
# ticks (6 ticks wide) so it can answer any READY gate whenever it appears.
const TAPE := [
	{"t": 0, "move": Vector2(-1, 0), "a": false},
	{"t": 60, "move": Vector2(0, -1), "a": false},
	{"t": 120, "move": Vector2(1, 0), "a": false},
	{"t": 180, "move": Vector2(0, 1), "a": false},
	{"t": 240, "move": Vector2.ZERO, "a": false},
	{"t": 300, "move": Vector2.ZERO, "a": true},    # single A press: lobby READY
	{"t": 306, "move": Vector2.ZERO, "a": false},
]
const TAPE_PULSE_FROM := 660
const TAPE_PULSE_EVERY := 90
const TAPE_PULSE_WIDTH := 6
const TAPE_END := 5400

var _tape_requested := false
var _tape_active := false
var _tape_local := false          # couch probe: inject directly, no wire
var _tape_seat := -1
var _tape_tick := -1
var _tape_prev_a := false
var _tape_pa := 0
var _tape_seq := 0
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
		elif arg == "--nettape":
			_tape_requested = true
		elif arg.begins_with("--netprobe="):
			_probe = true
	if _cli_mode == "host":
		var err := host_night(_listen_port)
		print("NET host port=%d err=%d code=%s addr=%s" % [_listen_port, err, invite_code(), listen_addr()])
	elif _cli_mode == "join":
		_join_retries = 20
		call_deferred("_try_cli_join")

## ----- session lifecycle -----

func host_night(port := DEFAULT_PORT) -> int:
	if role != Role.OFFLINE:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_GUESTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_listen_port = port
	role = Role.HOST
	session_opened.emit(role)
	return OK

## Accepts a 6-char invite code, "IP:PORT", or a bare IP (default port).
func join_night(target: String) -> int:
	if role != Role.OFFLINE:
		return ERR_ALREADY_IN_USE
	var ip := ""
	var port := DEFAULT_PORT
	var t := target.strip_edges()
	if t == "":
		return ERR_INVALID_PARAMETER
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
	role = Role.CLIENT
	return OK

func leave(reason := "left the night") -> void:
	if role == Role.OFFLINE:
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
	role = Role.OFFLINE
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

func trace_tick() -> int:
	return _trace_tick

## Phase-2 hook: a game mirror installs a Callable returning
## {"aim": Vector3, "aim_screen": Vector2} computed against its own render.
func set_aim_provider(cb: Callable) -> void:
	_aim_provider = cb

func listen_addr() -> String:
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
	role = Role.OFFLINE
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
	role = Role.OFFLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_closed.emit("the host closed the night" if was_seated else "connection lost")

func _on_peer_connected(peer_id: int) -> void:
	if role == Role.HOST:
		print("NET peer %d connected" % peer_id)

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
func send_panel_intent(intent: Dictionary) -> void:
	if role == Role.CLIENT and _my_seat >= 0:
		_rpc_panel_intent.rpc_id(1, intent)

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
		"presses_a": _presses_a, "presses_b": _presses_b,
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
	if a and not _tape_prev_a:
		_tape_pa += 1
	_tape_prev_a = a
	if _tape_tick % INPUT_SEND_EVERY != 0:
		return
	_tape_seq = (_tape_seq + 1) & 0xFFFF
	var pkt := {
		"seq": _tape_seq, "seat": _tape_seat,
		"move": st.move, "a": a, "b": false,
		"presses_a": _tape_pa, "presses_b": 0,
		"aim": Vector3.ZERO, "aim_screen": Vector2.ZERO, "stick": Vector2.ZERO,
	}
	if _tape_local:
		_last_seq[_tape_seat] = int(pkt.seq)
		PlayerInput.set_remote_state(_tape_seat, pkt)
	elif role == Role.CLIENT:
		_rpc_input.rpc_id(1, pkt)

func _process(delta: float) -> void:
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
