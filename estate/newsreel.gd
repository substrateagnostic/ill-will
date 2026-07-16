class_name Newsreel
extends CanvasLayer
## THE NIGHT'S NEWSREEL — THE ESTATE'S MEMORY, part 2.
##
## A silent-film ceremony that plays the night's captured stills back before the
## will is read. Each still is run through the newsreel shader (sepia, grain,
## gate flicker, vignette, drifting scratches) with a slow Ken Burns pan, and
## between them an ornate intertitle card announces the act. A projector clatters
## the whole time; each card lands on a soft piano sting. The estate remembers,
## and it insists you watch it remember.
##
## API (static, no autoload):
##   Newsreel.play(moments, on_done)   moments = MomentScribe.night_moments()
##       (or any Array of { caption, game, players, abs|file|tex }).
##   Newsreel.test_run(shots_dir)      synthetic stills; drives the verify beats.
##
## Skippable only by UNANIMITY: every seated human must press A. One player alone
## cannot rob the rest of the reel (and an all-bots exhibition plays it through).
##
## Reads PlayerInput read-only. Writes nothing but its own verify screenshots.

const SHADER_PATH := "res://assets/shaders/newsreel.gdshader"
const HEADER_FONT := "res://assets/fonts/Bangers-Regular.ttf"
const BODY_FONT := "res://assets/fonts/Fredoka.ttf"
const SCENE_PATH := "res://estate/newsreel.tscn"

const CARD_TIME := 2.6           # intertitle hold
const STILL_TIME := 3.6          # Ken Burns per still
const MAX_STILLS := 6
const MIN_STILLS := 1

@onready var _bg: ColorRect = $Bg
@onready var _still: TextureRect = $Still
@onready var _card: Control = $Card
@onready var _skip_hint: Label = $SkipHint

var _moments: Array = []
var _on_done := Callable()
var _skip := false
var _finished := false
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _card_box: VBoxContainer
var _card_header: Label
var _card_title: Label
var _card_flavor: Label

# Projector + stings (built from the existing Sfx bank; no new audio files).
var _proj: Array = []
var _proj_i := 0
var _proj_accum := 0.0
var _proj_on := false
var _click_stream: AudioStream
var _sting_a: AudioStreamPlayer
var _sting_b: AudioStreamPlayer

# Unanimous-skip bookkeeping.
var _skip_pressed := {}

# Verify.
var _test := false
var _shot_dir := "verify_out/estate_memory"

## ---------------------------------------------------------------- entry points

static func play(moments: Array, on_done := Callable()) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var inst: Newsreel = (load(SCENE_PATH) as PackedScene).instantiate()
	tree.root.add_child(inst)
	inst._begin(moments, on_done)
	return inst

## Verify boot: synthesise a handful of distinct "frames" and play the reel,
## grabbing the required stills into `shots_dir`, then quit.
static func test_run(shots_dir := "verify_out/estate_memory") -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var inst: Newsreel = (load(SCENE_PATH) as PackedScene).instantiate()
	inst._test = true
	inst._shot_dir = shots_dir
	tree.root.add_child(inst)
	var caps := ["THE DECIDING MOMENT", "THE VICTOR", "THE BETRAYAL",
		"THE LAST STAND", "THE RECKONING"]
	var games := ["echo_chamber", "throne", "greed", "dead_weight", "last_will"]
	var synth: Array = []
	for i in caps.size():
		synth.append({
			"caption": caps[i], "game": games[i], "players": [],
			"tex": _synthetic_still(i, caps.size()),
			"priority": 3 if i == 0 else 2,
		})
	inst._begin(synth, Callable())
	return inst

## ---------------------------------------------------------------- lifecycle

func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS   # the reel runs even if the tree pauses

	_bg.color = Color.BLACK
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_still.stretch_mode = TextureRect.STRETCH_SCALE
	_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_still.modulate.a = 0.0
	var sh := load(SHADER_PATH)
	if sh != null:
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_still.material = _mat

	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()

	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skip_hint.offset_top = -46
	_skip_hint.offset_bottom = -14
	_skip_hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.66, 0.55))
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.text = ""

	_build_audio()

