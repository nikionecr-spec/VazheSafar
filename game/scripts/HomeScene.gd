extends Control
## Main menu — animated, layered, with parallax, particles and juicy buttons.

const UI := preload("res://scripts/UIKit.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")
const IconBtn := preload("res://scripts/IconButton.gd")

var coin_label: Label
var name_label: Label
var level_badge: Label
var xp_bar: ProgressBar
var xp_fill_tween: Tween
var xp_text: Label
var next_level_label: Label
var daily_btn: IconButton
var _oldman: TextureRect
var _cat: TextureRect
var _logo: TextureRect
var _entrance: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	Game.coins_changed.connect(_on_coins_changed)
	Audio.start_music()
	_play_entrance()


# ================================================================== build
func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_home.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_add_ambient_particles()
	_add_sun_rays()

	# ---------------- characters
	_oldman = TextureRect.new()
	_oldman.texture = load("res://assets/art/char_oldman.png")
	_oldman.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_oldman.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_oldman.position = Vector2(115, 875)
	_oldman.size = Vector2(700, 745)
	_oldman.pivot_offset = Vector2(350, 700)
	_oldman.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_oldman)

	_cat = TextureRect.new()
	_cat.texture = load("res://assets/art/char_cat.png")
	_cat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cat.position = Vector2(700, 1140)
	_cat.size = Vector2(325, 325)
	_cat.pivot_offset = Vector2(162, 300)
	_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cat)
	# tap the cat for a reaction
	var cat_hit := Control.new()
	cat_hit.position = _cat.position
	cat_hit.size = _cat.size
	cat_hit.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_poke_cat())
	add_child(cat_hit)

	# ---------------- logo
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/art/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.position = Vector2(150, 315)
	_logo.size = Vector2(780, 385)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_entrance.append(_logo)

	var tagline := UI.outlined_label("کلمه بساز، حال خوب بچین!", 42,
		Color("#fff6dd"), Color("#5b3a1c"), 9)
	tagline.position = Vector2(190, 672)
	tagline.size = Vector2(700, 62)
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tagline)
	_entrance.append(tagline)

	# ---------------- HUD
	var pcard := _player_card()
	add_child(pcard)
	_entrance.append(pcard)

	var cpill := _coin_pill()
	add_child(cpill)
	_entrance.append(cpill)

	var gear := IconBtn.new()
	gear.icon_path = "res://assets/icons/settings.png"
	gear.icon_size = 116.0
	gear.float_phase = 0.4
	gear.position = Vector2(936, 46)
	gear.pressed.connect(func(): _go("res://scenes/SettingsScene.tscn", gear))
	add_child(gear)
	_entrance.append(gear)

	# ---------------- side rail
	var rail := [
		["shop", "فروشگاه", "res://scenes/ShopScene.tscn"],
		["book", "کتابخانه", "res://scenes/LibraryScene.tscn"],
		["chest", "جایزه روزانه", ""],
	]
	for i in rail.size():
		var e: Array = rail[i]
		var b := IconBtn.new()
		b.icon_path = "res://assets/icons/%s.png" % e[0]
		b.caption = String(e[1])
		b.icon_size = 150.0
		b.float_phase = 0.25 * float(i)
		b.position = Vector2(20, 322 + i * 205)
		var target := String(e[2])
		if target == "":
			daily_btn = b
			b.add_badge()
			b.pressed.connect(_on_daily)
		else:
			b.pressed.connect(func(): _go(target, b))
		add_child(b)
		_entrance.append(b)

	# ---------------- next-level card
	var nc := _next_card()
	add_child(nc)
	_entrance.append(nc)

	# ---------------- CTA
	var play := JuicyBtn.new()
	play.text = "شروع بازی"
	play.icon_path = "res://assets/icons/btn_play.png"
	play.base_color = Color("#5cbf2a")
	play.shadow_color = Color("#357d12")
	play.font_size = 60
	play.corner = 44.0
	play.depth = 13.0
	play.idle_pulse = true
	play.shine = true
	play.position = Vector2(145, 1545)
	play.size = Vector2(790, 148)
	play.pressed.connect(func(): _go("res://scenes/MapScene.tscn", play))
	add_child(play)
	_entrance.append(play)

	# ---------------- tab bar
	var tabs := _tab_bar()
	add_child(tabs)
	_entrance.append(tabs)

	_breathe(_oldman, 0.016, 3.4)
	_breathe(_cat, 0.022, 2.4)
	_logo_idle()


