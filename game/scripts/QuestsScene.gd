extends SubScene


func _init() -> void:
	screen_title = "ماموریت‌ها"


func build_body() -> void:
	_daily_card()
	for q in Game.quests:
		body.add_child(_quest_card(q))
	_stats_card()


func _daily_card() -> void:
	var c := card(190)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var btn := UI.green_button("دریافت", 34)
	btn.custom_minimum_size = Vector2(230, 96)
	btn.disabled = not Game.can_claim_daily()
	btn.pressed.connect(func() -> void:
		var amount := Game.claim_daily()
		if amount > 0:
			Audio.play("coin")
			_toast("+" + Game.fa_num(amount) + " سکه")
			_rebuild())
	hb.add_child(btn)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t1 := UI.label("جایزه روزانه", 40, UI.TEXT_DARK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var streak := int(Game.daily.get("streak", 0))
	var t2 := UI.label("روز پیاپی: " + Game.fa_num(streak), 28, Color("#8a6a3c"))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t1)
	tv.add_child(t2)
	hb.add_child(tv)

	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/gift.png")
	ic.custom_minimum_size = Vector2(120, 120)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ic)
	c.add_child(hb)
	body.add_child(c)


func _quest_card(q: Dictionary) -> Control:
	var c := card(180)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var done: bool = int(q["progress"]) >= int(q["goal"])
	var claimed: bool = bool(q["claimed"])
	var btn := UI.green_button("گرفتن" if done and not claimed else "…", 32)
	btn.custom_minimum_size = Vector2(210, 92)
	btn.disabled = claimed or not done
	if claimed:
		btn.text = "✓"
	var qid := String(q["id"])
	btn.pressed.connect(func() -> void:
		if Game.claim_quest(qid):
			Audio.play("coin")
			_toast("+" + Game.fa_num(int(q["reward"])) + " سکه")
			_rebuild())
	hb.add_child(btn)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 10)
	var t1 := UI.label(String(q["text"]), 34, UI.TEXT_DARK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t1)

	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 34)
	pb.max_value = float(q["goal"])
	pb.value = float(q["progress"])
	pb.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color("#e3d3ab")
	bgs.set_corner_radius_all(17)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = Color("#63c132")
	fgs.set_corner_radius_all(17)
	pb.add_theme_stylebox_override("background", bgs)
	pb.add_theme_stylebox_override("fill", fgs)
	tv.add_child(pb)

	var t2 := UI.label(Game.fa_num(int(q["progress"])) + " / " + Game.fa_num(int(q["goal"]))
		+ "   •   " + Game.fa_num(int(q["reward"])) + " سکه", 26, Color("#8a6a3c"))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t2)
	hb.add_child(tv)
	c.add_child(hb)
	return c


func _stats_card() -> void:
	var c := card(230)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(UI.label("آمار تو", 38, UI.TEXT_DARK))
	var rows := [
		["کلمات پیدا شده", int(Game.stats.get("words_found", 0))],
		["کلمات جایزه‌ای", int(Game.stats.get("bonus_found", 0))],
		["مراحل کامل‌شده", int(Game.stats.get("levels_done", 0))],
		["ستاره‌ها", Game.total_stars()],
	]
	for r in rows:
		vb.add_child(UI.label(String(r[0]) + ": " + Game.fa_num(int(r[1])), 28,
			Color("#8a6a3c")))
	c.add_child(vb)
	body.add_child(c)


func _rebuild() -> void:
	for ch in body.get_children():
		ch.queue_free()
	await get_tree().process_frame
	build_body()


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(size.x * 0.5 - 200, size.y * 0.5)
