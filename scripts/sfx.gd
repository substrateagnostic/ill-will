extends Node
## Autoloaded SFX bus. Sfx.play("putt") etc. Variants picked at random,
## slight pitch wobble so repeats never sound canned.
##
## Night-4 AAA pass: the original 12 keys still exist and still resolve to the
## same base samples (games call them by name); several gained extra round-robin
## variants so common repeats stop sounding canned. ~30 new key families were
## added (impact tiers, whoosh, a full UI set, stingers, countdown tick, and a
## gothic layer: bells, raven, creak, thunder, chain, coffin thud, organ stab,
## projector). All new samples are declicked 44.1 kHz 16-bit WAVs baked by
## tools/sfx_process.ps1 (edges at exact zero — see _load_sample). Looping
## ambience beds live in core/ambience.gd, NOT here.

const BANK := {
	# ---- original keys (unchanged names; * = gained round-robin variants) ----
	"putt": ["impactGeneric_light_000", "impactGeneric_light_001", "impactGeneric_light_002"],
	"bounce": ["impactPlate_light_000", "impactPlate_light_001", "impactPlate_light_002"],
	"bumper": ["impactBell_heavy_000", "impactBell_heavy_001", "impactBell_heavy_002"], # *
	"death": ["jingles_HIT01", "jingles_HIT04"], # *
	"crush": ["impactMining_000", "impactMining_001", "impactMining_002"], # *
	"splat": ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002"], # *
	"sink": ["jingles_NES03"],
	"round_over": ["jingles_NES09"],
	"match_win": ["jingles_NES13"],
	"card": ["click_001", "click_002", "click_003"],
	"place": ["drop_001", "drop_002", "drop_003"], # *
	"confirm": ["confirmation_001", "confirmation_002", "confirmation_003"], # *
	"invalid": ["error_004", "error_005", "error_006"], # *
	"grudge": ["bong_001"],

	# ---- new: impact tiers (attack weight; sharp transients, razor onsets) ----
	"impact_light": ["impact_light_v1", "impact_light_v2", "impact_light_v3", "impact_light_v4"],
	"impact_heavy": ["impact_heavy_v1", "impact_heavy_v2", "impact_heavy_v3", "impact_heavy_v4"],
	"impact_wood": ["impact_wood_v1", "impact_wood_v2", "impact_wood_v3", "impact_wood_v4"],
	"impact_metal": ["impact_metal_v1", "impact_metal_v2", "impact_metal_v3", "impact_metal_v4"],

	# ---- new: whoosh ----
	"whoosh_small": ["whoosh_small_v1", "whoosh_small_v2", "whoosh_small_v3", "whoosh_small_v4"],
	"whoosh_big": ["whoosh_big_v1", "whoosh_big_v2", "whoosh_big_v3", "whoosh_big_v4"],

	# ---- new: UI family ----
	"ui_move": ["ui_move_v1", "ui_move_v2", "ui_move_v3"],
	"ui_confirm": ["ui_confirm_v1", "ui_confirm_v2", "ui_confirm_v3"],
	"ui_back": ["ui_back_v1", "ui_back_v2", "ui_back_v3"],
	"ui_error": ["ui_error_v1", "ui_error_v2", "ui_error_v3"],
	"ui_tab": ["ui_tab_v1", "ui_tab_v2", "ui_tab_v3"],

	# ---- new: stingers (abstract SFX cues, NOT melodies — see doc 21) ----
	"stinger_win": ["stinger_win_v1"],
	"stinger_lose": ["stinger_lose_v1"],
	"stinger_reveal": ["stinger_reveal_v1"],
	"stinger_dread": ["stinger_dread_v1"],

	# ---- new: countdown (pitchable — Sfx.play("tick_countdown", 0, 0, pitch)) ----
	"tick_countdown": ["tick_countdown_v1", "tick_countdown_v2", "tick_countdown_v3"],

	# ---- new: gothic layer ----
	"bell_toll": ["bell_toll_v1", "bell_toll_v2", "bell_toll_v3"],
	"bell_small": ["bell_small_v1", "bell_small_v2", "bell_small_v3"],
	"raven": ["raven_v1", "raven_v2"],
	"creak": ["creak_v1", "creak_v2", "creak_v3"],
	"thunder_far": ["thunder_far_v1", "thunder_far_v2", "thunder_far_v3"],
	"gust": ["gust_v1", "gust_v2"],
	"chain": ["chain_v1", "chain_v2", "chain_v3"],
	"thud_coffin": ["thud_coffin_v1", "thud_coffin_v2", "thud_coffin_v3"],
	"organ_stab": ["organ_stab_v1"], # PLACEHOLDER (dark gong) — see doc 21 morning call
	"projector": ["projector_v1", "projector_v2", "projector_v3"],
}

## Optional per-key default volume trims (dB), added on top of the caller's
## volume_db. Family peak-normalization already sets relative levels; these are
## small taste nudges for keys that tend to sit too forward. Tunable — a key not
## listed here defaults to 0.
const VOL := {
	"ui_move": -3.0,
	"ui_tab": -2.0,
	"tick_countdown": -1.0,
	"projector": -3.0,
	"raven": -1.0,
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
## The original UI one-shots and every Night-4 sample ship as .wav; a few legacy
## base samples are still .ogg and fall back cleanly.
## See tools/declick_sfx.py (legacy) and tools/sfx_process.ps1 (Night-4) for the
## exact fade/DC-removal that bakes the edges.
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

## Fixed-pitch variant of play() for callers that want a deterministic pitch
## (e.g. a countdown that ramps tick pitch up as the clock runs out). pitch_wobble
## is applied on top; pass 0.0 for an exact pitch.
func play_pitched(key: String, pitch := 1.0, volume_db := 0.0, pitch_wobble := 0.0) -> void:
	_emit(key, volume_db, pitch, pitch_wobble)

func play(key: String, volume_db := 0.0, pitch_wobble := 0.07) -> void:
	_emit(key, volume_db, 1.0, pitch_wobble)

func _emit(key: String, volume_db: float, pitch_base: float, pitch_wobble: float) -> void:
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
	p.volume_db = volume_db + float(VOL.get(key, 0.0))
	p.pitch_scale = pitch_base + randf_range(-pitch_wobble, pitch_wobble)
	p.play()
