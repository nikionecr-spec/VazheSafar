extends RefCounted
class_name UIKit
## Shared visual language of Vazhe Safar.
##
## Design goals (v1.1 "soft-premium"):
##   * nothing reads as a flat cartoon: real vertical gradients, thin light rims,
##     soft large-radius shadows, glass highlights
##   * everything is finger-sized (>= 120 px) — no tiny controls on a 1080p canvas
##   * one warm, calm palette; greens are only used for affirmative actions
##   * RTL first: helpers default to right alignment

const FONT_BLACK := "res://assets/fonts/Vazirmatn-Black.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"
const FONT_MED := "res://assets/fonts/Vazirmatn-Medium.ttf"

# ------------------------------------------------------------------ palette
const CREAM := Color("#fdf6e6")
const CREAM_DEEP := Color("#f0e2c4")
const INK := Color("#4a3520")
const INK_SOFT := Color("#8a7051")

const GOLD := Color("#f4c766")
const GOLD_DEEP := Color("#d69b3a")
const AMBER := Color("#f0a93a")
const AMBER_DEEP := Color("#c07a17")

const GREEN := Color("#6cc03f")
const GREEN_DEEP := Color("#3f8a1e")
const GREEN_DARK := Color("#2f6a15")

const SKY := Color("#5aa9e6")
const SKY_DEEP := Color("#2f74ad")
const PLUM := Color("#8d7bd4")
const PLUM_DEEP := Color("#5b4a9e")

const WOOD := Color("#9a6438")
const WOOD_DEEP := Color("#6b4123")

const TEXT_DARK := INK


static func _ready_palette() -> void:
	pass


