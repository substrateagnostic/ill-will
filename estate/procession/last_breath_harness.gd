extends Node
## THE LAST BREATH — self-contained dev harness (no live game wiring touched).
##
## Runs the ProcessionLastBreath component in isolation so the roll meter can be
## verified and captured before board integration. Two modes:
##
##   --lastbreathtest --seed=N
##       Headless determinism receipt. Builds 4 bot seats, runs the SAME seeded
##       queue three times, prints every seat's face per run, asserts
##       run1 == run2 == run3, prints the p=0 and p=1 weight tables (must match
##       RD: 40/25/15/10/6/4 and its mirror). Exits 0 on pass, 1 on fail.
##
##   --lastbreathcap --outdir=verify_out/lastbreath
##       Windowed capture. Drives one live bot roll slowly and snaps the meter
##       mid-sweep (crit band telegraphed) and again on the release flash.
##
## Launched directly as the run scene, so project.godot is never edited:
##   godot --headless --path . res://estate/procession/last_breath_harness.tscn -- --lastbreathtest --seed=7
##   godot           --path . res://estate/procession/last_breath_harness.tscn -- --lastbreathcap --outdir=verify_out/lastbreath

const LastBreath := preload("res://estate/procession/last_breath.gd")

# The four house seats (RED/BLUE/GOLD/MINT, matching PlayerBadge/DEFAULT_COLORS)
# with fixed wanted faces + persona crit appetites, so the receipt is stable.
const SEAT_NAMES := ["RED", "BLUE", "GOLD", "MINT"]
const SEAT_COLORS: Array[Color] = [
	Color(0.92, 0.34, 0.30), Color(0.25, 0.55, 0.90),
	Color(0.95, 0.75, 0.20), Color(0.30, 0.85, 0.60),
]
const SEAT_TARGETS := [1, 3, 5, 6]          # low, mid, high, top — spans the bar
const SEAT_APPETITE := [0.75, 0.25, 0.55, 0.90]

var seed_value := 7
var out_dir := "verify_out/lastbreath"
var _cap := false
var lb: ProcessionLastBreath = null

# Capture bookkeeping.
var _cap_frame := 0
var _snapped_mid := false
var _snapped_release := false
var _cap_done_frame := -1

func _ready() -> void:
	var mode := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--lastbreathtest":
			mode = "test"
		elif arg == "--lastbreathcap":
			mode = "cap"
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	match mode:
		"test":
			call_deferred("_run_test")
		"cap":
			_cap = true
			call_deferred("_run_cap")
		_:
			print("LASTBREATH harness: pass --lastbreathtest or --lastbreathcap")
			get_tree().quit(2)

# ============================================================================
# DETERMINISM RECEIPT
# ============================================================================

func _build_roster() -> Array:
	var r: Array = []
	for i in 4:
		r.append({"name": SEAT_NAMES[i], "color": SEAT_COLORS[i], "bot": true,
			"target": SEAT_TARGETS[i], "crit_appetite": SEAT_APPETITE[i]})
	return r

