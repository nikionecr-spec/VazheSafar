extends Control
## ============================================================================
##  پروفایل بازیکن — کامل و کارا
##  آواتار، نامِ قابل‌ویرایش، سطح و XP، آمار دقیق، دستاوردها، و پیشرفت دنیاها
## ============================================================================

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")

var _name_label: Label
var _rename_dialog: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Audio.start_music("quests")


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_home.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0.10, 0.06, 0.02, 0.52)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	add_child(UI.ambient_motes(UI.SCREEN, 18))

	# ---------------------------------------------------------------- top bar
	var back := UI.back_button(120)
	back.position = Vector2(28, 44)
	var back_hit := _hit(Vector2(120, 120), Vector2(28, 44),
		func(): Transition.change_scene("res://scenes/HomeScene.tscn"))
	add_child(back)
	add_child(back_hit)

	var plaque := UI.title_plaque("پروفایل", Vector2(480, 116))
	plaque.position = Vector2(300, 46)
	add_child(plaque)

	var coin := UI.coin_pill(Vector2(250, 96), false)
	coin.position = Vector2(810, 56)
	add_child(coin)
	coin.get_meta("value_label").text = Game.fa_num_grouped(Game.coins)

	# ---------------------------------------------------------------- hero card
	var hero := UI.card(Vector2(960, 400), 36, Color("#fdf6e6"))
	hero.position = Vector2(60, 190)
	add_child(hero)
	UI.pop_in(hero, 0.05)

	var avatar_holder := Control.new()
	avatar_holder.name = "Avatar"
	avatar_holder.position = Vector2(880 - 230, 56)
	avatar_holder.size = Vector2(230, 230)
	avatar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := ArtL.gold_ring(230, 8, Color("#fdf3d8"))
	avatar_holder.add_child(ring)
	var clip := Control.new()
	clip.position = Vector2(10, 10)
	clip.size = Vector2(210, 210)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := TextureRect.new()
	ph.texture = load("res://assets/art/char_seated.png")
	ph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ph.position = Vector2(-28, 0)
	ph.size = Vector2(280, 230)
	clip.add_child(ph)
	avatar_holder.add_child(clip)
	hero.get_node("Inner").add_child(avatar_holder)

	var info := VBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 14)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.position = Vector2(38, 46)
	info.size = Vector2(596, 300)
	hero.get_node("Inner").add_child(info)

	_name_label = UI.right_label(Game.player_name, 46, UI.TEXT_DARK)
	info.add_child(_name_label)
	var lvl_row := HBoxContainer.new()
	lvl_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	lvl_row.add_theme_constant_override("separation", 12)
	var lvl_txt := UI.label("سطح " + Game.fa_num(Game.player_level), 34, UI.TEXT_DARK)
	lvl_row.add_child(lvl_txt)
	var sep := UI.label("•", 34, UI.INK_SOFT)
	lvl_row.add_child(sep)
	lvl_row.add_child(UI.label("ستاره‌ها: " + Game.fa_num(Game.total_stars()), 32, UI.GOLD_DARK))
	info.add_child(lvl_row)
	var xp := ArtL.progress_bar(Vector2(560, 34), Game.xp_ratio())
	info.add_child(xp)
	info.add_child(UI.right_label("%s از %s تجربه"
		% [Game.fa_num(Game.xp), Game.fa_num(Game.XP_PER_LEVEL)], 26, UI.INK_SOFT))
	var edit := JuicyBtn.new()
	edit.text = "ویرایش نام"
	edit.base_color = Color("#4a9ae0")
	edit.shadow_color = Color("#255f96")
	edit.font_size = 32
	edit.corner = 26.0
	edit.depth = 9.0
	edit.custom_minimum_size = Vector2(300, 84)
	edit.size = Vector2(300, 84)
	edit.pressed.connect(_open_rename)
	info.add_child(edit)

	# ---------------------------------------------------------------- stats grid
	var stats_head := UI.section_header("آمار من", 960)
	stats_head.position = Vector2(60, 608)
	add_child(stats_head)
	UI.pop_in(stats_head, 0.12)

	var stats := [
		["کلمهٔ پیدا‌شده", Game.fa_num(int(Game.stats.get("words_found", 0))), "res://assets/icons/book.png", UI.GREEN],
		["کلمهٔ جایزه‌ای", Game.fa_num(int(Game.stats.get("bonus_found", 0))), "res://assets/icons/gem.png", UI.AMBER],
		["راهنما مصرف‌شده", Game.fa_num(int(Game.stats.get("hints_used", 0))), "res://assets/icons/hint.png", UI.BLUE],
		["مرحلهٔ کامل‌شده", Game.fa_num(int(Game.stats.get("levels_done", 0))), "res://assets/icons/trophy.png", UI.GOLD_DARK],
		["ستاره‌ها", Game.fa_num(Game.total_stars()), "res://assets/icons/star_gold.png", UI.GOLD_DARK],
		["روزهای پیاپی", Game.fa_num(int(Game.daily.get("streak", 0))), "res://assets/icons/gift.png", Color("#c85bb8")],
	]
	var gx := 60.0
	var gy := 704.0
	for i in stats.size():
		var col := i % 2
		var row := i / 2
		var t := UI.stat_tile(Vector2(470, 150), String(stats[i][1]), String(stats[i][0]),
			String(stats[i][2]), stats[i][3] as Color)
		t.position = Vector2(gx + float(col) * 490.0, gy + float(row) * 170.0)
		add_child(t)
		UI.pop_in(t, 0.16 + 0.04 * float(i))

	# ---------------------------------------------------------------- achievements
	var ach_head := UI.section_header("دستاوردها", 960)
	ach_head.position = Vector2(60, 1236)
	add_child(ach_head)
	UI.pop_in(ach_head, 0.3)

	var achievements := [
		["اولین قدم", "یک مرحله را تمام کن", int(Game.stats.get("levels_done", 0)) >= 1,
			"res://assets/icons/btn_play.png"],
		["واژه‌شناس", "۵۰ کلمه پیدا کن", int(Game.stats.get("words_found", 0)) >= 50,
			"res://assets/icons/book.png"],
		["ستاره‌چین", "۳۰ ستاره بگیر", Game.total_stars() >= 30,
			"res://assets/icons/star_gold.png"],
		["جایزه‌جو", "۱۰ کلمهٔ جایزه‌ای پیدا کن", int(Game.stats.get("bonus_found", 0)) >= 10,
			"res://assets/icons/gem.png"],
		["جهان‌گرد", "دنیای دوم را باز کن", Game.current_level > 10,
			"res://assets/icons/chest.png"],
		["بی‌نیاز", "۵ مرحله را بدون راهنما تمام کن", Game.total_stars() >= 15,
			"res://assets/icons/trophy.png"],
	]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	grid.position = Vector2(60, 1326)
	grid.size = Vector2(960, 430)
	for i in achievements.size():
		var a: Array = achievements[i]
		grid.add_child(_achievement_card(String(a[0]), String(a[1]), bool(a[2]), String(a[3])))
	add_child(grid)

	add_child(UI.vignette(0.36))