func _add_sun_rays() -> void:
	var rays := Control.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.set_script(preload("res://scripts/SunRays.gd"))
	add_child(rays)


func _add_ambient_particles() -> void:
	# drifting pollen / light motes
	var p := CPUParticles2D.new()
	p.position = Vector2(540, 1950)
	p.emitting = true
	p.amount = 26
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(560, 10)
	p.direction = Vector2(0.25, -1)
	p.spread = 22.0
	p.initial_velocity_min = 26.0
	p.initial_velocity_max = 72.0
	p.gravity = Vector2(6, -14)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.5
	p.color = Color(1.0, 0.97, 0.80, 0.55)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 0.85, 0.0))
	grad.set_color(1, Color(1, 1, 0.85, 0.0))
	grad.add_point(0.25, Color(1, 0.98, 0.85, 0.65))
	grad.add_point(0.75, Color(1, 0.98, 0.85, 0.55))
	p.color_ramp = grad
	add_child(p)


func _player_card() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.gold_pill(42))
	p.position = Vector2(26, 46)
	p.custom_minimum_size = Vector2(480, 124)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	name_label = UI.label("کاربر عزیز", 34, Color("#5b3a1c"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(name_label)

	var xrow := HBoxContainer.new()
	xrow.add_theme_constant_override("separation", 9)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(235, 36)
	xp_bar.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color("#dcc79a")
	bgs.set_corner_radius_all(18)
	bgs.border_color = Color("#b99f68")
	bgs.set_border_width_all(3)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("#f5b820")
	fgs.set_corner_radius_all(18)
	xp_bar.add_theme_stylebox_override("background", bgs)
	xp_bar.add_theme_stylebox_override("fill", fgs)
	xrow.add_child(xp_bar)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(60, 60)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#3d8bd4")
	bs.set_corner_radius_all(30)
	bs.border_color = Color("#f2c14e")
	bs.set_border_width_all(4)
	bs.shadow_color = Color(0, 0, 0, 0.25)
	bs.shadow_size = 4
	badge.add_theme_stylebox_override("panel", bs)
	level_badge = UI.outlined_label("۱", 32, Color.WHITE, Color("#1d4e7d"), 6)
	level_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(level_badge)
	xrow.add_child(badge)
	info.add_child(xrow)

	xp_text = UI.label("", 22, Color("#8a6a3c"))
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(xp_text)
	hb.add_child(info)
	hb.add_child(_avatar(108))
	p.add_child(hb)
	return p


func _avatar(box: float) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(box, box)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("#fdf3d8")
	fs.set_corner_radius_all(int(box * 0.5))
	fs.border_color = Color("#f2c14e")
	fs.set_border_width_all(5)
	fs.shadow_color = Color(0, 0, 0, 0.22)
	fs.shadow_size = 5
	frame.add_theme_stylebox_override("panel", fs)
	var clip := Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.offset_left = 5
	clip.offset_top = 5
	clip.offset_right = -5
	clip.offset_bottom = -5
	clip.clip_contents = true
	var tr := TextureRect.new()
	tr.texture = load("res://assets/art/char_oldman.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(tr)
	frame.add_child(clip)
	return frame


func _coin_pill() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.gold_pill(36))
	p.position = Vector2(600, 58)
	p.custom_minimum_size = Vector2(300, 94)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var plus := Panel.new()
	plus.custom_minimum_size = Vector2(60, 60)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#4caf50")
	ps.set_corner_radius_all(30)
	ps.border_color = Color("#7fe083")
	ps.set_border_width_all(3)
	ps.shadow_color = Color(0, 0, 0, 0.25)
	ps.shadow_size = 4
	ps.shadow_offset = Vector2(0, 3)
	plus.add_theme_stylebox_override("panel", ps)
	var pl := UI.outlined_label("+", 44, Color.WHITE, Color("#2f7d32"), 5)
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus.add_child(pl)
	var ph := Control.new()
	ph.custom_minimum_size = Vector2(60, 60)
	ph.add_child(plus)
	ph.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_go("res://scenes/ShopScene.tscn", ph))
	hb.add_child(ph)

	var ci := TextureRect.new()
	ci.name = "CoinIcon"
	ci.texture = load("res://assets/icons/coin.png")
	ci.custom_minimum_size = Vector2(66, 66)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ci)
	# slow coin spin
	ci.pivot_offset = Vector2(33, 33)
	var ctw := ci.create_tween().set_loops()
	ctw.tween_interval(2.4)
	ctw.tween_property(ci, "scale:x", 0.12, 0.28).set_trans(Tween.TRANS_SINE)
	ctw.tween_property(ci, "scale:x", 1.0, 0.28).set_trans(Tween.TRANS_SINE)

	coin_label = UI.label("0", 40, Color("#5b3a1c"))
	coin_label.custom_minimum_size = Vector2(130, 0)
	hb.add_child(coin_label)
	p.add_child(hb)
	return p


