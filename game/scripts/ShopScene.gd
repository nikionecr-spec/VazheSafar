extends SubScene
## ============================================================================
##  فروشگاه — چیدمان درشت و گرافیکی
##  ● کارت ویژه (پیشنهاد اول) با جایزهٔ روزانه
##  ● بسته‌های سکه در شبکهٔ ۲ ستونه با دکمه‌های بزرگ و برچسبِ برنده
##  ● بسته‌های جم (برای آیندهٔ بازی) و یادآوری اتصال فروشگاه در نسخهٔ بعد
## ============================================================================

const JuicyBtn := preload("res://scripts/JuicyButton.gd")

const COIN_PACKS := [
	{"coins": 500, "price": "رایگان", "free": true, "tag": "هدیهٔ امروز"},
	{"coins": 1200, "price": "۹٬۰۰۰ تومان", "tag": ""},
	{"coins": 3500, "price": "۲۵٬۰۰۰ تومان", "tag": "محبوب‌ترین"},
	{"coins": 9000, "price": "۵۹٬۰۰۰ تومان", "tag": "به‌صرفه‌ترین"},
]

const GEM_PACKS := [
	{"gems": 20, "price": "۱۵٬۰۰۰ تومان"},
	{"gems": 60, "price": "۳۹٬۰۰۰ تومان"},
]


func _init() -> void:
	screen_title = "فروشگاه"
	nav_index = -1


func build_body() -> void:
	_hero_offer()
	section("بسته‌های سکه")
	_pack_grid()
	section("جم‌ها")
	_gem_row()
	_info_card()
	spacer(40)


# ------------------------------------------------------------------ hero
func _hero_offer() -> void:
	var c := card(430, 36, Color("#fdf3dc"), true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.card_add(c, col, 34.0)

	var title := UI.outlined_label("هدیهٔ امروز", 44, Color("#fff6dc"), Color("#4a2c10"), 8)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.custom_minimum_size = Vector2(0, 150)
	col.add_child(row)

	var coin := TextureRect.new()
	coin.texture = load("res://assets/icons/coin.png")
	coin.custom_minimum_size = Vector2(132, 132)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(coin)

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 4)
	center.custom_minimum_size = Vector2(420, 130)
	row.add_child(center)
	var amt_l := UI.label("۵۰۰ سکه", 56, UI.TEXT_DARK)
	amt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center.add_child(amt_l)
	var sub_l := UI.label("هر روز یک هدیه، بدون هزینه", 26, UI.INK_SOFT)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center.add_child(sub_l)

	var claim := JuicyBtn.new()
	claim.text = "دریافت هدیه"
	claim.base_color = Color("#57c22c")
	claim.shadow_color = Color("#2f7a1c")
	claim.font_size = 42
	claim.corner = 34.0
	claim.depth = 13.0
	claim.shine = true
	claim.custom_minimum_size = Vector2(620, 124)
	claim.size = claim.custom_minimum_size
	var taken := not Game.can_claim_daily()
	claim.set_disabled(taken)
	if taken:
		claim.set_text("فردا بیا")
	claim.pressed.connect(func() -> void:
		var got := Game.claim_daily()
		if got > 0:
			Audio.play("coin")
			toast("+" + Game.fa_num(got) + " سکه اضافه شد")
			claim.set_disabled(true)
			claim.set_text("فردا بیا"))
	col.add_child(claim)


# ------------------------------------------------------------------- packs
func _pack_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	body.add_child(grid)
	for pack in COIN_PACKS:
		grid.add_child(_pack_card(pack))


