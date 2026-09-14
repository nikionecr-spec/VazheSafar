extends Control
## Main menu, matching the reference mock: HUD, logo, characters, CTA, tab bar.

const UI := preload("res://scripts/UIKit.gd")

var coin_label: Label
var name_label: Label
var level_badge: Label
var xp_bar: ProgressBar
var xp_text: Label
var next_level_label: Label
var daily_dot: Panel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	Game.coins_changed.connect(func(_v): _refresh())
	Audio.start_music()


func _build() -> void:
	# ---------------------------------------------------------- background
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_home.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ---------------------------------------------------------- characters
	var oldman := TextureRect.new()
	oldman.texture = load("res://assets/art/char_oldman.png")
	oldman.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	oldman.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	oldman.position = Vector2(120, 880)
	oldman.size = Vector2(700, 740)
	oldman.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oldman)

	var cat := TextureRect.new()
	cat.texture = load("res://assets/art/char_cat.png")
	cat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cat.position = Vector2(700, 1130)
	cat.size = Vector2(330, 330)
	cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cat)

	# ---------------------------------------------------------- logo
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(175, 330)
	logo.size = Vector2(730, 360)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var tagline := UI.outlined_label("کلمه بساز، حال خوب بچین!", 40,
		Color("#fff6dd"), Color("#5b3a1c"), 8)
	tagline.position = Vector2(190, 670)
	tagline.size = Vector2(700, 60)
	add_child(tagline)

	# ---------------------------------------------------------- top-left HUD
	add_child(_player_card())

	# ---------------------------------------------------------- top-right HUD
	var coinp := PanelContainer.new()
	coinp.add_theme_stylebox_override("panel", UI.gold_pill(34))
	coinp.position = Vector2(620, 62)
	coinp.custom_minimum_size = Vector2(270, 86)
	var chb := HBoxContainer.new()
	chb.add_theme_constant_override("separation", 10)
	chb.alignment = BoxContainer.ALIGNMENT_CENTER
	var plus := _round_btn(Color("#4caf50"), Color("#2f7d32"), "+", 54)
	plus.pressed.connect(func(): _open("res://scenes/ShopScene.tscn"))
	chb.add_child(plus)
	var ci := TextureRect.new()
	ci.texture = load("res://assets/icons/coin.png")
	ci.custom_minimum_size = Vector2(58, 58)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chb.add_child(ci)
	coin_label = UI.label("0", 38, Color("#5b3a1c"))
	coin_label.custom_minimum_size = Vector2(130, 0)
	chb.add_child(coin_label)
	coinp.add_child(chb)
	add_child(coinp)

	var gear := UI.icon_button("res://assets/icons/settings.png", 92)
	gear.position = Vector2(930, 58)
	gear.pressed.connect(func(): _open("res://scenes/SettingsScene.tscn"))
	add_child(gear)

	# ---------------------------------------------------------- side buttons
	var side := [
		["shop", "فروشگاه", "res://scenes/ShopScene.tscn"],
		["book", "ماموریت‌ها", "res://scenes/QuestsScene.tscn"],
		["chest", "جوایز روزانه", ""],
	]
	for i in side.size():
		var entry: Array = side[i]
		var holder := _side_button(String(entry[0]), String(entry[1]))
		holder.position = Vector2(30, 330 + i * 200)
		var target := String(entry[2])
		var btn: TextureButton = holder.get_node("Btn")
		if target == "":
			btn.pressed.connect(_on_daily)
			daily_dot = _dot()
			daily_dot.position = Vector2(112, 4)
			holder.add_child(daily_dot)
		else:
			btn.pressed.connect(func(): _open(target))
		add_child(holder)

	# ---------------------------------------------------------- next level card
	add_child(_next_level_card())

	# ---------------------------------------------------------- CTA
	var play := UI.green_button("▶   شروع بازی", 58)
	play.position = Vector2(150, 1560)
	play.size = Vector2(780, 140)
	play.custom_minimum_size = play.size
	play.pressed.connect(_on_play)
	add_child(play)
	_pulse(play)

	# ---------------------------------------------------------- tab bar
	add_child(_tab_bar())

	UI.idle_bob(oldman, 7.0, 3.0)
	UI.idle_bob(cat, 5.0, 2.2)
	UI.idle_bob(logo, 6.0, 3.4)


