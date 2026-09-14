extends Control
## Level-complete celebration. Shows the star payout, the reward breakdown
## (including the once-a-day double), how close the next surprise chest is,
## and a single, unmissable "next level" action.

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")

signal next_pressed
signal map_pressed

var stars_box: HBoxContainer
var title: Label
var reward_label: Label
var bonus_line: Label
var chest_line: Label
var daily_line: Label
var next_btn: JuicyButton
var card: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	card = UI.paper_card(44, 40)
	card.position = Vector2(96, 430)
	card.custom_minimum_size = Vector2(888, 1052)
	card.size = Vector2(888, 1052)
	card.pivot_offset = Vector2(444, 526)
	add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER

	title = UI.label("مرحله کامل شد!", 50, UI.INK, UI.FONT_BLACK)
	vb.add_child(title)

	stars_box = HBoxContainer.new()
	stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_box.add_theme_constant_override("separation", 14)
	stars_box.custom_minimum_size = Vector2(0, 138)
	vb.add_child(stars_box)

	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 12)
	reward_label = UI.label("+۰", 56, Color("#c98a12"), UI.FONT_BLACK)
	rrow.add_child(reward_label)
	var ci := TextureRect.new()
	ci.texture = load("res://assets/icons/coin.png")
	ci.custom_minimum_size = Vector2(84, 84)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rrow.add_child(ci)
	vb.add_child(rrow)

	daily_line = UI.label("", 30, Color("#3f8a1e"))
	daily_line.visible = false
	vb.add_child(daily_line)

	bonus_line = UI.label("", 30, UI.INK_SOFT)
	vb.add_child(bonus_line)

	chest_line = UI.label("", 30, Color("#c98a12"))
	vb.add_child(chest_line)

	next_btn = JuicyBtn.new()
	next_btn.text = "مرحله بعد"
	next_btn.icon_path = "res://assets/icons/btn_play.png"
	next_btn.base_color = Color("#5cbf2a")
	next_btn.shadow_color = Color("#2f6a15")
	next_btn.font_size = 48
	next_btn.corner = 40.0
	next_btn.depth = 12.0
	next_btn.idle_pulse = true
	next_btn.shine = true
	next_btn.glow = true
	next_btn.custom_minimum_size = Vector2(700, 146)
	next_btn.size = Vector2(700, 146)
	next_btn.pressed.connect(func():
		Audio.play("tap")
		next_pressed.emit())
	vb.add_child(next_btn)

	var map_btn := UI.alt_button("بازگشت به نقشه", Color("#8a6134"), Color("#543616"), 30)
	map_btn.custom_minimum_size = Vector2(520, 96)
	map_btn.size = Vector2(520, 96)
	map_btn.pressed.connect(func():
		Audio.play("tap")
		map_pressed.emit())
	vb.add_child(map_btn)

	card.add_child(vb)
	UI.pop_in(card)
	_confetti()


