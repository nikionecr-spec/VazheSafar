extends SubScene
## Quests & rewards — built around the daily habit loop:
## a 7-day streak strip, three live quests with progress, player stats.

const JuicyBtn := preload("res://scripts/JuicyButton.gd")


func _init() -> void:
	screen_title = "ماموریت‌ها"
	section = "quests"
	nav_key = "quests"


func build_body() -> void:
	_streak_strip()
	_daily_card()
	for q in Game.quests:
		body.add_child(_quest_card(q))
	_stats_card()
	_achievement_card()


# ------------------------------------------------------------- 7-day strip
func _streak_strip() -> void:
	var c := card(300)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(_icon("gift", 96))
	var t1 := UI.label("زنجیرهٔ روزانه", 42, UI.INK, UI.FONT_BLACK)
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(t1)
	var streak := UI.label(Game.fa_num(int(Game.daily.get("streak", 0))) + " روز", 34,
		Color("#c98a12"))
	head.add_child(streak)
	vb.add_child(head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for d in Game.daily_strip():
		var box := Control.new()
		box.custom_minimum_size = Vector2(122, 168)
		var done: bool = bool(d["done"])
		var cur: bool = bool(d["current"])
		var big: bool = bool(d["big"])
		var top := Color("#f7d78a") if not big else Color("#f6c95f")
		var bot := Color("#e0a93c") if not big else Color("#d98a1f")
		if done:
			top = Color("#a8dd84")
			bot = Color("#5da13c")
		var face := UI.gradient_panel(122, 168, top, bot, 26,
			Color(1, 1, 1, 0.45), 2, 0.18)
		box.add_child(face)
		var dl := UI.label("روز " + Game.fa_num(int(d["day"])), 24,
			Color("#4a2c10") if not done else Color("#204a12"))
		dl.position = Vector2(0, 8)
		dl.size = Vector2(122, 30)
		box.add_child(dl)
		var rw := UI.label(Game.fa_num(int(d["reward"])), 30, Color("#4a2c10"))
		rw.position = Vector2(0, 44)
		rw.size = Vector2(122, 36)
		box.add_child(rw)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/icons/%s.png" % ("chest" if big else "coin"))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(28, 84)
		ic.size = Vector2(66, 66)
		box.add_child(ic)
		if done:
			var chk := UI.label("✓", 34, Color.WHITE, UI.FONT_BLACK)
			chk.position = Vector2(0, 128)
			chk.size = Vector2(122, 34)
			box.add_child(chk)
		if cur:
			box.pivot_offset = box.custom_minimum_size * 0.5
			var tw := box.create_tween().set_loops()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(box, "scale", Vector2(1.06, 1.06), 0.7)
			tw.tween_property(box, "scale", Vector2.ONE, 0.7)
			var glow := UI.glow(80, Color(1.0, 0.85, 0.4, 0.35), 2.0)
			glow.position = Vector2(-19, 4)
			box.add_child(glow)
			box.move_child(glow, 0)
		row.add_child(box)
	vb.add_child(row)
	c.add_child(vb)
	body.add_child(c)


# ------------------------------------------------------------ daily claim
func _daily_card() -> void:
	var c := card(230)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	var ready := Game.can_claim_daily()
	var btn := JuicyBtn.new()
	btn.text = "دریافت جایزه" if ready else "امروز گرفتی"
	btn.icon_path = "res://assets/icons/coin.png"
	btn.base_color = Color("#5cbf2a") if ready else Color("#9a9284")
	btn.shadow_color = Color("#2f6a15") if ready else Color("#6a6355")
	btn.font_size = 38
	btn.corner = 32.0
	btn.custom_minimum_size = Vector2(330, 126)
	btn.set_disabled(not ready)
	if ready:
		btn.idle_pulse = true
		btn.shine = true
	btn.pressed.connect(func() -> void:
		var amount := Game.claim_daily()
		if amount > 0:
			Audio.play("chest")
			_toast("+" + Game.fa_num(amount) + " سکه!")
			_rebuild())
	hb.add_child(btn)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 6)
	var t1 := UI.label("جایزهٔ روزانه", 40, UI.INK, UI.FONT_BLACK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t1)
	var line := "امروز جایزه‌ات آماده است" if ready else "فردا دوباره سر بزن"
	var t2 := UI.label(line, 28, UI.INK_SOFT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t2)
	var t3 := UI.label("اولین مرحلهٔ هر روز هم سکهٔ دوبرابر می‌دهد"
		if Game.daily_bonus_ready() else "جایزهٔ دوبرابر امروز استفاده شد", 26,
		Color("#5da13c") if Game.daily_bonus_ready() else Color("#a08a6a"))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t3)
	hb.add_child(tv)
	hb.add_child(_icon("gift", 120))
	c.add_child(hb)
	body.add_child(c)


