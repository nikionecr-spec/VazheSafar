extends Control
class_name JuicyButton
## A game-feel button: 3D extruded body, squash on press, bounce on release,
## idle breathing, shine sweep and particle burst. Built for touch.

signal pressed

@export var text := ""
@export var icon_path := ""
@export var base_color := Color("#63c132")
@export var shadow_color := Color("#3f8c1f")
@export var font_size := 44
@export var corner := 34.0
@export var depth := 10.0          ## 3D extrusion height
@export var idle_pulse := false
@export var shine := false

var _pressed := false
var _hover := 0.0
var _body: Control
var _shadow: Panel
var _face: Panel
var _label: Label
var _icon: TextureRect
var _shine_x := -1.5
var _disabled := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	if idle_pulse:
		_start_idle()
	if shine:
		_start_shine()
	resized.connect(_relayout)


func _build() -> void:
	# drop shadow (the extruded side)
	_shadow = Panel.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := StyleBoxFlat.new()
	ss.bg_color = shadow_color
	ss.set_corner_radius_all(int(corner))
	_shadow.add_theme_stylebox_override("panel", ss)
	add_child(_shadow)

	# body holder (scaled for squash)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_face = Panel.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.clip_contents = true
	var fs := StyleBoxFlat.new()
	fs.bg_color = base_color
	fs.set_corner_radius_all(int(corner))
	fs.border_color = base_color.lightened(0.28)
	fs.border_width_top = 4
	fs.border_width_left = 3
	fs.border_width_right = 3
	fs.border_width_bottom = 0
	_face.add_theme_stylebox_override("panel", fs)
	_body.add_child(_face)

	# glossy top highlight
	var gloss := Panel.new()
	gloss.name = "Gloss"
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(1, 1, 1, 0.22)
	gs.corner_radius_top_left = int(corner * 0.8)
	gs.corner_radius_top_right = int(corner * 0.8)
	gs.corner_radius_bottom_left = int(corner * 0.5)
	gs.corner_radius_bottom_right = int(corner * 0.5)
	gloss.add_theme_stylebox_override("panel", gs)
	_face.add_child(gloss)

	var content := HBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
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
		_label.add_theme_font_override("font",
			load("res://assets/fonts/Vazirmatn-Black.ttf"))
		_label.add_theme_font_size_override("font_size", font_size)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_constant_override("outline_size", 7)
		_label.add_theme_color_override("font_outline_color", shadow_color.darkened(0.2))
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_label)

	_relayout()


func _relayout() -> void:
	if _shadow == null:
		return
	var s := size
	_shadow.position = Vector2(0, depth)
	_shadow.size = s
	_body.position = Vector2.ZERO
	_body.size = s
	_body.pivot_offset = s * 0.5
	_face.position = Vector2.ZERO
	_face.size = s
	var gloss: Panel = _face.get_node_or_null("Gloss")
	if gloss:
		gloss.position = Vector2(6, 4)
		gloss.size = Vector2(s.x - 12, s.y * 0.42)
	var content: HBoxContainer = _face.get_node_or_null("Content")
	if content:
		content.position = Vector2.ZERO
		content.size = s
	if _icon:
		var box: float = clampf(s.y * 0.62, 28.0, 92.0)
		_icon.custom_minimum_size = Vector2(box, box)


func set_disabled(v: bool) -> void:
	_disabled = v
	modulate = Color(0.62, 0.62, 0.62, 1.0) if v else Color.WHITE


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
				if Rect2(Vector2.ZERO, size).has_point(event.position):
					pressed.emit()
		accept_event()


func _press() -> void:
	_pressed = true
	Audio.play("btn_down")
	Audio.vibrate(14)
	var tw := create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# squash down into the shadow
	tw.tween_property(_body, "position:y", depth * 0.85, 0.07)
	tw.tween_property(_body, "scale", Vector2(1.04, 0.93), 0.07)


func _release() -> void:
	_pressed = false
	Audio.play("btn_up")
	var tw := create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", 0.0, 0.32)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.36)
	_burst()


## small sparkle burst on release
func _burst() -> void:
	var p := CPUParticles2D.new()
	p.position = size * 0.5
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 210.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = base_color.lightened(0.55)
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


func _start_idle() -> void:
	await get_tree().process_frame
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_body, "scale", Vector2(1.035, 1.035), 0.85)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.85)


func _start_shine() -> void:
	var sh := ColorRect.new()
	sh.color = Color(1, 1, 1, 0.30)
	sh.rotation = 0.35
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(sh)
	while is_instance_valid(sh):
		await get_tree().create_timer(2.6).timeout
		if not is_instance_valid(sh):
			return
		sh.size = Vector2(size.x * 0.22, size.y * 2.4)
		sh.position = Vector2(-size.x * 0.35, -size.y * 0.7)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sh, "position:x", size.x * 1.15, 0.65)
