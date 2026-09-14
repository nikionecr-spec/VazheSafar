extends Control
## Level-complete celebration popup with animated stars and rewards.

const UI := preload("res://scripts/UIKit.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")

signal next_pressed
signal map_pressed

var stars_box: HBoxContainer
var title: Label
var reward_label: Label
var bonus_line: Label
var card: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	card = PanelContainer.new()
	var sb := UI.cream_panel(40)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 44
	sb.content_margin_bottom = 44
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(110, 560)
	card.custom_minimum_size = Vector2(860, 800)
	add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER

	title = UI.label("مرحله کامل شد!", 48, UI.TEXT_DARK)
	vb.add_child(title)

	stars_box = HBoxContainer.new()
	stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_box.add_theme_constant_override("separation", 10)
	stars_box.custom_minimum_size = Vector2(0, 120)
	vb.add_child(stars_box)

	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 10)
	reward_label = UI.label("+۰", 52, Color("#c98a12"))
	rrow.add_child(reward_label)
	var ci := TextureRect.new()
	ci.texture = load("res://assets/icons/coin.png")
	ci.custom_minimum_size = Vector2(72, 72)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rrow.add_child(ci)
	vb.add_child(rrow)

	bonus_line = UI.label("", 30, Color("#8a6a3c"))
	vb.add_child(bonus_line)

	var next_btn := JuicyBtn.new()
	next_btn.text = "مرحله بعد"
	next_btn.icon_path = "res://assets/icons/btn_play.png"
	next_btn.base_color = Color("#5cbf2a")
	next_btn.shadow_color = Color("#357d12")
	next_btn.font_size = 46
	next_btn.corner = 38.0
	next_btn.idle_pulse = true
	next_btn.shine = true
	next_btn.custom_minimum_size = Vector2(600, 128)
	next_btn.pressed.connect(func(): next_pressed.emit())
	vb.add_child(next_btn)

	var map_btn := Button.new()
	map_btn.text = "بازگشت به نقشه"
	map_btn.add_theme_font_override("font", load(UI.FONT_BOLD))
	map_btn.add_theme_font_size_override("font_size", 32)
	map_btn.add_theme_color_override("font_color", Color("#8a6a3c"))
	map_btn.flat = true
	map_btn.custom_minimum_size = Vector2(0, 70)
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
	reward_label.text = "+" + Game.fa_num(reward + stars * 5)
	bonus_line.text = ("کلمات جایزه‌ای: " + Game.fa_num(bonus_count)) if bonus_count > 0 else ""
	bonus_line.visible = bonus_count > 0
	_animate_stars(stars)


func _animate_stars(count: int) -> void:
	for c in stars_box.get_children():
		c.queue_free()
	for i in 3:
		var s := TextureRect.new()
		s.texture = load("res://assets/icons/star_grey.png")
		s.custom_minimum_size = Vector2(112, 112)
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stars_box.add_child(s)
		if i < count:
			var idx := i
			var t := get_tree().create_timer(0.5 + idx * 0.33)
			t.timeout.connect(
				func() -> void:
					if not is_instance_valid(s) or not is_instance_valid(self):
						return
					s.texture = load("res://assets/icons/star_gold.png")
					s.pivot_offset = s.size * 0.5
					var tw := s.create_tween().set_trans(Tween.TRANS_BACK)
					tw.set_ease(Tween.EASE_OUT)
					tw.tween_property(s, "scale", Vector2(1.45, 1.45), 0.16)
					tw.tween_property(s, "scale", Vector2.ONE, 0.24)
					Audio.play("star", 1.0 + idx * 0.12))


func _confetti() -> void:
	for i in 3:
		var p := CPUParticles2D.new()
		p.position = Vector2(140.0 + 400.0 * float(i), 480.0)
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 34
		p.lifetime = 2.4
		p.direction = Vector2(0, -1)
		p.spread = 58.0
		p.initial_velocity_min = 620.0
		p.initial_velocity_max = 1150.0
		p.gravity = Vector2(0, 900)
		p.angular_velocity_min = -420.0
		p.angular_velocity_max = 420.0
		p.scale_amount_min = 5.0
		p.scale_amount_max = 11.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.85, 0.25))
		g.set_color(1, Color(0.35, 0.85, 1.0))
		g.add_point(0.35, Color(1.0, 0.42, 0.52))
		g.add_point(0.7, Color(0.55, 0.95, 0.45))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		p.color_ramp = g
		p.z_index = 60
		add_child(p)
		get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())