func _quest_card(q: Dictionary) -> Control:
	var c := card(200)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER


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
	var btn := JuicyBtn.new()
	btn.text = "✓" if claimed else ("گرفتن" if done else "در جریان")
	btn.base_color = Color("#5cbf2a") if done and not claimed else Color("#9a9284")
	btn.shadow_color = Color("#2f6a15") if done and not claimed else Color("#6a6355")
	btn.font_size = 34
	btn.corner = 30.0
	btn.custom_minimum_size = Vector2(260, 118)
	btn.set_disabled(claimed or not done)
	var qid := String(q["id"])
	btn.pressed.connect(func() -> void:
		if Game.claim_quest(qid):
			Audio.play("chest")
			_toast("+" + Game.fa_num(int(q["reward"])) + " سکه!")
			_rebuild())
	hb.add_child(btn)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 12)
	var t1 := UI.label(String(q["text"]), 36, UI.INK, UI.FONT_BLACK)
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
	fgs.bg_color = Color("#63c132") if done else Color("#f0a93a")
	fgs.set_corner_radius_all(17)
	pb.add_theme_stylebox_override("background", bgs)
	pb.add_theme_stylebox_override("fill", fgs)
	tv.add_child(pb)

	var t2 := UI.label("%s / %s   •   جایزه %s سکه" % [
		Game.fa_num(int(q["progress"])), Game.fa_num(int(q["goal"])),
		Game.fa_num(int(q["reward"]))], 26, UI.INK_SOFT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t2)
	hb.add_child(tv)
	c.add_child(hb)
	return c


func _stats_card() -> void:
	var c := card(0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	var t := UI.label("آمار تو", 40, UI.INK, UI.FONT_BLACK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(t)
	var s := Game.stats
	var rows := [
		["کلمه‌های پیدا شده", Game.fa_num(int(s.get("words_found", 0)))],
		["کلمهٔ جایزه‌ای", Game.fa_num(int(s.get("bonus_found", 0)))],
		["مرحله‌های کامل‌شده", Game.fa_num(int(s.get("levels_done", 0)))],
		["ستاره‌ها", Game.fa_num(Game.total_stars()) + " از "
			+ Game.fa_num(Game.total_levels() * 3)],
		["بهترین زنجیره", Game.fa_num(Game.best_combo)],
		["راهنماهای استفاده‌شده", Game.fa_num(int(s.get("hints_used", 0)))],
	]
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var v := UI.label(String(r[1]), 32, Color("#c98a12"), UI.FONT_BLACK)
		hb.add_child(v)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(sp)
		var l := UI.label(String(r[0]), 32, UI.INK)
		hb.add_child(l)
		vb.add_child(hb)
	c.add_child(vb)
	body.add_child(c)


func _achievement_card() -> void:
	var c := card(200)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_icon("trophy", 120))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t1 := UI.label("دستاوردها", 40, UI.INK, UI.FONT_BLACK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t1)
	var t2 := UI.label("%s از %s باز شد" % [
		Game.fa_num(Game.achievements_unlocked()),
		Game.fa_num(Game.achievements().size())], 28, UI.INK_SOFT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t2)
	tv.add_child(UI.label("برای دیدن فهرست کامل، در صفحهٔ خانه روی کارت پروفایل بزن",
		24, Color("#a08a6a")))
	hb.add_child(tv)
	c.add_child(hb)
	body.add_child(c)


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
