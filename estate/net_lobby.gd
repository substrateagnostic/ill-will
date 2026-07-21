class_name NetLobby
extends RefCounted

## ===== ONLINE PHASE 1 — the estate as the shared lobby (doc 10 §5) =====
## Host: remote peers claim seats; their walkers stroll these grounds on
## relayed input; READY polls PlayerInput as ever (relay-transparent).
## Client: renders a mirror of the lobby facts + walker
## snapshots; minigames stay host-screen-only this phase (spectate card).

static func wire_signals(estate) -> void:
	NetSession.seat_requested.connect(Callable(estate, "_on_net_seat_requested"))
	NetSession.peer_left_seat.connect(Callable(estate, "_on_net_peer_left_seat"))
	NetSession.panel_intent_received.connect(Callable(estate, "_on_net_panel_intent"))
	NetSession.seat_granted.connect(Callable(estate, "_on_net_seat_granted"))
	NetSession.lobby_state_received.connect(Callable(estate, "_on_net_lobby_state"))
	NetSession.walker_state_received.connect(Callable(estate, "_on_net_walker_state"))
	NetSession.session_closed.connect(Callable(estate, "_on_net_session_closed"))
	NetSession.probe_first_input.connect(Callable(estate, "_on_net_probe_first_input"))
	NetSession.module_state_received.connect(Callable(estate, "_on_net_module_state"))
	NetSession.module_private_received.connect(Callable(estate, "_on_net_module_private"))

## ----- host side -----

static func host_night_pressed(estate) -> void:
	if not NetSession.is_online():
		var err: int = NetSession.host_night()
		if err != OK:
			Sfx.play("ui_error")
			estate._flash("THE ESTATE COULD NOT OPEN ITS DOORS (port %d is otherwise engaged)" % NetSession.DEFAULT_PORT, Color(0.9, 0.6, 0.6), 3.0)
			return
	Sfx.play("ui_confirm")
	estate._enter_lobby()

## A guest knocked. Seat policy is the shell's: first BOT/EMPTY chair becomes
## theirs; a couch full of humans declines politely. Mid-game joins wait for
## the boundary (rejoin-at-boundary is phase 3).
static func on_seat_requested(estate, peer_id: int) -> void:
	var phase_name: String = estate.get_phase_name()
	if phase_name != "LOBBY" and phase_name != "GROUNDS" and phase_name != "TITLE":
		NetSession.grant_seat(peer_id, -1, "the estate is mid-game — knock again between games")
		return
	for i in 4:
		var st: String = estate._seat_status(i)
		if st == "BOT" or st == "EMPTY":
			PlayerInput.assign(i, -99)
			PlayerInput.set_bot(i, false)
			estate._lobby_ready.erase(i)
			estate._join_ready_lock.erase(i)
			NetSession.grant_seat(peer_id, i)
			Sfx.play("ui_confirm")
			estate._flash("%s JOINS FROM AFAR" % GameState.PLAYER_NAMES[i], GameState.PLAYER_COLORS[i], 2.2)
			estate.get_tree().create_timer(2.3).timeout.connect(func():
				if estate.get_phase_name() == "LOBBY":
					estate._flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0))
			if estate.get_phase_name() == "LOBBY":
				estate._build_lobby_panel()
			return
	NetSession.grant_seat(peer_id, -1, "the couch is full of humans")

## The wire dropped: the seat flips BOT on the existing Executor register.
## Mid-game the relay already feeds neutral input (the pawn idles); the bot
## flag takes over at the next boundary, exactly the couch unplug behavior.
static func on_peer_left_seat(estate, seat: int, _peer_id: int) -> void:
	if seat < 0 or seat > 3:
		return
	PlayerInput.set_bot(seat, true)
	estate._lobby_ready.erase(seat)
	estate._join_ready_lock.erase(seat)
	Sfx.play("grudge", -4.0)
	estate._flash("%s HAS BEEN CALLED AWAY — THE ESTATE WILL KEEP THEIR SEAT, AND THEIR GRUDGES" % GameState.PLAYER_NAMES[seat], GameState.PLAYER_COLORS[seat], 2.6)
	if estate.get_phase_name() == "LOBBY":
		estate.get_tree().create_timer(2.7).timeout.connect(func():
			if estate.get_phase_name() == "LOBBY":
				estate._flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0))
		estate._build_lobby_panel()