# ------------------------------------------------------------------ helpers
static func label(text: String, size: int = 34, color: Color = INK,
		font: String = FONT_BOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# long strings must be able to wrap, otherwise a label's minimum width
	# pushes whole cards out of their container
	if text.length() > 16:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# wrapped text must also be allowed to grow, otherwise a container
		# squeezes it down to one letter per line
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func right_label(text: String, size: int = 34, color: Color = TEXT_DARK,
		font: String = FONT_BOLD) -> Label:
	var l := label(text, size, color, font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


static func outlined_label(text: String, size: int = 40,
		color: Color = Color.WHITE, outline: Color = Color("#3d2a14"),
		outline_size: int = 8) -> Label:
	var l := label(text, size, color, FONT_BLACK)
	l.add_theme_constant_override("outline_size", outline_size)
	l.add_theme_color_override("font_outline_color", outline)
	return l


## soft drop shadow helper — one shared look for every floating element
static func shadow(owner: Control, size: float = 18.0, alpha: float = 0.30,
		offset := Vector2(0, 8)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, alpha)
	sb.set_corner_radius_all(40)
	sb.shadow_color = Color(0, 0, 0, 0)
	owner.add_theme_stylebox_override("panel", sb)
	sb.shadow_size = int(size)
	sb.shadow_offset = offset


# ============================================================ gradient baking
## Generates a rounded rectangle texture with a real vertical gradient, a light
## rim on top, a darker rim on the bottom and optional inner gloss. Results are
## cached, so repeated buttons cost nothing after the first build.
static var _tex_cache: Dictionary = {}


static func gradient_tex(w: int, h: int, radius: int, top: Color, bottom: Color,
		rim_top: Color = Color(1, 1, 1, 0.35), rim_bottom: Color = Color(0, 0, 0, 0.18),
		border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		gloss: float = 0.16, ss: int = 2) -> ImageTexture:
	w = maxi(w, 4)
	h = maxi(h, 4)
	var key := "%d_%d_%d_%s_%s_%s_%s_%s_%d_%.2f_%d" % [w, h, radius,
		top.to_html(), bottom.to_html(), rim_top.to_html(), rim_bottom.to_html(),
		border.to_html(), border_w, gloss, ss]
	if _tex_cache.has(key):
		return _tex_cache[key]

	var W := w * ss
	var H := h * ss
	var R := float(radius) * float(ss)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bw := float(border_w) * float(ss)
	var rad := Vector2(W, H) * 0.5
	var box := Vector2(W, H) * 0.5 - Vector2.ONE * 0.5
	for y in H:
		var fy := float(y) / float(maxi(H - 1, 1))
		var base: Color = top.lerp(bottom, pow(fy, 0.92))
		for x in W:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - rad
			var d := _sd_round_rect(p, box, R)
			var cov: float = clampf(0.5 - d, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var col := base
			# top light rim / bottom shade rim inside the shape
			if d > -2.6 * float(ss):
				col = col.lerp(rim_top, 0.85)
			if y > H - int(3.0 * float(ss)):
				col = col.lerp(rim_bottom, 0.5)
			# glossy sheen across the upper half
			if gloss > 0.0 and fy < 0.52:
				var g: float = (1.0 - fy / 0.52)
				col = col.lerp(Color(1, 1, 1, 1), g * gloss)
			if border_w > 0 and d > -bw:
				col = border
			col.a *= cov
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


static func _sd_round_rect(p: Vector2, box: Vector2, r: float) -> float:
	var q := Vector2(absf(p.x) - box.x + r, absf(p.y) - box.y + r)
	var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()
	return outside + minf(maxf(q.x, q.y), 0.0) - r


# ================================================================ components
## A gradient panel of an exact pixel size (used for buttons, pills, bars).
static func gradient_panel(w: int, h: int, top: Color, bottom: Color,
		radius: int = 28, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		gloss: float = 0.16) -> TextureRect:
	var t := TextureRect.new()
	t.texture = gradient_tex(w, h, radius, top, bottom, Color(1, 1, 1, 0.38),
		Color(0, 0, 0, 0.22), border, border_w, gloss)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(w, h)
	t.size = Vector2(w, h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Soft cream "paper" card: gradient, delicate rim, generous padding.
static func paper_card(radius: int = 34, pad: int = 28) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.28, 0.18, 0.08, 0.28)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = int(pad * 0.75)
	sb.content_margin_bottom = int(pad * 0.75)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Deep coloured card used on top of artwork (frosted look, no hard outline).
static func glass_card(radius: int = 34, tint: Color = Color(0.36, 0.22, 0.08, 0.72),
		pad: int = 26) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.22)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = int(pad * 0.6)
	sb.content_margin_bottom = int(pad * 0.6)
	p.add_theme_stylebox_override("panel", sb)
	return p


# ---------------------------------------------------- backwards compatibility
static func wood_panel(radius: int = 26, border: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(radius)
	sb.border_color = GOLD
	sb.set_border_width_all(maxi(border, 2))
	sb.shadow_color = Color(0, 0, 0, 0.34)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	return sb


static func cream_panel(radius: int = 26) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.28, 0.18, 0.08, 0.26)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 7)
	return sb


static func gold_pill(radius: int = 30) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff2cf")
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.3, 0.2, 0.05, 0.22)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


# ------------------------------------------------------------------- buttons
static func _btn_style(top: Color, bottom: Color, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bottom.darkened(0.08) if pressed else top.lerp(bottom, 0.55)
	sb.set_corner_radius_all(30)
	sb.border_color = top.lightened(0.25) if not pressed else bottom.darkened(0.1)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.30 if not pressed else 0.12)
	sb.shadow_size = 0 if pressed else 12
	sb.shadow_offset = Vector2(0, 0 if pressed else 5)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


static func green_button_style(pressed: bool = false) -> StyleBoxFlat:
	return _btn_style(GREEN, GREEN_DEEP, pressed)


