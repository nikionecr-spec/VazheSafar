extends Control
class_name IconButton
## Big tappable icon with a caption ribbon. Bounces, tilts and sparkles.

signal pressed

@export var icon_path := ""
@export var caption := ""
@export var icon_size := 132.0
@export var idle_float := true
@export var float_phase := 0.0

var _icon: TextureRect
var _cap: PanelContainer
var _badge: Panel
var _base_y := 0.0
var _disabled := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(icon_size + 16.0, icon_size + (44.0 if caption != "" else 0.0))
	size = custom_minimum_size
	_build()
	if idle_float:
		_start_float()


func _build() -> void:
	_icon = TextureRect.new()
	_icon.texture = load(icon_path)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.size = _icon.custom_minimum_size
	_icon.position = Vector2(8, 0)
	_icon.pivot_offset = _icon.size * 0.5
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	if caption != "":
		_cap = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.30, 0.18, 0.06, 0.88)
		sb.set_corner_radius_all(15)
		sb.border_color = Color(1, 0.85, 0.45, 0.55)
		sb.set_border_width_all(2)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
		_cap.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = caption
		l.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
		l.add_theme_font_size_override("font_size", 25)
		l.add_theme_color_override("font_color", Color("#ffeec4"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cap.add_child(l)
		_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_cap)
		await get_tree().process_frame
		if is_instance_valid(_cap):
			_cap.position = Vector2((size.x - _cap.size.x) * 0.5, icon_size - 6.0)


func add_badge() -> void:
	_badge = Panel.new()
	_badge.custom_minimum_size = Vector2(30, 30)
	_badge.size = _badge.custom_minimum_size
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#e53935")
	s.set_corner_radius_all(15)
	s.border_color = Color.WHITE
	s.set_border_width_all(3)
	_badge.add_theme_stylebox_override("panel", s)
	_badge.position = Vector2(icon_size - 20.0, 2)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	var tw := _badge.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	_badge.pivot_offset = Vector2(15, 15)
	tw.tween_property(_badge, "scale", Vector2(1.25, 1.25), 0.5)
	tw.tween_property(_badge, "scale", Vector2.ONE, 0.5)


func set_badge_visible(v: bool) -> void:
	if _badge:
		_badge.visible = v


func set_disabled(v: bool) -> void:
	_disabled = v
	modulate = Color(0.6, 0.6, 0.6) if v else Color.WHITE


func _start_float() -> void:
	await get_tree().process_frame
	_base_y = _icon.position.y
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(float_phase)
	tw.tween_property(_icon, "position:y", _base_y - 7.0, 1.5)
	tw.tween_property(_icon, "position:y", _base_y, 1.5)


func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			Audio.play("btn_down")
			Audio.vibrate(12)
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_icon, "scale", Vector2(0.84, 0.84), 0.08)
		else:
			Audio.play("btn_up")
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_icon, "scale", Vector2.ONE, 0.55)
			_sparkle()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		accept_event()


func _sparkle() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x * 0.5, icon_size * 0.5)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.55
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.92, 0.6)
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())
