extends RefCounted
class_name UIKit
## ============================================================================
##  زبان بصری واژه‌سفر — نسخهٔ ۲ (گرافیکی، نرم، لوکس)
##  Facade روی Art.gd: پنل‌ها، دکمه‌ها، HUD، نوار پایین، تیترها، توست و انیمیشن‌ها.
## ============================================================================

const ArtL := preload("res://scripts/Art.gd")

const FONT_BLACK := "res://assets/fonts/Vazirmatn-Black.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"
const FONT_MED := "res://assets/fonts/Vazirmatn-Medium.ttf"

# ------- palette shortcuts (برای سازگاری با کد قبلی)
const WOOD := Color("#8a5527")
const WOOD_DARK := Color("#5d3714")
const GOLD := Color("#f2c14e")
const GOLD_DARK := Color("#c89328")
const CREAM := Color("#f7ecd6")
const GREEN := Color("#4cb02f")
const GREEN_DARK := Color("#2f7a1c")
const TEXT_DARK := Color("#4a3117")
const INK_SOFT := Color("#7b5c34")
const BLUE := Color("#4a9ae0")
const RED := Color("#ec6a5a")
const AMBER := Color("#f7b731")

const SCREEN := Vector2(1080, 1920)


# ============================================================ styleboxes پایه
static func wood_panel(radius: int = 26, border: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(radius)
	sb.border_color = GOLD
	sb.set_border_width_all(border)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	return sb


static func cream_panel(radius: int = 26) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(radius)
	sb.border_color = Color("#dcc79a")
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.20)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func gold_pill(radius: int = 30) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fdeec2")
	sb.set_corner_radius_all(radius)
	sb.border_color = GOLD_DARK
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func green_button_style(pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GREEN.darkened(0.14) if pressed else GREEN
	sb.set_corner_radius_all(30)
	sb.border_color = GREEN_DARK
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 0 if pressed else 8
	sb.shadow_offset = Vector2(0, 0 if pressed else 5)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


# ==================================================================== labels
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


static func right_label(text: String, size: int = 34, color: Color = TEXT_DARK,
		font: String = FONT_BOLD) -> Label:
	var l := label(text, size, color, font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


static func outlined_label(text: String, size: int = 40,
		color: Color = Color.WHITE, outline: Color = Color("#4a2c10"),
		outline_size: int = 8) -> Label:
	var l := label(text, size, color, FONT_BLACK)
	l.add_theme_constant_override("outline_size", outline_size)
	l.add_theme_color_override("font_outline_color", outline)
	return l


# =================================================================== buttons
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
static func juice(b: BaseButton, squash: float = 0.94) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(squash + 0.02, squash - 0.03), 0.06)
		Audio.play("btn_down")
		Audio.vibrate(12))
	b.button_up.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.32)
		Audio.play("btn_up"))


## Glossy top highlight overlay so flat buttons read as 3D candy.
static func gloss(b: Control, alpha: float = 0.24) -> void:
	var g := TextureRect.new()
	g.texture = ArtL.gloss_texture(256, 96, 30, alpha)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_preset(Control.PRESET_TOP_WIDE)
	g.anchor_bottom = 0.46
	g.offset_left = 7
	g.offset_right = -7
	g.offset_top = 6
	g.offset_bottom = 0
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	b.add_child(g)


static func icon_button(tex_path: String, box: float = 92.0) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(tex_path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(box, box)
	b.size = Vector2(box, box)
	return b


# =============================================================== screen chrome
## پردهٔ تیرهٔ ملایم پایین صفحه برای خوانایی متن و کنتراست نوار پایین
static func vignette(strength: float = 0.42) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	var img := Image.create(8, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		var k: float = float(y) / 255.0
		var a: float = pow(k, 1.7) * strength
		for x in 8:
			img.set_pixel(x, y, Color(0.10, 0.05, 0.02, a))
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	t.anchor_top = 0.45
	t.offset_bottom = 0
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(t)
	return holder


## دکمهٔ بازگشت بزرگ و خوانا
static func back_button(box: float = 118.0) -> Control:
	return _round_icon_action("res://assets/icons/btn_back.png", box, Color("#fdf3d8"))


static func _round_icon_action(icon: String, box: float, tint: Color = Color("#fdf3d8")) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(box, box)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := ArtL.gold_ring(box, maxf(4.0, box * 0.055), tint)
	holder.add_child(ring)
	var icon_rect := TextureRect.new()
	icon_rect.texture = load(icon)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.position = Vector2(box * 0.19, box * 0.19)
	icon_rect.size = Vector2(box * 0.62, box * 0.62)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon_rect)
	holder.set_meta("icon_rect", icon_rect)
	return holder


## پلاک چوبی تیتر صفحه با سایه و برچسب
static func title_plaque(text: String, size: Vector2 = Vector2(520, 116), font_size: int = 46) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := ArtL.wooden_panel(size, 30, 9)
	holder.add_child(panel)
	var l := outlined_label(text, font_size, Color("#fff0cd"), Color("#3f2609"), 7)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_top = -5
	holder.add_child(l)
	return holder


## قرصِ سکهٔ گرافیکی با دکمهٔ + برجسته؛ مقدارش با set_meta("value_label") به‌روز می‌شود
static func coin_pill(size: Vector2 = Vector2(300, 104), show_plus: bool = true) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ArtL.glass_pill(size, Color("#fff4d6"), int(size.y * 0.5)))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)

	var plus := Label.new()
	plus.text = "+"
	plus.add_theme_font_override("font", load(FONT_BLACK))
	plus.add_theme_font_size_override("font_size", int(size.y * 0.46))
	plus.add_theme_color_override("font_color", Color("#2f7a1c"))
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if show_plus:
		row.add_child(plus)

	var val := label("۰", int(size.y * 0.38), Color("#6b4a12"), FONT_BLACK)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)

	var coin := TextureRect.new()
	coin.texture = load("res://assets/icons/coin.png")
	coin.custom_minimum_size = Vector2(size.y * 0.64, size.y * 0.64)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin)

	holder.set_meta("value_label", val)
	return holder


