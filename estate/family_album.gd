class_name FamilyAlbumWall
extends Node3D
## THE FAMILY ALBUM — THE ESTATE'S MEMORY, part 3.
##
## After each newsreel, its stills are archived to disk. On the grounds they
## hang as framed photographs in a salon wall: ornate dark frames, a brass
## caption plate under each, hung with the slight careless tilt of a house that
## has been collecting portraits for longer than anyone remembers. The newest
## ten hang; the rest are kept on disk behind a plaque that counts the nights.
##
## This one class carries both the wall (a Node3D you can instance anywhere) and
## the archive library (static). The estate wires:
##   FamilyAlbumWall.archive(MomentScribe.night_moments(), EstateState.current_slot)
## after the newsreel, and instances a wall on the grounds:
##   var wall := FamilyAlbumWall.new(); wall.slot = EstateState.current_slot
##
## Archiving copies PNGs into user://saves/album/slot_N/ and appends to
## album.json. It NEVER writes outside the album dir — the owner's saves are
## sacred.

const ALBUM_ROOT := "user://saves/album"
const SHOWN := 10                 # newest N hang on the wall
const COLS := 5
const FRAME_W := 1.55
const FRAME_H := 0.9
const GAP_X := 0.55
const GAP_Y := 0.95

@export var slot := 1
## Optional in-memory override for verification: an Array of
## { tex: Texture2D, caption, night, game }. When set, the wall renders these
## instead of reading from disk.
var photos_override: Array = []
var total_count := 0

# -------------------------------------------------------------- archive library

static func album_dir(slot_n: int) -> String:
	return "%s/slot_%d" % [ALBUM_ROOT, slot_n]

static func album_json(slot_n: int) -> String:
	return "%s/album.json" % album_dir(slot_n)

## Copy each captured still into the slot's album dir and append its entry.
## Additive only: nothing outside the album dir is touched.
static func archive(moments: Array, slot_n: int) -> int:
	var dir := album_dir(slot_n)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var records := entries(slot_n)
	var added := 0
	for m in moments:
		if not (m is Dictionary):
			continue
		var src := ""
		if m.has("abs"):
			src = String(m.abs)
		elif m.has("file"):
			src = ProjectSettings.globalize_path(String(m.file))
		if src == "" or not FileAccess.file_exists(src):
			continue
		var night := int(m.get("night", 0))
		var id := int(m.get("id", records.size() + added))
		var fname := "album_n%03d_%03d.png" % [night, id]
		var dst := ProjectSettings.globalize_path("%s/%s" % [dir, fname])
		if not FileAccess.file_exists(dst):
			DirAccess.copy_absolute(src, dst)
		records.append({
			"file": fname,
			"caption": String(m.get("caption", "A MOMENT")),
			"night": night,
			"game": String(m.get("game", "")),
			"players": m.get("players", []),
		})
		added += 1
	_write_entries(slot_n, records)
	print("ALBUM_ARCHIVE slot=%d added=%d total=%d" % [slot_n, added, records.size()])
	return added

static func entries(slot_n: int) -> Array:
	var p := ProjectSettings.globalize_path(album_json(slot_n))
	if not FileAccess.file_exists(p):
		return []
	var data = JSON.parse_string(FileAccess.open(p, FileAccess.READ).get_as_text())
	if data is Dictionary and data.has("photos"):
		return data.photos
	return []

static func _write_entries(slot_n: int, records: Array) -> void:
	var f := FileAccess.open(album_json(slot_n), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"photos": records}, "  "))

# -------------------------------------------------------------- the wall

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var items := _gather()
	total_count = photos_override.size() if not photos_override.is_empty() else entries(slot).size()
	var shown := items.slice(maxi(0, items.size() - SHOWN))
	# Newest first, left-to-right, top row is the most recent.
	shown.reverse()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xA1B2 + slot
	var n := shown.size()
	for i in n:
		var col := i % COLS
		var row := i / COLS
		var cols_here: int = mini(COLS, n - row * COLS)
		var x := (col - (cols_here - 1) * 0.5) * (FRAME_W + GAP_X)
		var y := 2.6 - row * (FRAME_H + GAP_Y)
		_hang(shown[i], Vector3(x, y, 0.0), rng)
	if total_count > n:
		_plaque("...and %d more %s remembered" % [total_count - n,
			"night" if total_count - n == 1 else "nights"], Vector3(0, 2.6 - float((n - 1) / COLS + 1) * (FRAME_H + GAP_Y) - 0.2, 0))

