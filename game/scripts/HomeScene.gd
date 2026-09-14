extends Control
## Main menu — v1.2 layout pass.
##
## Composition rules (learned from how Amirza / Word Cookies compose a home):
##   * the hero artwork (seated grandfather + kitten) stays visible in the middle
##   * everything interactive lives in the top HUD or the bottom third, so the
##     player's thumbs never cover the art
##   * nothing is smaller than ~120 px; the bottom band is never empty: it holds
##     a big primary CTA, three action tiles and a full-width navigation bar
##   * rewards are always *visible*: chest countdown, daily badge, XP bar

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")
const IconBtn := preload("res://scripts/IconButton.gd")

const TOP := 36.0
const NAV_H := 208.0
const CTA_Y := 1326.0
const TILES_Y := 1506.0

var coin_label: Label
var name_label: Label
var level_badge: Label
var xp_bar: ProgressBar
var chest_strip: Control
var chest_label: Label
var chest_bar: ProgressBar
var cta: JuicyButton
var daily_tile: Control
var chest_tile: Control
var quests_tile: Control
var _chest_pulse_running := false
var _entrance: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	Game.coins_changed.connect(_on_coins_changed)
	Game.gems_changed.connect(func(_v): _refresh())
	Game.chest_changed.connect(func(_a, _b): _refresh())
	Audio.set_section("home")
	_entrance_anim()


# ==================================================================== build
func _build() -> void:
	_hero()
	_add_ambient_particles()
	_add_sun_rays()
	_build_top_bar()
	_build_logo_block()
	_build_chest_strip()
	_build_cta()
	_build_tiles()
	_build_nav()


# ------------------------------------------------------------------ artwork
func _hero() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_home.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# very slow drift so the illustration feels alive without looking wobbling
	bg.pivot_offset = Vector2(540, 960)
	var tw := bg.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bg, "scale", Vector2(1.018, 1.018), 9.0)
	tw.tween_property(bg, "scale", Vector2.ONE, 9.0)

	# readability scrims (top for the HUD, bottom for the controls)
	var top_scrim := UI.gradient_panel(1080, 320, Color(0.18, 0.10, 0.04, 0.62),
		Color(0.18, 0.10, 0.04, 0.0), 0, Color(0, 0, 0, 0), 0, 0.0)
	top_scrim.position = Vector2.ZERO
	add_child(top_scrim)
	var bot_scrim := UI.gradient_panel(1080, 760, Color(0.10, 0.05, 0.02, 0.0),
		Color(0.10, 0.05, 0.02, 0.78), 0, Color(0, 0, 0, 0), 0, 0.0)
	bot_scrim.position = Vector2(0, 1160)
	add_child(bot_scrim)


func _add_sun_rays() -> void:
	var rays := Control.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.set_script(preload("res://scripts/SunRays.gd"))
	rays.modulate.a = 0.55
	add_child(rays)

	add_child(UI.ambient_motes(UI.SCREEN, 34))

func _add_ambient_particles() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(540, 1960)
	p.emitting = true
	p.amount = 22
	p.lifetime = 11.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(560, 10)
	p.direction = Vector2(0.22, -1)
	p.spread = 20.0
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 62.0
	p.gravity = Vector2(5, -12)
	p.scale_amount_min = 1.8
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.96, 0.78, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 0.85, 0.0))
	grad.set_color(1, Color(1, 1, 0.85, 0.0))
	grad.add_point(0.25, Color(1, 0.98, 0.85, 0.6))
	grad.add_point(0.75, Color(1, 0.98, 0.85, 0.5))
	p.color_ramp = grad
	add_child(p)


