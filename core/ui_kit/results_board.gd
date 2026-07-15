class_name ResultsBoard
extends CanvasLayer
## AAA results ceremony (doc 14 §3.5, §3.1-3.4). The standardized end-of-round /
## end-of-match reveal every anthology game routes through, so the room hears the
## same shape every time: FREEZE beat -> per-player REVEAL rows (count-up + row
## settle + rising placement stingers, worst->best) -> protected WINNER hero beat.
##
## Data-driven, zero per-game assumptions. The caller passes placement-ordered
## rows + options; game-specific spectacle (turf saturation, a 3D cheer, a camera
## pull) rides the signals below so it stays game-side while the count-up + winner
## card live here.
##
## Timing follows doc 14 §3 (freeze -> reveal -> count-up -> hero) and the §6 juice
## table (100/200-300/300-400ms ease-out tweens). Skippability follows item 22/23:
## ANY listed player HOLDS A (~0.6s, the couch-safe variant §3.4) to skip the
## current beat; the winner reveal is PROTECTED and cannot be skipped past.
## Reduced motion (FinalStretch.motion_ok()) snaps values + drops pops, keeps sound.
##
## Usage:
##   var board := ResultsBoard.new()
##   add_child(board)
##   board.freeze_beat.connect(func(): camera_pull())          # optional
##   board.row_started.connect(func(p): lawn.set_tally(p+1, 0)) # optional
##   board.row_tick.connect(func(p, shown, t): lawn.set_tally(p+1, t)) # optional
##   board.winner_beat.connect(func(p): winner.cheer())         # optional
##   board.done.connect(_on_results_done)
##   board.present(rows, {title="TALLYING...", score_type=ResultsBoard.ScoreType.PERCENT})
##
## rows: Array of Dictionaries, caller-ordered BEST -> WORST (final placement):
##   { player:int,               # seat index -> PlayerBadge shape + fallback name/color
##     score:float,              # the number that counts up 0 -> score
##     delta:float = 0.0,        # optional "+N" fly-in (0 = hidden)
##     label:String = "",        # optional trailing tag (e.g. "fuel 40%")
##     callout:String = "",      # optional royalty/credit line under the row
##     color:Color,              # optional explicit identity color
##     name:String }             # optional explicit display name
## opts (all optional):
##   title:String, subtitle:String
##   score_type:ScoreType        # POINTS | PERCENT | TIME  (default POINTS)
##   win_title:String            # template, {name} substituted (default "{name} WINS")
##   accent:Color                # title/subtitle tint (default GOLD)
##   skip_seats:Array            # seats allowed to hold-A to skip (default: rows' players)
##   protect_winner:bool         # default true (item 22)
##   reduced_motion:bool         # default: not FinalStretch.motion_ok()
##   freeze_time/row_time/row_gap/winner_time:float   # per-beat overrides

signal freeze_beat                              ## the "calculating" hold begins
signal row_started(player: int)                 ## a placement row begins its count-up
signal row_tick(player: int, shown_value: float, t: float)  ## count-up progress (t 0..1)
signal winner_beat(player: int)                 ## the protected hero beat begins
signal done                                     ## ceremony finished (safe to report)

enum ScoreType { POINTS, PERCENT, TIME }

const FREEZE_TIME := 0.8
const ROW_TIME := 0.5          # count-up duration (doc 14 §6: hero-scale transition)
const ROW_GAP := 0.12
const WINNER_TIME := 1.6
const SKIP_HOLD := 0.6         # doc 14 item 23: HOLD not tap, couch-safe
const TICK_THROTTLE_MS := 32   # ~30 Hz roll ceiling — never a machine-gun

const _FONT_BIG := "res://assets/fonts/LuckiestGuy-Regular.ttf"
const _FONT_BODY := "res://assets/fonts/Baloo2.ttf"
const GOLD := Color(1, 0.85, 0.25)

var _rows: Array = []
var _opts: Dictionary = {}
var _score_type := ScoreType.POINTS
var _reduced := false

var _root: Control
var _title: Label
var _subtitle: Label
var _rows_box: VBoxContainer
var _winner_banner: Label
var _row_widgets: Array = []          # per rank: {row, badge, name, value, delta, callout, player, score}
var _running := false
var _protected := false

# skip bookkeeping
var _skip_seats: Array = []
var _hold_t: Dictionary = {}
var _skip_pending := false
var _pi: Node = null

