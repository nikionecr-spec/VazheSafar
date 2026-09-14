extends Control
class_name SubScene
## Shared base for the simple full-screen menus (shop, quests, library, ...).

const UI := preload("res://scripts/UIKit.gd")
const IconBtn := preload("res://scripts/IconButton.gd")

@export var screen_title := "صفحه"

var body: VBoxContainer
var coin_label: Label


func _ready() -> void:
	_build_chrome()
	build_body()
	animate_cards()


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
	veil.color = Color(0.1, 0.06, 0.02, 0.45)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	# ---- top bar
	var back := IconBtn.new()
	back.icon_path = "res://assets/icons/btn_back.png"
	back.icon_size = 104.0
	back.position = Vector2(34, 56)
	back.pressed.connect(func():
		Transition.change_scene("res://scenes/HomeScene.tscn"))
	add_child(back)

	var titlep := PanelContainer.new()
	titlep.add_theme_stylebox_override("panel", UI.wood_panel(28, 5))
	titlep.position = Vector2(300, 62)
	titlep.custom_minimum_size = Vector2(480, 92)
	var tl := UI.outlined_label(screen_title, 44, Color("#ffe9b8"), Color("#3f2609"), 7)
	titlep.add_child(tl)
	add_child(titlep)

	var coinp := PanelContainer.new()
	coinp.add_theme_stylebox_override("panel", UI.gold_pill(30))
	coinp.position = Vector2(820, 66)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	coin_label = UI.label(Game.fa_num_grouped(Game.coins), 34, Color("#5b3a1c"))
	hb.add_child(coin_label)
	var ci := TextureRect.new()
	ci.texture = load("res://assets/icons/coin.png")
	ci.custom_minimum_size = Vector2(52, 52)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ci)
	coinp.add_child(hb)
	add_child(coinp)
	Game.coins_changed.connect(func(v):
		if is_instance_valid(coin_label):
			coin_label.text = Game.fa_num_grouped(v))

	# ---- scrollable body
	var sc := ScrollContainer.new()
	sc.position = Vector2(60, 200)
	sc.size = Vector2(960, 1600)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)

	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(960, 0)
	body.add_theme_constant_override("separation", 22)
	sc.add_child(body)


func build_body() -> void:
	pass  # overridden


## staggered entrance for whatever build_body() produced
func animate_cards() -> void:
	await get_tree().process_frame
	for i in body.get_child_count():
		var c := body.get_child(i) as Control
		if c == null:
			continue
		var target := c.position
		c.position = target + Vector2(70, 0)
		c.modulate.a = 0.0
		var tw := c.create_tween().set_parallel()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position", target, 0.45).set_delay(0.06 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(0.06 * i)


func card(height: float = 150.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.cream_panel(24))
	p.custom_minimum_size = Vector2(940, height)
	return p


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Transition.change_scene("res://scenes/HomeScene.tscn")