# ------------------------------------------------------------------ top bar
func _build_top_bar() -> void:
	var gear := IconBtn.new()
	gear.icon_path = "res://assets/icons/settings.png"
	gear.icon_size = 132.0
	gear.float_phase = 0.3
	gear.position = Vector2(30, TOP + 6)
	gear.pressed.connect(func(): _go("res://scenes/SettingsScene.tscn", gear))
	add_child(gear)
	_entrance.append(gear)

	var pill := UI.currency_pill("res://assets/icons/coin.png",
		Game.fa_num_grouped(Game.coins), Vector2(310, 112))
	pill.position = Vector2(180, TOP + 12)
	coin_label = pill.get_node_or_null("Row/Value") as Label
	if coin_label == null:
		coin_label = _find_label(pill)
	var tap := Control.new()
	tap.position = pill.position
	tap.size = Vector2(310, 112)
	tap.mouse_filter = Control.MOUSE_FILTER_STOP
	tap.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_bump(tap)
			_go("res://scenes/ShopScene.tscn", tap))
	add_child(pill)
	add_child(tap)
	_entrance.append(pill)

	add_child(_profile_card())


func _find_label(node: Node) -> Label:
	for c in node.get_children():
		if c is Label:
			return c
		var r := _find_label(c)
		if r != null:
			return r
	return null


## Tappable player card: avatar, name, title, level ring and XP progress.
func _profile_card() -> Control:
	var holder := Control.new()
	holder.position = Vector2(546, TOP)
	holder.size = Vector2(504, 148)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	var face := UI.gradient_panel(504, 148, Color(0.28, 0.17, 0.07, 0.92),
		Color(0.16, 0.09, 0.03, 0.95), 36, Color(1, 0.86, 0.58, 0.35), 2, 0.12)
	holder.add_child(face)

	# avatar with a soft gold ring
	var ring := Panel.new()
	ring.position = Vector2(24, 20)
	ring.custom_minimum_size = Vector2(108, 108)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color("#f7e6c0")
	rs.set_corner_radius_all(54)
	rs.border_color = Color("#f4c766")
	rs.set_border_width_all(5)
	rs.shadow_color = Color(0, 0, 0, 0.35)
	rs.shadow_size = 8
	ring.add_theme_stylebox_override("panel", rs)
	var clip := Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.offset_left = 6
	clip.offset_top = 6
	clip.offset_right = -6
	clip.offset_bottom = -6
	clip.clip_contents = true
	var av := TextureRect.new()
	av.texture = load("res://assets/art/avatar_oldman.png")
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	av.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(av)
	ring.add_child(clip)
	holder.add_child(ring)

	name_label = UI.label(Game.player_name, 33, Color("#fff2d4"), UI.FONT_BLACK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.position = Vector2(150, 14)
	name_label.size = Vector2(330, 42)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(name_label)

	var sub := UI.label(Game.player_title(), 23, Color("#ffd98a"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub.position = Vector2(150, 56)
	sub.size = Vector2(330, 30)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(sub)

	# level chip sits on the avatar's shoulder so nothing overlaps the text
	level_badge = UI.label(Game.fa_num(Game.player_level), 26, Color.WHITE, UI.FONT_BLACK)
	level_badge.position = Vector2(6, 6)
	level_badge.size = Vector2(52, 52)
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_bg := Panel.new()
	badge_bg.position = Vector2(96, 82)
	badge_bg.custom_minimum_size = Vector2(56, 56)
	var bs := StyleBoxFlat.new()
	bs.bg_color = UI.SKY_DEEP
	bs.set_corner_radius_all(28)
	bs.border_color = Color("#f4c766")
	bs.set_border_width_all(3)
	bs.shadow_color = Color(0, 0, 0, 0.3)
	bs.shadow_size = 6
	badge_bg.add_theme_stylebox_override("panel", bs)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_bg.add_child(level_badge)
	holder.add_child(badge_bg)

	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(150, 100)
	xp_bar.custom_minimum_size = Vector2(330, 24)
	xp_bar.size = Vector2(330, 24)
	xp_bar.max_value = float(Game.XP_PER_LEVEL)
	xp_bar.value = float(Game.xp)
	xp_bar.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.40)
	bgs.set_corner_radius_all(12)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("#f5b820")
	fgs.set_corner_radius_all(12)
	xp_bar.add_theme_stylebox_override("background", bgs)
	xp_bar.add_theme_stylebox_override("fill", fgs)
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(xp_bar)

	var chev := UI.label("›", 40, Color("#ffdf9b"))
	chev.position = Vector2(8, 40)
	chev.size = Vector2(36, 44)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(chev)

	holder.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_bump(holder)
			_open_profile())
	_entrance.append(holder)
	return holder


# ------------------------------------------------------------------- logo
func _build_logo_block() -> void:
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(120, 176)
	logo.size = Vector2(840, 405)
	logo.pivot_offset = logo.size * 0.5
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	_entrance.append(logo)

	var glow := UI.glow(430, Color(1.0, 0.88, 0.55, 0.30), 2.4)
	glow.position = Vector2(280, 300)
	glow.modulate.a = 0.9
	add_child(glow)
	move_child(glow, logo.get_index())

	var tagline := UI.outlined_label("کلمه بساز، حال خوب بچین!", 46,
		Color("#fff6dd"), Color("#4a2c10"), 9)
	tagline.position = Vector2(190, 588)
	tagline.size = Vector2(700, 64)
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tagline)
	_entrance.append(tagline)


