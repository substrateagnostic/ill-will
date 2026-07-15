class_name ProcessionPresets
extends RefCounted
## THE PROCESSION ships as one engine with four public dials.  QUICK WAKE
## removes the decision layer: minigame score is movement and the first pawn
## to complete two laps wins.  The other presets use the full Deed economy.

const QUICK_WAKE := "quick_wake"
const SHORT := "short"
const FULL := "full"
const VIGIL := "vigil"

const DATA := {
	QUICK_WAKE: {
		"label": "QUICK WAKE",
		"deed_goal": 0,
		"decision_layer": false,
		"movement_goal": 48,
		"description": "MINIGAME SCORE IS MOVEMENT · TWO LAPS TO THE MANOR",
	},
	SHORT: {
		"label": "SHORT PROCESSION",
		"deed_goal": 4,
		"decision_layer": true,
		"movement_goal": 0,
		"description": "FIRST CLAIM ENDS THE NIGHT AT FOUR DEEDS",
	},
	FULL: {
		"label": "FULL PROCESSION",
		"deed_goal": 6,
		"decision_layer": true,
		"movement_goal": 0,
		"description": "SIX DEEDS · THE ESTATE TAKES ITS TIME",
	},
	VIGIL: {
		"label": "LONG VIGIL",
		"deed_goal": 9,
		"decision_layer": true,
		"movement_goal": 0,
		"description": "NINE DEEDS · BRING PROVISIONS AND ALIBIS",
	},
}

static func get_preset(id: String) -> Dictionary:
	var key := id.to_lower().replace("-", "_")
	if key == "wake":
		key = QUICK_WAKE
	elif key == "procession":
		key = FULL
	elif key == "long":
		key = VIGIL
	if not DATA.has(key):
		key = SHORT
	return (DATA[key] as Dictionary).duplicate(true)

static func from_goal(goal: int) -> Dictionary:
	match goal:
		6: return get_preset(FULL)
		9: return get_preset(VIGIL)
		_: return get_preset(SHORT)
