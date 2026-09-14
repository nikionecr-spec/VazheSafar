extends SubScene
## ============================================================================
##  ماموریت‌ها و جوایز — چیدمان گرافیکی با نوار روزهای پیاپی و نوار پیشرفت
## ============================================================================

const JuicyBtn := preload("res://scripts/JuicyButton.gd")


func _init() -> void:
	screen_title = "ماموریت‌ها"
	nav_index = 3


func build_body() -> void:
	_daily_hero()
	section("ماموریت‌های امروز")
	for q in Game.quests:
		_quest_card(q)
	section("آمار من")
	_stats_grid()
	spacer(40)


# ------------------------------------------------------------------- daily
func _daily_hero() -> void:
	var c := card(430, 38, Color("#fdf3dc"), true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.card_add(c, col, 30.0)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	var gift := TextureRect.new()
	gift.texture = load("res://assets/icons/gift.png")
	gift.custom_minimum_size = Vector2(104, 104)
	gift.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gift.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(gift)
	var t := UI.outlined_label("جایزهٔ روزانه", 46, Color("#fff6dc"), Color("#4a2c10"), 8)
	head.add_child(t)
	col.add_child(head)

	# نوار ۷ روز
	var streak: int = int(Game.daily.get("streak", 0))
	var claimed_today := not Game.can_claim_daily()
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 14)
	col.add_child(strip)
	for i in 7:
		var day_no := i + 1
		var lit := day_no <= streak
		var is_today := day_no == streak + 1 and not claimed_today
		var dot := _day_dot(day_no, lit, is_today, 50 + day_no * 25)
		strip.add_child(dot)

	var next_amount := 50 + mini(streak + 1, 7) * 25
	var claim := JuicyBtn.new()
	claim.text = ("دریافت " + Game.fa_num(next_amount) + " سکه") if not claimed_today else "فردا برگرد"
	claim.base_color = Color("#57c22c") if not claimed_today else Color("#b9ae98")
	claim.shadow_color = Color("#2f7a1c") if not claimed_today else Color("#8a8070")
	claim.font_size = 40
	claim.corner = 34.0
	claim.depth = 13.0
	claim.shine = not claimed_today
	claim.idle_pulse = not claimed_today
	claim.custom_minimum_size = Vector2(560, 126)
	claim.set_disabled(claimed_today)
	claim.pressed.connect(func() -> void:
		var got := Game.claim_daily()
		if got > 0:
			Audio.play("coin")
			toast("+" + Game.fa_num(got) + " سکه")
			rebuild())
	col.add_child(claim)


func _day_dot(day: int, lit: bool, is_today: bool, amount: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(118, 168)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color("#ffd76a") if lit else (Color("#fff3d6") if is_today else Color("#e8dfc8"))
	if is_today:
		var glow := ArtL.glow_disc(150, Color("#ffe08a"))
		glow.position = Vector2(-16, -12)
		holder.add_child(glow)
	var disc := TextureRect.new()
	disc.texture = ArtL.radial_texture(96, color, color.darkened(0.30))
	disc.position = Vector2(11, 6)
	disc.size = Vector2(96, 96)
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.stretch_mode = TextureRect.STRETCH_SCALE
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	var num := UI.label(Game.fa_num(day), 44, Color("#6b4a12") if lit else UI.INK_SOFT)
	num.position = Vector2(11, 6)
	num.size = Vector2(96, 96)
	holder.add_child(num)
	var amt := UI.label(Game.fa_num(amount), 24, Color("#ffedc4"))
	amt.position = Vector2(0, 112)
	amt.size = Vector2(118, 34)
	holder.add_child(amt)
	if lit:
		var check := UI.label("✓", 30, Color("#1f6f12"))
		check.position = Vector2(11, 62)
		check.size = Vector2(96, 40)
		holder.add_child(check)
	return holder


# ------------------------------------------------------------------ quests
func _quest_card(q: Dictionary) -> void:
	var c := card(232, 30, Color("#fdf6e6"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.card_add(c, row, 28.0)

	var progress := int(q["progress"])
	var goal: int = int(q["goal"])
	var done := progress >= goal
	var claimed: bool = bool(q["claimed"])

	var state_icon := TextureRect.new()
	state_icon.texture = load("res://assets/icons/%s.png" % (
		"trophy" if claimed else ("star_gold" if done else "quests")))
	state_icon.custom_minimum_size = Vector2(120, 120)
	state_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	state_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	state_icon.modulate = Color.WHITE if done else Color(0.85, 0.85, 0.85)
	row.add_child(state_icon)

	var btn := JuicyBtn.new()
	btn.text = "گرفتن" if (done and not claimed) else ("✓ گرفته شد" if claimed else "در جریان")
	btn.base_color = Color("#57c22c") if (done and not claimed) else Color("#b9ae98")
	btn.shadow_color = Color("#2f7a1c") if (done and not claimed) else Color("#8a8070")
	btn.font_size = 34
	btn.corner = 28.0
	btn.depth = 11.0
	btn.shine = done and not claimed
	btn.custom_minimum_size = Vector2(280, 116)
	btn.set_disabled(claimed or not done)
	var qid := String(q["id"])
	btn.pressed.connect(func() -> void:
		if Game.claim_quest(qid):
			Audio.play("coin")
			toast("+" + Game.fa_num(int(q["reward"])) + " سکه")
			rebuild())
	row.add_child(btn)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	col.add_child(UI.label(String(q["text"]), 38, UI.TEXT_DARK))
	var bar := ArtL.progress_bar(Vector2(430, 32), float(progress) / float(maxi(goal, 1)))
	col.add_child(bar)
	col.add_child(UI.label(Game.fa_num(progress) + " از " + Game.fa_num(goal)
		+ "   •   جایزه " + Game.fa_num(int(q["reward"])) + " سکه", 26, UI.INK_SOFT))
	row.add_child(col)


# ------------------------------------------------------------------- stats
func _stats_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	body.add_child(grid)
	var stats := [
		["کلمهٔ پیدا‌شده", Game.fa_num(int(Game.stats.get("words_found", 0))), "res://assets/icons/book.png", UI.GREEN],
		["کلمهٔ جایزه‌ای", Game.fa_num(int(Game.stats.get("bonus_found", 0))), "res://assets/icons/gem.png", UI.AMBER],
		["مرحلهٔ کامل‌شده", Game.fa_num(int(Game.stats.get("levels_done", 0))), "res://assets/icons/trophy.png", UI.GOLD_DARK],
		["ستاره‌ها", Game.fa_num(Game.total_stars()), "res://assets/icons/star_gold.png", UI.GOLD_DARK],
	]
	for i in stats.size():
		grid.add_child(UI.stat_tile(Vector2(480, 150), String(stats[i][1]),
			String(stats[i][0]), String(stats[i][2]), stats[i][3] as Color))