## Resolve the render list to { tex, caption, night, game }.
func _gather() -> Array:
	if not photos_override.is_empty():
		return photos_override.duplicate()
	var out: Array = []
	var dir := album_dir(slot)
	for e in entries(slot):
		var abs := ProjectSettings.globalize_path("%s/%s" % [dir, String(e.get("file", ""))])
		if not FileAccess.file_exists(abs):
			continue
		var img := Image.load_from_file(abs)
		if img == null:
			continue
		out.append({
			"tex": ImageTexture.create_from_image(img),
			"caption": String(e.get("caption", "")),
			"night": int(e.get("night", 0)),
			"game": String(e.get("game", "")),
		})
	return out

func _hang(item: Dictionary, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var frame := Node3D.new()
	add_child(frame)
	frame.position = pos
	# The careless tilt of a long-hung portrait.
	frame.rotation.z = rng.randf_range(-0.045, 0.045)
	frame.rotation.y = rng.randf_range(-0.03, 0.03)

	# Ornate frame, built back-to-front so the photo is never occluded:
	#   molding (dark wood, deepest) < gilt liner (recessed) < photo (frontmost).
	var molding := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(FRAME_W + 0.24, FRAME_H + 0.24, 0.12)
	molding.mesh = mm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.12, 0.09, 0.07)
	wood.metallic = 0.25
	wood.roughness = 0.55
	molding.material_override = wood
	molding.position.z = -0.10
	frame.add_child(molding)

	var liner := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(FRAME_W + 0.10, FRAME_H + 0.10, 0.08)
	liner.mesh = lm
	var gilt := StandardMaterial3D.new()
	gilt.albedo_color = Color(0.45, 0.34, 0.14)
	gilt.metallic = 0.8
	gilt.roughness = 0.35
	liner.material_override = gilt
	liner.position.z = -0.05      # front face at z = -0.01
	frame.add_child(liner)

	# The photograph itself, unshaded so it always reads on a dim wall, sitting
	# proud of the liner's front face so nothing covers it.
	var photo := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(FRAME_W, FRAME_H)
	photo.mesh = qm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_texture = item.get("tex")
	pmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	# A faint aged wash so the photos sit into the salon rather than pop.
	pmat.albedo_color = Color(0.93, 0.88, 0.8)
	photo.material_override = pmat
	photo.position.z = 0.03
	frame.add_child(photo)

	# Brass caption plate.
	var plate := MeshInstance3D.new()
	var pl := BoxMesh.new()
	pl.size = Vector3(FRAME_W * 0.7, 0.16, 0.03)
	plate.mesh = pl
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.6, 0.47, 0.2)
	brass.metallic = 0.9
	brass.roughness = 0.3
	plate.material_override = brass
	plate.position = Vector3(0, -FRAME_H * 0.5 - 0.16, 0.02)
	frame.add_child(plate)

	var cap := Label3D.new()
	cap.text = _plate_text(item)
	cap.font_size = 44
	cap.pixel_size = 0.0022
	cap.modulate = Color(0.08, 0.06, 0.03)
	cap.outline_size = 0
	cap.position = plate.position + Vector3(0, 0, 0.02)
	frame.add_child(cap)

func _plate_text(item: Dictionary) -> String:
	var cap := String(item.get("caption", "")).capitalize()
	var night := int(item.get("night", 0))
	return "%s  ·  Night %d" % [cap, night + 1]

func _plaque(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.003
	l.modulate = Color(0.78, 0.73, 0.62)
	l.outline_size = 6
	l.position = pos
	add_child(l)

# -------------------------------------------------------------- verify helper

## Build a wall from synthetic in-memory photos (no disk), for --album-test.
static func test_wall(count: int) -> FamilyAlbumWall:
	var w := FamilyAlbumWall.new()
	var synth: Array = []
	var caps := ["THE DECIDING MOMENT", "THE VICTOR", "THE BETRAYAL",
		"THE LAST STAND", "THE RECKONING", "THE COLLAPSE", "THE HEIST",
		"THE OATH", "THE FALL", "THE CROWNING", "THE VENDETTA", "THE RUIN"]
	var games := ["echo_chamber", "throne", "greed", "dead_weight", "last_will",
		"tilt", "swap_meet", "orbital", "mower", "seance", "masked_ball", "understudy",
		"pallbearers"]  # B7-HOOK
	for i in count:
		synth.append({
			"tex": Newsreel._synthetic_still(i, count),
			"caption": caps[i % caps.size()],
			"night": i,
			"game": games[i % games.size()],
		})
	w.photos_override = synth
	return w
