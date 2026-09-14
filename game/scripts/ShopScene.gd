extends SubScene
## Shop — large, readable cards. The free coin bag is a real, working loop
## (3-hour cooldown, random payout); paid packs are clearly marked as
## "coming soon" so nothing here pretends to take money.

const JuicyBtn := preload("res://scripts/JuicyButton.gd")

var _bag_btn: JuicyBtn
var _bag_timer: Label
var _tick := 0.0


func _init() -> void:
	screen_title = "فروشگاه"
	section = "shop"
	nav_key = "shop"


func build_body() -> void:
	_free_bag_card()
	_gem_row()
	for pack in PACKS:
		body.add_child(_pack_card(pack))
	_note_card()
	set_process(true)


const PACKS := [
	{"coins": 1200, "price": "۹٬۰۰۰ تومان", "icon": "coin"},
	{"coins": 3500, "price": "۲۵٬۰۰۰ تومان", "icon": "chest"},
	{"coins": 9000, "price": "۵۹٬۰۰۰ تومان", "icon": "chest"},
]


# ------------------------------------------------------------- free coin bag
func _free_bag_card() -> void:
	var c := card(372)
	c.set_meta("bag", true)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := _icon("gift", 150)
	head.add_child(ic)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t1 := UI.label("کیسهٔ سکهٔ رایگان", 44, UI.INK, UI.FONT_BLACK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t1)
	var t2 := UI.label("هر ۳ ساعت یک بار، بین ۱۰۰ تا ۴۰۰ سکه", 28, UI.INK_SOFT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t2)
	_bag_timer = UI.label("", 30, Color("#c98a12"))
	_bag_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(_bag_timer)
	head.add_child(tv)
	vb.add_child(head)

	_bag_btn = JuicyBtn.new()
	_bag_btn.text = "برداشتن سکه‌ها"
	_bag_btn.icon_path = "res://assets/icons/coin.png"
	_bag_btn.base_color = Color("#5cbf2a")
	_bag_btn.shadow_color = Color("#2f6a15")
	_bag_btn.font_size = 42
	_bag_btn.corner = 34.0
	_bag_btn.shine = true
	_bag_btn.custom_minimum_size = Vector2(0, 130)
	_bag_btn.pressed.connect(_claim_bag)
	vb.add_child(_bag_btn)
	c.add_child(vb)
	body.add_child(c)
	_refresh_bag()


func _claim_bag() -> void:
	var amount := Game.claim_free_bag()
	if amount <= 0:
		_toast("هنوز آماده نشده — کمی صبر کن")
		return
	Audio.play("chest")
	_toast("+" + Game.fa_num(amount) + " سکه!")
	_refresh_bag()


func _refresh_bag() -> void:
	if _bag_btn == null:
		return
	if Game.free_bag_ready():
		_bag_btn.set_disabled(false)
		_bag_btn.text = "برداشتن سکه‌ها"
		_bag_timer.text = "آماده است!"
	else:
		_bag_btn.set_disabled(true)
		_bag_btn.text = "بعداً برگرد"
		_bag_timer.text = "بعدی در " + Game.countdown_text(Game.free_bag_wait())


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	_refresh_bag()


# ------------------------------------------------------------------- gems
func _gem_row() -> void:
	var c := card(268)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_icon("gem", 130))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t1 := UI.label("جواهر", 42, UI.INK, UI.FONT_BLACK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t1)
	var t2 := UI.label("با جواهر می‌توانی یک کلمه را کامل آشکار کنی", 27, UI.INK_SOFT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t2)
	var t3 := UI.label("موجودی: " + Game.fa_num(Game.gems), 30, Color("#3f6ea8"))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t3)
	hb.add_child(tv)
	var ex := UI.alt_button("تبدیل سکه به جواهر", Color("#8bb8e8"), Color("#3f6ea8"), 30)
	ex.custom_minimum_size = Vector2(320, 108)
	ex.size = Vector2(320, 108)
	ex.pressed.connect(func() -> void:
		if Game.spend_coins(300):
			Game.gems += 3
			Game.gems_changed.emit(Game.gems)
			Game.save_game()
			Audio.play("coin")
			_toast("۳ جواهر گرفتی!")
		else:
			Audio.play("word_bad")
			_toast("سکه کافی نداری"))
	hb.add_child(ex)
	c.add_child(hb)
	body.add_child(c)


# ------------------------------------------------------------- paid packs
func _pack_card(pack: Dictionary) -> Control:
	var c := card(252)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER

	hb.add_child(_icon(String(pack["icon"]), 160))

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 8)
	var t1 := UI.label(Game.fa_num_grouped(int(pack["coins"])) + " سکه", 46,
		UI.INK, UI.FONT_BLACK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t1)
	var t2 := UI.label(String(pack["price"]), 30, UI.INK_SOFT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t2)
	var t3 := UI.label("به‌زودی در کافه‌بازار و مایکت", 24, Color("#a08a6a"))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(t3)
	hb.add_child(tv)

	var buy := UI.alt_button("خرید", Color("#f0a93a"), Color("#b3761a"), 34)
	buy.custom_minimum_size = Vector2(250, 118)
	buy.pressed.connect(func() -> void:
		Audio.play("word_bad")
		_toast("پرداخت درون‌برنامه‌ای در این نسخه فعال نیست"))
	hb.add_child(buy)
	c.add_child(hb)
	return c


func _note_card() -> void:
	var c := card(160)
	c.add_child(UI.label("همهٔ بخش‌های بازی بدون پرداخت هم قابل بازی است؛\n"
		+ "خرید فقط سرعت پیشرفت را بیشتر می‌کند.", 30, UI.INK_SOFT))
	body.add_child(c)


func _icon(name: String, box: float) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = load("res://assets/icons/%s.png" % name)
	ic.custom_minimum_size = Vector2(box, box)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return ic