# ------------------------------------------------------------ chest meter
func _build_chest_strip() -> void:
	chest_strip = Control.new()
	chest_strip.position = Vector2(230, 672)
	chest_strip.size = Vector2(620, 108)
	chest_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chest_strip)

	var face := UI.gradient_panel(620, 108, Color(0.30, 0.18, 0.07, 0.90),
		Color(0.17, 0.10, 0.03, 0.92), 54, Color(1, 0.86, 0.58, 0.30), 2, 0.12)
	chest_strip.add_child(face)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/chest.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(16, 12)
	icon.size = Vector2(84, 84)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_strip.add_child(icon)

	chest_label = UI.label("", 30, Color("#ffe9b8"))
	chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chest_label.position = Vector2(110, 16)
	chest_label.size = Vector2(490, 40)
	chest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_strip.add_child(chest_label)

	chest_bar = ProgressBar.new()
	chest_bar.position = Vector2(110, 62)
	chest_bar.size = Vector2(490, 22)
	chest_bar.custom_minimum_size = Vector2(490, 22)
	chest_bar.max_value = float(Game.CHEST_EVERY)
	chest_bar.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.45)
	bgs.set_corner_radius_all(11)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("#f5b820")
	fgs.set_corner_radius_all(11)
	chest_bar.add_theme_stylebox_override("background", bgs)
	chest_bar.add_theme_stylebox_override("fill", fgs)
	chest_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_strip.add_child(chest_bar)

	chest_strip.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_bump(chest_strip)
			if Game.chest_levels_left() <= 0:
				_open_chest()
			else:
				_toast("%s مرحله تا صندوقچه!" % Game.fa_num(Game.chest_levels_left())))
	_entrance.append(chest_strip)


# -------------------------------------------------------------------- CTA
func _build_cta() -> void:
	cta = JuicyBtn.new()
	cta.text = "ادامهٔ سفر"
	cta.icon_path = "res://assets/icons/btn_play.png"
	cta.base_color = Color("#5cbf2a")
	cta.shadow_color = Color("#2f6a15")
	cta.font_size = 62
	cta.corner = 46.0
	cta.depth = 14.0
	cta.idle_pulse = true
	cta.shine = true
	cta.glow = true
	cta.position = Vector2(140, CTA_Y)
	cta.size = Vector2(800, 158)
	cta.pressed.connect(_on_play)
	add_child(cta)
	_entrance.append(cta)


func _star_icon() -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/icons/star_gold.png")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(46, 46)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Three big glass tiles — thumbs live here, so nothing is smaller than 190 px.
func _build_tiles() -> void:
	daily_tile = _tile("gift", "جایزهٔ روزانه", Vector2(40, TILES_Y), _on_daily)
	add_child(daily_tile)
	_entrance.append(daily_tile)

	chest_tile = _tile("shop", "فروشگاه", Vector2(380, TILES_Y),
		func(): _go("res://scenes/ShopScene.tscn", chest_tile))
	add_child(chest_tile)
	_entrance.append(chest_tile)

	quests_tile = _tile("quests", "ماموریت‌ها", Vector2(720, TILES_Y),
		func(): _go("res://scenes/QuestsScene.tscn", quests_tile))
	add_child(quests_tile)
	_entrance.append(quests_tile)


