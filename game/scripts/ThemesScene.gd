extends SubScene
## ============================================================================
##  تم‌ها — قفل‌شکنِ بلندمدت (خرج کردن ستاره‌ها برای زیبایی)
##  هر کارت پیش‌نمایش رنگی، نیاز ستاره و دکمهٔ فعال‌سازی بزرگ دارد.
## ============================================================================

const JuicyBtn := preload("res://scripts/JuicyButton.gd")

const THEMES := [
	{"id": "spring", "name": "باغ بهاری", "stars": 0, "c1": "#8fd66a", "c2": "#f3c969",
		"desc": "شکوفه‌ها و نسیم صبح"},
	{"id": "sea", "name": "دهکدهٔ ساحلی", "stars": 9, "c1": "#63b8d6", "c2": "#a9e4f2",
		"desc": "آبی دریا و باد شرجی"},
	{"id": "sunset", "name": "غروب نارنجی", "stars": 24, "c1": "#f28d52", "c2": "#f7c873",
		"desc": "طلای غروب روی پشت‌بام‌ها"},
	{"id": "night", "name": "شب یلدا", "stars": 45, "c1": "#6a5ca8", "c2": "#b39ddb",
		"desc": "شب‌های بلند و انار و شمع"},
	{"id": "gold", "name": "قلهٔ طلایی", "stars": 75, "c1": "#e0a93c", "c2": "#f6e0a0",
		"desc": "افتخارِ فتحِ بلندترین قله"},
]


func _init() -> void:
	screen_title = "تم‌ها"
	nav_index = -1


func build_body() -> void:
	var have := Game.total_stars()
	var head := card(150, 30, Color("#fdf3dc"), true)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	UI.card_add(head, hb, 26.0)
	var star := TextureRect.new()
	star.texture = load("res://assets/icons/star_gold.png")
	star.custom_minimum_size = Vector2(100, 100)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(star)
	hb.add_child(UI.label("ستاره‌های تو: " + Game.fa_num(have) + " از "
		+ Game.fa_num(Game.total_levels() * 3), 38, UI.TEXT_DARK))

	for t in THEMES:
		var need: int = int(t["stars"])
		var unlocked: bool = have >= need
		var active: bool = String(Game.settings.get("theme", "spring")) == String(t["id"])
		body.add_child(_theme_card(t, unlocked, active, need))
	spacer(40)


func _theme_card(t: Dictionary, unlocked: bool, active: bool, need: int) -> Control:
	var size := Vector2(984, 226)
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(ArtL.card_panel(size, 32, Color("#fdf6e6") if unlocked else Color("#ded4c0")))

	# پیش‌نمایش رنگی
	var prev := Control.new()
	prev.position = Vector2(38, 38)
	prev.size = Vector2(150, 150)
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c1 := Color(String(t["c1"]))
	var c2 := Color(String(t["c2"]))
	var disc := TextureRect.new()
	disc.texture = ArtL.radial_texture(128, c2, c1)
	disc.size = prev.size
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.stretch_mode = TextureRect.STRETCH_SCALE
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.add_child(disc)
	var ring := ArtL.gold_ring(150, 6, Color("#fffaf0"))
	ring.modulate.a = 0.0
	prev.add_child(ring)
	var frame := Panel.new()
	frame.size = prev.size
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.set_corner_radius_all(75)
	fs.set_border_width_all(6)
	fs.border_color = UI.GOLD
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.add_child(frame)
	if not unlocked:
		prev.modulate = Color(0.55, 0.55, 0.55, 0.9)
		var lock := Control.new()
		lock.set_script(load("res://scripts/LockIcon.gd"))
		lock.size = Vector2(90, 90)
		lock.position = Vector2(30, 34)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prev.add_child(lock)
	holder.add_child(prev)

	var name_l := UI.label(String(t["name"]), 44, UI.TEXT_DARK if unlocked else Color("#8a7a5e"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_l.position = Vector2(130, 42)
	name_l.size = Vector2(470, 62)
	holder.add_child(name_l)

	var desc := UI.label(String(t.get("desc", "")), 26, UI.INK_SOFT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc.position = Vector2(130, 106)
	desc.size = Vector2(470, 44)
	holder.add_child(desc)

	var need_row := HBoxContainer.new()
	need_row.alignment = BoxContainer.ALIGNMENT_END
	need_row.add_theme_constant_override("separation", 8)
	need_row.position = Vector2(130, 152)
	need_row.size = Vector2(470, 50)
	need_row.add_child(UI.label("ستارهٔ لازم: " + Game.fa_num(need), 26, UI.INK_SOFT))
	need_row.add_child(UI.star_row(mini(3, maxi(1, int(round(float(need) / 25.0)) + 1 if need > 0 else 1)), 34))
	holder.add_child(need_row)

	var btn := JuicyBtn.new()
	btn.text = "فعال است" if active else ("انتخاب" if unlocked else "قفل است")
	btn.base_color = Color("#b9ae98") if (active or not unlocked) else Color("#57c22c")
	btn.shadow_color = Color("#8a8070") if (active or not unlocked) else Color("#2f7a1c")
	btn.font_size = 34
	btn.corner = 28.0
	btn.depth = 11.0
	btn.shine = unlocked and not active
	btn.custom_minimum_size = Vector2(280, 116)
	btn.position = Vector2(size.x - 300, 55)
	btn.size = btn.custom_minimum_size
	btn.set_disabled(active or not unlocked)
	var tid := String(t["id"])
	btn.pressed.connect(func() -> void:
		Game.settings["theme"] = tid
		Game.save_game()
		Audio.play("unlock")
		toast("تم «" + String(t["name"]) + "» فعال شد")
		rebuild())
	holder.add_child(btn)

	if active:
		var glow := ArtL.glow_disc(420, Color("#ffe08a"))
		glow.position = Vector2(size.x - 420, -40)
		glow.modulate.a = 0.35
		holder.add_child(glow)
		holder.move_child(glow, 0)
	return holder
