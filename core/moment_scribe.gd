extends Node
## MomentScribe (autoload) — THE ESTATE'S MEMORY, part 1: the night's camera.
##
## Memory made visible is this project's thesis, and a party you cannot
## remember was not a party. MomentScribe watches the anthology's dramatic
## peaks and quietly takes a picture — the deciding-moment freeze, the victor's
## reveal — so the estate can play them back as a silent-film newsreel before
## the will is read, then hang the best in the Family Album.
##
## Capture is PRESENTATION ONLY. It reads the viewport and writes a PNG to its
## OWN directory (user://saves/moments/<session>/). It touches no rng stream,
## no sim state, and prints nothing in the hot path, so a headless receipt run
## is byte-identical whether the scribe is watching or not. In fact a headless
## run never captures at all — there is no frame to grab (see _capture_async).
##
## API:
##   MomentScribe.capture(tag, caption, priority, players := [], game := "")
##       Grab the current frame, async, throttled. priority: 3 = deciding
##       moment, 2 = victor, 1 = colour. The best ~8 of the night survive.
##   MomentScribe.note_game(id) / clear_game()   — the estate tells the scribe
##       which minigame is on screen (wired in doc 20; a scene-scan fallback
##       keeps standalone captures labelled without it).
##   MomentScribe.night_moments() -> Array        — best-first, for the newsreel.
##   MomentScribe.clear_night()                   — after archiving: fresh reel.
##
## The owner's save files are sacred. The scribe writes and prunes ONLY inside
## user://saves/moments/ and never touches a slot save.

const ROOT_DIR := "user://saves/moments"
const MIN_GAP_MS := 6000        # min real-time between captures (spec throttle)
const KEEP_PER_NIGHT := 8       # best-N survive; ranked priority, then recency

## The deciding-moment default caption when a game passes no context string.
const DEFAULT_DECIDING := "THE DECIDING MOMENT"

var enabled := true
var log_captures := false        # --moment-log turns on receipts for verify

var _session := ""               # sortable id for this night's subfolder
var _dir := ""                   # user://saves/moments/<session>
var _moments: Array = []         # kept buffer (<= KEEP_PER_NIGHT)
var _seq := 0                    # monotonic capture counter (filenames + ties)
var _last_ms := -100000          # last capture wall-clock (throttle)
var _manual_game := ""           # set by note_game(); overrides the scene scan
var _headless := false
var _boot_test := ""             # "newsreel" | "album" (verify boots)

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	for arg in OS.get_cmdline_user_args():
		if arg == "--moment-log":
			log_captures = true
		elif arg == "--no-moments":
			enabled = false
		elif arg == "--newsreel-test":
			_boot_test = "newsreel"
		elif arg == "--album-test":
			_boot_test = "album"
		elif arg == "--chronicle-test":
			_boot_test = "chronicle"
	_new_session()
	if _boot_test != "":
		# Defer past autoload init so the SceneTree/root are live, then overlay
		# the requested verify harness on top of whatever booted.
		_run_boot_test.call_deferred()

## Self-contained verify boots (see estate/newsreel.gd, estate/family_album.gd).
func _run_boot_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _boot_test == "newsreel":
		Newsreel.test_run()
	elif _boot_test == "album":
		_run_album_test()
	elif _boot_test == "chronicle":
		_run_chronicle_test()