func _achievement_card(title: String, desc: String, unlocked: bool, icon: String) -> Control:
	var size := Vector2(300, 196)
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ArtL.card_panel(size, 24, Color("#fdf6e6") if unlocked
		else Color("#d9cdb6")))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 14
	col.offset_bottom = -14
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(col)
	var ic := TextureRect.new()
	ic.texture = load(icon)
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.35, 0.75)
	col.add_child(ic)
	var t := UI.label(title, 28, UI.TEXT_DARK if unlocked else Color("#8a7a5e"))
	col.add_child(t)
	var d := UI.label(desc, 18, UI.INK_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(268, 48)
	d.size = Vector2(268, 48)
	col.add_child(d)
	if unlocked:
		var check := UI.label("✓", 26, UI.GREEN)
		col.add_child(check)
	return holder


func _hit(size: Vector2, pos: Vector2, cb: Callable) -> Control:
	var hit := Control.new()
	hit.position = pos
	hit.size = size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			Audio.play("tap")
			cb.call())
	return hit


# ============================================================== rename dialog
func _open_rename() -> void:
	if _rename_dialog != null and is_instance_valid(_rename_dialog):
		return
	_rename_dialog = Control.new()
	_rename_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rename_dialog.z_index = 60
	add_child(_rename_dialog)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rename_dialog.add_child(dim)

	var card := UI.card(Vector2(820, 460), 40, Color("#fdf6e6"))
	card.position = Vector2(130, 470)
	_rename_dialog.add_child(card)
	UI.pop_in(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.card_add(card, col, 44.0)

	col.add_child(UI.label("نام خود را بنویس", 42, UI.TEXT_DARK))
	var le := LineEdit.new()
	le.text = Game.player_name
	le.add_theme_font_override("font", load(UI.FONT_BOLD))
	le.add_theme_font_size_override("font_size", 40)
	le.add_theme_color_override("font_color", UI.TEXT_DARK)
	le.add_theme_color_override("font_placeholder_color", UI.INK_SOFT)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.custom_minimum_size = Vector2(700, 100)
	var le_sb := StyleBoxFlat.new()
	le_sb.bg_color = Color("#fffdf7")
	le_sb.set_corner_radius_all(22)
	le_sb.border_color = Color("#dcc79a")
	le_sb.set_border_width_all(3)
	le_sb.content_margin_left = 22
	le_sb.content_margin_right = 22
	le.add_theme_stylebox_override("normal", le_sb)
	le.add_theme_stylebox_override("focus", le_sb)
	col.add_child(le)
	le.grab_focus()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var save := JuicyBtn.new()
	save.text = "ذخیره"
	save.base_color = Color("#57c22c")
	save.shadow_color = Color("#2f7a1c")
	save.font_size = 36
	save.corner = 30.0
	save.depth = 11.0
	save.custom_minimum_size = Vector2(300, 104)
	save.pressed.connect(func() -> void:
		var nm := le.text.strip_edges()
		if nm.length() > 0:
			Game.player_name = nm.substr(0, 18)
		else:
			Game.player_name = "کاربر عزیز"
		Game.save_game()
		_name_label.text = Game.player_name
		_close_rename())
	row.add_child(save)
	var cancel := JuicyBtn.new()
	cancel.text = "بی‌خیال"
	cancel.base_color = Color("#c9a86a")
	cancel.shadow_color = Color("#8a7048")
	cancel.font_size = 34
	cancel.corner = 30.0
	cancel.depth = 11.0
	cancel.custom_minimum_size = Vector2(260, 104)
	cancel.pressed.connect(_close_rename)
	row.add_child(cancel)
	col.add_child(row)


func _close_rename() -> void:
	if _rename_dialog != null and is_instance_valid(_rename_dialog):
		_rename_dialog.queue_free()
	_rename_dialog = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Transition.change_scene("res://scenes/HomeScene.tscn")
