extends Control
class_name JuicyButton
## ============================================================================
##  دکمهٔ اصلی بازی — گرافیکی، سه‌بعدی، نرم و «لمس‌کردنی»
##  بدنهٔ گرادیانی + لبهٔ پایین ضخیم + براقی شیشه‌ای + درخشش عبوری
##  بازخورد: فشرده‌شدن، جهش ارتجاعی، ذرات، صدا و لرزش.
## ============================================================================

signal pressed

const ArtL := preload("res://scripts/Art.gd")

@export var text := ""
@export var subtitle := ""
@export var icon_path := ""
@export var base_color := Color("#4cb02f")
@export var shadow_color := Color("#2f7a1c")
@export var font_size := 52
@export var corner := 40.0
@export var depth := 14.0
@export var idle_pulse := false
@export var shine := false
@export var badge_text := ""

var _pressed := false
var _body: Control
var _shadow: TextureRect
var _face: TextureRect
var _label: Label
var _sub: Label
var _icon: TextureRect
var _shine_layer: Control
var _disabled := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(560, 140)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	_build()
	resized.connect(_relayout)
	if idle_pulse:
		_start_idle()
	if shine:
		_start_shine()


func _retex() -> void:
	## تصویرها را با مقیاس کوچک می‌سازیم (سریع) و با فیلتر نرم بزرگ می‌کنیم
	var k := 0.34
	var w: int = maxi(int(size.x * k), 24)
	var h: int = maxi(int(size.y * k), 12)
	var c: int = maxi(int(corner * k), 4)
	_shadow.texture = ArtL.rounded_texture(w, h, c,
		shadow_color.darkened(0.30), shadow_color.darkened(0.55))
	_face.texture = ArtL.rounded_texture(w, h, c,
		base_color.lightened(0.20), base_color.darkened(0.14),
		base_color.lightened(0.55), maxf(2.0, corner * 0.16), 0.30, 0.22)


func _build() -> void:
	_shadow = TextureRect.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_shadow)

	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_face = TextureRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_body.add_child(_face)

	# لایهٔ براقی نرم بالای بدنه
	var gloss := TextureRect.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gloss.stretch_mode = TextureRect.STRETCH_SCALE
	gloss.texture = ArtL.gloss_texture(200, 64, 24, 0.26)
	gloss.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gloss.name = "Gloss"
	_face.add_child(gloss)

	# درخشش عبوری (shine sweep) داخل یک ظرف بریده‌شده
	_shine_layer = Control.new()
	_shine_layer.name = "ShineLayer"
	_shine_layer.clip_contents = true
	_shine_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_shine_layer)

	var content := HBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(content)

	if icon_path != "":
		_icon = TextureRect.new()
		_icon.texture = load(icon_path)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_icon)

	if text != "" or subtitle != "":
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", -4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if text != "":
			_label = Label.new()
			_label.text = text
			_label.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Black.ttf"))
			_label.add_theme_font_size_override("font_size", font_size)
			_label.add_theme_color_override("font_color", Color.WHITE)
			_label.add_theme_constant_override("outline_size", 8)
			_label.add_theme_color_override("font_outline_color", shadow_color.darkened(0.30))
			_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(_label)
		if subtitle != "":
			_sub = Label.new()
			_sub.text = subtitle
			_sub.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
			_sub.add_theme_font_size_override("font_size", int(font_size * 0.46))
			_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
			_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(_sub)
		content.add_child(col)
	_relayout()
	_retex()


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
	var gloss: TextureRect = _face.get_node_or_null("Gloss")
	if gloss:
		gloss.position = Vector2(8, 6)
		gloss.size = Vector2(s.x - 16, s.y * 0.44)
	var shine_l: Control = _face.get_node_or_null("ShineLayer")
	if shine_l:
		shine_l.position = Vector2.ZERO
		shine_l.size = s
	var content: HBoxContainer = _face.get_node_or_null("Content")
	if content:
		content.position = Vector2.ZERO
		content.size = s
	if _icon:
		var box: float = clampf(s.y * 0.60, 30.0, 108.0)
		_icon.custom_minimum_size = Vector2(box, box)
	if badge_text != "" and not has_node("Badge"):
		var b := ArtL.badge_count(badge_text)
		b.name = "Badge"
		b.position = Vector2(6, -10)
		add_child(b)


func set_disabled(v: bool) -> void:
	_disabled = v
	modulate = Color(0.68, 0.68, 0.68, 1.0) if v else Color.WHITE


func set_text(t: String) -> void:
	text = t
	if _label:
		_label.text = t


func set_subtitle(t: String) -> void:
	subtitle = t
	if _sub:
		_sub.text = t


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
	tw.tween_property(_body, "position:y", depth * 0.92, 0.06)
	tw.tween_property(_body, "scale", Vector2(1.035, 0.94), 0.06)


func _release() -> void:
	_pressed = false
	Audio.play("btn_up")
	var tw := create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", 0.0, 0.30)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.36)
	_burst()


func _burst() -> void:
	var p := CPUParticles2D.new()
	p.position = size * 0.5
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 230.0
	p.gravity = Vector2(0, 430)
	p.scale_amount_min = 2.6
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
	tw.tween_property(_body, "scale", Vector2(1.03, 1.03), 0.9)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.9)


## درخشش نرمی که هر چند ثانیه از روی دکمه عبور می‌کند
func _start_shine() -> void:
	await get_tree().process_frame
	var sh := TextureRect.new()
	sh.texture = ArtL.rounded_texture(48, 220, 22,
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0))
	# گرادیان افقی نرم برای درخشش
	var img := Image.create(24, 8, false, Image.FORMAT_RGBA8)
	for x in 24:
		var k: float = float(x) / 23.0
		var a: float = sin(k * PI) * 0.30
		for y in 8:
			img.set_pixel(x, y, Color(1, 1, 1, a))
	sh.texture = ImageTexture.create_from_image(img)
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.rotation = 0.0
	var shine_l: Control = _face.get_node_or_null("ShineLayer")
	if shine_l == null:
		return
	shine_l.add_child(sh)
	while is_instance_valid(sh) and is_instance_valid(self):
		await get_tree().create_timer(2.4 + randf() * 1.6).timeout
		if not is_instance_valid(sh) or not is_instance_valid(self):
			return
		var target_w: float = maxf(size.x * 0.28, 60.0)
		sh.size = Vector2(target_w, size.y * 1.6)
		sh.position = Vector2(-target_w * 1.4, -size.y * 0.3)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sh, "position:x", size.x * 1.15, 0.75)