static func green_button(text: String, font_size: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", load(FONT_BLACK))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("#eaffdc"))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", GREEN_DARK)
	b.add_theme_stylebox_override("normal", _btn_style(GREEN, GREEN_DEEP, false))
	b.add_theme_stylebox_override("hover", _btn_style(GREEN.lightened(0.05), GREEN_DEEP, false))
	b.add_theme_stylebox_override("pressed", _btn_style(GREEN, GREEN_DEEP, true))
	var ds := _btn_style(Color("#c9c3b4"), Color("#a49d8c"), true)
	b.add_theme_stylebox_override("disabled", ds)
	b.add_theme_color_override("font_disabled_color", Color("#f6f2e7"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	juice(b)
	gloss(b, 0.20)
	return b


static func alt_button(text: String, top: Color, bottom: Color, font_size: int = 38) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", load(FONT_BLACK))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", bottom.darkened(0.35))
	b.add_theme_stylebox_override("normal", _btn_style(top, bottom, false))
	b.add_theme_stylebox_override("hover", _btn_style(top.lightened(0.05), bottom, false))
	b.add_theme_stylebox_override("pressed", _btn_style(top, bottom, true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	juice(b)
	gloss(b, 0.20)
	return b


## Adds press-squash / elastic-release / sound / haptics to any BaseButton.
static func juice(b: BaseButton, squash: float = 0.94) -> void:
	if b.has_meta("juiced"):
		return
	b.set_meta("juiced", true)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(squash + 0.02, squash - 0.02), 0.07)
		Audio.play("btn_down")
		Audio.vibrate(12))
	b.button_up.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.30)
		Audio.play("btn_up"))


## Soft glossy highlight overlay so filled buttons read as rounded 3D objects.
static func gloss(b: Control, alpha: float = 0.20) -> void:
	b.clip_contents = true
	var g := Panel.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_preset(Control.PRESET_TOP_WIDE)
	g.anchor_bottom = 0.46
	g.offset_left = 8
	g.offset_right = -8
	g.offset_top = 6
	g.offset_bottom = 0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	g.add_theme_stylebox_override("panel", sb)
	b.add_child(g)


static func icon_button(tex_path: String, box: float = 110.0) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(tex_path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(box, box)
	b.size = Vector2(box, box)
	return b


# ------------------------------------------------------------------ HUD bits
## Top-of-screen currency pill: gradient glass, icon, big readable number.
static func currency_pill(icon_path: String, text: String, size := Vector2(300, 108),
		tint := Color("#fff3d2")) -> Control:
	var holder := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(int(size.y * 0.5))
	sb.border_color = Color(1, 1, 1, 0.65)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.3, 0.2, 0.05, 0.25)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 16
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	holder.custom_minimum_size = size
	holder.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "Row"
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ic := TextureRect.new()
	ic.texture = load(icon_path)
	ic.custom_minimum_size = Vector2(size.y * 0.70, size.y * 0.70)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ic)

	var l := label(text, int(size.y * 0.42), INK, FONT_BLACK)
	l.name = "Value"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(l)
	holder.add_child(hb)
	return holder


static func pill_label(text: String, size: int = 26) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.19, 0.07, 0.82)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, size, Color("#fff0cf")))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# --------------------------------------------------------------- bottom nav
const NAV_ICONS := {
	"home": "res://assets/icons/home.png",
	"library": "res://assets/icons/book.png",
	"quests": "res://assets/icons/quests.png",
	"shop": "res://assets/icons/shop.png",
	"themes": "res://assets/icons/themes.png",
	"settings": "res://assets/icons/settings.png",
}