func _run_test() -> void:
	print("LASTBREATH_TEST seed=%d — 3 identical seeded queues of 4 bot seats" % seed_value)
	print("  targets=%s appetites=%s" % [str(SEAT_TARGETS), str(SEAT_APPETITE)])

	var runs: Array = []
	for run_i in 3:
		lb = LastBreath.new()
		lb._fast = true
		add_child(lb)
		lb.configure(_build_roster())
		# Capture via in-place mutation: a lambda captures the Array reference by
		# value, so `.assign()` (mutate) is visible outside, but `got = faces`
		# (rebind) would not be. _fast makes begin_night_roll emit synchronously.
		var got: Array = []
		lb.all_released.connect(func(faces): got.assign(faces), CONNECT_ONE_SHOT)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		lb.begin_night_roll([0, 1, 2, 3], SEAT_TARGETS, rng)
		runs.append(got.duplicate())
		print("  run %d faces: %s" % [run_i + 1, str(got)])
		lb.queue_free()
		lb = null

	var determinism_ok: bool = runs[0] == runs[1] and runs[1] == runs[2]
	print("  DETERMINISM run1==run2==run3: %s" % ("PASS" if determinism_ok else "FAIL"))

	# ---- weight-table check (RD §2.1): p=0 -> 40/25/15/10/6/4, p=1 mirrors ----
	var w0 := LastBreath.weight_kernel(6, 0.0, LastBreath.BIAS_DECAY)
	var w1 := LastBreath.weight_kernel(6, 1.0, LastBreath.BIAS_DECAY)
	print("  weight p=0.0: %s" % _pct_row(w0))
	print("  weight p=1.0: %s" % _pct_row(w1))
	var rd := [40.0, 25.0, 15.0, 10.0, 6.0, 4.0]
	var table_ok := true
	for i in 6:
		# The RD integers are hand-rounded to sum to 100; assert within 1.0 pt.
		if absf(w0[i] * 100.0 - rd[i]) > 1.0:
			table_ok = false
	# p=1 must be the exact mirror of p=0.
	var mirror_ok := true
	for i in 6:
		if not is_equal_approx(w1[i], w0[5 - i]):
			mirror_ok = false
	print("  TABLE p=0 within 1.0pt of [40,25,15,10,6,4]: %s" % ("PASS" if table_ok else "FAIL"))
	print("  TABLE p=1 is exact mirror of p=0: %s" % ("PASS" if mirror_ok else "FAIL"))

	# Configurable-die smoke (informational — receipts stay d6). The public weights
	# API answers for any die size without consuming rng, for the aim-time heatmap.
	var probe: ProcessionLastBreath = LastBreath.new()
	var d8 := probe.weights_for_p(0.0, 8)
	print("  DIE d8 weights p=0.0 (%d faces): %s" % [d8.size(), _pct_row(d8)])
	probe.free()

	var ok := determinism_ok and table_ok and mirror_ok
	print("LASTBREATH_TEST %s (seed %d)" % ["PASS" if ok else "FAIL", seed_value])
	get_tree().quit(0 if ok else 1)

func _pct_row(w: Array) -> String:
	var parts: Array = []
	for x in w:
		parts.append("%.1f" % (float(x) * 100.0))
	return "[" + "/".join(parts) + "]"

# ============================================================================
# WINDOWED CAPTURE
# ============================================================================

func _run_cap() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	_add_backdrop()
	lb = LastBreath.new()
	lb._fast = false
	add_child(lb)
	# One roller wanting the TOP face (p_target = 1.0) with NO crit appetite, so the
	# needle sweeps the whole bar — guaranteeing it passes crit_center (which reveals
	# the tell) with room to spare before releasing near the top with a bright flash.
	lb.configure([{"name": "GOLD", "color": SEAT_COLORS[2], "bot": true,
		"target": 6, "crit_appetite": 0.0}])
	lb.seat_released.connect(func(_s, _f, _p, _c): _cap_done_frame = _cap_frame + 24)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	lb.begin_night_roll([0], [6], rng)
	print("LASTBREATH_CAP seed=%d outdir=%s" % [seed_value, out_dir])

func _process(_delta: float) -> void:
	if not _cap or lb == null or lb.meter == null:
		return
	_cap_frame += 1
	var m := lb.meter
	# Mid-sweep snap: the first frame the crit band is telegraphed (needle has swept
	# past it once) and the roll is still live — band visible, needle mid-bar.
	if not _snapped_mid and m.crit_seen and not m.released:
		_snap("midsweep")
		_snapped_mid = true
	# Release snap: the flash is at/near full right after the seal fires.
	if not _snapped_release and m.released and m.flash > 0.5:
		_snap("release")
		_snapped_release = true
	if _cap_done_frame > 0 and _cap_frame >= _cap_done_frame:
		if not _snapped_mid:
			_snap("midsweep")   # fallback so the receipt always has both frames
		if not _snapped_release:
			_snap("release")
		print("LASTBREATH_CAP done")
		get_tree().quit(0)

## A dark parchment backdrop on a low layer so the windowed capture reads as a
## gothic stage, not a black void. Purely cosmetic; below the meter's layer 100.
func _add_backdrop() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(bg)
	var label := Label.new()
	label.text = "THE PROCESSION — roll meter dev harness"
	label.add_theme_color_override("font_color", Color(0.55, 0.48, 0.34))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 40.0
	label.offset_left = -240.0
	label.offset_right = 240.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_child(label)

func _snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/lastbreath_%s.png" % [out_dir, tag]
	img.save_png(path)
	print("LASTBREATH_SNAP ", path)