## Semantic UI intents from guests (spec §5.3): the client clicked a mirrored
## control, the host runs the seat-parameterized handler.
static func on_panel_intent(estate, seat: int, intent: Dictionary) -> void:
	match String(intent.get("kind", "")):
		"ready_toggle":
			if estate.get_phase_name() == "LOBBY" or estate.get_phase_name() == "GROUNDS":
				estate._lobby_ready[seat] = not estate._lobby_ready.get(seat, false)
				Sfx.play("ui_move")
				if estate.get_phase_name() == "LOBBY":
					estate._build_lobby_panel()

## 5 Hz lobby facts (reliable) + 15 Hz walker snapshots (unreliable_ordered).
static func host_broadcast(estate, delta: float) -> void:
	if not NetSession.has_guests():
		return
	estate._net_state_accum += delta
	if estate._net_state_accum >= 0.2:
		estate._net_state_accum = 0.0
		NetSession.send_lobby_state(estate._net_build_lobby_state())
	estate._net_walker_accum += delta
	if estate._net_walker_accum >= 1.0 / 15.0:
		estate._net_walker_accum = 0.0
		estate._net_walker_seq += 1
		var ws: Dictionary = estate._net_build_walker_state(estate._net_walker_seq)
		NetSession.send_walker_state(ws)
		if estate._netprobe != "" and estate._net_walker_seq % 15 == 0:
			print("NETHASH side=host seq=%d h=%s" % [estate._net_walker_seq, NetSession.snapshot_hash(ws)])
	# ONLINE PHASE 2: the game-mirror pump (20 Hz, unreliable_ordered ch 4).
	if estate._module != null and estate._net_mirror_id != "":
		estate._net_module_accum += delta
		if estate._net_module_accum >= 1.0 / 20.0:
			estate._net_module_accum = 0.0
			estate._net_module_seq += 1
			var ms: Dictionary = estate._module._net_state()
			ms["seq"] = estate._net_module_seq
			NetSession.send_module_state(ms)
			if estate._netprobe != "" and estate._net_module_seq % 40 == 0:
				print("NETHASH_MOD side=host seq=%d h=%s bytes=%d" % [
					estate._net_module_seq, NetSession.snapshot_hash(ms), var_to_bytes(ms).size()])

static func build_lobby_state(estate) -> Dictionary:
	var seats: Array = []
	for i in 4:
		seats.append({
			"name": GameState.PLAYER_NAMES[i],
			"status": estate._seat_status(i),
			"ready": estate._lobby_ready.get(i, false),
			"ping": NetSession.rtt_of_seat(i),
		})
	var state := {
		"phase": estate.get_phase_name(),
		"code": NetSession.invite_code(),
		"addr": NetSession.listen_addr(),
		"seats": seats,
		"hats": estate._net_hats(),
	}
	if not estate._net_ceremony.is_empty():
		state["ceremony"] = estate._net_ceremony
	if estate.get_phase_name() == "GAME":
		state["game"] = estate._net_game_name
		if estate._net_mirror_id != "" and estate._module != null:
			state["mirror"] = estate._net_mirror_id   # phase 2: clients boot this scene
	return state

## The estate's wardrobe truth per seat: {p: [worn cosmetic ids]}. Guests
## restage podiums/walkers from THESE — their local cosmetics.json is a
## different estate's closet.
static func hats() -> Dictionary:
	var hats := {}
	for i in EstateState.players.size():
		var loadout: Dictionary = Cosmetics.get_player_cosmetics(i)
		if not loadout.is_empty():
			hats[i] = loadout.values()
	return hats

## Enter/replace/leave a mirrored ceremony stage. Stage flips matter more than
## the 5 Hz cadence, so every change pushes the facts immediately (reliable).
static func set_ceremony(estate, cer: Dictionary) -> void:
	estate._net_ceremony = cer
	estate._net_push_facts()

static func push_facts(estate) -> void:
	if NetSession.is_host() and NetSession.has_guests():
		NetSession.send_lobby_state(estate._net_build_lobby_state())

static func build_walker_state(estate, seq: int) -> Dictionary:
	var w := {}
	for i in estate.walkers.size():
		if not is_instance_valid(estate.walkers[i]):
			continue
		var wk: EstateWalker = estate.walkers[i]
		w[i] = [
			snappedf(wk.global_position.x, 0.001), snappedf(wk.global_position.y, 0.001),
			snappedf(wk.global_position.z, 0.001), snappedf(wk.rotation.y, 0.001),
			Vector2(wk.velocity.x, wk.velocity.z).length() > 0.5,
		]
	return {"seq": seq, "w": w}

