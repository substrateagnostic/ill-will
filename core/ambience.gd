extends Node
## Ambience bed player (Night-4 AAA SFX pass). Looping environmental beds — wind
## over the grounds, parlor room tone, night crickets — kept OUT of the one-shot
## Sfx bank because they loop and crossfade. Delivered as an inert singleton so
## game lanes can adopt it later; nothing calls it tonight.
##
##   Ambience.play_bed("amb_wind_grounds")      # crossfade in a bed
##   Ambience.play_bed("amb_room_parlor", 2.0, -18.0)
##   Ambience.stop()                             # fade the current bed out
##
## Beds are 44.1 kHz mono WAVs baked by tools/sfx_process.ps1. They are looped by
## setting LOOP_FORWARD on a duplicated stream at load time.

const BEDS := {
	"amb_wind_grounds": "res://assets/audio/amb_wind_grounds.wav",
	"amb_room_parlor": "res://assets/audio/amb_room_parlor.wav",
	"amb_night_crickets": "res://assets/audio/amb_night_crickets.wav",
}

const DEFAULT_DB := -20.0    # beds sit well under gameplay SFX
const SILENT_DB := -60.0

var _players: Array = []      # two players for A/B crossfade
var _active := -1             # index of the currently-fading-in player, or -1
var _current_key := ""
var _tween: Tween = null

func _ready() -> void:
	_ensure_bus("Ambience")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)

## Crossfade to bed `key`. No-op if it is already the active bed.
func play_bed(key: String, fade := 1.5, volume_db := DEFAULT_DB) -> void:
	if not BEDS.has(key):
		push_warning("Ambience: unknown bed '%s'" % key)
		return
	if key == _current_key and _active >= 0 and _players[_active].playing:
		return
	var incoming := 1 - _active if _active >= 0 else 0
	var outgoing := _active
	var stream := _make_looping(BEDS[key])
	if stream == null:
		return
	var pin: AudioStreamPlayer = _players[incoming]
	pin.stream = stream
	pin.volume_db = SILENT_DB
	pin.play()
	_active = incoming
	_current_key = key
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(pin, "volume_db", volume_db, fade)
	if outgoing >= 0:
		var pout: AudioStreamPlayer = _players[outgoing]
		_tween.tween_property(pout, "volume_db", SILENT_DB, fade)
		_tween.chain().tween_callback(pout.stop)

## Fade the current bed out and stop it.
func stop(fade := 1.5) -> void:
	if _active < 0:
		return
	var pout: AudioStreamPlayer = _players[_active]
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(pout, "volume_db", SILENT_DB, fade)
	_tween.tween_callback(pout.stop)
	_active = -1
	_current_key = ""

func is_playing() -> bool:
	return _active >= 0 and _players[_active].playing

func current_bed() -> String:
	return _current_key

func _make_looping(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("Ambience: missing bed file '%s'" % path)
		return null
	var base := load(path)
	if base == null:
		return null
	var stream: AudioStream = base.duplicate()
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / _bytes_per_frame(w)
	return stream

func _bytes_per_frame(w: AudioStreamWAV) -> int:
	var bytes := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
	if w.stereo:
		bytes *= 2
	return max(bytes, 1)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
