extends CanvasLayer
## Animated scene transitions. Autoloaded as `Transition`.
## Circular iris wipe + soft fade, so screens never hard-cut.

var _rect: ColorRect
var _busy := false

const SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 tint : source_color = vec4(0.09, 0.06, 0.02, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	// correct for portrait aspect so the iris stays circular
	vec2 d = uv - center;
	d.y *= 0.5625;
	float dist = length(d) * 2.0;
	// progress 0 = fully open (transparent), 1 = fully closed (opaque)
	float radius = mix(1.6, 0.0, progress);
	float edge = smoothstep(radius - 0.14, radius, dist);
	COLOR = vec4(tint.rgb, edge * tint.a);
}
"""


func _ready() -> void:
	layer = 128
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("progress", 0.0)
	_rect.material = mat
	_rect.visible = false
	add_child(_rect)


## Change scene with an iris-close / iris-open wipe.
func change_scene(path: String, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	if _busy:
		return
	_busy = true
	var mat: ShaderMaterial = _rect.material
	mat.set_shader_parameter("center", center)
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # block input mid-wipe

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v),
		0.0, 1.0, 0.34)
	await tw.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_method(func(v: float): mat.set_shader_parameter("progress", v),
		1.0, 0.0, 0.40)
	await tw2.finished
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Animate every direct child of a screen in with a staggered slide+fade.
static func enter_stagger(nodes: Array, from := Vector2(0, 40),
		step := 0.045, time := 0.42) -> void:
	for i in nodes.size():
		var n: Control = nodes[i]
		if not is_instance_valid(n):
			continue
		var target := n.position
		n.position = target + from
		n.modulate.a = 0.0
		var tw := n.create_tween().set_parallel()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position", target, time).set_delay(i * step)
		tw.tween_property(n, "modulate:a", 1.0, time * 0.7).set_delay(i * step)