func _tile(icon: String, caption: String, pos: Vector2, cb: Callable) -> Control:
	var holder := Control.new()
	holder.position = pos
	holder.size = Vector2(320, 192)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	var face := UI.gradient_panel(320, 192, Color(0.30, 0.18, 0.07, 0.88),
		Color(0.15, 0.08, 0.03, 0.92), 34, Color(1, 0.86, 0.58, 0.28), 2, 0.14)
	holder.add_child(face)

	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(96, 18)
	ic.size = Vector2(128, 128)
	ic.pivot_offset = ic.size * 0.5
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ic)
	UI.idle_bob(ic, 6.0, 2.0)

	var cap := UI.label(caption, 32, Color("#ffe9b8"))
	cap.position = Vector2(0, 148)
	cap.size = Vector2(320, 36)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cap)

	# pulsing "!" badge, toggled by _refresh()
	var badge := Panel.new()
	badge.name = "Badge"
	badge.position = Vector2(256, 14)
	badge.custom_minimum_size = Vector2(48, 48)
	badge.size = Vector2(48, 48)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#e8453c")
	bs.set_corner_radius_all(24)
	bs.border_color = Color(1, 1, 1, 0.9)
	bs.set_border_width_all(3)
	badge.add_theme_stylebox_override("panel", bs)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := UI.label("!", 30, Color.WHITE, UI.FONT_BLACK)
	bl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(bl)
	badge.visible = false
	holder.add_child(badge)
	var btw := badge.create_tween().set_loops()
	btw.set_trans(Tween.TRANS_SINE)
	badge.pivot_offset = Vector2(24, 24)
	btw.tween_property(badge, "scale", Vector2(1.22, 1.22), 0.55)
	btw.tween_property(badge, "scale", Vector2.ONE, 0.55)

	holder.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_bump(holder)
			cb.call())
	return holder


func _build_nav() -> void:
	var nav := UI.bottom_nav(["home", "library", "quests", "shop", "themes"], "home",
		_on_nav, NAV_H)
	nav.position = Vector2(0, 1920 - NAV_H)
	add_child(nav)


func _on_nav(key: String) -> void:
	match key:
		"library": _go("res://scenes/LibraryScene.tscn", null)
		"quests": _go("res://scenes/QuestsScene.tscn", null)
		"shop": _go("res://scenes/ShopScene.tscn", null)
		"themes": _go("res://scenes/ThemesScene.tscn", null)


# ================================================================== state
func _refresh() -> void:
	if coin_label:
		coin_label.text = Game.fa_num_grouped(Game.coins)
	if name_label:
		name_label.text = Game.player_name
	if level_badge:
		level_badge.text = Game.fa_num(Game.player_level)
	if xp_bar:
		xp_bar.max_value = float(Game.XP_PER_LEVEL)
		xp_bar.value = float(Game.xp)
	if chest_label:
		var left := Game.chest_levels_left()
		if left <= 0:
			chest_label.text = "صندوقچه آماده است — بازش کن!"
		else:
			chest_label.text = "%s مرحله تا صندوقچهٔ جایزه" % Game.fa_num(left)
	if chest_bar:
		chest_bar.value = float(Game.chest_progress)
	if chest_strip:
		var ready := Game.chest_levels_left() <= 0
		if ready and not _chest_pulse_running:
			_chest_pulse_running = true
			chest_strip.modulate = Color.WHITE
			var tw := chest_strip.create_tween().set_loops()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(chest_strip, "modulate", Color(1.18, 1.1, 0.85), 0.7)
			tw.tween_property(chest_strip, "modulate", Color.WHITE, 0.7)
		elif not ready:
			_chest_pulse_running = false
			chest_strip.modulate = Color.WHITE
	if cta:
		var lvl := Game.current_level
		cta.set_text("شروع بازی" if lvl <= 1 and Game.total_stars() == 0
			else "ادامهٔ سفر  •  مرحله " + Game.fa_num(lvl))
	if daily_tile:
		var b := daily_tile.get_node_or_null("Badge")
		if b:
			b.visible = Game.can_claim_daily()
	if chest_tile:
		var b2 := chest_tile.get_node_or_null("Badge")
		if b2:
			b2.visible = false


