extends Node
## Headless smoke test for the Night-4 SFX pass. Runs as a scene so the Sfx +
## Ambience autoloads are fully _ready() before we probe them. Asserts every
## bank key resolved to real (non-null) streams, plays a spread of old + new
## keys, and exercises an ambience crossfade. Non-zero exit on any problem.
##
##   godot --headless --path . res://tools/sfx_smoke.tscn

func _ready() -> void:
	await get_tree().process_frame
	var fails: int = 0
	var sfx := get_node_or_null("/root/Sfx")
	var amb := get_node_or_null("/root/Ambience")
	if sfx == null:
		push_error("SMOKE FAIL: Sfx autoload missing"); get_tree().quit(1); return
	if amb == null:
		push_error("SMOKE FAIL: Ambience autoload missing"); get_tree().quit(1); return

	var total_variants: int = 0
	for key in sfx.BANK.keys():
		if not sfx._streams.has(key):
			push_error("SMOKE FAIL: key not loaded: %s" % key); fails += 1; continue
		var idx := 0
		for s in sfx._streams[key]:
			total_variants += 1
			if s == null:
				push_error("SMOKE FAIL: null stream %s[%d] (%s)" % [key, idx, sfx.BANK[key][idx]]); fails += 1
			idx += 1

	for bkey in amb.BEDS.keys():
		if not ResourceLoader.exists(amb.BEDS[bkey]):
			push_error("SMOKE FAIL: ambience bed missing: %s" % amb.BEDS[bkey]); fails += 1

	for k in ["putt", "splat", "confirm", "impact_heavy", "whoosh_big", "ui_move",
			  "stinger_dread", "bell_toll", "raven", "thunder_far", "creak", "organ_stab"]:
		sfx.play(k)
	sfx.play_pitched("tick_countdown", 1.5)
	amb.play_bed("amb_wind_grounds", 0.5)
	amb.play_bed("amb_night_crickets", 0.5)
	amb.stop(0.2)
	await get_tree().process_frame

	print("SMOKE: %d keys, %d variants, %d ambience beds" % [sfx.BANK.size(), total_variants, amb.BEDS.size()])
	if fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		push_error("SMOKE FAIL: %d problem(s)" % fails)
		get_tree().quit(1)