func setup(level_id: int, stars: int, reward: int, bonus_count: int) -> void:
	if title == null:
		await ready
	title.text = "مرحله " + Game.fa_num(level_id) + " کامل شد!"
	var r := Game.last_reward
	var base: int = int(r.get("base", reward))
	var star_bonus: int = stars * 5
	var daily: int = int(r.get("daily", 0))
	reward_label.text = "+" + Game.fa_num(base + star_bonus + daily)
	if daily > 0:
		daily_line.text = "جایزهٔ اولین مرحلهٔ امروز دوبرابر شد! (+" + Game.fa_num(daily) + ")"
		daily_line.visible = true
	if bonus_count > 0:
		bonus_line.text = "کلمه‌های جایزه‌ای: " + Game.fa_num(bonus_count) + "  •  +" + Game.fa_num(bonus_count * 5) + " سکه"
	else:
		bonus_line.text = ""
	bonus_line.visible = bonus_count > 0
	var left: int = int(r.get("chest_left", Game.chest_levels_left()))
	if left <= 0:
		chest_line.text = "صندوقچهٔ جایزه‌ات آماده شد! در صفحهٔ خانه بازش کن"
		chest_line.add_theme_color_override("font_color", Color("#3f8a1e"))
	elif left <= 2:
		chest_line.text = "فقط " + Game.fa_num(left) + " مرحله تا صندوقچه!"
	else:
		chest_line.text = Game.fa_num(left) + " مرحله تا صندوقچهٔ جایزه"
	chest_line.visible = true
	if level_id < Game.total_levels():
		next_btn.set_text("مرحله " + Game.fa_num(level_id + 1))
	_animate_stars(stars)
	_fly_coins(6 + stars * 3)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.01, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	card = UI.card(Vector2(900, 1120), 44, Color("#fdf6e6"), true)
	card.position = Vector2(90, 390)
	add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.card_add(card, col, 40.0)

	title = UI.label("مرحله کامل شد!", 54, UI.TEXT_DARK)
	col.add_child(title)

	stars_box = HBoxContainer.new()
	stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_box.add_theme_constant_override("separation", 18)
	stars_box.custom_minimum_size = Vector2(0, 190)
	col.add_child(stars_box)

	# ردیف جایزه: سکه + مقدار
	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 18)
	reward_label = UI.label("+۰", 66, Color("#c98a12"))
	rrow.add_child(reward_label)
	var coin := TextureRect.new()
	coin.texture = load("res://assets/icons/coin.png")
	coin.custom_minimum_size = Vector2(92, 92)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rrow.add_child(coin)
	var coin_pulse := coin.create_tween().set_loops()
	coin_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	coin_pulse.tween_property(coin, "scale", Vector2(1.12, 1.12), 0.7)
	coin_pulse.tween_property(coin, "scale", Vector2.ONE, 0.7)
	coin.pivot_offset = Vector2(46, 46)
	col.add_child(rrow)

	bonus_line = UI.label("", 32, UI.INK_SOFT)
	col.add_child(bonus_line)

	var next_btn := JuicyBtn.new()
	next_btn.text = "مرحلهٔ بعد"
	next_btn.icon_path = "res://assets/icons/btn_play.png"
	next_btn.base_color = Color("#57c22c")
	next_btn.shadow_color = Color("#2f7a1c")
	next_btn.font_size = 52
	next_btn.corner = 40.0
	next_btn.depth = 15.0
	next_btn.idle_pulse = true
	next_btn.shine = true
	next_btn.custom_minimum_size = Vector2(700, 158)
	next_btn.pressed.connect(func(): next_pressed.emit())
	col.add_child(next_btn)

	var map_btn := JuicyBtn.new()
	map_btn.text = "بازگشت به نقشه"
	map_btn.base_color = Color("#c9a86a")
	map_btn.shadow_color = Color("#8a7048")
	map_btn.font_size = 34
	map_btn.corner = 30.0
	map_btn.depth = 11.0
	map_btn.custom_minimum_size = Vector2(560, 112)
	map_btn.pressed.connect(func(): map_pressed.emit())
	col.add_child(map_btn)

	UI.pop_in(card)
	_confetti()


func _animate_stars(count: int) -> void:
	for c in stars_box.get_children():
		c.queue_free()
	for i in 3:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(150, 150)
		holder.size = holder.custom_minimum_size
		var glow := ArtL.glow_disc(200, Color("#ffe08a"))
		glow.position = Vector2(-25, -25)
		glow.modulate.a = 0.0
		holder.add_child(glow)
		var s := TextureRect.new()
		s.texture = load("res://assets/icons/star_grey.png")
		s.custom_minimum_size = Vector2(130, 130)
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder.add_child(s)
		stars_box.add_child(holder)
		if i < count:
			var idx := i
			var t := get_tree().create_timer(0.45 + float(idx) * 0.32)
			t.timeout.connect(
				func() -> void:
					if not is_instance_valid(s) or not is_instance_valid(self):
						return
					s.texture = load("res://assets/icons/star_gold.png")
					s.pivot_offset = s.size * 0.5
					var tw := s.create_tween().set_trans(Tween.TRANS_BACK)
					tw.set_ease(Tween.EASE_OUT)
					tw.tween_property(s, "scale", Vector2(1.42, 1.42), 0.18)
					tw.tween_property(s, "scale", Vector2.ONE, 0.26)
					Audio.play("star", 1.0 + float(idx) * 0.12))
		else:
			s.modulate = Color(1, 1, 1, 0.45)


func _confetti() -> void:
	for i in 3:
		var p := CPUParticles2D.new()
		p.position = Vector2(160.0 + 380.0 * float(i), 400.0)
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 26
		p.lifetime = 2.4
		p.direction = Vector2(0, -1)
		p.spread = 55.0
		p.initial_velocity_min = 520.0
		p.initial_velocity_max = 980.0
		p.gravity = Vector2(0, 880)
		p.angular_velocity_min = -380.0
		p.angular_velocity_max = 380.0
		p.scale_amount_min = 4.0
		p.scale_amount_max = 9.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.85, 0.25))
		g.set_color(1, Color(0.35, 0.85, 1.0))
		g.add_point(0.35, Color(1.0, 0.42, 0.52))
		g.add_point(0.7, Color(0.55, 0.95, 0.45))
		p.color_ramp = g
		p.z_index = 60
		add_child(p)
		get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		map_pressed.emit()
