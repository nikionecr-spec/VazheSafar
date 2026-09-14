extends Control
class_name IconButton
## ============================================================================
##  دکمهٔ آیکونیِ درشت و «زنده» — صفحهٔ شیشه‌ای طلایی + ریبون عنوان
##  شنا کردنِ نرم، فشرده‌شدن، جرقه و بازخورد لرزشی.
## ============================================================================

signal pressed

const ArtL := preload("res://scripts/Art.gd")

@export var icon_path := ""
@export var caption := ""
@export var icon_size := 150.0
@export var idle_float := true
@export var float_phase := 0.0
@export var plate := true
@export var ribbon_color := Color("#5d3714")

var _plate: Control
var _icon: TextureRect
var _cap: Control
var _badge: Control
var _base_y := 0.0
var _disabled := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var cap_h: float = 60.0 if caption != "" else 0.0
	var plate_size: float = icon_size * (1.26 if plate else 1.0)
	custom_minimum_size = Vector2(maxf(plate_size, icon_size + 12.0), plate_size + cap_h + 6.0)
	size = custom_minimum_size
	_build()
	if idle_float:
		_start_float()


func _build() -> void:
	var plate_size: float = icon_size * (1.26 if plate else 1.0)
	var px: float = (size.x - plate_size) * 0.5
	_plate = Control.new()
	_plate.position = Vector2(px, 0)
	_plate.size = Vector2(plate_size, plate_size)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if plate:
		var glow := ArtL.glow_disc(plate_size * 1.5, Color(1.0, 0.86, 0.5))
		glow.position = -Vector2(plate_size, plate_size) * 0.25
		_plate.add_child(glow)
		var disc := ArtL.gold_ring(plate_size, maxf(5.0, plate_size * 0.05), Color("#fff7e4"))
		_plate.add_child(disc)
	add_child(_plate)

	_icon = TextureRect.new()
	_icon.texture = load(icon_path)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(px + plate_size * 0.14, plate_size * 0.14)
	_icon.size = Vector2(plate_size * 0.72, plate_size * 0.72)
	_icon.pivot_offset = _icon.size * 0.5
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	var shadow := ArtL.ground_shadow(plate_size * 0.72, plate_size * 0.22, 0.30)
	shadow.position = Vector2(px + plate_size * 0.14, plate_size * 0.92)
	add_child(shadow)
	move_child(shadow, 0)

	if caption != "":
		_cap = ArtL.ribbon(caption, 27, ribbon_color)
		add_child(_cap)
		await get_tree().process_frame
		if is_instance_valid(_cap):
			_cap.position = Vector2((size.x - _cap.size.x) * 0.5, plate_size - 12.0)


func add_badge(text: String = "!") -> Control:
	_badge = ArtL.badge_count(text)
	_badge.position = Vector2(size.x - 54, 2)
	add_child(_badge)
	var tw := _badge.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_badge, "scale", Vector2(1.22, 1.22), 0.55)
	tw.tween_property(_badge, "scale", Vector2.ONE, 0.55)
	return _badge


func set_badge_visible(v: bool) -> void:
	if _badge:
		_badge.visible = v


func set_disabled(v: bool) -> void:
	_disabled = v
	modulate = Color(0.62, 0.62, 0.62) if v else Color.WHITE


func _start_float() -> void:
	await get_tree().process_frame
	_base_y = _icon.position.y
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(float_phase)
	tw.tween_property(_icon, "position:y", _base_y - 9.0, 1.6)
	tw.parallel().tween_property(_plate, "position:y", -9.0, 1.6)
	tw.tween_property(_icon, "position:y", _base_y, 1.6)
	tw.parallel().tween_property(_plate, "position:y", 0.0, 1.6)


func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			Audio.play("btn_down")
			Audio.vibrate(12)
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_icon, "scale", Vector2(0.86, 0.86), 0.07)
			tw.parallel().tween_property(_plate, "scale", Vector2(0.92, 0.92), 0.07)
		else:
			Audio.play("btn_up")
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_icon, "scale", Vector2.ONE, 0.42)
			tw.parallel().tween_property(_plate, "scale", Vector2.ONE, 0.42)
			_sparkle()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		accept_event()


func _sparkle() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x * 0.5, icon_size * 0.6)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 190.0
	p.gravity = Vector2(0, 280)
	p.scale_amount_min = 2.4
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.92, 0.6)
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())
