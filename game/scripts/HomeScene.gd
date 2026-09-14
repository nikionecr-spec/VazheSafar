extends Control
## ============================================================================
##  صفحهٔ اصلی — چیدمان گرافیکیِ پر، لایه‌بندیشده و «زنده»
##  HUD بالا · لوگو · ریل آیکون‌های درشت · کارت مرحلهٔ بعدی · CTA درشت · نوار پایین
##  کاراکترها روی مبلمان «نشسته»اند (سایهٔ تماس + مقیاس درست) نه شناور در هوا.
## ============================================================================

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")
const JuicyBtn := preload("res://scripts/JuicyButton.gd")
const IconBtn := preload("res://scripts/IconButton.gd")

var _coin_pill: Control
var _player_card: Control
var _next_card: Control
var _daily_btn: IconBtn
var _cta: JuicyButton
var _oldman: TextureRect
var _cat: TextureRect
var _entrance: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()
	Game.coins_changed.connect(func(_v): _refresh())
	Game.xp_changed.connect(func(_x, _l): _refresh())
	Audio.start_music("home")
	_entrance_play()


# ==================================================================== build
func _build() -> void:
	# ---------------------------------------------------------------- background
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_home.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var rays := Control.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.set_script(preload("res://scripts/SunRays.gd"))
	add_child(rays)

	add_child(UI.ambient_motes(UI.SCREEN, 34))

	# ---------------------------------------------------------------- characters
	# پیرمرد نشسته روی صندلی، پشت میز (پایین قاب، پشتِ دکمهٔ اصلی)
	_oldman = TextureRect.new()
	_oldman.texture = load("res://assets/art/char_seated.png")
	_oldman.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_oldman.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_oldman.position = Vector2(232, 900)
	_oldman.size = Vector2(620, 655)
	_oldman.pivot_offset = Vector2(310, 600)
	_oldman.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_oldman)

	# گربه، نشسته روی میز کنارِ او (با سایهٔ تماس تا «روی هوا» نباشد)
	var cat_shadow := ArtL.ground_shadow(210, 56, 0.32)
	cat_shadow.position = Vector2(760, 1428)
	add_child(cat_shadow)
	_cat = TextureRect.new()
	_cat.texture = load("res://assets/art/cat.png")
	_cat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cat.position = Vector2(760, 1068)
	_cat.size = Vector2(210, 380)
	_cat.pivot_offset = Vector2(105, 344)
	_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cat)
	var cat_hit := Control.new()
	cat_hit.position = _cat.position
	cat_hit.size = _cat.size
	cat_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	cat_hit.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_poke_cat())
	add_child(cat_hit)

	var om_shadow := ArtL.ground_shadow(620, 120, 0.26)
	om_shadow.position = Vector2(232, 1490)
	add_child(om_shadow)
	move_child(om_shadow, _oldman.get_index())

	# ---------------------------------------------------------------- logo + tagline
	var logo_glow := ArtL.glow_disc(880, Color(1.0, 0.92, 0.6))
	logo_glow.position = Vector2(100, 150)
	logo_glow.modulate.a = 0.55
	add_child(logo_glow)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(120, 168)
	logo.size = Vector2(840, 400)
	logo.pivot_offset = logo.size * 0.5
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	_entrance.append(logo)
	_logo_idle(logo)

	var tag := UI.outlined_label("کلمه بساز، حال خوب بچین!", 40,
		Color("#fff8e6"), Color("#5b3a1c"), 9)
	tag.position = Vector2(190, 566)
	tag.size = Vector2(700, 60)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag)
	_entrance.append(tag)

	# ---------------------------------------------------------------- HUD
	_player_card = UI.player_card(Vector2(470, 130))
	_player_card.position = Vector2(24, 40)
	add_child(_player_card)
	_entrance.append(_player_card)
	var profile_hit := _hit_area(Vector2(470, 130), Vector2(24, 40),
		func(): _go("res://scenes/ProfileScene.tscn"))
	add_child(profile_hit)

	_coin_pill = UI.coin_pill(Vector2(320, 104))
	_coin_pill.position = Vector2(536, 52)
	add_child(_coin_pill)
	_entrance.append(_coin_pill)
	add_child(_hit_area(Vector2(320, 104), Vector2(536, 52),
		func(): _go("res://scenes/ShopScene.tscn")))

	var gear := IconBtn.new()
	gear.icon_path = "res://assets/icons/settings.png"
	gear.icon_size = 96.0
	gear.float_phase = 0.4
	gear.position = Vector2(886, 40)
	gear.pressed.connect(func(): _go("res://scenes/SettingsScene.tscn"))
	add_child(gear)
	_entrance.append(gear)

	# ---------------------------------------------------------------- left rail
	var rail := [
		["shop", "فروشگاه", "res://scenes/ShopScene.tscn"],
		["book", "کتابخانه", "res://scenes/LibraryScene.tscn"],
		["themes", "تم‌ها", "res://scenes/ThemesScene.tscn"],
	]
	for i in rail.size():
		var e: Array = rail[i]
		var b := IconBtn.new()
		b.icon_path = "res://assets/icons/%s.png" % e[0]
		b.caption = String(e[1])
		b.icon_size = 132.0
		b.float_phase = 0.35 * float(i)
		b.position = Vector2(12, 690 + i * 262)
		var target := String(e[2])
		b.pressed.connect(func(): _go(target))
		add_child(b)
		_entrance.append(b)

	# ---------------------------------------------------------------- next level card
	_next_card = _build_next_card()
	add_child(_next_card)
	_entrance.append(_next_card)

	# ---------------------------------------------------------------- daily reward
	_daily_btn = IconBtn.new()
	_daily_btn.icon_path = "res://assets/icons/chest.png"
	_daily_btn.caption = "جایزهٔ روزانه"
	_daily_btn.icon_size = 120.0
	_daily_btn.float_phase = 0.8
	_daily_btn.position = Vector2(806, 1234)
	_daily_btn.pressed.connect(_on_daily)
	add_child(_daily_btn)
	_entrance.append(_daily_btn)
	_daily_btn.add_badge("!")

	# ---------------------------------------------------------------- CTA
	var cta_glow := ArtL.glow_disc(1000, Color(1.0, 0.85, 0.45))
	cta_glow.position = Vector2(40, 1370)
	cta_glow.modulate.a = 0.5
	add_child(cta_glow)

	var play := JuicyBtn.new()
	play.text = "شروع بازی"
	play.subtitle = "مرحلهٔ " + Game.fa_num(Game.current_level)
	play.icon_path = "res://assets/icons/btn_play.png"
	play.base_color = Color("#57c22c")
	play.shadow_color = Color("#2f7a1c")
	play.font_size = 62
	play.corner = 46.0
	play.depth = 16.0
	play.idle_pulse = true
	play.shine = true
	play.position = Vector2(118, 1462)
	play.size = Vector2(844, 186)
	play.pressed.connect(func(): _go("res://scenes/MapScene.tscn"))
	add_child(play)
	_entrance.append(play)
	_cta = play

	# ---------------------------------------------------------------- bottom nav
	add_child(UI.vignette(0.30))
	var nav := UI.bottom_nav(_nav_items(), 0, _on_nav)
	nav.position = Vector2(0, UI.SCREEN.y - 214)
	add_child(nav)