## Build a synthetic multi-night history straight into EstateState, rebuild the
## chronicle from it, and dump sample Executor observations. Verify only.
func _run_chronicle_test() -> void:
	var es := get_node_or_null(^"/root/EstateState")
	if es == null:
		get_tree().quit()
		return
	# Five nights of recorded conduct, in the shape end_night() writes.
	es.ledger = [
		{"night": 0, "winner": "GOLD", "awards": [
			{"who": "BLUE", "title": "THE SNAKE", "line": ""},
			{"who": "MINT", "title": "THE DOORMAT", "line": ""},
			{"who": "RED", "title": "NEMESIS OF BLUE", "line": ""}]},
		{"night": 1, "winner": "GOLD", "awards": [
			{"who": "BLUE", "title": "THE SNAKE", "line": ""},
			{"who": "MINT", "title": "THE DOORMAT", "line": ""},
			{"who": "RED", "title": "NEMESIS OF BLUE", "line": ""},
			{"who": "GOLD", "title": "THE HOARDER", "line": ""}]},
		{"night": 2, "winner": "MINT", "awards": [
			{"who": "MINT", "title": "THE ARCHITECT", "line": ""},
			{"who": "RED", "title": "NEMESIS OF BLUE", "line": ""},
			{"who": "GOLD", "title": "THE HOARDER", "line": ""}]},
		{"night": 3, "winner": "GOLD", "awards": [
			{"who": "BLUE", "title": "THE SNAKE", "line": ""},
			{"who": "MINT", "title": "THE LANDLORD", "line": ""},
			{"who": "RED", "title": "THE WORKHORSE", "line": ""},
			{"who": "RED", "title": "NEMESIS OF BLUE", "line": ""}]},
		{"night": 4, "winner": "GOLD", "awards": [
			{"who": "RED", "title": "THE RECKONER", "line": ""},
			{"who": "MINT", "title": "THE DOORMAT", "line": ""}]},
	]
	es.monuments = [
		{"owner": "GOLD", "label": "GOLD — Champion of Night 1", "night": 0},
		{"owner": "GOLD", "label": "GOLD — Champion of Night 2", "night": 1},
		{"owner": "MINT", "label": "MINT — Champion of Night 3", "night": 2},
		{"owner": "MINT", "label": "the folly", "night": 2},
		{"owner": "MINT", "label": "the spite obelisk", "night": 3},
		{"owner": "MINT", "label": "the unkind cairn", "night": 3},
		{"owner": "GOLD", "label": "GOLD — Champion of Night 4", "night": 3},
		{"owner": "GOLD", "label": "GOLD — TOOK THE MANOR (run of 5 nights)", "night": 4},
	]
	# A future game-fed fact, to prove the events accumulator survives rebuild.
	es.chronicle = {"by_name": {"BLUE": {"events": {"quiet_betrayal": 2}}}}
	es._rebuild_chronicle()
	var lines: Array = es.chronicle_lines()
	print("CHRONICLE_LINES_DUMP total=%d" % lines.size())
	var n: int = mini(10, lines.size())
	for i in n:
		print("CHRON %02d | %s" % [i + 1, lines[i]])
	print("CHRONICLE_TEST done")
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

## A dedicated 3D salon: free whatever booted (this is a verify-only boot), then
## stand up a lit wall of synthetic framed photos, a camera, one screenshot, quit.
func _run_album_test() -> void:
	var cur := get_tree().current_scene
	if cur != null:
		cur.queue_free()
	await get_tree().process_frame

	var world := Node3D.new()
	get_tree().root.add_child(world)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.6)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	world.add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_energy = 1.3
	world.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 1.5, 6)
	fill.omni_range = 26.0
	fill.light_energy = 1.6
	world.add_child(fill)

	var wall := FamilyAlbumWall.test_wall(12)
	world.add_child(wall)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 7.8)
	cam.fov = 62.0
	world.add_child(cam)
	cam.current = true

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var out := "verify_out/estate_memory"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out))
		img.save_png("res://%s/album_wall.png" % out)
		print("ALBUM_TEST_SHOT res://%s/album_wall.png" % out)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _new_session() -> void:
	# A per-night subfolder keyed to wall-clock so nights never collide on disk.
	var t := Time.get_datetime_dict_from_system()
	_session = "n%03d_%04d%02d%02d_%02d%02d%02d" % [
		_estate_night(), t.year, t.month, t.day, t.hour, t.minute, t.second]
	_dir = "%s/%s" % [ROOT_DIR, _session]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))

func _estate_night() -> int:
	# EstateState is an autoload; guard for tool/standalone contexts anyway.
	var es := get_node_or_null(^"/root/EstateState")
	return int(es.nights_played) if es != null else 0

## ---------------------------------------------------------------- capture

## Grab the current frame as a still. Fire-and-forget: the caller (a static
## fov_punch, a podium beat) does not await. Synchronous work is only a
## real-time throttle check + a buffer reservation; the frame grab and the PNG
## encode happen after an await, off the hot path. A no-op under headless.
func capture(tag: String, caption: String, priority: int, players: Array = [], game: String = "") -> void:
	if not enabled or _headless:
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < MIN_GAP_MS:
		return
	_last_ms = now
	_seq += 1
	var id := _seq
	var g := game if game != "" else _infer_game()
	var fname := "m%03d_%s.png" % [id, _slug(tag)]
	var entry := {
		"id": id,
		"file": "%s/%s" % [_dir, fname],
		"game": g,
		"tag": tag,
		"caption": caption if caption != "" else DEFAULT_DECIDING,
		"priority": priority,
		"players": players.duplicate(),
		"night": _estate_night(),
		"ts": now,
	}
	_capture_async(entry)

