extends SubScene
## Visual themes unlocked by stars.

const THEMES := [
	{"id": "spring", "name": "باغ بهاری",   "stars": 0,  "c1": "#8fd66a", "c2": "#f3c969"},
	{"id": "sea",    "name": "دهکده ساحلی", "stars": 9,  "c1": "#63b8d6", "c2": "#a9e4f2"},
	{"id": "sunset", "name": "غروب نارنجی", "stars": 24, "c1": "#f28d52", "c2": "#f7c873"},
	{"id": "night",  "name": "شب یلدا",     "stars": 45, "c1": "#6a5ca8", "c2": "#b39ddb"},
	{"id": "gold",   "name": "قله طلایی",   "stars": 75, "c1": "#e0a93c", "c2": "#f6e0a0"},
]


func _init() -> void:
	screen_title = "تم‌ها"


func build_body() -> void:
	var have := Game.total_stars()
	var head := card(110)
	head.add_child(UI.label("ستاره‌های تو: " + Game.fa_num(have), 34, UI.TEXT_DARK))
	body.add_child(head)

	for t in THEMES:
		var need: int = int(t["stars"])
		var unlocked: bool = have >= need
		var active: bool = String(Game.settings.get("theme", "spring")) == String(t["id"])
		var c := card(170)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER

		var btn := UI.green_button("فعال" if active else ("انتخاب" if unlocked
			else Game.fa_num(need) + " ★"), 30)
		btn.custom_minimum_size = Vector2(220, 92)
		btn.disabled = not unlocked or active
		var tid := String(t["id"])
		btn.pressed.connect(func() -> void:
			Game.settings["theme"] = tid
			Game.save_game()
			Audio.play("unlock")
			_rebuild())
		hb.add_child(btn)

		var name_l := UI.label(String(t["name"]), 36, UI.TEXT_DARK)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(name_l)

		var sw := ColorRect.new()
		sw.color = Color(String(t["c1"]))
		sw.custom_minimum_size = Vector2(70, 70)
		var sw2 := ColorRect.new()
		sw2.color = Color(String(t["c2"]))
		sw2.custom_minimum_size = Vector2(70, 70)
		hb.add_child(sw)
		hb.add_child(sw2)
		if not unlocked:
			c.modulate = Color(1, 1, 1, 0.62)
		c.add_child(hb)
		body.add_child(c)


func _rebuild() -> void:
	for ch in body.get_children():
		ch.queue_free()
	await get_tree().process_frame
	build_body()
