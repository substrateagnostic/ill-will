extends Minigame
## Exhibition-match stub: proves the night loop before real modules merge.
## Shows a banner for 2.5s, returns seeded plausible results.

var _config := {}

func begin(config: Dictionary) -> void:
	_config = config
	var lbl := Label.new()
	lbl.text = "EXHIBITION MATCH\n(the crowd pretends to care)"
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(lbl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_config.get("rng_seed", 1))
	await get_tree().create_timer(2.5).timeout
	var roster: Array = _config.get("roster", [])
	var order := range(roster.size())
	for i in order.size():
		var j := rng.randi_range(0, order.size() - 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var points := {}
	var pts := [5, 3, 2, 1]
	for rank in order.size():
		points[order[rank]] = pts[rank] if rank < pts.size() else 0
	var events: Array = [
		{"type": "grudge", "player": order.back(), "amount": 1, "reason": "humiliated in the exhibition"},
	]
	if rng.randf() < 0.5:
		events.append({"type": "royalty", "player": order[0], "amount": 2, "reason": "showboating"})
	var results := {
		"placements": order,
		"points": points,
		"currency_events": events,
		"highlights": ["%s peaked in a fake game" % roster[order[0]].name] if roster.size() > 0 else [],
		"monuments": [],
	}
	if rng.randf() < 0.34 and roster.size() > 0:
		results.monuments = [{"player": order[0], "kind": "brag", "label": "%s, Exhibitionist" % roster[order[0]].name}]
	report_finished(results)
