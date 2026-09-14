extends Control
class_name SubScene
## ============================================================================
##  پایهٔ صفحه‌های منو (فروشگاه، ماموریت‌ها، کتابخانه، تم‌ها، تنظیمات)
##  ● نوار بالا: بازگشت · پلاک تیتر · سکه
##  ● بدنهٔ اسکرولیِ تمام‌عرض با کارت‌های گرافیکی
##  ● نوار پایین با ۵ تب درشت (همیشه در دسترس)
## ============================================================================

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")

@export var screen_title := "صفحه"
@export var nav_index := -1

var body: VBoxContainer
var scroll: ScrollContainer
var coin_label: Label
var _coin_pill: Control


func _ready() -> void:
	_build_chrome()
	build_body()
	_stagger_cards()


func build_body() -> void:
	pass


# ------------------------------------------------------------------- chrome
func _build_chrome() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_home.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var veil := ColorRect.new()
	veil.color = Color(0.10, 0.06, 0.02, 0.44)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	add_child(UI.ambient_motes(UI.SCREEN, 20))

	# ---- top bar
	var back := UI.back_button(122)
	back.position = Vector2(26, 42)
	add_child(back)
	_add_hit(Vector2(122, 122), Vector2(26, 42),
		func(): Transition.change_scene("res://scenes/HomeScene.tscn"))

	var plaque := UI.title_plaque(screen_title, Vector2(500, 118), 46)
	plaque.position = Vector2(290, 44)
	add_child(plaque)

	_coin_pill = UI.coin_pill(Vector2(262, 96), false)
	_coin_pill.position = Vector2(792, 54)
	add_child(_coin_pill)
	coin_label = _coin_pill.get_meta("value_label")
	coin_label.text = Game.fa_num_grouped(Game.coins)
	Game.coins_changed.connect(func(v):
		if is_instance_valid(coin_label):
			coin_label.text = Game.fa_num_grouped(v))
	_add_hit(Vector2(262, 96), Vector2(792, 54),
		func(): Transition.change_scene("res://scenes/ShopScene.tscn"))

	# ---- scrollable body
	scroll = ScrollContainer.new()
	scroll.position = Vector2(48, 196)
	scroll.size = Vector2(984, UI.SCREEN.y - 196 - 236)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)

	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(984, 0)
	body.add_theme_constant_override("separation", 24)
	scroll.add_child(body)

	# ---- bottom nav
	add_child(UI.vignette(0.36))
	var nav := UI.bottom_nav(_nav_items(), nav_index, _on_nav)
	nav.position = Vector2(0, UI.SCREEN.y - 214)
	add_child(nav)


func _nav_items() -> Array:
	return [
		{"icon": "res://assets/icons/home.png", "label": "خانه"},
		{"icon": "res://assets/icons/trophy.png", "label": "پروفایل"},
		{"icon": "res://assets/icons/book.png", "label": "کتابخانه"},
		{"icon": "res://assets/icons/quests.png", "label": "ماموریت‌ها"},
		{"icon": "res://assets/icons/settings.png", "label": "تنظیمات"},
	]


func _on_nav(i: int) -> void:
	var scenes := [
		"res://scenes/HomeScene.tscn", "res://scenes/ProfileScene.tscn",
		"res://scenes/LibraryScene.tscn", "res://scenes/QuestsScene.tscn",
		"res://scenes/SettingsScene.tscn",
	]
	if i >= 0 and i < scenes.size():
		Transition.change_scene(scenes[i])


func _add_hit(size: Vector2, pos: Vector2, cb: Callable) -> Control:
	var hit := Control.new()
	hit.position = pos
	hit.size = size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			Audio.play("tap")
			cb.call())
	add_child(hit)
	return hit


# ------------------------------------------------------------------- helpers
func card(height: float = 170.0, radius: int = 30, base: Color = UI.CREAM,
		wooden: bool = false) -> Control:
	var c := UI.card(Vector2(984, height), radius, base, wooden)
	body.add_child(c)
	return c


func section(text: String) -> Control:
	var h := UI.section_header(text, 984)
	body.add_child(h)
	return h


func spacer(h: float = 8.0) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	body.add_child(s)


func toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(UI.SCREEN.x * 0.5 - t.size.x * 0.5, UI.SCREEN.y * 0.52)


func rebuild() -> void:
	for ch in body.get_children():
		ch.queue_free()
	await get_tree().process_frame
	build_body()
	_stagger_cards()


## ورود پله‌ای کارت‌ها (حس زنده بودن صفحه)
func _stagger_cards() -> void:
	await get_tree().process_frame
	var i := 0
	for c in body.get_children():
		var ctrl := c as Control
		if ctrl == null:
			continue
		var target := ctrl.position
		ctrl.position = target + Vector2(0, 46)
		ctrl.modulate.a = 0.0
		var tw := ctrl.create_tween().set_parallel()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ctrl, "position", target, 0.42).set_delay(0.045 * float(i))
		tw.tween_property(ctrl, "modulate:a", 1.0, 0.30).set_delay(0.045 * float(i))
		i += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Transition.change_scene("res://scenes/HomeScene.tscn")
