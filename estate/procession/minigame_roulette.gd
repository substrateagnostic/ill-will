class_name MinigameRoulette
extends Control
## THE MINIGAME ROULETTE (doc 24 F22). Before each minigame block a reel of game
## cards shuffles and DECELERATES onto the game the sim already picked, then a
## "TAKE YOUR PLACES" splash (the estate's voice — never "GET READY", per the
## voice bible, doc 26). Pure theater: the reel animates TOWARD a decided result
## and draws no rng, so the receipt is safe; gated behind not _fast by the caller.
##
## Titles + accents are a LOCAL catalogue (the games declare these privately in
## their own IntroCards; replicated here so this lane touches no minigame file).

const SLOTS := 5                    # visible cards: centre + two each side
const SPINS := 2                    # full cycles before the reel lands
const TICK_FAST := 0.045
const TICK_SLOW := 0.26
const CARD_W := 300.0
const CARD_H := 132.0

# id -> {title, accent}. Mirrors each game's own IntroCard name/accent.
const CATALOG := {
	"echo": {"title": "ECHO CHAMBER", "accent": Color(1.0, 0.80, 0.35)},
	"tilt": {"title": "TILT", "accent": Color(1.0, 0.82, 0.30)},
	"orbital": {"title": "ORBITAL DODGEBALL", "accent": Color(0.50, 0.75, 1.0)},
	"mower": {"title": "MOWER MAYHEM", "accent": Color(0.42, 0.82, 0.34)},
	"greed": {"title": "GREED INC.", "accent": Color(1.0, 0.82, 0.20)},
	"swap": {"title": "SWAP MEET", "accent": Color(1.0, 0.85, 0.30)},
	"deadweight": {"title": "DEAD WEIGHT", "accent": Color(0.62, 0.78, 0.95)},
	"throne": {"title": "THE THRONE", "accent": Color(0.90, 0.75, 0.30)},
	"lastwill": {"title": "LAST WILL", "accent": Color(0.72, 0.55, 0.95)},
}

var finished := false               # capture-mode poll flag
var _slots: Array = []              # the SLOTS card panels, left->right
var _slot_titles: Array = []        # their Label children
var _reel: HBoxContainer
var _splash: Label

func setup(host: Control) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	host.add_child(self)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.04, 0.035, 0.06, 0.78)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	_reel = HBoxContainer.new()
	_reel.alignment = BoxContainer.ALIGNMENT_CENTER
	_reel.add_theme_constant_override("separation", 18)
	_reel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reel.offset_left = -(CARD_W * SLOTS) * 0.5; _reel.offset_right = (CARD_W * SLOTS) * 0.5
	_reel.offset_top = -CARD_H * 0.5 - 20.0; _reel.offset_bottom = CARD_H * 0.5 - 20.0
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reel)
	for i in SLOTS:
		var card := _make_card()
		_reel.add_child(card)
		_slots.append(card)
		_slot_titles.append(card.get_child(0))
	_splash = Label.new()
	_splash.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash.offset_top = 96; _splash.offset_bottom = 176
	_splash.offset_left = -560; _splash.offset_right = 560
	_splash.add_theme_font_size_override("font_size", 54)
	_splash.add_theme_color_override("font_color", Color(0.96, 0.92, 0.8))
	_splash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_splash.add_theme_constant_override("outline_size", 10)
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.visible = false
	add_child(_splash)

## Spin the reel and land on `chosen_id`. Async; the caller awaits it. The result
## is the chosen game's IntroCard title/accent, centred and lit.
func present(pool: Array, chosen_id: String) -> void:
	var ids: Array[String] = []
	for p in pool:
		ids.append(String(p))
	var n := maxi(1, ids.size())
	var chosen := ids.find(chosen_id)
	if chosen < 0:
		chosen = 0
	# Land so the CENTRE slot shows `chosen`: base advances each tick from 0.
	var total := SPINS * n + ((chosen % n) + n) % n
	finished = false
	visible = true
	modulate.a = 0.0
	_splash.visible = false
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.18)
	for step in range(total + 1):
		_render(ids, step)
		Sfx.play("card", -16.0 + 6.0 * float(step) / float(total + 1))
		var frac := float(step) / float(total + 1)
		await get_tree().create_timer(lerpf(TICK_FAST, TICK_SLOW, _ease(frac))).timeout
	# Landed on the chosen game.
	Sfx.play("sink", -3.0)
	_pulse_center()
	_splash.text = "TAKE YOUR PLACES"
	_splash.visible = true
	_splash.modulate.a = 0.0
	var st := _splash.create_tween()
	st.tween_property(_splash, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(1.1).timeout
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.25)
	await out.finished
	visible = false
	finished = true

## Render the reel for a given base index: centre slot = pool[base], neighbours
## the adjacent games, so the strip reads as a moving reel.
func _render(ids: Array, base: int) -> void:
	var n := ids.size()
	for k in range(SLOTS):
		var offset := k - int(SLOTS / 2)
		var idx := ((base + offset) % n + n) % n
		var info: Dictionary = CATALOG.get(ids[idx], {"title": ids[idx].to_upper(), "accent": Color(0.7, 0.7, 0.75)})
		var card: PanelContainer = _slots[k]
		var lbl: Label = _slot_titles[k]
		var accent: Color = info["accent"]
		lbl.text = String(info["title"])
		var centre := offset == 0
		lbl.add_theme_color_override("font_color", Color.WHITE if centre else accent.lerp(Color(0.5, 0.5, 0.55), 0.4))
		lbl.add_theme_font_size_override("font_size", 30 if centre else 20)
		var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = accent
			sb.set_border_width_all(4 if centre else 2)
			sb.bg_color = accent.darkened(0.55) if centre else Color(0.09, 0.085, 0.11, 0.9)
		card.modulate.a = 1.0 if centre else 0.42
		card.scale = Vector2(1.0, 1.0) if centre else Vector2(0.8, 0.8)

func _pulse_center() -> void:
	var card: PanelContainer = _slots[int(SLOTS / 2)]
	card.pivot_offset = card.size * 0.5
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2(1.18, 1.18), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2)

func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.085, 0.11, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.6, 0.6, 0.65)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	card.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	card.add_child(lbl)
	return card

func _ease(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x   # ease-in on the interval => the reel slows toward the end
