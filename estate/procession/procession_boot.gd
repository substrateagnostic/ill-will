extends Node
## PROCESSION BOOT — the one autoload the board mode needs, and only because
## the project's main scene is estate.tscn (which this lane must NOT touch).
##
## On `--procession` it swaps the running scene to procession.tscn at the first
## idle frame, so a full board night boots straight from the CLI.
##
## CANONICAL RECEIPT COMMANDS (graph board, night 7 — docs/verify/VERIFY-BOARD.md):
##   godot --headless --path . -- --procession --seed=7 --turncap=12 --autoplay=bots
##   godot --headless --path . -- --procession --boardgraphtest
##
## --deedgoal/--preset are RETIRED with the Codicil (doc 28); --turncap=N is the
## night-length dial. Inert on every normal launch (no flag = no-op). At merge
## the estate PLAY menu enters the same scene without this flag; the autoload
## stays as the headless/verification entry point.

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