func _pack_card(pack: Dictionary) -> Control:
	var size := Vector2(480, 500)
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(ArtL.card_panel(size, 34,
		Color("#fdf3dc") if not bool(pack.get("free", false)) else Color("#f3fbe8")))

	var tag := String(pack.get("tag", ""))
	if tag != "":
		var rib: Control = ArtL.ribbon(tag, 25, Color("#c89328"))
		holder.add_child(rib)
		rib.position = Vector2((size.x - rib.size.x) * 0.5, 14)

	var icon_path := "res://assets/icons/coin.png"
	var amount: int = int(pack.get("coins", 0))
	if amount >= 3500:
		icon_path = "res://assets/icons/chest.png"
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(size.x * 0.5 - 76, 74)
	icon.size = Vector2(152, 152)
	holder.add_child(icon)
	UI.idle_bob(icon, 7.0, 2.2)

	var amount_l := UI.label(Game.fa_num_grouped(amount), 60, UI.TEXT_DARK)
	amount_l.position = Vector2(0, 230)
	amount_l.size = Vector2(size.x, 72)
	holder.add_child(amount_l)
	var coins_l := UI.label("سکه", 30, UI.INK_SOFT)
	coins_l.position = Vector2(0, 298)
	coins_l.size = Vector2(size.x, 38)
	holder.add_child(coins_l)

	var btn := JuicyBtn.new()
	btn.text = "برداشت" if bool(pack.get("free", false)) else "خرید"
	btn.base_color = Color("#57c22c") if bool(pack.get("free", false)) else Color("#4a9ae0")
	btn.shadow_color = Color("#2f7a1c") if bool(pack.get("free", false)) else Color("#255f96")
	btn.font_size = 38
	btn.corner = 30.0
	btn.depth = 11.0
	btn.shine = true
	btn.custom_minimum_size = Vector2(size.x - 60, 112)
	btn.position = Vector2(30, size.y - 126)
	btn.size = btn.custom_minimum_size
	var is_free: bool = bool(pack.get("free", false))
	btn.pressed.connect(func() -> void:
		if is_free:
			Game.add_coins(amount)
			Audio.play("coin")
			toast("+" + Game.fa_num_grouped(amount) + " سکه اضافه شد")
		else:
			Audio.play("word_bad")
			toast("خرید درون‌برنامه‌ای در نسخهٔ بعدی فعال می‌شود"))
	holder.add_child(btn)

	var price := UI.label(String(pack.get("price", "")), 28,
		UI.GREEN if is_free else UI.INK_SOFT)
	price.position = Vector2(0, 342)
	price.size = Vector2(size.x, 40)
	holder.add_child(price)
	return holder


# -------------------------------------------------------------------- gems
func _gem_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	for g in GEM_PACKS:
		var size := Vector2(480, 250)
		var holder := Control.new()
		holder.custom_minimum_size = size
		holder.size = size
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.add_child(ArtL.card_panel(size, 30, Color("#eef4ff")))
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/gem.png")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(size.x - 140, 50)
		icon.size = Vector2(120, 120)
		holder.add_child(icon)
		var amount := UI.label(Game.fa_num(int(g["gems"])) + " جم", 44, UI.TEXT_DARK)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.position = Vector2(40, 46)
		amount.size = Vector2(size.x - 190, 60)
		holder.add_child(amount)
		var price := UI.label(String(g["price"]), 28, UI.INK_SOFT)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.position = Vector2(40, 112)
		price.size = Vector2(size.x - 190, 40)
		holder.add_child(price)
		var btn := JuicyBtn.new()
		btn.text = "خرید"
		btn.base_color = Color("#9a7bd6")
		btn.shadow_color = Color("#5f4699")
		btn.font_size = 32
		btn.corner = 26.0
		btn.depth = 9.0
		btn.custom_minimum_size = Vector2(size.x - 80, 86)
		btn.position = Vector2(40, size.y - 112)
		btn.size = btn.custom_minimum_size
		btn.pressed.connect(func() -> void:
			Audio.play("word_bad")
			toast("خرید درون‌برنامه‌ای در نسخهٔ بعدی فعال می‌شود"))
		holder.add_child(btn)
		row.add_child(holder)


func _info_card() -> void:
	var c := card(210, 30, Color("#fdf6e6"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.card_add(c, col, 30.0)
	col.add_child(UI.label("سکه‌ها را کجا خرج کنم؟", 34, UI.TEXT_DARK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.add_child(UI.label("راهنما ۸۰ سکه  •  کلمهٔ جایزه‌ای ۵ سکه  •  باز کردن تم‌ها با ستاره",
		26, UI.INK_SOFT))
	col.add_child(row)