## کارت آواتار + نام + سطح + نوار XP
static func player_card(size: Vector2 = Vector2(470, 128)) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ArtL.glass_pill(size, Color("#fff6e2"), int(size.y * 0.42)))

	var avatar := ArtL.gold_ring(size.y - 18, 5, Color("#fdf3d8"))
	avatar.position = Vector2(9, 9)
	holder.add_child(avatar)
	var clip := Control.new()
	clip.position = Vector2(13, 13)
	clip.size = Vector2(size.y - 26, size.y - 26)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := TextureRect.new()
	ph.texture = load("res://assets/art/char_oldman.png")
	ph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(ph)
	holder.add_child(clip)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 10)
	name_row.position = Vector2(size.y + 2, 12)
	name_row.size = Vector2(size.x - size.y - 18, 46)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(name_row)

	var name_l := right_label("کاربر عزیز", 33, Color("#4a3117"))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_row.add_child(name_l)
	holder.set_meta("name_label", name_l)

	var lvl := ArtL.badge_count("۱")
	lvl.custom_minimum_size = Vector2(48, 48)
	name_row.add_child(lvl)
	holder.set_meta("level_badge", lvl)

	var xp := ArtL.progress_bar(Vector2(size.x - size.y - 18, 26), 0.0)
	xp.position = Vector2(size.y - 14, size.y - 42)
	holder.add_child(xp)
	holder.set_meta("xp_bar", xp)
	return holder


## نوار پایین با ۵ تب بزرگ، تب فعال برجسته و درخشان
static func bottom_nav(items: Array, current: int, on_tap: Callable,
		size: Vector2 = Vector2(1080, 214)) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_PASS

	var bar := TextureRect.new()
	bar.texture = ArtL.rounded_texture(int(size.x), int(size.y), 40,
		Color("#fff8e8"), Color("#eed7ac"), Color("#c9a86a"), 3.0, 0.22, 0.18)
	bar.size = size
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)

	var shadow := TextureRect.new()
	shadow.texture = ArtL.rounded_texture(int(size.x), int(size.y), 40,
		Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.28))
	shadow.size = size
	shadow.position = Vector2(0, -8)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow)
	holder.move_child(shadow, 0)

	var n := items.size()
	var cell := size.x / float(n)
	for i in n:
		var it: Dictionary = items[i]
		var cell_c := Vector2(cell * (float(i) + 0.5), size.y * 0.54)
		var active := i == current
		var box := 96.0 if not active else 132.0

		if active:
			var glow := ArtL.glow_disc(box * 1.9, Color("#ffd876"))
			glow.position = cell_c - glow.size * 0.5
			holder.add_child(glow)

		var icon_holder := Control.new()
		icon_holder.size = Vector2(box, box)
		icon_holder.position = cell_c - Vector2(box, box) * 0.5 - (Vector2(0, 22) if active else Vector2.ZERO)
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if active:
			var plate := ArtL.gold_ring(box + 16, 7, Color("#fff2cf"))
			plate.position = Vector2(-8, -8)
			icon_holder.add_child(plate)

		var ic := TextureRect.new()
		ic.texture = load(String(it["icon"]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(box * 0.14, box * 0.14)
		ic.size = Vector2(box * 0.72, box * 0.72)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(ic)
		holder.add_child(icon_holder)

		var cap := label(String(it.get("label", "")), 27 if not active else 30,
			Color("#6b4a12") if active else Color("#8a7048"), FONT_BLACK)
		cap.size = Vector2(cell, 40)
		cap.position = Vector2(cell * float(i), size.y - 52)
		holder.add_child(cap)

		# hit area
		var hit := Control.new()
		hit.position = Vector2(cell * float(i), 0)
		hit.size = Vector2(cell, size.y)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
				Audio.play("tap")
				Audio.vibrate(10)
				if idx != current:
					on_tap.call(idx))
		holder.add_child(hit)

		if active:
			var tw := icon_holder.create_tween().set_loops()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(icon_holder, "position:y", icon_holder.position.y - 8, 1.1)
			tw.tween_property(icon_holder, "position:y", icon_holder.position.y, 1.1)
	return holder


# ================================================================ components
static func star_row(stars: int, icon_size: float = 44.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var s := TextureRect.new()
		s.texture = load("res://assets/icons/star_gold.png" if i < stars
			else "res://assets/icons/star_grey.png")
		s.custom_minimum_size = Vector2(icon_size, icon_size)
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(s)
	return hb


static func make_toast(msg: String) -> Control:
	var holder := Control.new()
	holder.z_index = 100
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(msg, 32, Color.WHITE)
	var w: float = clampf(ArtL.text_width(msg, 32) + 96.0, 300.0, 900.0)
	var size := Vector2(w, 84)
	holder.custom_minimum_size = size
	holder.size = size
	var bg := TextureRect.new()
	bg.texture = ArtL.rounded_texture(int(size.x), int(size.y), 34,
		Color(0.16, 0.10, 0.04, 0.94), Color(0.09, 0.05, 0.02, 0.94), GOLD_DARK, 3.0, 0.10)
	bg.size = size
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(l)
	holder.modulate.a = 0.0
	var tw := holder.create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.16)
	tw.tween_interval(1.5)
	tw.tween_property(holder, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): if is_instance_valid(holder): holder.queue_free())
	return holder


