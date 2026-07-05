extends Node
## Autoload Migrate (loads FIRST): one-time user:// migration.
## The project was renamed (Par for the Curse -> ILL WILL) and user:// is
## now pinned to app_userdata/illwill. Estate history, seat setup, and
## cosmetics from the old name's dir are copied over so nothing is lost —
## the monuments are the product.

func _ready() -> void:
	var new_dir := ProjectSettings.globalize_path("user://")
	var old_dir := new_dir.replace("ILL WILL", "Par for the Curse")
	if old_dir == new_dir or not DirAccess.dir_exists_absolute(old_dir):
		return
	DirAccess.make_dir_recursive_absolute(new_dir)
	for fname in ["estate_save.json", "party_setup.json", "cosmetics.json", "prefs.json"]:
		var src := old_dir.path_join(fname)
		var dst := new_dir.path_join(fname)
		if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
			DirAccess.copy_absolute(src, dst)
			print("MIGRATE copied ", fname)
