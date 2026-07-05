extends Node
## COSMETICS — unlockable hats & accessories for the KayKit characters.
## Autoload-ready (director registers `Cosmetics="*res://core/cosmetics.gd"`;
## nothing here requires the autoload — the wardrobe probe instances it directly).
##
## Responsibilities:
##   * Registry of every cosmetic: slot, GLB path, normalized size, per-KayKit-head
##     offsets (the four heads share a skeleton, but hairstyles/hats differ).
##   * equip(character_root, id) / unequip(character_root, slot): finds the rig's
##     BoneAttachment3D ("head", "handslot_l", "handslot_r", "chest"), creates it
##     if the GLB ships without one (Rogue has no `head` attachment), instances
##     the GLB normalized via MeshyProp math, and hides the character's default
##     headwear (Barbarian_Hat / Knight_Helmet / Mage_Hat) while a head cosmetic
##     is worn — the cosmetic REPLACES the stock look, restored on unequip.
##   * Per-player persistence {player_index -> {slot -> cosmetic_id}} in
##     user://cosmetics.json (load on _ready, save on every change).
##
## Purely visual. Store/unlock UI is the director's pass (estate/ untouched).

const MeshyPropLib := preload("res://scripts/meshy_prop.gd")

const SAVE_PATH := "user://cosmetics.json"

## slot name -> BoneAttachment3D node name in the KayKit GLBs
const SLOT_ATTACHMENTS := {
	"head": "head",
	"hand_l": "handslot_l",
	"hand_r": "handslot_r",
	"chest": "chest",
}

## slot name -> skeleton bone name (used when the attachment node is missing)
const SLOT_BONES := {
	"head": "head",
	"hand_l": "handslot.l",
	"hand_r": "handslot.r",
	"chest": "chest",
}

## Default headwear meshes that a head cosmetic temporarily hides.
const DEFAULT_HEADWEAR := ["Barbarian_Hat", "Knight_Helmet", "Mage_Hat"]

## Registry. Sizing/offsets are in rig space (KayKit head bone sits at y=1.24,
## crown of the bare head ~+0.72 above the bone, heads ~1.09 units wide).
##   size      – target dimension after normalization (world units at rig scale 1)
##   size_mode – "height" (scale so AABB height == size) or
##               "width"  (scale so max horizontal extent == size; for brims/rings)
##   offset    – wrapper position relative to the bone attachment (wrapper's own
##               origin = base of the model, centered on x/z)
##   rot_deg   – model rotation (e.g. yaw to face forward)
##   hide_default_hat – replace the stock headwear look while worn
##   per_char  – optional {"barbarian"/"knight"/"mage"/"rogue": {overrides}}
##   price     – suggested store price {royalties, grudge} (director tunes)
const REGISTRY := {
	"party_cone": {
		"name": "Party Cone",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/party_cone.glb",
		"size": 1.05, "size_mode": "height",
		"offset": Vector3(0, 0.50, 0.02),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": true,
		"price": {"royalties": 120, "grudge": 0},
	},
	"flower_crown": {
		"name": "Flower Crown",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/flower_crown.glb",
		"size": 1.50, "size_mode": "width",
		"offset": Vector3(0, 0.26, 0.0),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": true,
		"price": {"royalties": 150, "grudge": 0},
	},
	"viking_helm": {
		"name": "Viking Helm",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/viking_helm.glb",
		"size": 1.55, "size_mode": "width",
		"offset": Vector3(0, 0.17, 0.0),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": true,
		"price": {"royalties": 200, "grudge": 25},
	},
	"chef_hat": {
		"name": "Chef's Toque",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/chef_hat.glb",
		"size": 1.0, "size_mode": "height", "xz_scale": 1.5,
		"offset": Vector3(0, 0.42, 0.0),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": true,
		"price": {"royalties": 140, "grudge": 0},
	},
	"halo": {
		"name": "Halo",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/halo.glb",
		"size": 0.90, "size_mode": "width",
		"offset": Vector3(0, 1.12, 0.0),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": false,
		# Meshy textured the ring harlequin; a gold emissive override sells it.
		"override_material": {
			"albedo": Color(1.0, 0.84, 0.25),
			"metallic": 0.7, "roughness": 0.3,
			"emission": Color(1.0, 0.8, 0.3), "emission_energy": 0.6,
		},
		"price": {"royalties": 300, "grudge": 0},
	},
	"jester_cap": {
		"name": "Jester Cap",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/jester_cap.glb",
		"size": 1.30, "size_mode": "width",
		"offset": Vector3(0, 0.33, 0.0),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": true,
		"price": {"royalties": 180, "grudge": 15},
	},
	"tophat_monocle": {
		"name": "Top Hat & Monocle",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/tophat_monocle.glb",
		"size": 0.85, "size_mode": "height",
		"offset": Vector3(0, 0.48, 0.0),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": true,
		"per_char": {"knight": {"offset": Vector3(0, 0.56, 0.0)}},
		"price": {"royalties": 250, "grudge": 40},
	},
	"propeller_beanie": {
		"name": "Propeller Beanie",
		"slot": "head",
		"path": "res://assets/models/meshy/cosmetics/propeller_beanie.glb",
		"size": 1.05, "size_mode": "width",
		"offset": Vector3(0, 0.31, -0.05),
		"rot_deg": Vector3.ZERO,
		"hide_default_hat": true,
		"price": {"royalties": 100, "grudge": 0},
	},
}

