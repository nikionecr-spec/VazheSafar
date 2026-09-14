extends Control
class_name SubScene
## Shared chrome for the full-screen menus (shop, quests, library, themes,
## settings): full-bleed art, oversized header, scrolling body and the same
## bottom navigation as the home screen — so no screen ever has an empty band.

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")

@export var screen_title := "صفحه"
## which music track this screen plays (see Audio.SPECS)
var section := "library"
## which bottom-nav entry is highlighted
var nav_key := "home"
## optional different backdrop
var bg_path := "res://assets/art/bg_home.png"

var body: VBoxContainer
var scroll: ScrollContainer
var coin_label: Label
var gem_label: Label

const NAV_H := 208.0


func _ready() -> void:
	_build_chrome()
	build_body()
	animate_cards()
	Audio.set_section(section)


func build_body() -> void:
	pass


# ------------------------------------------------------------------- chrome
func _build_chrome() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load(bg_path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var veil := ColorRect.new()
	veil.color = Color(0.10, 0.06, 0.02, 0.62)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	# ---- header
	var back := IconBtn.new()
	back.icon_path = "res://assets/icons/btn_back.png"
	back.icon_size = 128.0
	back.position = Vector2(26, 42)
	back.pressed.connect(func(): _go_home(back))
	add_child(back)
	_add_hit(Vector2(122, 122), Vector2(26, 42),
		func(): Transition.change_scene("res://scenes/HomeScene.tscn"))

	var title := UI.glass_card(30, Color(0.30, 0.18, 0.07, 0.86), 26)
	title.position = Vector2(286, 40)
	title.custom_minimum_size = Vector2(508, 124)
	title.add_child(UI.outlined_label(screen_title, 52, Color("#ffe9b8"),
		Color("#3f2609"), 8))
	add_child(title)

	var coinp := UI.currency_pill("res://assets/icons/coin.png",
		Game.fa_num_grouped(Game.coins), Vector2(286, 104))
	coinp.position = Vector2(38, 190)
	coin_label = _find_label(coinp)
	add_child(coinp)

	var gemp := UI.currency_pill("res://assets/icons/gem.png",
		Game.fa_num(Game.gems), Vector2(266, 104), Color("#e8f2ff"))
	gemp.position = Vector2(344, 190)
	gem_label = _find_label(gemp)
	add_child(gemp)

	Game.coins_changed.connect(func(v):
		if is_instance_valid(coin_label):
			coin_label.text = Game.fa_num_grouped(v))
	Game.gems_changed.connect(func(v):
		if is_instance_valid(gem_label):
			gem_label.text = Game.fa_num(v))

	# ---- scrollable body
	var sc := ScrollContainer.new()
	sc.position = Vector2(0, 320)
	sc.size = Vector2(1080, 1920 - 320 - NAV_H)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	add_child(sc)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(1080, 0)
	sc.add_child(pad)

	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(1000, 0)
	body.position = Vector2(40, 0)
	body.add_theme_constant_override("separation", 26)
	pad.add_child(body)

	# ---- bottom navigation
	var nav := UI.bottom_nav(["home", "library", "quests", "shop", "themes"], nav_key,
		_on_nav, NAV_H)
	nav.position = Vector2(0, 1920 - NAV_H)
	add_child(nav)


func _find_label(node: Node) -> Label:
	for c in node.get_children():
		if c is Label:
			return c
		var r := _find_label(c)
		if r != null:
			return r
	return null


func _go_home(_src: Control) -> void:
	Audio.play("tap")
	Transition.change_scene("res://scenes/HomeScene.tscn")


func _on_nav(key: String) -> void:
	match key:
		"home": Transition.change_scene("res://scenes/HomeScene.tscn")
		"library": Transition.change_scene("res://scenes/LibraryScene.tscn")
		"quests": Transition.change_scene("res://scenes/QuestsScene.tscn")
		"shop": Transition.change_scene("res://scenes/ShopScene.tscn")
		"themes": Transition.change_scene("res://scenes/ThemesScene.tscn")


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
		# only touch properties the container does not own (position/size are
		# managed by VBoxContainer; animating them left cards offset)
		c.modulate.a = 0.0
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(0.95, 0.95)
		var tw := c.create_tween().set_parallel()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.30).set_delay(0.05 * float(i))
		tw.tween_property(c, "scale", Vector2.ONE, 0.42).set_delay(0.05 * float(i))


## big rounded cream card, used by every sub-scene
func card(height: float = 150.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fdf6e6")
	sb.set_corner_radius_all(32)
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.2, 0.12, 0.04, 0.35)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(1000, height)
	return p


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(300, 1400)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Transition.change_scene("res://scenes/HomeScene.tscn")
