extends Node
## Autoloaded SFX bus. Sfx.play("putt") etc. Variants picked at random,
## slight pitch wobble so repeats never sound canned.

const BANK := {
	"putt": ["impactGeneric_light_000", "impactGeneric_light_001", "impactGeneric_light_002"],
	"bounce": ["impactPlate_light_000", "impactPlate_light_001", "impactPlate_light_002"],
	"bumper": ["impactBell_heavy_000", "impactBell_heavy_001"],
	"death": ["jingles_HIT01"],
	"crush": ["impactMining_000"],
	"splat": ["impactPunch_heavy_000"],
	"sink": ["jingles_NES03"],
	"round_over": ["jingles_NES09"],
	"match_win": ["jingles_NES13"],
	"card": ["click_001", "click_002", "click_003"],
	"place": ["drop_001"],
	"confirm": ["confirmation_001"],
	"invalid": ["error_004"],
	"grudge": ["bong_001"],
}

var _streams := {}
var _pool: Array = []
var _next := 0

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for key in BANK:
		var list: Array = []
		for name in BANK[key]:
			list.append(_load_sample(name))
		_streams[key] = list
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

## Prefer a declicked .wav (baked so the waveform starts AND ends at exactly
## zero — a non-zero edge is a step discontinuity = the button-click "pop" the
## r2 tester heard in the wardrobe and join-night menus) over the shipped .ogg.
## Only the one-shot UI samples have a .wav; everything else falls back to .ogg.
## See tools/declick_sfx.py for the exact fade/DC-removal that bakes the edges.
func _load_sample(sample: String) -> AudioStream:
	var wav := "res://assets/audio/%s.wav" % sample
	if ResourceLoader.exists(wav):
		return load(wav)
	return load("res://assets/audio/%s.ogg" % sample)

## Runtime bus creation so the AUDIO settings sliders have something to
## drive; Music bus sits empty until the soundtrack lands.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func play(key: String, volume_db := 0.0, pitch_wobble := 0.07) -> void:
	if not _streams.has(key):
		return
	var list: Array = _streams[key]
	# Prefer a voice that is NOT currently sounding — restarting a still-playing
	# voice hard-cuts its wave mid-cycle, itself a pop. Only when all ten are
	# busy do we steal round-robin (the oldest). Declicked samples already fade
	# in from zero, so the fresh voice starts clean either way.
	var p: AudioStreamPlayer = null
	for i in _pool.size():
		var cand: AudioStreamPlayer = _pool[i]
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = _pool[_next]
		_next = (_next + 1) % _pool.size()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_wobble, pitch_wobble)
	p.play()
