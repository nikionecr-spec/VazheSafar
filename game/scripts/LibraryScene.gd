extends SubScene
## Word library: every word the player has discovered, grouped by level.


func _init() -> void:
	screen_title = "کتابخانه"
	section = "library"
	nav_key = "library"


func build_body() -> void:
	var total := 0
	var solved: Array = []
	for i in range(1, Game.total_levels() + 1):
		if Game.stars_for(i) > 0:
			solved.append(i)

	if solved.is_empty():
		var c := card(200)
		c.add_child(UI.label("هنوز کلمه‌ای پیدا نکرده‌ای!\nاولین مرحله را کامل کن.",
			32, Color("#8a6a3c")))
		body.add_child(c)
		return

	for lvl in solved:
		var data := Game.get_level(lvl)
		var words: Array = data.get("words", [])
		var bonus: Array = Game.found_bonus.get(str(lvl), [])
		total += words.size() + bonus.size()

		var c := card(0)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 12)

		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_END
		var st := Game.stars_for(lvl)
		for i in 3:
			var s := TextureRect.new()
			s.texture = load("res://assets/icons/star_gold.png" if i < st
				else "res://assets/icons/star_grey.png")
			s.custom_minimum_size = Vector2(34, 34)
			s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			head.add_child(s)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sp)
		head.add_child(UI.label("مرحله " + Game.fa_num(lvl), 34, UI.TEXT_DARK))
		vb.add_child(head)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		for w in words:
			flow.add_child(_chip(String(w), false))
		for w in bonus:
			flow.add_child(_chip(String(w), true))
		vb.add_child(flow)
		c.add_child(vb)
		body.add_child(c)

	var summary := card(120)
	summary.add_child(UI.label("مجموع کلمات: " + Game.fa_num(total), 34, UI.TEXT_DARK))
	body.add_child(summary)


func _chip(word: String, bonus: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f7d774") if bonus else Color("#cfe9b8")
	sb.set_corner_radius_all(16)
	sb.border_color = Color("#d9a93c") if bonus else Color("#8dc46a")
	sb.set_border_width_all(2)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UI.label(word, 30, UI.TEXT_DARK))
	return p