## player_index (int) -> {slot (String) -> cosmetic_id (String)}
var equipped: Dictionary = {}


func _ready() -> void:
	load_state()


# ---------------------------------------------------------------- registry --

static func ids() -> Array:
	var out := REGISTRY.keys()
	out.sort()
	return out


static func info(id: String) -> Dictionary:
	return REGISTRY.get(id, {})


# ------------------------------------------------------------------- equip --

## Attach cosmetic `id` to `character_root` (any node containing a KayKit rig).
## Replaces whatever cosmetic occupied the same slot. Returns the wrapper node
## (or null on failure).
static func equip(character_root: Node, id: String) -> Node3D:
	if not REGISTRY.has(id):
		push_warning("Cosmetics: unknown id '%s'" % id)
		return null
	var cfg: Dictionary = REGISTRY[id]
	var slot: String = cfg["slot"]
	var att := _find_or_create_attachment(character_root, slot)
	if att == null:
		push_warning("Cosmetics: no rig/attachment for slot '%s' under %s" % [slot, character_root.name])
		return null
	unequip(character_root, slot)

	# per-character overrides
	var ck := character_key(character_root)
	var size: float = cfg.get("size", 0.8)
	var size_mode: String = cfg.get("size_mode", "height")
	var offset: Vector3 = cfg.get("offset", Vector3.ZERO)
	var rot: Vector3 = cfg.get("rot_deg", Vector3.ZERO)
	var xz_scale: float = cfg.get("xz_scale", 1.0)
	var pc: Dictionary = cfg.get("per_char", {}).get(ck, {})
	size = pc.get("size", size)
	offset = pc.get("offset", offset)
	rot = pc.get("rot_deg", rot)
	xz_scale = pc.get("xz_scale", xz_scale)

	var wrap := _instance_normalized(cfg["path"], size, size_mode, xz_scale)
	if wrap == null:
		return null
	wrap.name = "Cosmetic_" + slot
	wrap.set_meta("cosmetic_id", id)
	wrap.position = offset
	wrap.rotation_degrees = rot
	if cfg.has("override_material"):
		_apply_override_material(wrap, cfg["override_material"])
	att.add_child(wrap)

	if slot == "head" and cfg.get("hide_default_hat", true):
		for m in _headwear_meshes(character_root):
			m.visible = false
	return wrap


## Remove the cosmetic in `slot` (if any) and restore hidden default headwear.
static func unequip(character_root: Node, slot: String) -> void:
	var att := _find_attachment(character_root, slot)
	if att == null:
		return
	var existing := att.get_node_or_null("Cosmetic_" + slot)
	if existing:
		att.remove_child(existing)
		existing.queue_free()
	if slot == "head":
		for m in _headwear_meshes(character_root):
			m.visible = true


## Which cosmetic id is currently worn in `slot` on this rig ("" if none).
static func worn_id(character_root: Node, slot: String) -> String:
	var att := _find_attachment(character_root, slot)
	if att == null:
		return ""
	var c := att.get_node_or_null("Cosmetic_" + slot)
	return String(c.get_meta("cosmetic_id", "")) if c else ""


# ------------------------------------------------------- player persistence --

## Equip everything player `player_index` owns onto `character_root`.
func apply_to_character(character_root: Node, player_index: int) -> void:
	var loadout := get_player_cosmetics(player_index)
	for slot in loadout:
		equip(character_root, loadout[slot])


func get_player_cosmetics(player_index: int) -> Dictionary:
	return (equipped.get(player_index, {}) as Dictionary).duplicate()


## Persist `id` as equipped for the player (slot comes from the registry).
func set_player_cosmetic(player_index: int, id: String) -> void:
	if not REGISTRY.has(id):
		push_warning("Cosmetics: unknown id '%s'" % id)
		return
	var slot: String = REGISTRY[id]["slot"]
	var d: Dictionary = equipped.get(player_index, {})
	d[slot] = id
	equipped[player_index] = d
	save_state()