func _on_nav(i: int) -> void:
	match i:
		1:
			_go("res://scenes/ProfileScene.tscn")
		2:
			_go("res://scenes/LibraryScene.tscn")
		3:
			_go("res://scenes/QuestsScene.tscn")
		4:
			_go("res://scenes/SettingsScene.tscn")


func _nav_items() -> Array:
	return [
		{"icon": "res://assets/icons/home.png", "label": "خانه"},
		{"icon": "res://assets/icons/trophy.png", "label": "پروفایل"},
		{"icon": "res://assets/icons/book.png", "label": "کتابخانه"},
		{"icon": "res://assets/icons/quests.png", "label": "ماموریت‌ها"},
		{"icon": "res://assets/icons/settings.png", "label": "تنظیمات"},
	]


func _hit_area(size: Vector2, pos: Vector2, cb: Callable) -> Control:
	var hit := Control.new()
	hit.position = pos
	hit.size = size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			Audio.play("tap")
			cb.call())
	return hit


## کارت «مرحلهٔ بعدی» — هدفِ نزدیک و همیشه قابل‌دسترس (قلابِ برگشت)
func _build_next_card() -> Control:
	var size := Vector2(300, 400)
	var holder := Control.new()
	holder.position = Vector2(756, 690)
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := ArtL.wooden_panel(size, 34, 11)
	holder.add_child(panel)

	var title: Control = ArtL.ribbon("مرحلهٔ بعدی", 28, Color("#5d3714"))
	holder.add_child(title)
	title.ready.connect(func():
		title.position = Vector2((size.x - title.size.x) * 0.5, -16))

	var num := UI.outlined_label(Game.fa_num(Game.current_level), 92,
		Color("#fff3d0"), Color("#3f2609"), 9)
	num.position = Vector2(0, 42)
	num.size = Vector2(size.x, 120)
	num.name = "LevelNum"
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(num)

	var world := UI.label(Game.world_of(Game.current_level).get("name", ""), 28,
		Color("#ffe9c0"))
	world.position = Vector2(0, 158)
	world.size = Vector2(size.x, 44)
	world.name = "WorldName"
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(world)

	var stars := UI.star_row(0, 46)
	stars.position = Vector2(size.x * 0.5 - 82, 212)
	stars.name = "Stars"
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stars)

	var wp := ArtL.progress_bar(Vector2(size.x - 72, 30), 0.0, Color("#ffe08a"), Color("#e8a92c"))
	wp.position = Vector2(36, 282)
	wp.name = "WorldBar"
	holder.add_child(wp)

	var hint := UI.label("", 24, Color("#ffeccb"))
	hint.position = Vector2(0, 322)
	hint.size = Vector2(size.x, 40)
	hint.name = "WorldHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(hint)

	var hit := Control.new()
	hit.size = size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			Audio.play("tap")
			Game.set_meta("goto_level", Game.current_level)
			_go("res://scenes/LevelScene.tscn"))
	holder.add_child(hit)
	return holder


