extends Control
class_name JuicyButton
## A premium soft-3D button: baked gradient face, real extrusion that sinks on
## press, spring-back release, optional idle breathing and a travelling shine.
## Touch feedback is deliberately smooth rather than bouncy-cartoon.

signal pressed

@export var text := ""
@export var icon_path := ""
@export var base_color := Color("#63c132")
@export var shadow_color := Color("#3f8c1f")
@export var font_size := 44
@export var corner := 34.0
@export var depth := 10.0          ## extrusion height in pixels
@export var idle_pulse := false
@export var shine := false
@export var glow := false          ## soft halo behind the button

var _pressed := false
var _body: Control
var _shadow: TextureRect
var _face: TextureRect
var _label: Label
var _icon: TextureRect
var _glow: TextureRect
var _disabled := false
var _base_icon_box := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_relayout)
	if idle_pulse:
		_start_idle()
	if shine:
		_start_shine()


func _build() -> void:
	if glow:
		_glow = TextureRect.new()
		_glow.texture = UIKit.glow_tex(int(maxf(120.0, size.x * 0.55)), Color(base_color.r, base_color.g, base_color.b, 0.5), 2.0)
		_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_glow)

	# extruded side
	_shadow = TextureRect.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_shadow)

	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_face = TextureRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.clip_contents = true          # keeps the shine sweep inside the shape
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_body.add_child(_face)

	var content := HBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(content)

	if icon_path != "":
		_icon = TextureRect.new()
		_icon.texture = load(icon_path)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_icon)

	if text != "":
		_label = Label.new()
		_label.text = text
		_label.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Black.ttf"))
		_label.add_theme_font_size_override("font_size", font_size)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_constant_override("outline_size", 6)
		_label.add_theme_color_override("font_outline_color",
			shadow_color.darkened(0.35))
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_label)
	_relayout()


func _relayout() -> void:
	if _face == null:
		return
	var s := size
	if s.x < 4.0 or s.y < 4.0:
		return
	var r := int(corner)
	# baked gradient faces (cached by UIKit, so this is cheap after frame 1)
	_face.texture = UIKit.gradient_tex(int(s.x), int(s.y), r,
		base_color.lightened(0.22), base_color.darkened(0.16),
		Color(1, 1, 1, 0.5), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 0, 0.20)
	_face.position = Vector2.ZERO
	_face.size = s
	_shadow.texture = UIKit.gradient_tex(int(s.x), int(s.y), r,
		shadow_color.lightened(0.05), shadow_color.darkened(0.22),
		Color(1, 1, 1, 0.10), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 0.0)
	_shadow.position = Vector2(0, depth)
	_shadow.size = s
	if _glow:
		_glow.size = Vector2(s.x * 1.18, s.y * 2.4)
		_glow.position = Vector2(-s.x * 0.09, -s.y * 0.7)
	_body.position = Vector2.ZERO
	_body.size = s
	_body.pivot_offset = s * 0.5
	var content: HBoxContainer = _face.get_node_or_null("Content")
	if content:
		content.position = Vector2.ZERO
		content.size = s
	if _icon:
		_base_icon_box = clampf(s.y * 0.58, 30.0, 104.0)
		_icon.custom_minimum_size = Vector2(_base_icon_box, _base_icon_box)


func set_disabled(v: bool) -> void:
	_disabled = v
	modulate = Color(0.68, 0.68, 0.70, 0.9) if v else Color.WHITE


func set_text(t: String) -> void:
	text = t
	if _label:
		_label.text = t


# ------------------------------------------------------------------ input
func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_press()
		else:
			if _pressed:
				_release()
				if Rect2(Vector2.ZERO, Vector2(size.x, size.y + depth)).has_point(event.position):
					pressed.emit()
		accept_event()


func _press() -> void:
	_pressed = true
	Audio.play("btn_down")
	Audio.vibrate(14)
	var tw := create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# sink into the extrusion, squash just enough to feel soft
	tw.tween_property(_body, "position:y", depth * 0.72, 0.08)
	tw.tween_property(_body, "scale", Vector2(1.025, 0.955), 0.08)
	tw.tween_property(_shadow, "size:y", size.y - depth * 0.72, 0.08)
	if _glow:
		tw.tween_property(_glow, "modulate:a", 0.45, 0.08)


func _release() -> void:
	_pressed = false
	Audio.play("btn_up")
	var tw := create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", 0.0, 0.34)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.34)
	tw.tween_property(_shadow, "size:y", size.y, 0.34)
	if _glow:
		tw.tween_property(_glow, "modulate:a", 1.0, 0.34)
	_burst()


func _burst() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x * 0.5, size.y * 0.35)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 150.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = base_color.lightened(0.5)
	p.color.a = 0.75
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


func _start_idle() -> void:
	await get_tree().process_frame
	if _body == null:
		return
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_body, "scale", Vector2(1.018, 1.018), 1.1)
	tw.tween_property(_body, "scale", Vector2.ONE, 1.1)


func _start_shine() -> void:
	var sh := TextureRect.new()
	sh.texture = UIKit.gradient_tex(70, 260, 34, Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(0, 0, 0, 0), 0, 0.0)
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.modulate.a = 0.9
	_face.add_child(sh)
	while is_instance_valid(sh):
		await get_tree().create_timer(3.2).timeout
		if not is_instance_valid(sh) or _face == null:
			return
		sh.size = Vector2(size.x * 0.30, size.y * 1.4)
		sh.position = Vector2(-size.x * 0.35, -size.y * 0.2)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sh, "position:x", size.x * 1.15, 0.75)
