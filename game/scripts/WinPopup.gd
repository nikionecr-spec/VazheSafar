extends Control
## ============================================================================
##  پاپ‌آپ پایان مرحله — جشنِ گرافیکی
##  تابلو، ستاره‌های جهنده، سکه‌های پرنده، کلمه‌های جایزه و دو دکمهٔ درشت
## ============================================================================

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")

signal next_pressed
signal map_pressed

var stars_box: HBoxContainer
var title: Label
var reward_label: Label
var bonus_line: Label
var card: Control
var _coin_pill: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	_build()


func setup(level_id: int, stars: int, reward: int, bonus_count: int) -> void:
	if title == null:
		await ready
	title.text = "مرحلهٔ " + Game.fa_num(level_id) + " تمام شد!"
	reward_label.text = "+" + Game.fa_num(reward + stars * 5)
	bonus_line.text = ("کلمه‌های جایزه‌ای: " + Game.fa_num(bonus_count)) if bonus_count > 0 else ""
	bonus_line.visible = bonus_count > 0
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
		s.size = Vector2(150, 150)
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder.add_child(s)
		stars_box.add_child(holder)
		if i < count:
			var idx := i
			var t := get_tree().create_timer(0.45 + idx * 0.30)
			t.timeout.connect(func() -> void:
				if not is_instance_valid(s) or not is_instance_valid(self):
					return
				s.texture = load("res://assets/icons/star_gold.png")
				glow.modulate.a = 1.0
				s.pivot_offset = s.size * 0.5
				var tw := s.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(s, "scale", Vector2(1.35, 1.35), 0.44).from(Vector2(0.4, 0.4))
				Audio.play("star", 1.0 + idx * 0.12)
				var gt := glow.create_tween().set_loops()
				gt.set_trans(Tween.TRANS_SINE)
				gt.tween_property(glow, "modulate:a", 0.55, 0.6)
				gt.tween_property(glow, "modulate:a", 1.0, 0.6))


## سکه‌ها از تابلو به سمت شمارندهٔ سکه پرواز می‌کنند (بازخورد پاداش)
func _fly_coins(count: int) -> void:
	var from := Vector2(UI.SCREEN.x * 0.5, 900)
	var target := Vector2(UI.SCREEN.x * 0.5, UI.SCREEN.y + 60)
	for i in count:
		var c := TextureRect.new()
		c.texture = load("res://assets/icons/coin.png")
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.size = Vector2(64, 64)
		c.position = from + Vector2(randf_range(-220, 220), randf_range(-60, 60))
		c.z_index = 60
		add_child(c)
		var mid := c.position.lerp(target, 0.5) + Vector2(randf_range(-200, 200), -420)
		var tw := c.create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.6 + 0.05 * float(i))
		tw.tween_property(c, "position", mid, 0.34)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(c, "position", target, 0.42)
		tw.parallel().tween_property(c, "scale", Vector2(0.4, 0.4), 0.42)
		tw.tween_callback(func():
			Audio.play("coin", randf_range(0.95, 1.1))
			if is_instance_valid(c):
				c.queue_free())


func _confetti() -> void:
	for i in 3:
		var p := CPUParticles2D.new()
		p.position = Vector2(140.0 + 400.0 * float(i), 420.0)
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 30
		p.lifetime = 2.4
		p.direction = Vector2(0, -1)
		p.spread = 58.0
		p.initial_velocity_min = 620.0
		p.initial_velocity_max = 1150.0
		p.gravity = Vector2(0, 900)
		p.angular_velocity_min = -420.0
		p.angular_velocity_max = 420.0
		p.scale_amount_min = 4.5
		p.scale_amount_max = 10.0
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