func _next_card() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.wood_panel(28, 6))
	p.position = Vector2(852, 300)
	p.custom_minimum_size = Vector2(210, 318)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	vb.add_child(UI.label("مرحله بعدی", 26, Color("#ffe9b8")))
	next_level_label = UI.outlined_label("۱", 50, Color.WHITE, Color("#3f2609"), 8)
	vb.add_child(next_level_label)
	var clip := Control.new()
	clip.custom_minimum_size = Vector2(178, 190)
	clip.clip_contents = true
	var thumb := TextureRect.new()
	thumb.texture = load("res://assets/art/bg_map.png")
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(thumb)
	vb.add_child(clip)
	p.add_child(vb)
	p.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_go("res://scenes/MapScene.tscn", p))
	return p


func _tab_bar() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f7e2b4")
	sb.set_corner_radius_all(38)
	sb.border_color = Color("#d9b871")
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(36, 1726)
	p.custom_minimum_size = Vector2(1008, 162)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 4)
	var tabs := [
		["home", "خانه", ""],
		["book", "کتابخانه", "res://scenes/LibraryScene.tscn"],
		["quests", "ماموریت‌ها", "res://scenes/QuestsScene.tscn"],
		["themes", "تم‌ها", "res://scenes/ThemesScene.tscn"],
		["settings", "تنظیمات", "res://scenes/SettingsScene.tscn"],
	]
	for e in tabs:
		hb.add_child(_tab_item(String(e[0]), String(e[1]), String(e[2])))
	p.add_child(hb)
	return p


func _tab_item(icon: String, cap: String, target: String) -> Control:
	var active := target == ""
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(190, 138)
	if active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#ffd95e")
		sb.set_corner_radius_all(28)
		sb.border_color = Color("#e8a93c")
		sb.set_border_width_all(4)
		sb.shadow_color = Color(0.9, 0.7, 0.2, 0.5)
		sb.shadow_size = 7
		holder.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % icon)
	ic.custom_minimum_size = Vector2(96, 96)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.pivot_offset = Vector2(48, 48)
	vb.add_child(ic)
	var l := UI.label(cap, 25, Color("#6b4a1e"))
	vb.add_child(l)
	holder.add_child(vb)

	if active:
		var tw := ic.create_tween().set_loops()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(ic, "scale", Vector2(1.1, 1.1), 0.9)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.9)

	holder.gui_input.connect(func(e: InputEvent):
		if not (e is InputEventScreenTouch or e is InputEventMouseButton):
			return
		if e.pressed:
			Audio.play("btn_down")
			var t := ic.create_tween()
			t.tween_property(ic, "scale", Vector2(0.82, 0.82), 0.07)
		else:
			Audio.play("btn_up")
			var t := ic.create_tween().set_trans(Tween.TRANS_ELASTIC)
			t.set_ease(Tween.EASE_OUT)
			t.tween_property(ic, "scale", Vector2.ONE, 0.5)
			if target != "":
				_go(target, holder))
	return holder


