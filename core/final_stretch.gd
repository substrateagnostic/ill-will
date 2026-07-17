class_name FinalStretch
extends Node
## THE FINAL STRETCH kit (doc 09 §Q1) — one shared helper for the anthology's
## endgame seconds, so every game closes the same way the estate opens: heard.
##
##   * music escalation — `game_light` on PLAY, crossfade to `game_tense` at
##     each game's own threshold (mower OT, greed LAST BANKS, tilt sudden
##     death, throne crisis, orbital T-30, swap final lap, echo round 5,
##     dead_weight HOUSE AWAKENS, last will's final race);
##   * a warm-red screen-edge lighting nudge while escalated (subtle, capped);
##   * a timer pulse + rising tick ladder over the last 10 seconds.
##
## Presentation ONLY. No rng streams, no sim writes, no prints. Callers gate
## attach() behind their existing receipt discipline (fx_on(), --covtest,
## _test_mode, --willtally...) exactly like the HIT KIT — a headless receipt
## path never constructs the kit, so its receipts stay byte-identical.
##
## Net mirrors attach their own kit and drive it from mirrored facts (phase /
## clock / threshold deltas already on the wire) — the couch and the client
## hear the same bell without growing any snapshot.
##
## Where a game already OWNS a bespoke endgame beat (greed's CLOSING BELL
## ticks, throne's crisis banner, dead weight's HOUSE AWAKENS dim), the kit
## only unifies music + timer pulse — pass {ticks/vignette: false} and keep
## the bespoke drama single-sourced (doc 09's reconciliation rule).

const TICK_WINDOW := 10          # last N seconds get ticks + timer pulse
const TICK_DB := -9.0            # matches greed's CLOSING BELL cadence
const TICK_PITCH_TOP := 1.55
const VIG_STRENGTH := 0.16       # subtle: a mood, never a wall
const VIG_TINT := Color(0.90, 0.18, 0.10)

var escalated := false

var _timer_label: Label = null
var _use_vignette := true
var _use_ticks := true
var _last_tick_s := -1
var _base_font_size := -1
var _vig_mat: ShaderMaterial = null
var _vig_now := 0.0
var _vig_target := 0.0
var _breathe_t := 0.0

## One kit per game controller. `timer_label` may be null (lap races).
## opts: {"vignette": bool, "ticks": bool} — see the reconciliation note above.
static func attach(host: Node, timer_label: Label = null, opts: Dictionary = {}) -> FinalStretch:
	var kit := FinalStretch.new()
	kit.name = "FinalStretch"
	kit._timer_label = timer_label
	kit._use_vignette = bool(opts.get("vignette", true))
	kit._use_ticks = bool(opts.get("ticks", true))
	host.add_child(kit)
	return kit

func _ready() -> void:
	if _use_vignette:
		_build_vignette()

## PLAY begins (or a fresh round begins) — the light bed. No-op if already on.
func play_started() -> void:
	Music.play_slot("game_light")

## The game's own threshold crossed: tense music + the lighting nudge. Once
## per round; round_reset() re-arms it.
func escalate() -> void:
	if escalated:
		return
	escalated = true
	Music.play_slot("game_tense")
	_vig_target = VIG_STRENGTH

## Between rounds: back to the light bed, nudge fades, ladder re-arms.
func round_reset() -> void:
	escalated = false
	_last_tick_s = -1
	_vig_target = 0.0
	Music.play_slot("game_light")

## Match over: the nudge fades under the winner tableau. The tense track may
## keep playing — the estate owns the next crossfade when the module reports.
func match_ended() -> void:
	_vig_target = 0.0

## Call every frame while the clock is hot. Fires at most once per second in
## the last TICK_WINDOW seconds: a rising-pitch tick + a timer pulse.
func tick(seconds_left: float) -> void:
	if seconds_left < 0.0 or seconds_left > float(TICK_WINDOW):
		return
	var s := int(ceil(seconds_left))
	if s == _last_tick_s or s < 1:
		return
	_last_tick_s = s
	if _use_ticks:
		_play_tick(lerpf(1.0, TICK_PITCH_TOP, float(TICK_WINDOW - s) / float(TICK_WINDOW - 1)))
	_pulse_timer()

