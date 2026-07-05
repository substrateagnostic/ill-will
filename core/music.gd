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

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _live: AudioStreamPlayer = null
var _current_slot := ""

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