# exact-pitch placement-stinger pool (Sfx wobbles pitch; a rising LADDER needs
# exact steps — FinalStretch precedent)
var _sting_players: Array = []
var _sting_next := 0
var _sting_stream: AudioStream = null
var _tick_last_ms := 0
var _tick_last_int := -999999

func _init() -> void:
	layer = 3   # above a game HUD (default CanvasLayer layer 1); games hide theirs anyway
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_pi = get_node_or_null(^"/root/PlayerInput")
	_build_ui()

# ---------------------------------------------------------------- public API

## Stage the ceremony. rows are BEST -> WORST. Returns immediately; listen to
## `done`. Safe to call once per instance.
func present(rows: Array, opts: Dictionary = {}) -> void:
	_rows = rows
	_opts = opts
	_score_type = int(opts.get("score_type", ScoreType.POINTS))
	_reduced = bool(opts.get("reduced_motion", not FinalStretch.motion_ok()))
	_skip_seats = opts.get("skip_seats", _players_of(rows))
	_title.text = str(opts.get("title", ""))
	_title.visible = _title.text != ""
	_subtitle.text = str(opts.get("subtitle", ""))
	_subtitle.visible = _subtitle.text != ""
	var accent: Color = opts.get("accent", GOLD)
	_title.add_theme_color_override("font_color", accent)
	_subtitle.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.35))
	_populate_rows()
	_running = true
	_run()

# ---------------------------------------------------------------- UI build

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var head := VBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.anchor_left = 0.0
	head.anchor_right = 1.0
	head.anchor_top = 0.10
	head.offset_bottom = 150
	head.add_theme_constant_override("separation", 2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(head)
	_title = _mk_label(_FONT_BIG, 46, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(_title)
	_subtitle = _mk_label(_FONT_BODY, 24, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(_subtitle)

	# the rows sit in the lower-middle third (mower precedent — never collides
	# with an upper-center banner/title)
	var cc := CenterContainer.new()
	cc.anchor_left = 0.0
	cc.anchor_right = 1.0
	cc.anchor_top = 0.34
	cc.anchor_bottom = 0.98
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cc)
	_rows_box = VBoxContainer.new()
	_rows_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows_box.add_theme_constant_override("separation", 8)
	cc.add_child(_rows_box)

	_winner_banner = _mk_label(_FONT_BIG, 62, HORIZONTAL_ALIGNMENT_CENTER)
	_winner_banner.anchor_left = 0.0
	_winner_banner.anchor_right = 1.0
	_winner_banner.anchor_top = 0.16
	_winner_banner.offset_bottom = 210
	_winner_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_winner_banner.visible = false
	_root.add_child(_winner_banner)

func _populate_rows() -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	_row_widgets.clear()
	for rank in _rows.size():
		var data: Dictionary = _rows[rank]
		var player := int(data.get("player", rank))
		# .get() default is eager — guard the autoload-touching fallbacks.
		var col: Color = data["color"] if data.has("color") else _color_for(player)
		var nm: String = data["name"] if data.has("name") else _name_for(player)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(560, 52)
		row.modulate = Color(1, 1, 1, 0)   # occupy layout, reveal by fade (stable digits)
		row.pivot_offset = Vector2(280, 26)

		var badge := PlayerBadge.make(player, 38)
		badge.color = col
		row.add_child(badge)

		var name_lbl := _mk_label(_FONT_BIG, 32, HORIZONTAL_ALIGNMENT_LEFT)
		name_lbl.text = nm
		name_lbl.add_theme_color_override("font_color", col)
		name_lbl.custom_minimum_size = Vector2(190, 0)
		row.add_child(name_lbl)

		var callout_lbl := _mk_label(_FONT_BODY, 20, HORIZONTAL_ALIGNMENT_LEFT)
		callout_lbl.text = str(data.get("callout", ""))
		callout_lbl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.4))
		callout_lbl.visible = callout_lbl.text != ""
		callout_lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(callout_lbl)

		var delta_lbl := _mk_label(_FONT_BIG, 26, HORIZONTAL_ALIGNMENT_RIGHT)
		var dv := float(data.get("delta", 0.0))
		delta_lbl.text = ("+%d" % int(round(dv))) if dv > 0.0 else ""
		delta_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		delta_lbl.custom_minimum_size = Vector2(64, 0)
		row.add_child(delta_lbl)

		var value_lbl := _mk_label(_FONT_BIG, 44, HORIZONTAL_ALIGNMENT_RIGHT)
		value_lbl.text = _fmt(0.0)
		value_lbl.add_theme_color_override("font_color", col)
		value_lbl.custom_minimum_size = Vector2(150, 0)
		value_lbl.pivot_offset = Vector2(75, 28)
		row.add_child(value_lbl)

		_rows_box.add_child(row)
		_row_widgets.append({
			"row": row, "value": value_lbl, "name": name_lbl,
			"player": player, "score": float(data.get("score", 0.0)), "color": col,
		})

