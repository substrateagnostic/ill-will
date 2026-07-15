class_name TransitionWipe
extends CanvasLayer
## Estate-gothic scene-transition wipe (doc 14 §5 "Loading/transition wipes":
## fully obscure for the wipe's duration, motion over a blank bar). Iris or
## curtain, 300-400ms ease-out (doc 14 §6 hero-transition band), one Sfx.
## CanvasLayer-based so it works over ANY scene (2D or 3D).
##
## API:
##   var w := TransitionWipe.cover(host, func(): swap_the_scene())   # closes, then calls back covered
##   ...                                                            # do the swap while fully hidden
##   w.reveal()                                                     # opens, then frees itself
##
## Or the one-shot convenience:
##   TransitionWipe.play(host, func(): swap_the_scene())            # cover -> callback -> reveal -> free

const IRIS := 0
const CURTAIN := 1
const COVER_TIME := 0.34       # doc 14 §6 hero band (300-400ms)
const REVEAL_TIME := 0.30
const TINT := Color(0.05, 0.04, 0.07)

var _rect: ColorRect
var _mat: ShaderMaterial
var _style := IRIS

func _init() -> void:
	layer = 90   # under Transition autoload's fade (layer 100), over everything else
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = _SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("progress", 0.0)   # 0 = open (screen clear)
	_mat.set_shader_parameter("tint", TINT)
	_mat.set_shader_parameter("style", _style)
	_rect.material = _mat
	add_child(_rect)

## Close the wipe over `host`. Calls `on_covered` once the screen is fully
## obscured. Returns the instance so you can call reveal() after.
static func cover(host: Node, on_covered := Callable(), style := IRIS) -> TransitionWipe:
	var w := TransitionWipe.new()
	w._style = style
	host.add_child(w)
	w._do_cover(on_covered)
	return w

## Cover -> callback (do your swap) -> reveal -> free, in one call.
static func play(host: Node, on_covered := Callable(), style := IRIS) -> TransitionWipe:
	var w := TransitionWipe.new()
	w._style = style
	host.add_child(w)
	w._do_cover(func() -> void:
		if on_covered.is_valid():
			on_covered.call()
		w.reveal())
	return w

func _do_cover(on_covered: Callable) -> void:
	Sfx.play("card", -3.0)
	var tw := create_tween()
	tw.tween_property(_mat, "shader_parameter/progress", 1.0, COVER_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on_covered.is_valid():
		tw.tween_callback(on_covered)

## Open the wipe back up, then free the instance. Optional `on_done` fires after.
func reveal(on_done := Callable()) -> void:
	var tw := create_tween()
	tw.tween_property(_mat, "shader_parameter/progress", 0.0, REVEAL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if on_done.is_valid():
			on_done.call()
		queue_free())

const _SHADER := """
shader_type canvas_item;
render_mode blend_mix;
uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0 open, 1 covered
uniform vec4 tint : source_color = vec4(0.05, 0.04, 0.07, 1.0);
uniform int style;

void fragment() {
	float a = 0.0;
	if (style == 0) {
		// IRIS: a clear circular window shrinks to nothing as progress -> 1.
		float d = distance(UV, vec2(0.5)) * 1.42;   // ~0..1 corner-normalized
		float radius = mix(1.15, 0.0, progress);
		a = smoothstep(radius - 0.04, radius + 0.04, d);   // outside window = covered
	} else {
		// CURTAIN: two panels close from top and bottom toward the middle.
		float edge = progress * 0.5;
		float top = smoothstep(edge + 0.02, edge - 0.02, UV.y);      // covered above
		float bot = smoothstep(1.0 - edge - 0.02, 1.0 - edge + 0.02, UV.y);  // covered below
		a = clamp(top + bot, 0.0, 1.0);
	}
	COLOR = vec4(tint.rgb, a);
}
"""