func _on_coins_changed(v: int) -> void:
	if coin_label:
		coin_label.text = Game.fa_num_grouped(v)
		var tw := coin_label.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin_label, "scale", Vector2(1.28, 1.28), 0.12)
		tw.tween_property(coin_label, "scale", Vector2.ONE, 0.24)


func _on_play() -> void:
	Audio.play("tap")
	Transition.change_scene("res://scenes/MapScene.tscn")


func _on_daily() -> void:
	if Game.can_claim_daily():
		Transition.change_scene("res://scenes/QuestsScene.tscn")
	else:
		_toast("جایزهٔ امروز را گرفته‌ای — فردا برگرد!")
		Transition.change_scene("res://scenes/QuestsScene.tscn")


# ----------------------------------------------------------- chest reveal
func _open_chest() -> void:
	Audio.play("chest")
	var reward := Game.claim_chest()
	_refresh()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	add_child(dim)
	var dtw := dim.create_tween()
	dtw.tween_property(dim, "modulate:a", 1.0, 0.2)

	var card := UI.paper_card(40, 34)
	card.position = Vector2(140, 660)
	card.custom_minimum_size = Vector2(800, 560)
	card.size = Vector2(800, 560)
	card.pivot_offset = Vector2(400, 280)
	card.modulate.a = 0.0
	add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	var chest := TextureRect.new()
	chest.texture = load("res://assets/icons/chest.png")
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest.custom_minimum_size = Vector2(220, 220)
	chest.pivot_offset = Vector2(110, 110)
	vb.add_child(chest)

	vb.add_child(UI.label(String(reward["label"]), 46, UI.INK, UI.FONT_BLACK))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/icons/coin.png")
	coin_icon.custom_minimum_size = Vector2(72, 72)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(coin_icon)
	row.add_child(UI.label("+" + Game.fa_num(int(reward["coins"])), 48, Color("#c98a12"),
		UI.FONT_BLACK))
	var gem_icon := TextureRect.new()
	gem_icon.texture = load("res://assets/icons/gem.png")
	gem_icon.custom_minimum_size = Vector2(72, 72)
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(gem_icon)
	row.add_child(UI.label("+" + Game.fa_num(int(reward["gems"])), 48, Color("#4a86c8"),
		UI.FONT_BLACK))
	vb.add_child(row)

	vb.add_child(UI.label("%s مرحله تا صندوقچهٔ بعدی"
		% Game.fa_num(Game.CHEST_EVERY), 30, UI.INK_SOFT))

	var ok := JuicyBtn.new()
	ok.text = "عالیه!"
	ok.base_color = Color("#f0a93a")
	ok.shadow_color = Color("#a96f12")
	ok.font_size = 42
	ok.corner = 36.0
	ok.custom_minimum_size = Vector2(520, 118)
	ok.size = Vector2(520, 118)
	ok.pressed.connect(func() -> void:
		Audio.play("coin")
		card.create_tween().tween_callback(func():
			card.queue_free()
			dim.queue_free()))
	vb.add_child(ok)

	var ctw := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ctw.tween_property(card, "modulate:a", 1.0, 0.25)
	ctw.parallel().tween_property(card, "scale", Vector2.ONE, 0.45).from(Vector2(0.7, 0.7))
	var ctw2 := chest.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ctw2.tween_interval(0.25)
	ctw2.tween_property(chest, "scale", Vector2(1.18, 1.18), 0.22)
	ctw2.tween_callback(func(): Audio.play("coin"))
	ctw2.tween_property(chest, "scale", Vector2.ONE, 0.3)


func _open_profile() -> void:
	var popup := preload("res://scenes/ProfilePopup.tscn").instantiate()
	popup.closed.connect(_refresh)
	add_child(popup)


# ================================================================== helpers
func _go(path: String, src: Control) -> void:
	Audio.play("tap")
	Transition.change_scene(path)


func _bump(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(0.96, 0.96), 0.07)
	tw.tween_property(node, "scale", Vector2.ONE, 0.28)


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(340, 980)


func _entrance_anim() -> void:
	for i in _entrance.size():
		var c := _entrance[i] as Control
		if c == null:
			continue
		UI.pop_in(c, 0.05 * float(i))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
