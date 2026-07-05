extends SceneTree
## Dev test: godot --headless --script res://scripts/dev/test_cosmetics.gd
## Exercises core/cosmetics.gd: equip/unequip/replace, Rogue head-attachment
## creation, default-headwear hiding/restoring, and save/load persistence.

const Cosmetics := preload("res://core/cosmetics.gd")

var fails := 0

func _init() -> void:
	_check_rogue_attachment_creation()
	_check_replace_and_unequip()
	_check_headwear_hiding()
	_check_persistence()
	print("COSMETICS_TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

func _t(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label)

func _spawn(path: String) -> Node3D:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	get_root().add_child(inst)
	return inst

func _check_rogue_attachment_creation() -> void:
	print("rogue head attachment:")
	var rogue := _spawn("res://assets/models/kaykit/Rogue.glb")
	var skel: Skeleton3D = rogue.find_child("Skeleton3D", true, false)
	_t(skel.get_node_or_null("head") == null, "Rogue ships without head attachment")
	var w := Cosmetics.equip(rogue, "party_cone")
	_t(w != null, "equip returns wrapper")
	_t(skel.get_node_or_null("head") is BoneAttachment3D, "head BoneAttachment3D created")
	_t(Cosmetics.worn_id(rogue, "head") == "party_cone", "worn_id reports party_cone")
	rogue.free()

func _check_replace_and_unequip() -> void:
	print("replace + unequip:")
	var knight := _spawn("res://assets/models/kaykit/Knight.glb")
	Cosmetics.equip(knight, "party_cone")
	Cosmetics.equip(knight, "viking_helm")
	var att: Node = knight.find_child("head", true, false)
	var count := 0
	for c in att.get_children():
		if String(c.name).begins_with("Cosmetic_"):
			count += 1
	_t(count == 1, "equipping twice keeps a single cosmetic in slot")
	_t(Cosmetics.worn_id(knight, "head") == "viking_helm", "second equip replaced first")
	Cosmetics.unequip(knight, "head")
	_t(Cosmetics.worn_id(knight, "head") == "", "unequip clears slot")
	knight.free()

func _check_headwear_hiding() -> void:
	print("default headwear hide/restore:")
	var mage := _spawn("res://assets/models/kaykit/Mage.glb")
	var hat: MeshInstance3D = mage.find_child("Mage_Hat", true, false)
	_t(hat.visible, "Mage hat visible before equip")
	Cosmetics.equip(mage, "tophat_monocle")
	_t(not hat.visible, "Mage hat hidden by tophat (hide_default_hat)")
	Cosmetics.unequip(mage, "head")
	_t(hat.visible, "Mage hat restored on unequip")
	Cosmetics.equip(mage, "halo")
	_t(hat.visible, "halo keeps Mage hat visible (hide_default_hat=false)")
	mage.free()

func _check_persistence() -> void:
	print("persistence (user://cosmetics.json):")
	if FileAccess.file_exists(Cosmetics.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Cosmetics.SAVE_PATH))
	# NOTE: _ready() doesn't fire synchronously inside SceneTree._init, so this
	# test calls load_state() explicitly; the in-game autoload gets it via _ready.
	var a: Node = Cosmetics.new()
	a.load_state()  # empty
	a.set_player_cosmetic(0, "halo")
	a.set_player_cosmetic(2, "jester_cap")
	a.set_player_cosmetic(2, "chef_hat")  # same slot, replaces
	var b: Node = Cosmetics.new()
	b.load_state()
	_t(b.get_player_cosmetics(0).get("head") == "halo", "player 0 loadout persisted")
	_t(b.get_player_cosmetics(2).get("head") == "chef_hat", "same-slot overwrite persisted")
	_t(b.get_player_cosmetics(1).is_empty(), "player 1 empty")
	b.remove_player_cosmetic(0, "head")
	var c: Node = Cosmetics.new()
	c.load_state()
	_t(c.get_player_cosmetics(0).is_empty(), "removal persisted")
	# apply_to_character round trip
	var barb := _spawn("res://assets/models/kaykit/Barbarian.glb")
	c.apply_to_character(barb, 2)
	_t(Cosmetics.worn_id(barb, "head") == "chef_hat", "apply_to_character equips saved loadout")
	barb.free()
	a.free(); b.free(); c.free()