func _capture_async(entry: Dictionary) -> void:
	# After the frame is on the GPU, pull it back and hand the encode to a
	# worker so PNG compression never hitches the frame we just froze.
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if vp == null:
		return
	var img := vp.get_texture().get_image()
	if img == null:
		return
	var abspath := ProjectSettings.globalize_path(String(entry.file))
	WorkerThreadPool.add_task(func() -> void: img.save_png(abspath))
	_admit(entry)
	if log_captures:
		print("MOMENT_CAPTURE id=%d pri=%d game=%s tag=%s night=%d file=%s" % [
			int(entry.id), int(entry.priority), entry.game, entry.tag,
			int(entry.night), entry.file])

## Admit a fresh capture and enforce the best-N cap: rank by priority, then
## recency; the loser is evicted and its PNG deleted (ONLY ever inside our own
## session dir). Then rewrite the manifest.
func _admit(entry: Dictionary) -> void:
	_moments.append(entry)
	if _moments.size() > KEEP_PER_NIGHT:
		# Worst = lowest priority, and among equals the oldest (smallest id).
		var worst := 0
		for i in range(1, _moments.size()):
			if _worse(_moments[i], _moments[worst]):
				worst = i
		var dropped: Dictionary = _moments[worst]
		_moments.remove_at(worst)
		_delete_own(String(dropped.file))
		if log_captures:
			print("MOMENT_EVICT id=%d pri=%d (best %d kept)" % [
				int(dropped.id), int(dropped.priority), KEEP_PER_NIGHT])
	_write_manifest()

## a ranks BELOW b (a is the more evictable of the two).
func _worse(a: Dictionary, b: Dictionary) -> bool:
	if int(a.priority) != int(b.priority):
		return int(a.priority) < int(b.priority)
	return int(a.id) < int(b.id)

## ---------------------------------------------------------------- queries

## The night's kept stills, best-first (priority desc, then most-recent).
## Paths are globalized so the newsreel/album can load them off-tree.
func night_moments() -> Array:
	var out := _moments.duplicate(true)
	out.sort_custom(func(a, b):
		if int(a.priority) != int(b.priority):
			return int(a.priority) > int(b.priority)
		return int(a.id) > int(b.id))
	for m in out:
		m["abs"] = ProjectSettings.globalize_path(String(m.file))
	return out

## Roll the reel: after the newsreel has played and the album has archived these
## stills, start a fresh session so the next night begins with a clean slate.
## Files already on disk are left in place (additive; the album owns copies).
func clear_night() -> void:
	_moments.clear()
	_seq = 0
	_last_ms = -100000
	_new_session()

func note_game(id: String) -> void:
	_manual_game = id

func clear_game() -> void:
	_manual_game = ""

## ---------------------------------------------------------------- internals

func _infer_game() -> String:
	if _manual_game != "":
		return _manual_game
	var tree := get_tree()
	if tree == null:
		return "estate"
	var cs := tree.current_scene
	if cs is Minigame and cs.scene_file_path != "":
		return _folder_of(cs.scene_file_path)
	# Module launched as a child of the estate (or added to root): shallow scan.
	for host in [cs, tree.root]:
		if host == null:
			continue
		for c in host.get_children():
			if c is Minigame and c.scene_file_path != "":
				return _folder_of(c.scene_file_path)
	return "estate"

func _folder_of(path: String) -> String:
	# res://minigames/echo_chamber/echo_chamber.tscn -> "echo_chamber"
	return path.get_base_dir().get_file()

func _slug(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "_" or ch == "-":
			out += "_"
	return out.substr(0, 24) if out != "" else "moment"

## Delete a file ONLY if it lives under our moments root — a hard guard so a
## bug can never reach into a slot save. The owner's saves are sacred.
func _delete_own(user_path: String) -> void:
	if not user_path.begins_with(ROOT_DIR):
		push_warning("MomentScribe refused to delete outside its dir: " + user_path)
		return
	var abs := ProjectSettings.globalize_path(user_path)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)

func _write_manifest() -> void:
	var f := FileAccess.open("%s/moments.json" % _dir, FileAccess.WRITE)
	if f == null:
		return
	var records: Array = []
	for m in _moments:
		records.append({
			"file": String(m.file).get_file(),
			"game": m.game, "tag": m.tag, "caption": m.caption,
			"priority": int(m.priority), "players": m.players,
			"night": int(m.night), "id": int(m.id),
		})
	f.store_string(JSON.stringify({"session": _session, "moments": records}, "  "))
