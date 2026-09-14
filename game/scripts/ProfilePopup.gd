extends Control
## Player profile: identity, progress, stats and achievements.
## Opened by tapping the profile card on the home screen.

const UI := preload("res://scripts/UIKit.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")

signal closed

var name_edit: LineEdit
var avatar: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 60
	_build()
	UI.pop_in(_card(), 0.0)


func _card() -> Control:
	return get_node_or_null("Card")


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_close())
	add_child(dim)

	var card := Control.new()
	card.name = "Card"
	card.position = Vector2(60, 170)
	card.size = Vector2(960, 1580)
	card.pivot_offset = card.size * 0.5
	add_child(card)

	var bg := UI.gradient_panel(960, 1580, Color("#463019"), Color("#2a1a0c"), 44,
		Color(1, 0.87, 0.62, 0.30), 2, 0.10)
	card.add_child(bg)

	# ---- header: avatar + name + title
	var hb := HBoxContainer.new()
	hb.position = Vector2(40, 34)
	hb.size = Vector2(880, 220)
	hb.add_theme_constant_override("separation", 24)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(190, 190)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("#f7e6c0")
	fs.set_corner_radius_all(95)
	fs.border_color = Color("#f4c766")
	fs.set_border_width_all(7)
	fs.shadow_color = Color(0, 0, 0, 0.4)
	fs.shadow_size = 14
	frame.add_theme_stylebox_override("panel", fs)
	var clip := Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.offset_left = 8
	clip.offset_top = 8
	clip.offset_right = -8
	clip.offset_bottom = -8
	clip.clip_contents = true
	avatar = TextureRect.new()
	avatar.texture = load("res://assets/art/avatar_oldman.png")
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(avatar)
	frame.add_child(clip)
	hb.add_child(frame)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	var nm := UI.label(Game.player_name, 46, Color("#fff2d4"), UI.FONT_BLACK)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(nm)
	var tl := UI.label("%s  •  سطح %s" % [Game.player_title(), Game.fa_num(Game.player_level)],
		30, Color("#ffd98a"))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(tl)

	# xp bar
	var xp := ProgressBar.new()
	xp.custom_minimum_size = Vector2(0, 44)
	xp.max_value = float(Game.XP_PER_LEVEL)
	xp.value = float(Game.xp)
	xp.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.35)
	bgs.set_corner_radius_all(22)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("#f5b820")
	fgs.set_corner_radius_all(22)
	xp.add_theme_stylebox_override("background", bgs)
	xp.add_theme_stylebox_override("fill", fgs)
	info.add_child(xp)
	var xpl := UI.label("تجربه " + Game.fa_num(Game.xp) + " از " + Game.fa_num(Game.XP_PER_LEVEL),
		24, Color("#e8d6ad"))
	xpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(xpl)
	hb.add_child(info)
	card.add_child(hb)

	# ---- name field
	var lbl := UI.label("نام نمایشی", 28, Color("#ffd98a"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.position = Vector2(60, 268)
	lbl.size = Vector2(840, 40)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	var field := PanelContainer.new()
	field.position = Vector2(60, 312)
	field.custom_minimum_size = Vector2(840, 96)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(1, 1, 1, 0.94)
	fsb.set_corner_radius_all(24)
	fsb.content_margin_left = 24
	fsb.content_margin_right = 24
	field.add_theme_stylebox_override("panel", fsb)
	name_edit = LineEdit.new()
	name_edit.text = Game.player_name
	name_edit.add_theme_font_override("font", load(UI.FONT_BOLD))
	name_edit.add_theme_font_size_override("font_size", 34)
	name_edit.add_theme_color_override("font_color", UI.INK)
	name_edit.add_theme_color_override("caret_color", UI.INK)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_edit.placeholder_text = "نامت را بنویس…"
	name_edit.text_submitted.connect(func(t: String) -> void: _save_name(t))
	name_edit.focus_exited.connect(func() -> void: _save_name(name_edit.text))
	field.add_child(name_edit)
	card.add_child(field)

	var save := UI.green_button("ذخیرهٔ نام", 32)
	save.position = Vector2(60, 424)
	save.custom_minimum_size = Vector2(840, 92)
	save.size = Vector2(840, 92)
	save.pressed.connect(func() -> void:
		_save_name(name_edit.text)
		_toast("نام ذخیره شد"))
	card.add_child(save)

	# ---- stats grid
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(60, 552)
	grid.size = Vector2(840, 300)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var s := Game.stats
	var cells := [
		["word", "کلمه", "words_found"],
		["star_gold", "ستاره", "stars"],
		["chest", "مرحله", "levels_done"],
		["gift", "جایزه‌ای", "bonus_found"],
		["hint", "راهنما", "hints_used"],
	]
	for c in cells:
		grid.add_child(_stat_tile(String(c[0]), String(c[1]), String(c[2]), s))
	grid.add_child(_combo_tile())
	card.add_child(grid)

	# ---- achievements
	var ah := UI.label("دستاوردها  " + Game.fa_num(Game.achievements_unlocked()) + " از "
		+ Game.fa_num(Game.achievements().size()), 32, Color("#ffd98a"))
	ah.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ah.position = Vector2(60, 884)
	ah.size = Vector2(840, 44)
	ah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ah)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, 938)
	scroll.size = Vector2(840, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(840, 0)
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for a in Game.achievements():
		list.add_child(_achievement_row(a))

	var close := JuicyBtn.new()
	close.text = "بازگشت"
	close.base_color = Color("#8a6134")
	close.shadow_color = Color("#543616")
	close.font_size = 38
	close.corner = 34.0
	close.position = Vector2(190, 1390)
	close.size = Vector2(580, 130)
	close.pressed.connect(_close)
	card.add_child(close)


func _stat_tile(icon: String, label_text: String, key: String, s: Dictionary) -> Control:
	var p := UI.glass_card(24, Color(1, 1, 1, 0.10), 12)
	p.custom_minimum_size = Vector2(268, 138)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % icon)
	ic.custom_minimum_size = Vector2(72, 72)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	var val: int = Game.total_stars() if key == "stars" else int(s.get(key, 0))
	var v := UI.label(Game.fa_num_grouped(val), 36, Color.WHITE, UI.FONT_BLACK)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(v)
	var l := UI.label(label_text, 24, Color("#e8d6ad"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(l)
	hb.add_child(vb)
	p.add_child(hb)
	return p


func _combo_tile() -> Control:
	var p := UI.glass_card(24, Color(1, 0.85, 0.4, 0.14), 12)
	p.custom_minimum_size = Vector2(268, 138)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/trophy.png")
	ic.custom_minimum_size = Vector2(72, 72)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	var v := UI.label(Game.fa_num(Game.best_combo), 36, Color.WHITE, UI.FONT_BLACK)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(v)
	var l := UI.label("بهترین زنجیره", 24, Color("#ffe6b0"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(l)
	hb.add_child(vb)
	p.add_child(hb)
	return p


func _achievement_row(a: Dictionary) -> Control:
	var done: bool = int(a["value"]) >= int(a["goal"])
	var p := UI.glass_card(22, Color(1, 1, 1, 0.13 if done else 0.07), 14)
	p.custom_minimum_size = Vector2(820, 108)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % String(a["icon"]))
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = Color.WHITE if done else Color(0.7, 0.7, 0.72, 0.7)
	hb.add_child(ic)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	var t := UI.label(("✓ " if done else "") + String(a["title"]), 30,
		Color("#ffe9b8") if done else Color("#d8cdbb"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(t)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 20)
	pb.max_value = float(a["goal"])
	pb.value = float(a["value"])
	pb.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.35)
	bgs.set_corner_radius_all(10)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("#f5b820") if done else Color("#7fb35a")
	fgs.set_corner_radius_all(10)
	pb.add_theme_stylebox_override("background", bgs)
	pb.add_theme_stylebox_override("fill", fgs)
	vb.add_child(pb)
	hb.add_child(vb)

	var pg := UI.label("%s/%s" % [Game.fa_num(int(a["value"])), Game.fa_num(int(a["goal"]))],
		24, Color("#e8d6ad"))
	hb.add_child(pg)
	p.add_child(hb)
	return p


func _save_name(t: String) -> void:
	var clean := t.strip_edges()
	if clean == "":
		clean = "کاربر عزیز"
	if clean.length() > 18:
		clean = clean.substr(0, 18)
	Game.player_name = clean
	if name_edit:
		name_edit.text = clean
	Game.save_game()
	Audio.play("btn_up")


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(330, 960)


func _close() -> void:
	Audio.play("tap")
	closed.emit()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()
