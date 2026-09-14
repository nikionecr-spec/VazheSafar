extends RefCounted
class_name UIKit
## Shared visual language: wooden panels, golden frames, Persian buttons.

const FONT_BLACK := "res://assets/fonts/Vazirmatn-Black.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"
const FONT_MED := "res://assets/fonts/Vazirmatn-Medium.ttf"

const WOOD := Color("#8b5a2b")
const WOOD_DARK := Color("#5f3b17")
const GOLD := Color("#f2c14e")
const GOLD_DARK := Color("#c89328")
const CREAM := Color("#fdf3d8")
const GREEN := Color("#63c132")
const GREEN_DARK := Color("#3f8c1f")
const TEXT_DARK := Color("#5b3a1c")


static func wood_panel(radius: int = 26, border: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(radius)
	sb.border_color = GOLD
	sb.set_border_width_all(border)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func cream_panel(radius: int = 26) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(radius)
	sb.border_color = Color("#d9bd88")
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func green_button_style(pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GREEN.darkened(0.12) if pressed else GREEN
	sb.set_corner_radius_all(28)
	sb.border_color = GREEN_DARK
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 0 if pressed else 7
	sb.shadow_offset = Vector2(0, 0 if pressed else 4)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


static func gold_pill(radius: int = 30) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fbe3a3")
	sb.set_corner_radius_all(radius)
	sb.border_color = GOLD_DARK
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func label(text: String, size: int = 34, color: Color = TEXT_DARK,
		font: String = FONT_BOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func outlined_label(text: String, size: int = 40,
		color: Color = Color.WHITE, outline: Color = Color("#4a2c10"),
		outline_size: int = 8) -> Label:
	var l := label(text, size, color, FONT_BLACK)
	l.add_theme_constant_override("outline_size", outline_size)
	l.add_theme_color_override("font_outline_color", outline)
	return l


static func green_button(text: String, font_size: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", load(FONT_BLACK))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("#e8ffdc"))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", GREEN_DARK)
	b.add_theme_stylebox_override("normal", green_button_style(false))
	b.add_theme_stylebox_override("hover", green_button_style(false))
	b.add_theme_stylebox_override("pressed", green_button_style(true))
	var ds := green_button_style(true)
	ds.bg_color = Color("#c9bda6")
	ds.border_color = Color("#a89a80")
	ds.shadow_size = 4
	ds.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("disabled", ds)
	b.add_theme_color_override("font_disabled_color", Color("#fdf6e3"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	juice(b)
	gloss(b)
	return b


## Adds press-squash / elastic-release / sound / haptics to any BaseButton.
static func juice(b: BaseButton, squash: float = 0.93) -> void:
	b.set_meta("juiced", true)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(squash + 0.03, squash - 0.02), 0.07)
		Audio.play("btn_down")
		Audio.vibrate(12))
	b.button_up.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.45)
		Audio.play("btn_up"))


## Glossy top highlight overlay so flat buttons read as 3D candy.
static func gloss(b: Control, alpha: float = 0.22) -> void:
	var g := Panel.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_preset(Control.PRESET_TOP_WIDE)
	g.anchor_bottom = 0.48
	g.offset_left = 6
	g.offset_right = -6
	g.offset_top = 5
	g.offset_bottom = 0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	g.add_theme_stylebox_override("panel", sb)
	b.add_child(g)


static func icon_button(tex_path: String, box: float = 92.0) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(tex_path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(box, box)
	b.size = Vector2(box, box)
	return b


static func make_toast(msg: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.09, 0.03, 0.9)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(msg, 30, Color.WHITE))
	p.modulate.a = 0.0
	p.z_index = 100
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): if is_instance_valid(p): p.queue_free())
	return p


## Adds a gentle idle bob to any control (used for characters / CTA buttons).
static func idle_bob(node: Control, amount: float = 8.0, time: float = 1.6) -> void:
	var base := node.position.y
	var tw := node.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base - amount, time * 0.5)
	tw.tween_property(node, "position:y", base, time * 0.5)


static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.6, 0.6)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector2.ONE, 0.38)
	tw.parallel().tween_property(node, "modulate:a", 1.0, 0.25)
