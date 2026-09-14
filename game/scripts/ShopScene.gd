extends SubScene

const PACKS := [
	{"coins": 500,  "price": "رایگان با تماشای ویدیو", "icon": "coin", "free": true},
	{"coins": 1200, "price": "۹٬۰۰۰ تومان", "icon": "coin", "free": false},
	{"coins": 3500, "price": "۲۵٬۰۰۰ تومان", "icon": "chest", "free": false},
	{"coins": 9000, "price": "۵۹٬۰۰۰ تومان", "icon": "chest", "free": false},
]


func _init() -> void:
	screen_title = "فروشگاه"


func build_body() -> void:
	for pack in PACKS:
		var c := card(170)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 24)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER

		var buy := UI.green_button("خرید", 34)
		buy.custom_minimum_size = Vector2(220, 96)
		var amount: int = int(pack["coins"])
		var is_free: bool = bool(pack["free"])
		buy.pressed.connect(func() -> void:
			if is_free:
				Game.add_coins(amount)
				Audio.play("coin")
				_toast("+" + Game.fa_num(amount) + " سکه اضافه شد")
			else:
				Audio.play("word_bad")
				_toast("خرید درون‌برنامه‌ای در این نسخه فعال نیست"))
		hb.add_child(buy)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		var t1 := UI.label(Game.fa_num_grouped(amount) + " سکه", 42, UI.TEXT_DARK)
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var t2 := UI.label(String(pack["price"]), 28, Color("#8a6a3c"))
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		texts.add_child(t1)
		texts.add_child(t2)
		hb.add_child(texts)

		var ic := TextureRect.new()
		ic.texture = load("res://assets/icons/%s.png" % pack["icon"])
		ic.custom_minimum_size = Vector2(120, 120)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(ic)

		c.add_child(hb)
		body.add_child(c)


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(size.x * 0.5 - 230, size.y * 0.5)
