extends SubScene
## ============================================================================
##  تنظیمات — ردیف‌های درشت با کلید کشوییِ گرافیکی
##  ● موسیقی، صدای بازی، لرزش (با پیش‌نمایش فوری)
##  ● نام بازیکن (ویرایش درجا)
##  ● بازنشانی پیشرفت با تأیید دو مرحله‌ای
##  ● دربارهٔ بازی و نسخه
## ============================================================================

const JuicyBtn := preload("res://scripts/JuicyButton.gd")

var _dialog: Control
var _pending := {}


func _init() -> void:
	screen_title = "تنظیمات"
	nav_index = 4


func build_body() -> void:
	section("صدا و حس")
	_toggle_row("موسیقی پس‌زمینه", "music", "res://assets/icons/sound.png",
		"هر صفحه موسیقی خودش را دارد")
	_toggle_row("صدای بازی", "sfx", "res://assets/icons/btn_play_blue.png",
		"کلیک‌ها، کلمه‌ها، سکه‌ها")
	_toggle_row("لرزش", "vibration", "res://assets/icons/heart.png",
		"بازخورد لمسی روی اندروید")

	section("بازیکن")
	_name_card()

	section("داده‌ها")
	_reset_card()

	var about := card(320, 30, Color("#fdf3dc"), true)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	UI.card_add(about, col, 26.0)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/logo.png")
	logo.custom_minimum_size = Vector2(380, 150)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(logo)
	col.add_child(UI.label("کلمه بساز، حال خوب بچین!", 30, Color("#ffeccb")))
	col.add_child(UI.label("نسخهٔ ۱٫۰  •  " + Game.fa_num(Game.total_levels())
		+ " مرحله  •  " + Game.fa_num(Game.dictionary.size()) + " واژهٔ جایزه‌ای",
		26, Color("#ffdca8")))
	spacer(40)


# ------------------------------------------------------------------ toggle
func _toggle_row(text: String, key: String, icon: String, hint: String) -> void:
	var c := card(176, 30, Color("#fdf6e6"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.card_add(c, row, 26.0)

	var ic := TextureRect.new()
	ic.texture = load(icon)
	ic.custom_minimum_size = Vector2(100, 100)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(ic)

	var sw := _switch(bool(Game.settings.get(key, true)))
	sw.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			Game.settings[key] = not bool(Game.settings.get(key, true))
			Game.save_game()
			Audio.play("tap")
			_apply_audio_settings()
			rebuild())
	row.add_child(sw)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	var t := UI.label(text, 38, UI.TEXT_DARK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(t)
	var h := UI.label(hint, 24, UI.INK_SOFT)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(h)
	row.add_child(col)


## کلید کشوییِ گرافیکی
func _switch(on: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(160, 84)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var track := TextureRect.new()
	track.texture = ArtL.rounded_texture(120, 56, 28,
		Color("#7ed957") if on else Color("#c9bda6"),
		Color("#4cb02f") if on else Color("#a4957c"),
		Color("#2f7a1c") if on else Color("#8a7a64"), 3.0, 0.26, 0.14)
	track.position = Vector2(0, 14)
	track.size = Vector2(160, 56)
	track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track.stretch_mode = TextureRect.STRETCH_SCALE
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(track)
	var knob := TextureRect.new()
	knob.texture = ArtL.rounded_texture(64, 64, 32, Color("#fffdf7"), Color("#e4d8bf"),
		Color("#b9a985"), 3.0, 0.45, 0.0)
	knob.size = Vector2(64, 64)
	knob.position = Vector2(160 - 72 if on else 8, 10)
	knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knob.stretch_mode = TextureRect.STRETCH_SCALE
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(knob)
	return holder


func _apply_audio_settings() -> void:
	if Game.settings.get("music", true):
		Audio.set_music_enabled(true)
	else:
		Audio.set_music_enabled(false)


# -------------------------------------------------------------------- name
func _name_card() -> void:
	var c := card(200, 30, Color("#fdf6e6"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	UI.card_add(c, col, 26.0)
	col.add_child(UI.right_label("نام بازیکن", 32, UI.TEXT_DARK))
	var le := LineEdit.new()
	le.text = Game.player_name
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	le.add_theme_font_override("font", load(UI.FONT_BOLD))
	le.add_theme_font_size_override("font_size", 36)
	le.add_theme_color_override("font_color", UI.TEXT_DARK)
	le.custom_minimum_size = Vector2(0, 84)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fffdf7")
	sb.set_corner_radius_all(22)
	sb.border_color = Color("#dcc79a")
	sb.set_border_width_all(3)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", sb)
	le.text_submitted.connect(func(t: String) -> void:
		Game.player_name = t.strip_edges().substr(0, 18)
		if Game.player_name == "":
			Game.player_name = "کاربر عزیز"
		Game.save_game()
		Audio.play("tap")
		toast("نام ذخیره شد"))
	col.add_child(le)


# ------------------------------------------------------------------- reset
func _reset_card() -> void:
	var c := card(196, 30, Color("#fbeeee"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	UI.card_add(c, row, 26.0)

	var btn := JuicyBtn.new()
	btn.text = "بازنشانی پیشرفت"
	btn.base_color = Color("#e0665a")
	btn.shadow_color = Color("#a8402f")
	btn.font_size = 34
	btn.corner = 28.0
	btn.depth = 11.0
	btn.custom_minimum_size = Vector2(420, 116)
	btn.pressed.connect(_confirm_reset)
	row.add_child(btn)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	var t1 := UI.right_label("همهٔ پیشرفت پاک می‌شود", 30, UI.TEXT_DARK)
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t1)
	var t2 := UI.right_label("سکه‌ها و ستاره‌ها هم پاک می‌شوند.", 24, UI.INK_SOFT)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t2)
	row.add_child(col)


func _confirm_reset() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	_dialog = Control.new()
	_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog.z_index = 60
	add_child(_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(dim)
	var c := UI.card(Vector2(820, 440), 40, Color("#fdf6e6"))
	c.position = Vector2(130, 620)
	_dialog.add_child(c)
	UI.pop_in(c)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 26)
	UI.card_add(c, col, 40.0)
	col.add_child(UI.label("مطمئنی؟", 48, UI.RED))
	col.add_child(UI.label("همهٔ پیشرفت پاک می‌شود و از مرحلهٔ ۱ شروع می‌کنی.",
		30, UI.INK_SOFT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	var yes := JuicyBtn.new()
	yes.text = "بله، پاک کن"
	yes.base_color = Color("#e0665a")
	yes.shadow_color = Color("#a8402f")
	yes.font_size = 34
	yes.corner = 28.0
	yes.depth = 11.0
	yes.custom_minimum_size = Vector2(340, 116)
	yes.pressed.connect(func() -> void:
		Game.reset_progress()
		_close_dialog()
		Audio.play("unlock")
		Transition.change_scene("res://scenes/HomeScene.tscn"))
	row.add_child(yes)
	var no := JuicyBtn.new()
	no.text = "نه، بی‌خیال"
	no.base_color = Color("#c9a86a")
	no.shadow_color = Color("#8a7048")
	no.font_size = 34
	no.corner = 28.0
	no.depth = 11.0
	no.custom_minimum_size = Vector2(300, 116)
	no.pressed.connect(_close_dialog)
	row.add_child(no)
	col.add_child(row)


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