func _player_card() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.gold_pill(40))
	p.position = Vector2(30, 50)
	p.custom_minimum_size = Vector2(470, 120)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	name_label = UI.label("کاربر عزیز", 34, Color("#5b3a1c"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(name_label)

	var xrow := HBoxContainer.new()
	xrow.add_theme_constant_override("separation", 8)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(230, 34)
	xp_bar.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color("#e0cda0")
	bgs.set_corner_radius_all(17)
	bgs.border_color = Color("#c2a870")
	bgs.set_border_width_all(2)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("#f0b429")
	fgs.set_corner_radius_all(17)
	xp_bar.add_theme_stylebox_override("background", bgs)
	xp_bar.add_theme_stylebox_override("fill", fgs)
	xrow.add_child(xp_bar)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(56, 56)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#3d8bd4")
	bs.set_corner_radius_all(28)
	bs.border_color = Color("#f2c14e")
	bs.set_border_width_all(3)
	badge.add_theme_stylebox_override("panel", bs)
	level_badge = UI.outlined_label("۱", 30, Color.WHITE, Color("#1d4e7d"), 5)
	level_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(level_badge)
	xrow.add_child(badge)
	info.add_child(xrow)

	xp_text = UI.label("", 22, Color("#8a6a3c"))
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(xp_text)
	hb.add_child(info)

	var avatar := _avatar(104)
	hb.add_child(avatar)
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
	frame.add_theme_stylebox_override("panel", fs)

	var tr := TextureRect.new()
	tr.texture = load("res://assets/art/char_oldman.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 5
	tr.offset_top = 5
	tr.offset_right = -5
	tr.offset_bottom = -5
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cont := Control.new()
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.clip_contents = true
	cont.add_child(tr)
	frame.add_child(cont)
	return frame


func _side_button(icon: String, caption: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(160, 180)
	holder.size = holder.custom_minimum_size

	var btn := UI.icon_button("res://assets/icons/%s.png" % icon, 128)
	btn.name = "Btn"
	btn.position = Vector2(10, 0)
	holder.add_child(btn)

	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.22, 0.08, 0.82)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	cap.add_theme_stylebox_override("panel", sb)
	cap.position = Vector2(0, 124)
	cap.custom_minimum_size = Vector2(150, 40)
	cap.add_child(UI.label(caption, 22, Color("#fff0cf")))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cap)
	return holder


func _dot() -> Panel:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(30, 30)
	d.size = d.custom_minimum_size
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#e53935")
	s.set_corner_radius_all(15)
	s.border_color = Color.WHITE
	s.set_border_width_all(3)
	d.add_theme_stylebox_override("panel", s)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _next_level_card() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.wood_panel(26, 5))
	p.position = Vector2(860, 300)
	p.custom_minimum_size = Vector2(200, 300)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(UI.label("مرحله بعدی", 26, Color("#ffe9b8")))
	next_level_label = UI.outlined_label("۱", 46, Color.WHITE, Color("#3f2609"), 7)
	vb.add_child(next_level_label)

	var thumb := TextureRect.new()
	thumb.texture = load("res://assets/art/bg_map.png")
	thumb.custom_minimum_size = Vector2(170, 180)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var clip := Control.new()
	clip.custom_minimum_size = Vector2(170, 180)
	clip.clip_contents = true
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(thumb)
	vb.add_child(clip)
	p.add_child(vb)

	var b := Button.new()
	b.flat = true
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(_on_play)
	p.add_child(b)
	return p


func _tab_bar() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f6dfae")
	sb.set_corner_radius_all(34)
	sb.border_color = Color("#d9b871")
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(40, 1740)
	p.custom_minimum_size = Vector2(1000, 150)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)

	# left -> right, matching the reference layout
	var tabs := [
		["shop", "خانه", ""],
		["book", "کتابخانه", "res://scenes/LibraryScene.tscn"],
		["quests", "ماموریت‌ها", "res://scenes/QuestsScene.tscn"],
		["themes", "تم‌ها", "res://scenes/ThemesScene.tscn"],
		["settings", "تنظیمات", "res://scenes/SettingsScene.tscn"],
	]
	for entry in tabs:
		hb.add_child(_tab_item(String(entry[0]), String(entry[1]), String(entry[2])))
	p.add_child(hb)
	return p


func _tab_item(icon: String, caption: String, target: String) -> Control:
	var active := target == ""
	var holder := PanelContainer.new()
	if active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#ffd95e")
		sb.set_corner_radius_all(26)
		sb.border_color = Color("#e8b83c")
		sb.set_border_width_all(3)
		holder.add_theme_stylebox_override("panel", sb)
	holder.custom_minimum_size = Vector2(186, 130)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % ("btn_play" if active else icon))
	ic.custom_minimum_size = Vector2(76, 76)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(ic)
	vb.add_child(UI.label(caption, 24, Color("#6b4a1e")))
	holder.add_child(vb)

	var b := Button.new()
	b.flat = true
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	if target != "":
		b.pressed.connect(func(): _open(target))
	else:
		b.pressed.connect(func(): Audio.play("tap"))
	holder.add_child(b)
	return holder


func _round_btn(bg: Color, border: Color, text: String, box: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(box, box)
	b.add_theme_font_override("font", load(UI.FONT_BLACK))
	b.add_theme_font_size_override("font_size", int(box * 0.6))
	b.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(box * 0.5))
	sb.border_color = border
	sb.set_border_width_all(3)
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	return b


func _refresh() -> void:
	coin_label.text = Game.fa_num_grouped(Game.coins)
	name_label.text = Game.player_name
	level_badge.text = Game.fa_num(Game.player_level)
	xp_bar.value = Game.xp_ratio() * 100.0
	xp_text.text = Game.fa_num(Game.xp) + "/" + Game.fa_num(Game.XP_PER_LEVEL)
	next_level_label.text = Game.fa_num(Game.current_level)
	if daily_dot:
		daily_dot.visible = Game.can_claim_daily()


func _pulse(node: Control) -> void:
	await get_tree().process_frame
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2(1.045, 1.045), 0.8)
	tw.tween_property(node, "scale", Vector2.ONE, 0.8)


func _on_play() -> void:
	Audio.play("tap")
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")


func _open(path: String) -> void:
	Audio.play("tap")
	get_tree().change_scene_to_file(path)


func _on_daily() -> void:
	var amount := Game.claim_daily()
	var msg := ("جایزه روزانه: " + Game.fa_num(amount) + " سکه!") if amount > 0 \
		else "جایزه امروز را گرفته‌ای"
	Audio.play("coin" if amount > 0 else "word_bad")
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(300, 800)
	_refresh()
