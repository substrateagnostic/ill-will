extends Node
## PROCESSION BOOT — the one autoload the board mode needs, and only because
## the project's main scene is estate.tscn (which this lane must NOT touch).
##
## On `--procession` it swaps the running scene to procession.tscn at the first
## idle frame, so a full board night boots straight from the CLI:
##
##   godot --path . -- --procession --seed=7 --autoplay=all-bots --deedgoal=4
##
## Inert on every normal launch (no flag = no-op). At merge the estate PLAY menu
## can enter the same scene without this flag (see doc 19); the autoload stays
## as the headless/verification entry point.

const PROCESSION_SCENE := "res://estate/procession/procession.tscn"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--procession":
			# Defer so the main scene finishes instancing first; change_scene
			# then frees it cleanly and raises the board in its place.
			call_deferred("_enter")
			return

func _enter() -> void:
	get_tree().change_scene_to_file(PROCESSION_SCENE)
	print("PROCESSION_BOOT swapped main scene -> ", PROCESSION_SCENE)