func _build_card() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(center)
	_card_box = VBoxContainer.new()
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_box.add_theme_constant_override("separation", 14)
	_card_box.modulate.a = 0.0
	center.add_child(_card_box)

	var hfont := load(HEADER_FONT)
	var bfont := load(BODY_FONT)

	_card_header = _mk_label(hfont, 76, Color(0.95, 0.92, 0.82))
	_card_box.add_child(_card_header)
	_card_box.add_child(_rule())
	_card_title = _mk_label(bfont if bfont != null else hfont, 46, Color(0.98, 0.96, 0.9))
	_card_box.add_child(_card_title)
	_card_flavor = _mk_label(bfont if bfont != null else hfont, 22, Color(0.78, 0.73, 0.6))
	_card_box.add_child(_rule())
	_card_box.add_child(_card_flavor)

func _mk_label(font: Variant, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 0)
	return l

func _rule() -> Control:
	# A thin double-rule, the ornament of a proper title card.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for w in [Vector2(320, 2), Vector2(220, 1)]:
		var line := ColorRect.new()
		line.color = Color(0.8, 0.75, 0.6, 0.85)
		line.custom_minimum_size = w
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(line)
	return box

func _build_audio() -> void:
	var cw := "res://assets/audio/click_001.wav"
	_click_stream = load(cw) if ResourceLoader.exists(cw) else load("res://assets/audio/click_001.ogg")
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = _click_stream
		add_child(p)
		_proj.append(p)
	_sting_a = AudioStreamPlayer.new()
	_sting_a.bus = "SFX"
	_sting_a.stream = _load_any(["jingles_NES03"])
	add_child(_sting_a)
	_sting_b = AudioStreamPlayer.new()
	_sting_b.bus = "SFX"
	_sting_b.stream = _load_any(["bong_001"])
	add_child(_sting_b)

func _load_any(names: Array) -> AudioStream:
	for n in names:
		for ext in [".wav", ".ogg"]:
			var p := "res://assets/audio/%s%s" % [n, ext]
			if ResourceLoader.exists(p):
				return load(p)
	return null

func _begin(moments: Array, on_done: Callable) -> void:
	_on_done = on_done
	_moments = []
	for m in moments:
		if m is Dictionary:
			_moments.append(m)
		if _moments.size() >= MAX_STILLS:
			break
	_run()

## ---------------------------------------------------------------- the reel

func _run() -> void:
	_proj_on = true
	# Fade the house to black under the projector.
	await _fade(_bg, 1.0, 0.6)
	if _moments.size() < MIN_STILLS:
		# Nothing was captured tonight — a single honest card, then out.
		_set_card("PROLOGUE", "\"AN UNRECORDED NIGHT\"",
			"the estate remembers nothing it can show")
		await _show_card()
		await _hide_card()
		_end()
		return

	await _title_card()

	var shot_card_done := false
	var shot_still_done := false
	for i in _moments.size():
		if _skip or _finished:
			break
		var m: Dictionary = _moments[i]
		_set_card("ACT %s" % _roman(i + 1), "\"%s\"" % _caption_of(m), _flavor_of(m))
		await _show_card()
		if _test and not shot_card_done:
			await _grab("intertitle_card")
			shot_card_done = true
		await _sleep(CARD_TIME)
		await _hide_card()
		if _skip or _finished:
			break
		var grab_this_still := _test and not shot_still_done and i == 0
		await _show_still(m, grab_this_still)
		if grab_this_still:
			shot_still_done = true
		# Verify boots need only prove the two beats; once both are on disk we
		# cut to the end rather than sitting through the whole reel.
		if _test and shot_card_done and shot_still_done:
			break
	await _end_card()
	_end()

func _title_card() -> void:
	_set_card("THE NIGHT'S", "\"NEWSREEL\"", "as recorded by the estate, in full and without mercy")
	await _show_card()
	await _sleep(2.2)
	await _hide_card()

func _end_card() -> void:
	if _skip or _finished:
		return
	_set_card("— FIN —", "\"THE ESTATE RESTS\"", "the will shall now be read")
	await _show_card()
	await _sleep(1.8)
	await _hide_card()