# ================================================================== refresh
func _refresh() -> void:
	if _player_card == null:
		return
	var name_l: Label = _player_card.get_meta("name_label")
	name_l.text = Game.player_name
	var xp: Control = _player_card.get_meta("xp_bar")
	ArtL.set_progress(xp, Game.xp_ratio())
	var lvl: Control = _player_card.get_meta("level_badge")
	var ll: Label = lvl.get_meta("label")
	ll.text = Game.fa_num(Game.player_level)
	var coin_l: Label = _coin_pill.get_meta("value_label")
	coin_l.text = Game.fa_num_grouped(Game.coins)

	if _daily_btn:
		_daily_btn.set_badge_visible(Game.can_claim_daily())
	if _cta:
		_cta.set_subtitle("مرحلهٔ " + Game.fa_num(Game.current_level))

	if _next_card:
		var nxt: int = mini(Game.current_level, Game.total_levels())
		_next_card.get_node("LevelNum").text = Game.fa_num(nxt)
		_next_card.get_node("WorldName").text = String(Game.world_of(nxt).get("name", ""))
		var stars_row: HBoxContainer = _next_card.get_node("Stars")
		var st := Game.stars_for(nxt)
		for i in stars_row.get_child_count():
			var s: TextureRect = stars_row.get_child(i)
			s.texture = load("res://assets/icons/star_gold.png" if i < st
				else "res://assets/icons/star_grey.png")
		# پیشرفت دنیا: چقدر از ۱۰ مرحلهٔ این دنیا تمام شده (هدفِ نزدیک)
		var world_index: int = (nxt - 1) / 10
		var done := 0
		for k in range(1, 11):
			var lid := world_index * 10 + k
			if lid <= Game.total_levels() and Game.stars_for(lid) > 0:
				done += 1
		ArtL.set_progress(_next_card.get_node("WorldBar"), float(done) / 10.0)
		_next_card.get_node("WorldHint").text = "%s از ۱۰ مرحله" % Game.fa_num(done)


func _on_daily() -> void:
	_go("res://scenes/QuestsScene.tscn")


func _poke_cat() -> void:
	Audio.play("letter_7", 1.25)
	Audio.vibrate(18)
	var base := _cat.position
	var tw := _cat.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cat, "position:y", base.y - 46, 0.18)
	tw.tween_property(_cat, "position:y", base.y, 0.34)
	tw.parallel().tween_property(_cat, "rotation", 0.10, 0.18)


func _go(path: String, _btn: Control = null) -> void:
	Audio.play("tap")
	Transition.change_scene(path)


# ==================================================================== motion
func _logo_idle(logo: TextureRect) -> void:
	var base := logo.position.y
	var tw := logo.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(logo, "position:y", base - 14.0, 2.1)
	tw.tween_property(logo, "position:y", base, 2.1)


func _entrance_play() -> void:
	var i := 0
	for node in _entrance:
		if node is Control:
			UI.pop_in(node, 0.05 * float(i))
		i += 1
	_breathe(_oldman, 0.012, 3.6)
	_breathe(_cat, 0.020, 2.6)


func _breathe(node: Control, amount: float, time: float) -> void:
	if node == null:
		return
	var base := node.scale
	var tw := node.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", base * (1.0 + amount), time * 0.5)
	tw.tween_property(node, "scale", base, time * 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
