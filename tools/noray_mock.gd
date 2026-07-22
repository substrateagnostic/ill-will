extends MainLoop
## MOCK noray server (ONLINE ERA #91) — tools-only, never shipped.
##
## Implements exactly the slice of foxssake/noray's documented protocol that
## core/net_session.gd speaks, so the transport's handshake state machine can
## be certified end-to-end on loopback without Bun/Docker or a live relay:
##
##   TCP (default 8890, line-based "<cmd> <data>\n"):
##     register-host           -> "set-oid <OID>" + "set-pid <PID>"
##     connect <oid>           -> BOTH parties get "connect <ip>:<port>"
##                                (each told the OTHER side's registered addr)
##     connect-relay <oid>     -> BOTH parties get "connect-relay <port>" and
##                                the mock forwards UDP between their
##                                registered endpoints on that port
##   UDP registrar (default 8809): a packet holding a known PID registers the
##     sender's ip:port and is answered "OK" (idempotent, like the real thing).
##
## OIDs are DETERMINISTIC by connection order (MOCKA, MOCKB, ...) so a test
## runner can script "host first, guest joins noray:MOCKA" with no discovery.
##
## Run:  godot --headless --path . --script res://tools/noray_mock.gd
## Stop: kill the process (the test runner owns its lifetime).

const ALPHA := "ABCDEFGH"

var _tcp_port := 8890
var _reg_port := 8809
var _server := TCPServer.new()
var _reg := PacketPeerUDP.new()
var _clients: Array = []   # [{peer, buf, oid, pid, ext_ip, ext_port}]
var _relay := PacketPeerUDP.new()
var _relay_open := false
var _relay_a := {}         # {"ip": String, "port": int} — the host side
var _relay_b := {}         # the guest side
var _n := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_args():
		if String(arg).begins_with("--mocktcp="):
			_tcp_port = int(String(arg).trim_prefix("--mocktcp="))
		elif String(arg).begins_with("--mockreg="):
			_reg_port = int(String(arg).trim_prefix("--mockreg="))
	var terr := _server.listen(_tcp_port)
	var uerr := _reg.bind(_reg_port)
	if terr != OK or uerr != OK:
		print("NORAY_MOCK bind failed tcp=%d(err %d) reg=%d(err %d)" % [
			_tcp_port, terr, _reg_port, uerr])
		return
	print("NORAY_MOCK up tcp=%d registrar=%d" % [_tcp_port, _reg_port])

func _process(_delta: float) -> bool:
	# new control connections
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		var tag := ALPHA[_n % ALPHA.length()]
		_n += 1
		_clients.append({
			"peer": peer, "buf": "",
			"oid": "MOCK%s" % tag, "pid": "PID%s" % tag,
			"ext_ip": "", "ext_port": 0,
		})
		print("NORAY_MOCK client MOCK%s connected" % tag)
	# UDP registrar: a PID packet registers the sender's external endpoint
	while _reg.get_available_packet_count() > 0:
		var pid := _reg.get_packet().get_string_from_utf8().strip_edges()
		var ip := _reg.get_packet_ip()
		var port := _reg.get_packet_port()
		for c in _clients:
			var entry: Dictionary = c
			if String(entry.pid) == pid:
				var fresh: bool = String(entry.ext_ip) == ""
				entry.ext_ip = ip
				entry.ext_port = port
				_reg.set_dest_address(ip, port)
				_reg.put_packet("OK".to_utf8_buffer())
				if fresh:
					print("NORAY_MOCK registered %s at %s:%d" % [String(entry.oid), ip, port])
	# control lines
	for c in _clients:
		var entry: Dictionary = c
		var peer: StreamPeerTCP = entry.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var avail := peer.get_available_bytes()
		if avail > 0:
			var res: Array = peer.get_partial_data(avail)
			if int(res[0]) == OK:
				entry.buf = String(entry.buf) + (res[1] as PackedByteArray).get_string_from_utf8()
		while String(entry.buf).contains("\n"):
			var nl := String(entry.buf).find("\n")
			var line := String(entry.buf).substr(0, nl).strip_edges()
			entry.buf = String(entry.buf).substr(nl + 1)
			if line != "":
				_command(entry, line)
	# relay pump: forward between the two registered endpoints, by source
	if _relay_open:
		while _relay.get_available_packet_count() > 0:
			var pkt := _relay.get_packet()
			var sip := _relay.get_packet_ip()
			var sport := _relay.get_packet_port()
			var dst := {}
			if sip == String(_relay_a.ip) and sport == int(_relay_a.port):
				dst = _relay_b
			elif sip == String(_relay_b.ip) and sport == int(_relay_b.port):
				dst = _relay_a
			if not dst.is_empty():
				_relay.set_dest_address(String(dst.ip), int(dst.port))
				_relay.put_packet(pkt)
	return false

func _command(c: Dictionary, line: String) -> void:
	var peer: StreamPeerTCP = c.peer
	if line == "register-host":
		peer.put_data(("set-oid %s\n" % String(c.oid)).to_utf8_buffer())
		peer.put_data(("set-pid %s\n" % String(c.pid)).to_utf8_buffer())
	elif line.begins_with("connect-relay "):
		var oid := line.trim_prefix("connect-relay ").strip_edges()
		var h := _by_oid(oid)
		if h.is_empty() or String(h.ext_ip) == "" or String(c.ext_ip) == "":
			peer.put_data("error no-such-host\n".to_utf8_buffer())
			return
		if not _relay_open:
			if _relay.bind(0) != OK:
				peer.put_data("error relay-bind\n".to_utf8_buffer())
				return
			_relay_open = true
		_relay_a = {"ip": String(h.ext_ip), "port": int(h.ext_port)}
		_relay_b = {"ip": String(c.ext_ip), "port": int(c.ext_port)}
		var rp := _relay.get_local_port()
		print("NORAY_MOCK relay open port=%d %s <-> %s" % [rp, oid, String(c.oid)])
		peer.put_data(("connect-relay %d\n" % rp).to_utf8_buffer())
		(h.peer as StreamPeerTCP).put_data(("connect-relay %d\n" % rp).to_utf8_buffer())
	elif line.begins_with("connect "):
		var oid := line.trim_prefix("connect ").strip_edges()
		var h := _by_oid(oid)
		if h.is_empty() or String(h.ext_ip) == "" or String(c.ext_ip) == "":
			peer.put_data("error no-such-host\n".to_utf8_buffer())
			return
		print("NORAY_MOCK introducing %s <-> %s (nat)" % [String(c.oid), oid])
		peer.put_data(("connect %s:%d\n" % [String(h.ext_ip), int(h.ext_port)]).to_utf8_buffer())
		(h.peer as StreamPeerTCP).put_data(
			("connect %s:%d\n" % [String(c.ext_ip), int(c.ext_port)]).to_utf8_buffer())

func _by_oid(oid: String) -> Dictionary:
	for c in _clients:
		var entry: Dictionary = c
		if String(entry.oid) == oid:
			return entry
	return {}
