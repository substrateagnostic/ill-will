extends Node3D
## Deliverable-3 probe: does the anthology's font render the never-color-alone
## glyphs ● ▲ ■ ◆ in a Label3D, or do they come out as tofu boxes? Builds one
## row per font (Fredoka = project default, LuckiestGuy = the racing/pawn tag
## font) plus a "real usage" row that mimics an actual name tag. Run windowed
## with VerifyCapture: godot --path . res://docs/verify/label3d_probe.tscn --
## --shots=20 --outdir=badge_probe

const SHAPES := "●  ▲  ■  ◆"
const TAGROW := "● RED   ▲ BLUE   ■ GOLD   ◆ MINT"

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.13, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 7.5)
	add_child(cam)
	cam.current = true

	var fredoka: Font = load("res://assets/fonts/Fredoka.ttf")
	var lucky: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")

	# Header + shapes row for each font.
	_label("DEFAULT FONT = Fredoka (used by pawn name tags):", fredoka, 40, Vector3(0, 3.1, 0), Color(0.8, 0.82, 0.9))
	_label(SHAPES, fredoka, 150, Vector3(0, 2.1, 0), Color(1, 1, 1))
	_label("LuckiestGuy (used by kart / orbital tags):", lucky, 40, Vector3(0, 0.7, 0), Color(0.8, 0.82, 0.9))
	_label(SHAPES, lucky, 150, Vector3(0, -0.3, 0), Color(1, 1, 1))
	# Real-usage mimic: a colored name tag with a shape prefix, Fredoka.
	_label("Name-tag mimic (Fredoka):", fredoka, 40, Vector3(0, -1.9, 0), Color(0.8, 0.82, 0.9))
	_label(TAGROW, fredoka, 90, Vector3(0, -2.9, 0), Color(0.95, 0.85, 0.4))

func _label(text: String, font: Font, fsize: int, pos: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	if font != null:
		l.font = font
	l.font_size = fsize
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 8
	l.outline_modulate = Color(0.04, 0.04, 0.07)
	l.position = pos
	add_child(l)