# ================================================================ motion
func _breathe(node: Control, amount: float, time: float) -> void:
	var tw := node.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2(1.0 + amount, 1.0 + amount * 1.4),
		time * 0.5)
	tw.tween_property(node, "scale", Vector2.ONE, time * 0.5)


func _logo_idle() -> void:
	var tw := _logo.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_logo, "rotation", 0.014, 2.1)
	tw.tween_property(_logo, "rotation", -0.014, 2.1)
	var tw2 := _logo.create_tween().set_loops()
	tw2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(_logo, "position:y", 305.0, 1.8)
	tw2.tween_property(_logo, "position:y", 322.0, 1.8)


func _poke_cat() -> void:
	Audio.play("word_bonus", 1.35)
	Audio.vibrate(18)
	var tw := _cat.create_tween()
	tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cat, "scale", Vector2(1.2, 0.82), 0.1)
	tw.tween_property(_cat, "scale", Vector2.ONE, 0.7)
	var p := CPUParticles2D.new()
	p.position = _cat.position + Vector2(160, 120)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 110.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0, 330)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(1.0, 0.75, 0.85)
	add_child(p)
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


func _play_entrance() -> void:
	for i in _entrance.size():
		var n: Control = _entrance[i]
		if not is_instance_valid(n):
			continue
		var target := n.position
		n.position = target + Vector2(0, 46)
		n.modulate.a = 0.0
		var tw := n.create_tween().set_parallel()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position", target, 0.5).set_delay(0.04 * i)
		tw.tween_property(n, "modulate:a", 1.0, 0.34).set_delay(0.04 * i)


# ================================================================ state
func _on_coins_changed(v: int) -> void:
	_refresh()
	# pop the coin label
	if coin_label:
		coin_label.pivot_offset = coin_label.size * 0.5
		var tw := coin_label.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin_label, "scale", Vector2(1.28, 1.28), 0.13)
		tw.tween_property(coin_label, "scale", Vector2.ONE, 0.22)


func _refresh() -> void:
	coin_label.text = Game.fa_num_grouped(Game.coins)
	name_label.text = Game.player_name
	level_badge.text = Game.fa_num(Game.player_level)
	var target := Game.xp_ratio() * 100.0
	if xp_fill_tween and xp_fill_tween.is_running():
		xp_fill_tween.kill()
	xp_fill_tween = create_tween()
	xp_fill_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	xp_fill_tween.tween_property(xp_bar, "value", target, 0.6)
	xp_text.text = Game.fa_num(Game.xp) + "/" + Game.fa_num(Game.XP_PER_LEVEL)
	next_level_label.text = Game.fa_num(Game.current_level)
	if daily_btn:
		daily_btn.set_badge_visible(Game.can_claim_daily())


func _go(path: String, from: Control = null) -> void:
	var c := Vector2(0.5, 0.5)
	if from and is_instance_valid(from):
		var g := from.get_global_rect().get_center()
		c = Vector2(g.x / 1080.0, g.y / 1920.0)
	Transition.change_scene(path, c)


func _on_daily() -> void:
	var amount := Game.claim_daily()
	if amount > 0:
		Audio.play("coin")
		_coin_burst()
		_toast("جایزه روزانه: " + Game.fa_num(amount) + " سکه!")
	else:
		Audio.play("word_bad")
		_toast("جایزه امروز را گرفته‌ای")
	_refresh()


func _coin_burst() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(120, 760)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 26
	p.lifetime = 1.2
	p.direction = Vector2(1, -1)
	p.spread = 55.0
	p.initial_velocity_min = 320.0
	p.initial_velocity_max = 620.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 5.0
	p.scale_amount_max = 10.0
	p.color = Color(1.0, 0.84, 0.25)
	add_child(p)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	await get_tree().process_frame
	t.position = Vector2((1080.0 - t.size.x) * 0.5, 820)
