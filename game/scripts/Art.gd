extends RefCounted
class_name Art
## ============================================================================
##  آرت پروسیدورال واژه‌سفر — کتابخانهٔ رسم گرافیکی
##  همهٔ پنل‌ها، دکمه‌ها، قاب‌ها و درخشش‌ها به‌صورت تصویر واقعی (نه StyleBox تخت)
##  در زمان اجرا ساخته و کش می‌شوند: گرادیان، لبهٔ سه‌بعدی، گلاس، خط طلایی.
##  هدف: حس «گرافیکی نرم و گران» به‌جای تخت و کارتونی.
## ============================================================================

# ------------------------------------------------------------------ palette
const WOOD_LIT := Color("#a06a3a")
const WOOD := Color("#8a5527")
const WOOD_DARK := Color("#5d3714")
const GOLD_LIT := Color("#ffe6a3")
const GOLD := Color("#f2c14e")
const CREAM_LIT := Color("#fffaf0")
const CREAM := Color("#f7ecd6")
const CREAM_DARK := Color("#e6d3ae")
const INK := Color("#4a3117")
const INK_SOFT := Color("#7b5c34")
const GREEN_LIT := Color("#7fd45a")
const GREEN := Color("#4cb02f")
const GREEN_DARK := Color("#2f7a1c")
const BLUE := Color("#4a9ae0")
const BLUE_DARK := Color("#255f96")
const RED := Color("#ec6a5a")
const RED_DARK := Color("#b23a2c")
const AMBER := Color("#f7b731")
const AMBER_DARK := Color("#c17c12")
const PURPLE := Color("#9a7bd6")
const PURPLE_DARK := Color("#5f4699")

static var _CACHE: Dictionary = {}


static func _c(key: String) -> Texture2D:
	return _CACHE.get(key)


## ---------------------------------------------------------------- core image
## یک مستطیل گرد با گرادیان عمودی، لبهٔ تیره، گلاس بالای کار و سایهٔ داخلی
static func rounded_texture(w: int, h: int, radius: int, top: Color, bottom: Color,
		border: Color = Color(0, 0, 0, 0), border_w: float = 0.0,
		gloss: float = 0.0, inner_shade: float = 0.0) -> Texture2D:
	var key := "rr_%d_%d_%d_%s_%s_%s_%.1f_%.2f_%.2f" % [w, h, radius, top.to_html(), bottom.to_html(),
		border.to_html(), border_w, gloss, inner_shade]
	var cached := _c(key)
	if cached != null:
		return cached

	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := float(radius)
	var fw := float(w)
	var fh := float(h)
	var bw := border_w
	for y in h:
		var fy := float(y) + 0.5
		# vertical gradient factor
		var gy: float = fy / fh
		var col: Color = top.lerp(bottom, gy)
		if inner_shade > 0.0:
			# soft inner shadow at the bottom inside the shape
			var sh: float = clampf((gy - 0.55) / 0.45, 0.0, 1.0)
			col = col.lerp(bottom.darkened(0.35), sh * inner_shade)
		for x in w:
			var fx := float(x) + 0.5
			# rounded-rect signed distance
			var dx: float = maxf(maxf(r - fx, fx - (fw - r)), 0.0)
			var dy: float = maxf(maxf(r - fy, fy - (fh - r)), 0.0)
			var d: float = sqrt(dx * dx + dy * dy) - r
			var a: float = clampf(0.5 - d, 0.0, 1.0)
			if a <= 0.001:
				continue
			var c := col
			if bw > 0.0:
				# border ring: darken near the edge
				var edge_t: float = clampf(1.0 - (d + bw) / maxf(bw, 0.001), 0.0, 1.0)
				if d > -bw:
					c = c.lerp(border, edge_t)
			if gloss > 0.0:
				var gl: float = 1.0 - clampf(fy / (fh * 0.46), 0.0, 1.0)
				var band: float = clampf(1.0 - d / (r + 2.0), 0.0, 1.0)
				c = c.lerp(Color(1, 1, 1, 1), pow(gl, 1.6) * gloss * (0.55 + 0.45 * band))
			c.a = a
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_CACHE[key] = tex
	return tex


## دایرهٔ نرم با گرادیان شعاعی (برای هاله، سکه، نور)
static func radial_texture(size: int, inner: Color, outer: Color) -> Texture2D:
	var key := "rad_%d_%s_%s" % [size, inner.to_html(), outer.to_html()]
	var cached := _c(key)
	if cached != null:
		return cached
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length() / c
			if d > 1.0:
				continue
			var t: float = clampf(d, 0.0, 1.0)
			var col: Color = inner.lerp(outer, pow(t, 1.35))
			col.a = clampf((1.0 - t) * 1.25, 0.0, 1.0) * inner.a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_CACHE[key] = tex
	return tex