## Adds a gentle idle bob to any control (used for characters / CTA buttons).
static func idle_bob(node: Control, amount: float = 8.0, time: float = 1.6) -> void:
	var base := node.position.y
	var tw := node.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base - amount, time * 0.5)
	tw.tween_property(node, "position:y", base, time * 0.5)


static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.7, 0.7)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector2.ONE, 0.42)
	tw.parallel().tween_property(node, "modulate:a", 1.0, 0.28)


## قطره‌های نور شناور (گرده/غبار طلایی) — جانِ پس‌زمینه
static func ambient_motes(bounds: Vector2, amount: int = 30, from_bottom: bool = true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(bounds.x * 0.5, bounds.y if from_bottom else 0.0)
	p.emitting = true
	p.amount = amount
	p.lifetime = 10.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(bounds.x * 0.55, 12)
	p.direction = Vector2(0.22, -1)
	p.spread = 26.0
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 66.0
	p.gravity = Vector2(5, -12)
	p.scale_amount_min = 1.6
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.96, 0.78, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 0.86, 0.0))
	grad.set_color(1, Color(1, 1, 0.86, 0.0))
	grad.add_point(0.22, Color(1, 0.98, 0.86, 0.6))
	grad.add_point(0.78, Color(1, 0.98, 0.86, 0.5))
	p.color_ramp = grad
	p.z_index = -1
	return p


# ========================================================== cards & sections
## کارتِ گرافیکی (کاغذی/چوبی) با لایهٔ محتوا؛ با card_add پر می‌شود
static func card(size: Vector2, radius: int = 30, base: Color = CREAM,
		wooden: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(ArtL.wooden_panel(size, radius, 10) if wooden
		else ArtL.card_panel(size, radius, base))
	var inner := Control.new()
	inner.name = "Inner"
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(inner)
	return holder


static func card_add(card_node: Control, node: Control, margin: float = 26.0) -> void:
	var inner := card_node.get_node("Inner")
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = margin
	node.offset_right = -margin
	node.offset_top = margin
	node.offset_bottom = -margin
	inner.add_child(node)


## سرتیتر بخش با خط طلایی دو طرف
static func section_header(text: String, width: float = 900.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 74)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := outlined_label(text, 38, Color("#fff3d2"), Color("#4a2c10"), 7)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(l)
	var line := TextureRect.new()
	line.texture = ArtL.rounded_texture(256, 8, 4, GOLD, GOLD_DARK)
	line.position = Vector2(0, 70)
	line.size = Vector2(width, 5)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.modulate.a = 0.75
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder


## کاشی آماری (برای پروفایل/ماموریت‌ها)
static func stat_tile(size: Vector2, value: String, caption: String, icon: String = "",
		accent: Color = GREEN) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ArtL.card_panel(size, 26, CREAM))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	if icon != "":
		var ic := TextureRect.new()
		ic.texture = load(icon)
		ic.custom_minimum_size = Vector2(size.y * 0.5, size.y * 0.5)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var v := label(value, int(size.y * 0.32), accent, FONT_BLACK)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.position = Vector2(size.y * 0.6, size.y * 0.16)
	v.size = Vector2(size.x - size.y * 0.8, size.y * 0.40)
	v.clip_text = true
	holder.add_child(v)
	var c := label(caption, int(size.y * 0.19), INK_SOFT)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.position = Vector2(size.y * 0.6, size.y * 0.58)
	c.size = Vector2(size.x - size.y * 0.8, size.y * 0.26)
	c.clip_text = true
	holder.add_child(c)
	return holder