## ----- client side (the estate-only mirror) -----

static func build_join_panel(estate, lobby_phase: int) -> void:
	estate.phase = lobby_phase
	estate._hide_title()
	Sfx.play("ui_move")
	estate._clear_panel("JOIN A NIGHT — the host reads you their code", Color(0.9, 0.95, 0.9))
	var entry := LineEdit.new()
	entry.name = "JoinEntry"
	entry.placeholder_text = "6-char code or IP:PORT"
	entry.custom_minimum_size = Vector2(360, 50)
	entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ec := CenterContainer.new()
	ec.add_child(entry)
	estate.phase_box.add_child(ec)
	var status := Label.new()
	status.name = "JoinStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 15)
	status.modulate.a = 0.8
	estate.phase_box.add_child(status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var join := Button.new()
	join.text = "KNOCK"
	join.custom_minimum_size = Vector2(180, 52)
	join.pressed.connect(func():
		var err: int = NetSession.join_night(entry.text)
		if err != OK:
			Sfx.play("ui_error")
			status.text = "that code does not parse — check it with the host"
		else:
			Sfx.play("ui_move")
			status.text = "knocking at the estate gate...")
	row.add_child(join)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120, 52)
	back.pressed.connect(func():
		NetSession.leave()
		estate._enter_title())
	row.add_child(back)
	estate.phase_box.add_child(row)
	var hint := Label.new()
	hint.text = "LAN or port-forwarded internet this phase — Steam invites arrive with phase 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.6
	estate.phase_box.add_child(hint)

static func on_seat_granted(estate, seat: int, reason: String) -> void:
	if seat < 0:
		estate._flash("THE ESTATE DECLINED: %s" % reason, Color(0.9, 0.6, 0.6), 3.2)
		var status: Node = estate.phase_box.get_node_or_null("JoinStatus")
		if status and status is Label:
			status.text = reason
		NetSession.leave()
		return
	# Local device feeds the relay through the SAME per-index API; a pad if
	# one is connected, else the WASD keyboard half. Tape mode samples nothing.
	if not NetSession.tape_mode():
		var pads := Input.get_connected_joypads()
		PlayerInput.assign(seat, pads[0] if pads.size() > 0 else -1)
		PlayerInput.set_bot(seat, false)
	estate._enter_client_lobby()

static func enter_client_lobby(estate, lobby_phase: int) -> void:
	estate.phase = lobby_phase
	estate._hide_title()
	Music.play_slot("lobby")
	# Walkers become mirror puppets: the host owns every transform.
	for w in estate.walkers:
		if is_instance_valid(w):
			w.set_physics_process(false)
	estate._flash("SEAT CLAIMED — YOUR WALKER IS ON THE HOST'S GROUNDS", Color(0.35, 0.9, 0.5), 3.0)
	estate._client_panel_sig = ""
	estate._client_build_panel()

static func on_lobby_state(estate, state: Dictionary) -> void:
	estate._client_last_state = state
	var sig := JSON.stringify(state)
	if sig != estate._client_panel_sig:
		estate._client_panel_sig = sig
		estate._client_build_panel()

static func on_walker_state(estate, state: Dictionary) -> void:
	var w: Dictionary = state.get("w", {})
	for k in w:
		var arr: Array = w[k]
		if arr.size() < 5:
			continue
		estate._client_walker_targets[int(str(k))] = {
			"pos": Vector3(float(arr[0]), float(arr[1]), float(arr[2])),
			"rot": float(arr[3]), "moving": bool(arr[4]),
		}
	if estate._netprobe != "" and int(state.get("seq", 0)) % 15 == 0:
		print("NETHASH side=client seq=%d h=%s" % [int(state.get("seq", 0)), NetSession.snapshot_hash(state)])

static func client_process(estate, delta: float) -> void:
	for p in estate._client_walker_targets:
		if p >= estate.walkers.size() or not is_instance_valid(estate.walkers[p]):
			continue
		var t: Dictionary = estate._client_walker_targets[p]
		var w: EstateWalker = estate.walkers[p]
		w.global_position = w.global_position.lerp(t.pos, 1.0 - exp(-12.0 * delta))
		w.rotation.y = lerp_angle(w.rotation.y, float(t.rot), 1.0 - exp(-10.0 * delta))
		if w.anim:
			var want: String = "Walking_A" if bool(t.moving) else "Idle"
			if w.anim.current_animation != want and w.anim.has_animation(want):
				w.anim.play(want)