## THE DECIDING MOMENT camera language (doc 09 §Q2): a fov punch-in synced to
## the game's own deep-freeze window. Real-time (ignores the freeze's
## time_scale) so the punch and the slow-mo resolve together. Reduced-motion
## skips the PUNCH — the freeze depth is the caller's concern.
##
## THE ESTATE'S MEMORY: this is every game's shared deciding-moment chokepoint,
## so it is also where the estate takes its picture. MomentScribe.capture is
## fire-and-forget, throttled, real-time, and a no-op under headless — it grabs
## the frame without touching the sim, so receipts stay byte-identical. It runs
## BEFORE the reduced-motion gate: the moment is worth remembering even for a
## player who has asked the camera to hold still. `context` names the still
## (default THE DECIDING MOMENT) and rides into the newsreel's intertitle card.
##
## R9: one tasteful stinger rides along with the punch — the visual language
## for this moment shipped long ago, the audio language didn't. `stinger`
## defaults to the ambiguous `stinger_reveal` cue (a caller who knows the
## moment is a clean win/loss may pass stinger_win/stinger_lose/stinger_dread
## instead); pass "" to opt out. Plays before the reduced-motion gate, same as
## the capture above — it's a sound, not a camera move, so it isn't motion.
static func fov_punch(cam: Camera3D, base_fov: float, depth := 6.0, dur := 0.8, context := "", stinger := "stinger_reveal") -> void:
	MomentScribe.capture("deciding", context if context != "" else "THE DECIDING MOMENT", 3)
	if stinger != "":
		Sfx.play(stinger)
	if cam == null or not motion_ok():
		return
	var tw := cam.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(cam, "fov", base_fov - depth, 0.10) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dur - 0.45, 0.0))
	tw.tween_property(cam, "fov", base_fov, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The house reduced-motion gate (doc 08): PartySetup's screen_shake pref.
static func motion_ok() -> bool:
	var ps := Engine.get_main_loop()
	if ps is SceneTree:
		var node: Node = (ps as SceneTree).root.get_node_or_null(^"PartySetup")
		if node != null:
			return bool(node.pref("screen_shake", true))
	return true

# ---------------------------------------------------------------- internals

func _process(delta: float) -> void:
	if _vig_mat == null:
		return
	_breathe_t += delta
	var target := _vig_target
	if escalated and target > 0.0 and FinalStretch.motion_ok():
		target *= 1.0 + 0.18 * sin(_breathe_t * TAU * 0.5)   # slow breathe
	_vig_now = lerpf(_vig_now, target, 1.0 - exp(-3.0 * delta))
	_vig_mat.set_shader_parameter("strength", _vig_now)

## Exact-pitch tick (R9: swapped from a repurposed UI click to the
## purpose-built, declicked `tick_countdown` family — Sfx.play_pitched
## already supports an exact pitch for a LADDER; no local voice pool needed).
func _play_tick(pitch: float) -> void:
	Sfx.play_pitched("tick_countdown", pitch, TICK_DB)

## Timer pulse: a font-size punch (layout-safe for any anchor preset, unlike
## a scale pop on a full-rect label). Reduced-motion drops the pulse, keeps
## the tick — motion is optional, information is not.
func _pulse_timer() -> void:
	if _timer_label == null or not FinalStretch.motion_ok():
		return
	if _base_font_size < 0:
		_base_font_size = _timer_label.get_theme_font_size("font_size")
	if _base_font_size <= 0:
		return
	var top := float(_base_font_size) * 1.22
	var tw := _timer_label.create_tween()
	tw.tween_method(_set_timer_font_size, top, float(_base_font_size), 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_timer_font_size(v: float) -> void:
	if _timer_label != null:
		_timer_label.add_theme_font_size_override("font_size", int(v))

## The lighting nudge: a warm-red screen-edge tint on its own CanvasLayer
## UNDER the game's HUD (layer 0 vs the scene UI's default 1) — banners and
## scores stay crisp on top. Same shader form as orbital's danger vignette.
func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode blend_mix;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.90, 0.18, 0.10, 1.0);
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 1.42;
	float v = smoothstep(0.36, 1.0, d);
	COLOR = vec4(tint.rgb, v * strength);
}
"""
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = sh
	_vig_mat.set_shader_parameter("strength", 0.0)
	_vig_mat.set_shader_parameter("tint", VIG_TINT)
	rect.material = _vig_mat
	layer.add_child(rect)