## دستمال کاغذی/پارچه: بافت نویزی خیلی ملایم برای حس «کاغذ واقعی»
static func paper_texture(w: int, h: int, base: Color, radius: int = 28, grain: float = 0.045) -> Texture2D:
	var key := "pap_%d_%d_%s_%d_%.3f" % [w, h, base.to_html(), radius, grain]
	var cached := _c(key)
	if cached != null:
		return cached
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := float(radius)
	for y in h:
		for x in w:
			var fx := float(x) + 0.5
			var fy := float(y) + 0.5
			var dx: float = maxf(maxf(r - fx, fx - (float(w) - r)), 0.0)
			var dy: float = maxf(maxf(r - fy, fy - (float(h) - r)), 0.0)
			var d: float = sqrt(dx * dx + dy * dy) - r
			var a: float = clampf(0.5 - d, 0.0, 1.0)
			if a <= 0.001:
				continue
			var n: float = rng.randf_range(-grain, grain)
			var edge: float = clampf((-d) / 12.0, 0.0, 1.0)
			var col: Color = base.lightened(maxf(n, 0.0)).darkened(maxf(-n, 0.0))
			col = col.darkened((1.0 - edge) * 0.06)
			col.a = a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_CACHE[key] = tex
	return tex


## براقی نرم بالای عناصر: سفید → محو، با محو شدن پایین
static func gloss_texture(w: int, h: int, radius: int = 22, alpha: float = 0.22) -> Texture2D:
	var key := "gl_%d_%d_%d_%.2f" % [w, h, radius, alpha]
	var cached := _c(key)
	if cached != null:
		return cached
	var img := Image.create(maxi(w, 8), maxi(h, 8), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := float(radius)
	for y in h:
		for x in w:
			var fx := float(x) + 0.5
			var fy := float(y) + 0.5
			var dx: float = maxf(maxf(r - fx, fx - (float(w) - r)), 0.0)
			var dy: float = maxf(maxf(r - fy, fy - (float(h) - r)), 0.0)
			var d: float = sqrt(dx * dx + dy * dy) - r
			var a: float = clampf(0.5 - d, 0.0, 1.0)
			if a <= 0.001:
				continue
			var k: float = fy / float(h)
			var band: float = pow(1.0 - k, 1.7) * (1.0 - 0.35 * k)
			img.set_pixel(x, y, Color(1, 1, 1, sin(PI * clampf(k, 0.0, 1.0)) * 0.35 + 0.65)
				* Color(1, 1, 1, alpha * band))
	var tex := ImageTexture.create_from_image(img)
	_CACHE[key] = tex
	return tex


## نوارِ کوچک مدور (ریبون/برچسب)
static func ribbon_texture(w: int, h: int, color: Color) -> Texture2D:
	var key := "rib_%d_%d_%s" % [w, h, color.to_html()]
	var cached := _c(key)
	if cached != null:
		return cached
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rr := 12.0
	for y in h:
		for x in w:
			var fy := float(y) + 0.5
			var fx: float = float(x) + 0.5
			var dx: float = maxf(maxf(rr - fx, fx - (float(w) - rr)), 0.0)
			var dy: float = maxf(maxf(rr - fy, fy - (float(h) - rr)), 0.0)
			var dd: float = sqrt(dx * dx + dy * dy) - rr
			var aa: float = clampf(0.5 - dd, 0.0, 1.0)
			if aa <= 0.002:
				continue
			var gy: float = fy / float(h)
			var col: Color = color.lightened(0.16 * (1.0 - gy)).darkened(0.10 * gy)
			# gold hairline top
			if fy < 2.0:
				col = col.lerp(GOLD_LIT, 0.5)
			col.a = aa
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_CACHE[key] = tex
	return tex


## ------------------------------------------------------------- widgets (UI)
## پنل چرمی/چوبی با لبهٔ طلایی، سایه و بافت — جایگزین StyleBox تخت
static func wooden_panel(size: Vector2, radius: int = 26, depth: int = 10,
		top: Color = WOOD_LIT, bottom: Color = WOOD_DARK) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var side := TextureRect.new()
	side.texture = rounded_texture(int(maxf(size.x, 8)), int(maxf(size.y, 8)), radius,
		bottom.darkened(0.25), bottom.darkened(0.5))
	side.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	side.stretch_mode = TextureRect.STRETCH_SCALE
	side.position = Vector2(0, depth * 0.55)
	side.size = size
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(side)

	var face := TextureRect.new()
	face.texture = rounded_texture(int(maxf(size.x, 8)), int(maxf(size.y, 8)), radius,
		top, bottom, GOLD.darkened(0.25), maxf(2.0, float(radius) * 0.18), 0.18, 0.16)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.size = size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	return holder


## کارت کرم/کاغذی با لبهٔ نازک و سایهٔ نرم
static func card_panel(size: Vector2, radius: int = 30, base: Color = CREAM) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := TextureRect.new()
	sh.texture = rounded_texture(int(maxf(size.x, 8)), int(maxf(size.y, 8)), radius,
		Color(0, 0, 0, 0.30), Color(0, 0, 0, 0.30))
	sh.position = Vector2(0, 6)
	sh.size = size
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(sh)
	var face := TextureRect.new()
	face.texture = paper_texture(int(maxf(size.x, 16)), int(maxf(size.y, 16)), base, radius)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.size = size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	return holder


## اندازهٔ دقیق متن با فونت (برای چیدمان قطعی، بدون انتظار فریم)
static func text_width(text: String, font_size: int,
		font_path: String = "res://assets/fonts/Vazirmatn-Bold.ttf") -> float:
	var f: Font = load(font_path)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## برچسب متن روی نوار رنگی (captions، badges)
static func ribbon(text: String, font_size: int = 26, color: Color = WOOD_DARK,
		text_color: Color = Color("#fff3d6")) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Bold.ttf"))
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", text_color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pad := 34
	var w: float = text_width(text, font_size) + pad * 2.0
	var h := float(font_size) + 22.0
	lbl.size = Vector2(w, h)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)
	holder.size = Vector2(w, h)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.texture = ribbon_texture(int(w), int(h), color)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(w, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	lbl.size = Vector2.ZERO
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(lbl)
	return holder


## قرصِ شیشه‌ای برای HUD (سکه، نام، XP)
static func glass_pill(size: Vector2, tint: Color = CREAM_LIT, radius: int = 40) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := TextureRect.new()
	sh.texture = rounded_texture(int(size.x), int(size.y), radius,
		Color(0, 0, 0, 0.32), Color(0, 0, 0, 0.32))
	sh.position = Vector2(0, 5)
	sh.size = size
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(sh)
	var face := TextureRect.new()
	face.texture = rounded_texture(int(size.x), int(size.y), radius,
		tint, tint.darkened(0.16), GOLD.darkened(0.1), 3.0, 0.30, 0.10)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.size = size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	return holder


## قاب دایره‌ای طلایی برای آواتار/آیکون
static func gold_ring(diameter: float, ring: float = 6.0, fill: Color = CREAM_LIT) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	face.texture = radial_texture(int(maxf(diameter, 16)), fill, fill.darkened(0.30))
	face.size = holder.size
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	var ringp := Panel.new()
	ringp.set_anchors_preset(Control.PRESET_FULL_RECT)
	ringp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(int(diameter * 0.5))
	sb.set_border_width_all(int(ring))
	sb.border_color = GOLD
	ringp.add_theme_stylebox_override("panel", sb)
	holder.add_child(ringp)
	return holder


## سایهٔ بیضی زیر کاراکتر برای «نشستن» روی زمین/میز
static func ground_shadow(w: float, h: float, alpha: float = 0.34) -> TextureRect:
	var t := TextureRect.new()
	t.texture = radial_texture(128, Color(0.22, 0.12, 0.05, alpha), Color(0.22, 0.12, 0.05, 0))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(w, h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## حلقهٔ نور پشت عنصر مهم (CTA، گرهٔ فعلی، هدیه)
static func glow_disc(diameter: float, color: Color = GOLD_LIT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = radial_texture(128, Color(color.r, color.g, color.b, 0.55),
		Color(color.r, color.g, color.b, 0.0))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(diameter, diameter)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## نوار پیشرفت گرافیکی (XP / ماموریت) با درخشش
static func progress_bar(size: Vector2, ratio: float, top: Color = GREEN_LIT,
		bottom: Color = GREEN) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := TextureRect.new()
	track.texture = rounded_texture(int(size.x), int(size.y), int(size.y * 0.5),
		Color("#c9b184"), Color("#a98c5c"), Color("#8a7040"), 2.0, 0.0, 0.35)
	track.size = size
	track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track.stretch_mode = TextureRect.STRETCH_SCALE
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(track)
	var fillw: float = maxf(size.y * 1.05, size.x * clampf(ratio, 0.0, 1.0))
	var clip := Control.new()
	clip.size = Vector2(fillw, size.y)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(clip)
	var fill := TextureRect.new()
	fill.texture = rounded_texture(int(size.x), int(size.y), int(size.y * 0.5),
		top, bottom, bottom.darkened(0.35), 2.0, 0.35, 0.0)
	fill.size = size
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(fill)
	return holder


static func set_progress(bar: Control, ratio: float) -> void:
	if bar.get_child_count() < 2:
		return
	var sz: Vector2 = bar.size
	var clip: Control = bar.get_child(1)
	clip.size = Vector2(maxf(sz.y, sz.x * clampf(ratio, 0.0, 1.0)), sz.y)


## تیکهٔ سه‌بعدی حروف (کاشی) — نسخهٔ براق با گرادیان و لبهٔ روشن
static func tile_texture(px: int, base: Color, edge: Color, selected: bool = false) -> Texture2D:
	var key := "tile_%d_%s_%s_%d" % [px, base.to_html(), edge.to_html(), int(selected)]
	var cached := _c(key)
	if cached != null:
		return cached
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(px) * 0.5
	var r := c - 1.0
	var spec_c := Vector2(c - r * 0.30, c - r * 0.38)
	var spec_r := r * 0.66
	var bot := Vector2(c, c + r * 0.72)
	var bot_r := r * 0.95
	for y in px:
		for x in px:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d: float = p.distance_to(Vector2(c, c))
			if d > r:
				continue
			var a: float = clampf((r - d) / 1.6, 0.0, 1.0)
			var gy: float = (p.y / float(px))
			var col: Color = base.lightened(0.10 * (1.0 - gy)).lerp(base.darkened(0.18), gy)
			# rim light bottom (3D pill)
			var rim: float = clampf((d - (r * 0.72)) / (r * 0.28), 0.0, 1.0)
			col = col.lerp(edge, rim * 0.55)
			# specular highlight
			var sd: float = p.distance_to(spec_c)
			col = col.lerp(Color(1, 1, 1), clampf(1.0 - sd / spec_r, 0.0, 1.0) * 0.55)
			# bottom inner shade
			col = col.lerp(edge.darkened(0.25), clampf(1.0 - p.distance_to(bot) / bot_r, 0.0, 1.0) * 0.28)
			if selected:
				col = col.lightened(0.06)
			col.a = a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_CACHE[key] = tex
	return tex


## برچسب اعلان قرمز براق با شماره
static func badge_count(text: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(54, 54)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = radial_texture(64, RED.lightened(0.10), RED_DARK)
	t.size = holder.size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(t)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://assets/fonts/Vazirmatn-Black.ttf"))
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color("#8e1a12"))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	holder.set_meta("label", l)
	return holder

## چرخ حروفِ گرافیکی: گرادیان شعاعی، رینگ طلایی، پرچ‌ها و رگهٔ چوب ملایم
static func wheel_texture(px: int = 512) -> Texture2D:
	var key := "wheel_%d" % px
	var cached := _c(key)
	if cached != null:
		return cached
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(px) * 0.5
	var outer := c - 2.0
	var cream := Color("#fff2d8")
	var honey := Color("#d9a463")
	var oak := Color("#a9743a")
	for y in px:
		for x in px:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d: float = p.distance_to(Vector2(c, c))
			if d > outer + 1.0:
				continue
			var t: float = clampf(d / outer, 0.0, 1.0)
			# بدنهٔ چوبی/عسلی با گرادیان گرم
			var col: Color = cream.lerp(honey, pow(t, 1.35))
			col = col.lerp(oak, pow(clampf((t - 0.72) / 0.28, 0.0, 1.0), 1.2) * 0.85)
			# رگهٔ چوب ملایم
			var grain: float = sin(p.angle() * 9.0 + t * 22.0) * 0.5 + 0.5
			col = col.darkened(grain * 0.030 * smoothstep(0.30, 1.0, t))
			# سایهٔ داخلی نزدیک لبه
			col = col.darkened(clampf((t - 0.86) / 0.14, 0.0, 1.0) * 0.18)
			# رینگ طلایی
			if t > 0.905:
				var k: float = (t - 0.905) / 0.095
				var gold := Color("#f7dfa0").lerp(Color("#c99326"), k)
				col = gold
				if t > 0.975:
					col = Color("#8a6414")
				# پرچ‌ها
				var ang: float = p.angle()
				var rivet: float = absf(fmod(ang + PI, TAU / 8.0) - TAU / 16.0)
				if t > 0.925 and t < 0.965 and rivet < 0.055:
					col = Color("#ffe9b8")
			var a: float = clampf((outer - d) / 1.6, 0.0, 1.0)
			col.a = a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_CACHE[key] = tex
	return tex
