extends SubScene


func _init() -> void:
	screen_title = "تنظیمات"


func build_body() -> void:
	body.add_child(_toggle("موسیقی", "music"))
	body.add_child(_toggle("صدای بازی", "sfx"))
	body.add_child(_toggle("لرزش", "vibration"))
	body.add_child(_name_card())
	body.add_child(_reset_card())
	body.add_child(_about_card())


func _toggle(text: String, key: String) -> Control:
	var c := card(140)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var on: bool = bool(Game.settings.get(key, true))
	var btn := UI.green_button("روشن" if on else "خاموش", 30)
	btn.custom_minimum_size = Vector2(200, 88)
	if not on:
		var sb := UI.green_button_style(false)
		sb.bg_color = Color("#b0a08a")
		sb.border_color = Color("#8a7a64")
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
	btn.pressed.connect(func() -> void:
		Game.settings[key] = not bool(Game.settings.get(key, true))
		Game.save_game()
		Audio.play("tap")
		if key == "music":
			if Game.settings["music"]:
				Audio.start_music()
			else:
				Audio.stop_music()
		_rebuild())
	hb.add_child(btn)

	var l := UI.label(text, 36, UI.TEXT_DARK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(l)
	c.add_child(hb)
	return c


func _name_card() -> Control:
	var c := card(160)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	var l := UI.label("نام بازیکن", 32, UI.TEXT_DARK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(l)
	var le := LineEdit.new()
	le.text = Game.player_name
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	le.add_theme_font_override("font", load(UI.FONT_BOLD))
	le.add_theme_font_size_override("font_size", 32)
	le.custom_minimum_size = Vector2(0, 66)
	le.text_submitted.connect(func(t: String) -> void:
		Game.player_name = t.strip_edges()
		Game.save_game()
		Audio.play("tap"))
	le.focus_exited.connect(func() -> void:
		Game.player_name = le.text.strip_edges()
		Game.save_game())
	vb.add_child(le)
	c.add_child(vb)
	return c


func _reset_card() -> Control:
	var c := card(150)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	var btn := UI.green_button("پاک کردن", 30)
	btn.custom_minimum_size = Vector2(230, 88)
	var sb := UI.green_button_style(false)
	sb.bg_color = Color("#d95f4b")
	sb.border_color = Color("#a8402f")
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var confirmed := {"v": false}
	btn.pressed.connect(func() -> void:
		if not confirmed["v"]:
			confirmed["v"] = true
			btn.text = "مطمئنی؟"
			Audio.play("word_bad")
			return
		Game.reset_progress()
		Audio.play("unlock")
		Transition.change_scene("res://scenes/HomeScene.tscn"))
	hb.add_child(btn)
	var l := UI.label("بازنشانی پیشرفت", 34, UI.TEXT_DARK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(l)
	c.add_child(hb)
	return c


func _about_card() -> Control:
	var c := card(180)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(UI.label("واژه‌سفر", 38, UI.TEXT_DARK))
	vb.add_child(UI.label("کلمه بساز، حال خوب بچین!", 26, Color("#8a6a3c")))
	vb.add_child(UI.label("نسخه ۱٫۰  •  " + Game.fa_num(Game.total_levels()) + " مرحله",
		26, Color("#8a6a3c")))
	c.add_child(vb)
	return c


func _rebuild() -> void:
	for ch in body.get_children():
		ch.queue_free()
	await get_tree().process_frame
	build_body()
