extends Node
## Autoload Music: soundtrack slots with crossfade, on the Music bus.
## Completely silent until files exist — drop .ogg files at the SLOTS
## paths (assets/music/) and the estate starts playing them, no code
## changes needed. Slot list agreed with Alex (he curates the tracks).

const SLOTS := {
	"lobby": "res://assets/music/lobby.ogg",
	"grounds": "res://assets/music/grounds.ogg",
	"auction": "res://assets/music/auction.ogg",
	"ceremony": "res://assets/music/ceremony.ogg",
	"game_light": "res://assets/music/game_light.ogg",
	"game_tense": "res://assets/music/game_tense.ogg",
}
const FADE := 1.4

# R9 — THE FIRST DUCKING SCAFFOLD: a bus-level dip so a loud one-shot moment
# (the podium's match_win + bell_toll layering is the first caller) reads over
# the soundtrack instead of fighting it. DUCK_ATTACK/RELEASE are the dip/return
# ramps (fast enough to feel immediate, slow enough to never zipper-click);
# `hold` (the caller-facing duration) is the plateau between them.
const DUCK_ATTACK := 0.12
const DUCK_RELEASE := 0.6

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _live: AudioStreamPlayer = null
var _current_slot := ""

var _duck_tween: Tween = null
var _duck_active := false
var _duck_base_db := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.bus = "Music"
		add_child(p)

## Crossfade to a slot's track (loops). No-op if the slot is already
## playing or its file doesn't exist yet.
func play_slot(slot: String) -> void:
	if slot == _current_slot:
		return
	if not SLOTS.has(slot) or not ResourceLoader.exists(SLOTS[slot]):
		stop()
		_current_slot = slot
		return
	var stream: AudioStream = load(SLOTS[slot])
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var next: AudioStreamPlayer = _b if _live == _a else _a
	next.stream = stream
	next.volume_db = -40.0
	next.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(next, "volume_db", 0.0, FADE)
	if _live != null and _live.playing:
		var old := _live
		tw.tween_property(old, "volume_db", -40.0, FADE)
		tw.chain().tween_callback(old.stop)
	_live = next
	_current_slot = slot

func stop() -> void:
	if _live != null and _live.playing:
		var old := _live
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, FADE * 0.6)
		tw.tween_callback(old.stop)
	_live = null
	_current_slot = ""

## Dip the Music BUS (not the crossfader's per-player volume, so it never fights
## play_slot's own fade) by `db` for `hold` seconds, then ease smoothly back.
## `db` is a delta (negative = quieter, e.g. -6.0). Ducks relative to whatever
## the bus is ACTUALLY at — the player's own Music volume slider (party_setup.gd)
## is never clobbered by the recovery. Re-entrant: a duck fired while already
## ducked reuses the original baseline and just extends/restarts the hold+release,
## so back-to-back moments never compound into silence. Reusable — future VO can
## hang off this same helper.
func duck(db := -6.0, hold := 1.5) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx == -1:
		return
	if not _duck_active:
		_duck_base_db = AudioServer.get_bus_volume_db(idx)
		_duck_active = true
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var floor_db := _duck_base_db + db
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_bus_db.bind(idx), AudioServer.get_bus_volume_db(idx), floor_db, DUCK_ATTACK) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(_set_bus_db.bind(idx), floor_db, _duck_base_db, DUCK_RELEASE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_duck_tween.tween_callback(func() -> void: _duck_active = false)

func _set_bus_db(v: float, idx: int) -> void:
	AudioServer.set_bus_volume_db(idx, v)