func _set_card(header: String, title: String, flavor: String) -> void:
	_card_header.text = header
	_card_title.text = title
	_card_flavor.text = flavor

func _show_card() -> void:
	# Card fades up from black; still is hidden beneath it.
	_still.modulate.a = 0.0
	_sting()
	var tw := create_tween()
	tw.tween_property(_card_box, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	await tw.finished

func _hide_card() -> void:
	var tw := create_tween()
	tw.tween_property(_card_box, "modulate:a", 0.0, 0.4)
	await tw.finished

func _show_still(m: Dictionary, grab: bool) -> void:
	var tex := _texture_for(m)
	if tex == null:
		return
	_still.texture = tex
	# Fresh decay per still, and a Ken Burns move chosen for this frame.
	if _mat != null:
		_mat.set_shader_parameter("seed", _rng.randf() * 100.0)
		var z0 := _rng.randf_range(1.02, 1.06)
		var z1 := z0 + _rng.randf_range(0.05, 0.09)
		if _rng.randf() < 0.5:
			var t := z0; z0 = z1; z1 = t          # sometimes push in, sometimes pull out
		var amp := 0.03
		var p0 := Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp))
		var p1 := Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp))
		_mat.set_shader_parameter("zoom", z0)
		_mat.set_shader_parameter("pan", p0)
		_mat.set_shader_parameter("reveal", 0.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_still, "modulate:a", 1.0, 0.35)
		tw.tween_property(_mat, "shader_parameter/reveal", 1.0, 0.5)
		tw.parallel().tween_property(_mat, "shader_parameter/zoom", z1, STILL_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(_mat, "shader_parameter/pan", p1, STILL_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_still.modulate.a = 1.0
	# Let the pan breathe, grabbing the verify still mid-move if asked.
	await _sleep(STILL_TIME * 0.45)
	if grab:
		await _grab("still_midpan")
	await _sleep(STILL_TIME * 0.55)
	# Cut to black before the next card (a hard film cut).
	var tw2 := create_tween()
	tw2.tween_property(_still, "modulate:a", 0.0, 0.25)
	await tw2.finished

## Net parity: the host's ceremony moved on (the will facts arrived on a guest
## mirror while this reel still ran) — wrap up through the normal skip path.
func finish_now() -> void:
	_skip = true

func _end() -> void:
	if _finished:
		return
	_finished = true
	_proj_on = false
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 0.0, 0.4)
	await tw.finished
	if _on_done.is_valid():
		_on_done.call()
	if _test:
		print("NEWSREEL_TEST done stills=%d" % _moments.size())
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()
		return
	queue_free()

## ---------------------------------------------------------------- helpers

func _caption_of(m: Dictionary) -> String:
	return String(m.get("caption", "A MOMENT"))

func _flavor_of(m: Dictionary) -> String:
	var g := String(m.get("game", ""))
	var players: Array = m.get("players", [])
	if not players.is_empty():
		return "with %s — %s" % [", ".join(PackedStringArray(_as_strings(players))), _game_title(g)]
	if g != "" and g != "estate":
		return "as it happened in %s" % _game_title(g)
	return "on the grounds of the estate"

func _as_strings(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(str(x))
	return out

func _game_title(g: String) -> String:
	return g.replace("_", " ").to_upper() if g != "" else "THE ESTATE"

func _texture_for(m: Dictionary) -> Texture2D:
	if m.has("tex") and m.tex is Texture2D:
		return m.tex
	var path := ""
	if m.has("abs"):
		path = String(m.abs)
	elif m.has("file"):
		path = ProjectSettings.globalize_path(String(m.file))
	if path != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null

func _roman(n: int) -> String:
	var vals := [10, 9, 5, 4, 1]
	var sym := ["X", "IX", "V", "IV", "I"]
	var out := ""
	for i in vals.size():
		while n >= vals[i]:
			out += sym[i]
			n -= vals[i]
	return out if out != "" else "I"

## Interruptible sleep — every wait yields to the unanimous-skip poll.
func _sleep(t: float) -> void:
	var elapsed := 0.0
	while elapsed < t and not _skip and not _finished:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _fade(node: CanvasItem, to: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", to, t)
	await tw.finished

func _grab(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _shot_dir))
	var path := "res://%s/newsreel_%s.png" % [_shot_dir, tag]
	img.save_png(path)
	print("NEWSREEL_SHOT ", path)

func _sting() -> void:
	if _sting_a != null and _sting_a.stream != null:
		_sting_a.pitch_scale = _rng.randf_range(0.78, 0.9)
		_sting_a.volume_db = -8.0
		_sting_a.play()
	if _sting_b != null and _sting_b.stream != null:
		_sting_b.pitch_scale = _rng.randf_range(0.62, 0.72)
		_sting_b.volume_db = -12.0
		_sting_b.play()

## ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	# Projector clatter: a soft irregular tick, ~11/s, pitched low.
	if _proj_on and _click_stream != null:
		_proj_accum += delta
		var period := 0.085
		if _proj_accum >= period:
			_proj_accum = 0.0
			var p: AudioStreamPlayer = _proj[_proj_i]
			_proj_i = (_proj_i + 1) % _proj.size()
			p.pitch_scale = _rng.randf_range(0.5, 0.6)
			p.volume_db = -16.0
			p.play()
	_poll_skip()

## Unanimous skip: every seated HUMAN must have pressed A. Bots and remote seats
## are ignored; with no humans (verify/all-bots) the reel simply plays through.
func _poll_skip() -> void:
	if _skip or _finished:
		return
	var pin := get_node_or_null(^"/root/PlayerInput")
	var es := get_node_or_null(^"/root/EstateState")
	if pin == null or es == null:
		return
	var humans: Array = []
	for pl in es.players:
		var idx := int(pl.index)
		if not pin.is_bot(idx):
			humans.append(idx)
	if humans.is_empty():
		if _skip_hint.text != "":
			_skip_hint.text = ""
		return
	for idx in humans:
		if pin.just_pressed(idx, "a"):
			_skip_pressed[idx] = true
	var have := 0
	for idx in humans:
		if _skip_pressed.get(idx, false):
			have += 1
	_skip_hint.text = "HOLD FOR THE ESTATE  ·  ALL PRESS A TO SKIP  (%d / %d)" % [have, humans.size()]
	if have >= humans.size():
		_skip = true
		_skip_hint.text = ""

## ---------------------------------------------------------------- synthetic

## A distinct, filmic-looking placeholder frame for the verify reel. Composed
## from a few filled bands + silhouette columns so the Ken Burns pan has real
## structure to move across (the sepia/grain pass does the rest).
static func _synthetic_still(i: int, n: int) -> Texture2D:
	var w := 1280
	var h := 720
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var hue := float(i) / float(maxi(1, n))
	var sky := Color.from_hsv(0.08 + hue * 0.5, 0.35, 0.85)
	var ground := Color.from_hsv(0.08 + hue * 0.5, 0.5, 0.28)
	# Sky gradient (coarse bands — cheap, and the shader smooths the read).
	for y in range(0, h):
		var t := float(y) / float(h)
		var c := sky.lerp(ground, smoothstep(0.35, 0.72, t))
		img.fill_rect(Rect2i(0, y, w, 1), c)
	# A horizon glow.
	img.fill_rect(Rect2i(0, int(h * 0.66) - 4, w, 8), Color.from_hsv(0.1, 0.2, 1.0))
	# Silhouette "figures" of varying height — the cast of the night.
	var seed := i * 977 + 13
	for k in range(5):
		var rng := (seed + k * 131) % 1000
		var fx := int(120 + (float(rng) / 1000.0) * (w - 260))
		var fw := 60 + (rng % 40)
		var fh := 150 + (rng % 240)
		var fy := int(h * 0.68) - fh
		var shade := Color(0.05, 0.04, 0.06)
		img.fill_rect(Rect2i(fx, fy, fw, fh), shade)
		# a head
		img.fill_rect(Rect2i(fx + fw / 2 - 16, fy - 30, 32, 34), shade)
	# A bright "flash" mote so the frame isn't flat.
	img.fill_rect(Rect2i(int(w * (0.2 + 0.14 * i)), int(h * 0.3), 10, 10), Color(1, 1, 0.9))
	return ImageTexture.create_from_image(img)