# ---------------------------------------------------------------- sequence

func _run() -> void:
	# 1) FREEZE beat — the room doesn't know the outcome yet (doc 14 §3.5).
	freeze_beat.emit()
	Sfx.play("card", -6.0)
	await _hold(_opts.get("freeze_time", FREEZE_TIME), true)

	# 2) REVEAL rows, WORST -> BEST (ascending drama; winner lands last).
	var n := _row_widgets.size()
	for i in range(n - 1, -1, -1):
		var w: Dictionary = _row_widgets[i]
		row_started.emit(int(w.player))
		# rising placement stinger: worst low, best high
		var pitch := 1.0
		if n > 1:
			pitch = lerpf(1.0, 1.5, float(n - 1 - i) / float(n - 1))
		_sting(pitch)
		_reveal_row(w)
		await _count_row(i, _opts.get("row_time", ROW_TIME), i != 0)  # winner row never skips
		await _hold(_opts.get("row_gap", ROW_GAP), i != 0)

	# 3) WINNER hero beat — PROTECTED (item 22).
	if n > 0:
		_protected = bool(_opts.get("protect_winner", true))
		_winner_beat()
		await _hold(_opts.get("winner_time", WINNER_TIME), false)
		_protected = false

	_running = false
	done.emit()

func _reveal_row(w: Dictionary) -> void:
	var row: Control = w.row
	if _reduced:
		row.modulate = Color(1, 1, 1, 1)
		return
	var tw := create_tween()
	tw.tween_property(row, "modulate", Color(1, 1, 1, 1), 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _count_row(rank: int, dur: float, skippable: bool) -> void:
	var w: Dictionary = _row_widgets[rank]
	var value_lbl: Label = w.value
	var target: float = w.score
	var player := int(w.player)
	if _reduced or dur <= 0.0:
		_set_value(value_lbl, target)
		row_tick.emit(player, target, 1.0)
		return
	# a small scale pop on the digits as they land (mower precedent)
	value_lbl.scale = Vector2(0.7, 0.7)
	var pop := create_tween()
	pop.tween_property(value_lbl, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t0 := Time.get_ticks_msec()
	_tick_last_int = -999999
	while true:
		var e := float(Time.get_ticks_msec() - t0) / 1000.0
		var t := clampf(e / dur, 0.0, 1.0)
		var te := 1.0 - pow(1.0 - t, 2.0)   # ease-out (doc 14 §6)
		var v := target * te
		_set_value(value_lbl, v)
		row_tick.emit(player, v, t)
		if t >= 1.0:
			break
		if skippable and _consume_skip():
			break
		await get_tree().process_frame
	_set_value(value_lbl, target)          # land exactly on the final number
	row_tick.emit(player, target, 1.0)

func _winner_beat() -> void:
	var w: Dictionary = _row_widgets[0]
	var player := int(w.player)
	var col: Color = w.color
	var nm := _name_for(player)
	if _rows[0].has("name"):
		nm = str(_rows[0]["name"])
	var tmpl := str(_opts.get("win_title", "{name} WINS"))
	_winner_banner.text = tmpl.replace("{name}", nm)
	_winner_banner.add_theme_color_override("font_color", col)
	_winner_banner.visible = true
	# clear the "calculating" title so the hero banner owns the top third
	if _reduced:
		_title.visible = false
		_subtitle.visible = false
	else:
		var ht := create_tween()
		ht.set_parallel(true)
		ht.tween_property(_title, "modulate:a", 0.0, 0.2)
		ht.tween_property(_subtitle, "modulate:a", 0.0, 0.2)
	if not _reduced:
		_winner_banner.pivot_offset = _winner_banner.size / 2.0
		_winner_banner.scale = Vector2(1.7, 1.7)
		var tw := create_tween()
		tw.tween_property(_winner_banner, "scale", Vector2.ONE, 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# emphasise the winner row
		var row: Control = w.row
		row.pivot_offset = row.size / 2.0
		var rp := create_tween()
		rp.tween_property(row, "scale", Vector2(1.12, 1.12), 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rp.tween_property(row, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_confetti(col)
	Sfx.play("match_win")
	winner_beat.emit(player)

# ---------------------------------------------------------------- skip / wait

## Real-time wait (ignores Engine.time_scale slow-mo) that a skip can cut short.
func _hold(dur: float, skippable: bool) -> void:
	if dur <= 0.0:
		return
	var t0 := Time.get_ticks_msec()
	var ms := int(dur * 1000.0)
	while (Time.get_ticks_msec() - t0) < ms:
		if skippable and _consume_skip():
			return
		await get_tree().process_frame

func _process(delta: float) -> void:
	if not _running or _protected or _pi == null:
		return
	for s in _skip_seats:
		if _pi.is_down(int(s), "a"):
			_hold_t[s] = float(_hold_t.get(s, 0.0)) + delta
			if _hold_t[s] >= SKIP_HOLD:
				_skip_pending = true
		else:
			_hold_t[s] = 0.0

func _consume_skip() -> bool:
	if _skip_pending:
		_skip_pending = false
		_hold_t.clear()
		return true
	return false

# ---------------------------------------------------------------- helpers

func _set_value(lbl: Label, v: float) -> void:
	lbl.text = _fmt(v)
	if _score_type == ScoreType.POINTS or _score_type == ScoreType.PERCENT:
		var iv := int(round(v))
		if iv != _tick_last_int:
			_tick_last_int = iv
			var now := Time.get_ticks_msec()
			if now - _tick_last_ms >= TICK_THROTTLE_MS:
				_tick_last_ms = now
				Sfx.play("card", -8.0)

func _fmt(v: float) -> String:
	match _score_type:
		ScoreType.PERCENT:
			return "%d%%" % int(round(v))
		ScoreType.TIME:
			if v >= 60.0:
				return "%d:%02d" % [int(v) / 60, int(v) % 60]
			return "%.1fs" % v
		_:
			return str(int(round(v)))

func _mk_label(font_path: String, size: int, halign: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = halign
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _players_of(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append(int(r.get("player", 0)))
	return out

func _gamestate() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root.has_node("GameState"):
		return (ml as SceneTree).root.get_node("GameState")
	return null

func _color_for(player: int) -> Color:
	var gs := _gamestate()
	if gs != null and player >= 0 and player < gs.PLAYER_COLORS.size():
		return gs.PLAYER_COLORS[player]
	return PlayerBadge.DEFAULT_COLORS[player % PlayerBadge.DEFAULT_COLORS.size()]

func _name_for(player: int) -> String:
	var gs := _gamestate()
	if gs != null and player >= 0 and player < gs.PLAYER_NAMES.size():
		return str(gs.PLAYER_NAMES[player])
	return "P%d" % (player + 1)

func _sting(pitch: float) -> void:
	if _sting_players.is_empty():
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.bus = "SFX"
			add_child(p)
			_sting_players.append(p)
	if _sting_stream == null:
		var wav := "res://assets/audio/confirmation_001.wav"
		_sting_stream = load(wav) if ResourceLoader.exists(wav) \
			else load("res://assets/audio/confirmation_001.ogg")
	if _sting_stream == null:
		return
	var p: AudioStreamPlayer = _sting_players[_sting_next]
	_sting_next = (_sting_next + 1) % _sting_players.size()
	p.stream = _sting_stream
	p.pitch_scale = pitch
	p.volume_db = -5.0
	p.play()

func _confetti(col: Color) -> void:
	for x in [0.25, 0.5, 0.75]:
		var p := CPUParticles2D.new()
		_root.add_child(p)
		p.position = Vector2(_root.size.x * x, -10.0)
		p.amount = 26
		p.lifetime = 2.2
		p.one_shot = true
		p.explosiveness = 0.55
		p.direction = Vector2.DOWN
		p.spread = 35.0
		p.gravity = Vector2(0, 340)
		p.initial_velocity_min = 90.0
		p.initial_velocity_max = 240.0
		p.angular_velocity_min = -320.0
		p.angular_velocity_max = 320.0
		p.scale_amount_min = 3.0
		p.scale_amount_max = 6.0
		p.color = col if x != 0.5 else Color(1, 0.92, 0.5)
		p.emitting = true
		get_tree().create_timer(3.0).timeout.connect(p.queue_free)