func remove_player_cosmetic(player_index: int, slot: String) -> void:
	if equipped.has(player_index):
		(equipped[player_index] as Dictionary).erase(slot)
		if (equipped[player_index] as Dictionary).is_empty():
			equipped.erase(player_index)
	save_state()


func save_state() -> void:
	var players := {}
	for idx in equipped:
		players[str(idx)] = equipped[idx]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cosmetics: cannot write " + SAVE_PATH)
		return
	f.store_string(JSON.stringify({"version": 1, "players": players}, "\t"))
	f.close()


func load_state() -> void:
	equipped = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	var players: Dictionary = data.get("players", {})
	for key in players:
		var loadout: Dictionary = players[key]
		var clean := {}
		for slot in loadout:
			if REGISTRY.has(loadout[slot]):
				clean[slot] = loadout[slot]
		if not clean.is_empty():
			equipped[int(key)] = clean


# ------------------------------------------------------------------ helpers --

## "barbarian" / "knight" / "mage" / "rogue" (from mesh names; "" if not KayKit).
static func character_key(character_root: Node) -> String:
	var skel := _find_skeleton(character_root)
	var probe := skel if skel else character_root
	for key in ["barbarian", "knight", "mage", "rogue"]:
		if _has_mesh_with_prefix(probe, key):
			return key
	return ""


static func _has_mesh_with_prefix(node: Node, prefix: String) -> bool:
	if node is MeshInstance3D and node.name.to_lower().begins_with(prefix):
		return true
	for c in node.get_children():
		if _has_mesh_with_prefix(c, prefix):
			return true
	return false


static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for c in root.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null


static func _find_attachment(character_root: Node, slot: String) -> BoneAttachment3D:
	var att_name: String = SLOT_ATTACHMENTS.get(slot, slot)
	var skel := _find_skeleton(character_root)
	if skel == null:
		return null
	return skel.get_node_or_null(att_name) as BoneAttachment3D


static func _find_or_create_attachment(character_root: Node, slot: String) -> BoneAttachment3D:
	var att := _find_attachment(character_root, slot)
	if att:
		return att
	# Rogue ships without a `head` BoneAttachment3D — create one on the bone.
	var skel := _find_skeleton(character_root)
	if skel == null:
		return null
	var bone: String = SLOT_BONES.get(slot, slot)
	if skel.find_bone(bone) < 0:
		return null
	att = BoneAttachment3D.new()
	att.name = SLOT_ATTACHMENTS.get(slot, slot)
	skel.add_child(att)
	att.bone_name = bone
	return att


static func _apply_override_material(root: Node, spec: Dictionary) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = spec.get("albedo", Color.WHITE)
	mat.metallic = spec.get("metallic", 0.0)
	mat.roughness = spec.get("roughness", 0.7)
	if spec.has("emission"):
		mat.emission_enabled = true
		mat.emission = spec["emission"]
		mat.emission_energy_multiplier = spec.get("emission_energy", 1.0)
	_override_meshes(root, mat)


static func _override_meshes(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_override_meshes(c, mat)


static func _headwear_meshes(character_root: Node) -> Array:
	var out: Array = []
	var skel := _find_skeleton(character_root)
	if skel == null:
		return out
	var att := skel.get_node_or_null("head")
	if att == null:
		return out
	for c in att.get_children():
		if c is MeshInstance3D and c.name in DEFAULT_HEADWEAR:
			out.append(c)
	return out


## Like MeshyProp.instance(), but the normalization dimension is selectable:
## "height" scales the AABB's y to `size`; "width" scales max(x,z) to `size`
## (rings, brims, crowns care about diameter, not height). `xz_scale` widens
## the model horizontally after normalization (Meshy sometimes returns hats
## much slimmer than the chunky KayKit heads). Base ends at y=0, centered on
## x/z, so `offset` in the registry is the seat point on the head.
static func _instance_normalized(path: String, size: float, size_mode: String,
		xz_scale := 1.0) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = "MeshyProp"
	if not ResourceLoader.exists(path):
		push_warning("Cosmetics: missing asset %s" % path)
		return wrap
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("Cosmetics: failed to load %s" % path)
		return wrap
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	wrap.add_child(model)
	var aabb: AABB = MeshyPropLib.merged_aabb(model)
	var dim := aabb.size.y if size_mode == "height" else maxf(aabb.size.x, aabb.size.z)
	if dim > 0.0001 and size > 0.0:
		var s := size / dim
		model.scale = Vector3(s * xz_scale, s, s * xz_scale)
		var scaled: AABB = MeshyPropLib.merged_aabb_of_scaled(model)
		var off := model.position
		off.x -= scaled.position.x + scaled.size.x * 0.5
		off.z -= scaled.position.z + scaled.size.z * 0.5
		off.y -= scaled.position.y
		model.position = off
	return wrap