## Big, always-visible bottom navigation. Keeps every screen finger-reachable
## and removes the empty band at the bottom of the layout.
static func bottom_nav(items: Array, current: String, handler: Callable,
		height: float = 210.0) -> Control:
	var holder := Control.new()
	holder.name = "BottomNav"
	holder.custom_minimum_size = Vector2(0, height)
	holder.size = Vector2(1080, height)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a2413")
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, -8)
	sb.border_color = Color(1, 0.85, 0.55, 0.35)
	sb.border_width_top = 2
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 10
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)

	var cell_w: float = 1080.0 / float(maxi(items.size(), 1))
	for it in items:
		var key := String(it)
		var active := key == current
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(cell_w, height - 22)
		cell.size = Vector2(cell_w, height - 22)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP

		var icon_size: float = 104.0 if active else 86.0
		var ic := TextureRect.new()
		ic.texture = load(String(NAV_ICONS.get(key, NAV_ICONS["home"])))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(icon_size, icon_size)
		ic.size = ic.custom_minimum_size
		ic.position = Vector2((cell_w - icon_size) * 0.5, 24 if active else 34)
		ic.pivot_offset = ic.size * 0.5
		ic.modulate = Color.WHITE if active else Color(0.82, 0.82, 0.86, 0.72)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ic)

		var captions := {
			"home": "خانه", "library": "کتابخانه", "quests": "ماموریت‌ها",
			"shop": "فروشگاه", "themes": "تم‌ها", "settings": "تنظیمات",
		}
		var cap := label(String(captions.get(key, "")), 27 if active else 25,
			Color("#ffdf9b") if active else Color(0.85, 0.83, 0.80, 0.72))
		cap.size = Vector2(cell_w, 34)
		cap.position = Vector2(0, icon_size + (10 if active else 18))
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cap)

		if active:
			var indicator := gradient_panel(120, 10, Color("#ffe6a8"), Color("#f0b24a"), 5)
			indicator.position = Vector2((cell_w - 120) * 0.5, 4)
			cell.add_child(indicator)
			var glow := CPUParticles2D.new()
			glow.position = Vector2(cell_w * 0.5, 74)
			glow.emitting = true
			glow.amount = 8
			glow.lifetime = 1.6
			glow.preprocess = 1.0
			glow.spread = 55.0
			glow.gravity = Vector2(0, -18)
			glow.initial_velocity_min = 10.0
			glow.initial_velocity_max = 34.0
			glow.scale_amount_min = 1.6
			glow.scale_amount_max = 3.6
			glow.color = Color(1.0, 0.88, 0.55, 0.6)
			cell.add_child(glow)

		if not active:
			cell.gui_input.connect(func(e: InputEvent) -> void:
				if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
					Audio.play("tab")
					Audio.vibrate(10)
					var tw := cell.create_tween().set_trans(Tween.TRANS_BACK)
					tw.set_ease(Tween.EASE_OUT)
					tw.tween_property(ic, "scale", Vector2(1.18, 1.18), 0.10)
					tw.tween_property(ic, "scale", Vector2.ONE, 0.22)
					handler.call(key))
		row.add_child(cell)
	return holder


# ------------------------------------------------------------------ misc fx
static func make_toast(msg: String, size: int = 32) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.10, 0.04, 0.92)
	sb.set_corner_radius_all(24)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_border_width_all(1)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(msg, size, Color.WHITE))
	p.modulate.a = 0.0
	p.z_index = 100
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): if is_instance_valid(p): p.queue_free())
	return p


static func idle_bob(node: Control, amount: float = 8.0, time: float = 1.6) -> void:
	var base := node.position.y
	var tw := node.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base - amount, time * 0.5)
	tw.tween_property(node, "position:y", base, time * 0.5)


static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.86, 0.86)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector2.ONE, 0.36)
	tw.parallel().tween_property(node, "modulate:a", 1.0, 0.24)


## Soft radial glow disc — used behind heroes, CTA buttons and avatar frames.
static func glow_tex(radius: int, color: Color, power: float = 2.2) -> ImageTexture:
	var key := "glow_%d_%s_%.2f" % [radius, color.to_html(), power]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var R := radius
	var img := Image.create(R * 2, R * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(R, R)
	for y in R * 2:
		for x in R * 2:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c) / float(R)
			if d >= 1.0:
				continue
			var a: float = pow(1.0 - d, power)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


static func glow(radius: int, color: Color, power: float = 2.2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = glow_tex(radius, color, power)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(radius * 2, radius * 2)
	t.size = t.custom_minimum_size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
