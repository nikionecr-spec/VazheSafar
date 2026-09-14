extends SubScene
## Settings — big rows, real volume control and a per-section music preview
## so the player can hear what each screen sounds like.

const JuicyBtn := preload("res://scripts/JuicyButton.gd")

const SECTIONS := [
	["home", "خانه"], ["map", "نقشه"], ["level", "مرحله"],
	["shop", "فروشگاه"], ["quests", "ماموریت‌ها"],
]


func _init() -> void:
	screen_title = "تنظیمات"
	section = "settings"
	nav_key = ""


func build_body() -> void:
	body.add_child(_toggle_card("موسیقی پس‌زمینه", "music", "sound"))
	body.add_child(_volume_card("صدای موسیقی", "music_volume", "sound"))
	body.add_child(_volume_card("صدای جلوه‌ها", "sfx_volume", "hint"))
	body.add_child(_toggle_card("لرزش", "vibration", "settings"))
	_preview_card()
	body.add_child(_name_card())
	body.add_child(_reset_card())
	_about_card()


func _toggle_card(text: String, key: String, icon: String) -> Control:
	var c := card(150)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var on: bool = bool(Game.settings.get(key, true))
	var btn := JuicyBtn.new()
	btn.text = "روشن" if on else "خاموش"
	btn.base_color = Color("#5cbf2a") if on else Color("#9a9284")
	btn.shadow_color = Color("#2f6a15") if on else Color("#6a6355")
	btn.font_size = 32
	btn.corner = 28.0
	btn.custom_minimum_size = Vector2(230, 104)
	btn.pressed.connect(func() -> void:
		Game.settings[key] = not bool(Game.settings.get(key, true))
		Game.save_game()
		Audio.play("tap")
		if key == "music":
			Audio.set_music_enabled(bool(Game.settings["music"]))
			if bool(Game.settings["music"]):
				Audio.set_section("settings")
		_rebuild())
	hb.add_child(btn)

	var l := UI.label(text, 36, UI.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(l)
	hb.add_child(_icon(icon, 92))
	c.add_child(hb)
	return c


func _volume_card(text: String, key: String, icon: String) -> Control:
	var c := card(170)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(_icon(icon, 76))
	var l := UI.label(text, 34, UI.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(l)
	var pct := UI.label(Game.fa_num(int(round(float(Game.settings.get(key, 1.0)) * 100.0)))
		+ "٪", 30, Color("#c98a12"))
	head.add_child(pct)
	vb.add_child(head)

	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Game.settings.get(key, 1.0))
	sl.custom_minimum_size = Vector2(0, 56)
	sl.value_changed.connect(func(v: float) -> void:
		Game.settings[key] = v
		pct.text = Game.fa_num(int(round(v * 100.0))) + "٪"
		if key == "sfx_volume":
			Audio.play("tap")
		else:
			Audio._music_db())
	sl.drag_ended.connect(func(_v): Game.save_game())
	vb.add_child(sl)
	c.add_child(vb)
	return c


## Let the player audition the music of each section.
func _preview_card() -> void:
	var c := card(300)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	var t := UI.label("موسیقی هر بخش", 38, UI.INK, UI.FONT_BLACK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(t)
	var hint := UI.label("هر صفحه موزیک مخصوص خودش را دارد — اینجا گوش کن",
		26, UI.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	for s in SECTIONS:
		var key := String(s[0])
		var b := UI.alt_button(String(s[1]), Color("#8bb8e8"), Color("#3f6ea8"), 30)
		b.custom_minimum_size = Vector2(190, 96)
		b.pressed.connect(func() -> void:
			Game.settings["music"] = true
			Audio.set_music_enabled(true)
			Audio.set_section(key)
			Audio.play("tab"))
		flow.add_child(b)
	vb.add_child(flow)
	c.add_child(vb)
	body.add_child(c)


func _name_card() -> Control:
	var c := card(200)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	var l := UI.label("نام بازیکن", 34, UI.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(l)
	var le := LineEdit.new()
	le.text = Game.player_name
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	le.add_theme_font_override("font", load(UI.FONT_BOLD))
	le.add_theme_font_size_override("font_size", 34)
	le.custom_minimum_size = Vector2(0, 84)
	le.add_theme_color_override("font_color", UI.INK)
	le.add_theme_color_override("caret_color", UI.INK)
	le.text_submitted.connect(func(t: String) -> void:
		Game.player_name = t.strip_edges() if t.strip_edges() != "" else "کاربر عزیز"
		Game.save_game()
		Audio.play("btn_up"))
	le.focus_exited.connect(func() -> void:
		Game.player_name = le.text.strip_edges() if le.text.strip_edges() != "" else "کاربر عزیز"
		Game.save_game())
	vb.add_child(le)
	c.add_child(vb)
	return c


func _reset_card() -> Control:
	var c := card(160)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	var btn := UI.alt_button("پاک کردن", Color("#e0715c"), Color("#a8402f"), 32)
	btn.custom_minimum_size = Vector2(260, 104)
	var confirmed := {"v": false}
	btn.pressed.connect(func() -> void:
		if not confirmed["v"]:
			confirmed["v"] = true
			btn.text = "مطمئنی؟ دوباره بزن"
			Audio.play("word_bad")
			return
		Game.reset_progress()
		Audio.play("unlock")
		Transition.change_scene("res://scenes/HomeScene.tscn"))
	hb.add_child(btn)
	var l := UI.label("بازنشانی پیشرفت", 36, UI.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(l)
	hb.add_child(_icon("settings", 92))
	c.add_child(hb)
	return c


func _about_card() -> void:
	var c := card(220)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(UI.label("واژه‌سفر  ۱٫۲", 40, UI.INK, UI.FONT_BLACK))
	vb.add_child(UI.label("کلمه بساز، حال خوب بچین!", 28, UI.INK_SOFT))
	vb.add_child(UI.label(Game.fa_num(Game.total_levels()) + " مرحله  •  "
		+ Game.fa_num(Game.dictionary.size()) + " کلمهٔ جایزه‌ای  •  بدون اینترنت",
		26, UI.INK_SOFT))
	c.add_child(vb)
	body.add_child(c)
	body.add_child(_footer_space())


func _footer_space() -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	return sp


func _icon(name: String, box: float) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % name)
	ic.custom_minimum_size = Vector2(box, box)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return ic


func _rebuild() -> void:
	for ch in body.get_children():
		ch.queue_free()
	await get_tree().process_frame
	build_body()