## ----- PHASE 2: the game mirror (client side of the handoff seam) -----

## Snapshots for the running game -> straight into the mirror's _net_apply.
static func on_module_state(estate, state: Dictionary) -> void:
	if estate._module != null and estate._module.has_method("_net_apply"):
		estate._module._net_apply(state)
		if estate._netprobe != "" and int(state.get("seq", 0)) % 40 == 0:
			print("NETHASH_MOD side=client seq=%d h=%s" % [int(state.get("seq", 0)), NetSession.snapshot_hash(state)])

## Hidden info for MY seat (rpc_id said so) -> the mirror's private handler.
static func on_module_private(estate, data: Dictionary) -> void:
	if estate._module != null and estate._module.has_method("_net_apply_private"):
		estate._module._net_apply_private(data)

## The client lobby: rebuilt from mirrored facts, never from local state.
static func client_build_panel(estate, client_last_state: Dictionary) -> void:
	var state := client_last_state
	if state.has("hats"):
		estate._client_apply_hats(state["hats"])
	var cer: Dictionary = state.get("ceremony", {})
	# CEREMONIES FIRST: the match podium plays while the host phase still reads
	# GAME — a guest must see the podium, never the spectate card, at that beat.
	if not cer.is_empty():
		estate._client_render_ceremony(cer)
		return
	estate._client_end_ceremony()
	var phase_name := String(state.get("phase", "LOBBY"))
	if phase_name == "GAME":
		if state.has("mirror"):
			estate._client_ensure_mirror(String(state["mirror"]))
			return
		# no mirror for this game: spectate card
		estate._client_teardown_mirror()
		estate._client_build_spectate_panel(state)
		return
	estate._client_teardown_mirror()
	estate._clear_panel("AN ONLINE ESTATE — hosted across the wire", Color(0.9, 0.95, 0.9))
	var seats: Array = state.get("seats", [])
	if seats.is_empty():
		var wait := Label.new()
		wait.text = "waiting for the estate to describe itself..."
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait.modulate.a = 0.7
		estate.phase_box.add_child(wait)
		return
	for i in seats.size():
		var s: Dictionary = seats[i]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		if String(s.get("status", "")) == "EMPTY":
			row.modulate.a = 0.5
		row.add_child(PlayerBadge.make(i, 20))
		var name_l := Label.new()
		name_l.text = String(s.get("name", "?")) + ("  (you)" if i == NetSession.my_seat() else "")
		name_l.custom_minimum_size = Vector2(170, 0)
		name_l.add_theme_font_size_override("font_size", 22)
		name_l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(name_l)
		var st_l := Label.new()
		st_l.text = String(s.get("status", "?"))
		st_l.custom_minimum_size = Vector2(110, 0)
		st_l.add_theme_font_size_override("font_size", 18)
		st_l.modulate.a = 0.85
		row.add_child(st_l)
		if bool(s.get("ready", false)):
			row.add_child(estate._make_ready_chip())
		estate.phase_box.add_child(row)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	var ready_btn := Button.new()
	ready_btn.text = "READY"
	ready_btn.custom_minimum_size = Vector2(200, 52)
	ready_btn.pressed.connect(func():
		Sfx.play("ui_move")
		NetSession.send_panel_intent({"kind": "ready_toggle"}))
	btn_row.add_child(ready_btn)
	var leave_btn := Button.new()
	leave_btn.text = "LEAVE THE ESTATE"
	leave_btn.custom_minimum_size = Vector2(200, 52)
	leave_btn.pressed.connect(func():
		NetSession.leave())
	btn_row.add_child(leave_btn)
	estate.phase_box.add_child(btn_row)
	var hint := Label.new()
	hint.text = "MOVE strolls your walker on the host's grounds  ·  your A (or READY) toggles ready  ·  the host holds the keys to the estate"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(700, 0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.7
	estate.phase_box.add_child(hint)

## Phase-1 posture (spec §8): games not yet mirrored render host-side only;
## the client keeps its seat, its input still relays, and this card says so.
static func client_build_spectate_panel(estate, state: Dictionary) -> void:
	estate._clear_panel(String(state.get("game", "A GAME")), Color(1, 0.9, 0.5))
	var body := Label.new()
	body.text = "This one plays on the host's screen — your inputs still reach your pawn.\nGames with remote mirrors play right here; the estate keeps your seat warm."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 0)
	estate.phase_box.add_child(body)
