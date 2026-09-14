extends Control
## Journey map: winding path of level nodes, 10 worlds x 10 levels.

const UI := preload("res://scripts/UIKit.gd")
const PathScript := preload("res://scripts/PathLine.gd")
const IconBtn := preload("res://scripts/IconButton.gd")
const PAGE := 10

var page := 0
var nodes_layer: Control
var path_layer: Control
var coin_label: Label
var world_label: Label
var scroll: ScrollContainer
var content: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	page = (Game.current_level - 1) / PAGE
	_build_chrome()
	_build_nodes()
	await get_tree().process_frame
	_scroll_to_current()
	Audio.start_music()


func _build_chrome() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_map.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# scrollable map area
	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(1080, 1920)
	scroll.custom_minimum_size = scroll.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	content = Control.new()
	content.custom_minimum_size = Vector2(1080, 2600)
	content.size = content.custom_minimum_size
	scroll.add_child(content)

	path_layer = Control.new()
	path_layer.set_script(PathScript)
	path_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	path_layer.custom_minimum_size = content.custom_minimum_size
	path_layer.size = content.custom_minimum_size
	path_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(path_layer)

	nodes_layer = Control.new()
	nodes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	nodes_layer.size = content.custom_minimum_size
	content.add_child(nodes_layer)

	# ---- fixed header on top of the scroll area
	var back := IconBtn.new()
	back.icon_path = "res://assets/icons/btn_back.png"
	back.icon_size = 106.0
	back.position = Vector2(32, 52)
	back.pressed.connect(func():
		Transition.change_scene("res://scenes/HomeScene.tscn"))
	add_child(back)

	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", UI.wood_panel(30, 6))
	plaque.position = Vector2(290, 54)
	plaque.custom_minimum_size = Vector2(500, 104)
	world_label = UI.outlined_label("نقشه سفر", 46, Color("#ffe9b8"),
		Color("#3f2609"), 8)
	plaque.add_child(world_label)
	add_child(plaque)

	var coinp := PanelContainer.new()
	coinp.add_theme_stylebox_override("panel", UI.gold_pill(30))
	coinp.position = Vector2(820, 62)
	coinp.custom_minimum_size = Vector2(230, 86)
	var chb := HBoxContainer.new()
	chb.add_theme_constant_override("separation", 8)
	chb.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_label = UI.label(Game.fa_num_grouped(Game.coins), 32, Color("#5b3a1c"))
	chb.add_child(coin_label)
	var ci := TextureRect.new()
	ci.texture = load("res://assets/icons/coin.png")
	ci.custom_minimum_size = Vector2(52, 52)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chb.add_child(ci)
	coinp.add_child(chb)
	add_child(coinp)
	Game.coins_changed.connect(func(v):
		if is_instance_valid(coin_label):
			coin_label.text = Game.fa_num_grouped(v))

	# world paging arrows
	var prev := _small_btn("‹")
	prev.position = Vector2(36, 176)
	prev.pressed.connect(prev_world)
	add_child(prev)
	var nxt := _small_btn("›")
	nxt.position = Vector2(960, 176)
	nxt.pressed.connect(next_world)
	add_child(nxt)

	# character speech bubble bottom-left
	var char_frame := Panel.new()
	char_frame.position = Vector2(40, 1700)
	char_frame.custom_minimum_size = Vector2(170, 170)
	char_frame.size = char_frame.custom_minimum_size
	var cfs := StyleBoxFlat.new()
	cfs.bg_color = Color("#fdf3d8")
	cfs.set_corner_radius_all(85)
	cfs.border_color = Color("#f2c14e")
	cfs.set_border_width_all(6)
	char_frame.add_theme_stylebox_override("panel", cfs)
	var clip := Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/art/char_oldman.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(portrait)
	char_frame.add_child(clip)
	add_child(char_frame)

	var bubble := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#fffaef")
	bs.set_corner_radius_all(28)
	bs.border_color = Color("#e6d2a4")
	bs.set_border_width_all(3)
	bs.content_margin_left = 26
	bs.content_margin_right = 26
	bs.content_margin_top = 14
	bs.content_margin_bottom = 14
	bubble.add_theme_stylebox_override("panel", bs)
	bubble.position = Vector2(240, 1720)
	bubble.custom_minimum_size = Vector2(500, 120)
	var bl := UI.label("بیا ببینیم\nتا کجا می‌تونی بری!", 32, Color("#5b3a1c"))
	bubble.add_child(bl)
	add_child(bubble)

	var reward_btn := Control.new()
	reward_btn.position = Vector2(878, 1694)
	var rb := IconBtn.new()
	rb.icon_path = "res://assets/icons/trophy.png"
	rb.icon_size = 126.0
	rb.pressed.connect(func():
		Transition.change_scene("res://scenes/QuestsScene.tscn"))
	reward_btn.add_child(rb)
	var cap := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.36, 0.22, 0.08, 0.85)
	cs.set_corner_radius_all(14)
	cs.content_margin_left = 12
	cs.content_margin_right = 12
	cs.content_margin_top = 3
	cs.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", cs)
	cap.position = Vector2(8, 112)
	cap.add_child(UI.label("جوایز", 24, Color("#fff0cf")))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_btn.add_child(cap)
	add_child(reward_btn)


func _small_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(84, 84)
	b.add_theme_font_override("font", load(UI.FONT_BLACK))
	b.add_theme_font_size_override("font_size", 48)
	b.add_theme_color_override("font_color", Color("#fff0cf"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.28, 0.11, 0.85)
	sb.set_corner_radius_all(42)
	sb.border_color = Color("#f2c14e")
	sb.set_border_width_all(4)
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	return b


func _build_nodes() -> void:
	for c in nodes_layer.get_children():
		c.queue_free()
	var w: Dictionary = Game.worlds[clampi(page, 0, Game.worlds.size() - 1)]
	world_label.text = String(w.get("name", "نقشه سفر"))

	var first := page * PAGE + 1
	var last := mini(first + PAGE - 1, Game.total_levels())
	var count := last - first + 1
	var area := content.custom_minimum_size
	var margin := 250.0
	var step := (area.y - margin * 2.0) / float(maxi(count - 1, 1))
	var points: PackedVector2Array = []

	for i in count:
		var lvl := first + i
		var t := float(i) / float(maxi(count - 1, 1))
		var x := area.x * 0.5 + sin(t * PI * 2.8) * area.x * 0.25
		var y := area.y - margin - step * float(i)
		points.append(Vector2(x, y))
		var nd := _make_node(lvl, Vector2(x, y))
		nodes_layer.add_child(nd)
		nd.scale = Vector2(0.2, 0.2)
		nd.modulate.a = 0.0
		var ntw := nd.create_tween().set_parallel()
		ntw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ntw.tween_property(nd, "scale", Vector2.ONE, 0.5).set_delay(0.05 * i)
		ntw.tween_property(nd, "modulate:a", 1.0, 0.32).set_delay(0.05 * i)

	path_layer.set_meta("points", points)
	path_layer.queue_redraw()


func _make_node(lvl: int, pos: Vector2) -> Control:
	var unlocked := Game.is_unlocked(lvl)
	var st := Game.stars_for(lvl)
	var is_current := lvl == Game.current_level
	var box := 118.0

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(box, box)
	holder.size = Vector2(box, box)
	holder.position = pos - Vector2(box, box) * 0.5
	holder.pivot_offset = Vector2(box, box) * 0.5

	var btn := Button.new()
	btn.size = Vector2(box, box)
	btn.custom_minimum_size = btn.size
	btn.text = Game.fa_num(lvl) if unlocked else ""
	btn.add_theme_font_override("font", load(UI.FONT_BLACK))
	btn.add_theme_font_size_override("font_size", 46)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("#d8d8d8"))
	btn.add_theme_constant_override("outline_size", 7)
	btn.add_theme_color_override("font_outline_color",
		Color("#2f4a19") if is_current else Color("#33322f"))

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(box * 0.5))
	sb.set_border_width_all(6)
	if is_current:
		sb.bg_color = Color("#59c236")
		sb.border_color = Color("#9ef47c")
	elif unlocked:
		sb.bg_color = Color("#6e6e6e")
		sb.border_color = Color("#cfcfcf")
	else:
		sb.bg_color = Color(0.33, 0.33, 0.33, 0.9)
		sb.border_color = Color("#8a8a8a")
	sb.shadow_color = Color(0, 0, 0, 0.32)
	sb.shadow_size = 9
	sb.shadow_offset = Vector2(0, 5)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, sb)
	holder.add_child(btn)

	if not unlocked:
		var lock := Control.new()
		lock.set_script(load("res://scripts/LockIcon.gd"))
		lock.size = Vector2(box, box)
		lock.custom_minimum_size = lock.size
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lock)

	if st > 0:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", -4)
		hb.position = Vector2(box * 0.5 - 57, box - 16)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 3:
			var s := TextureRect.new()
			s.texture = load("res://assets/icons/star_gold.png" if i < st
				else "res://assets/icons/star_grey.png")
			s.custom_minimum_size = Vector2(40, 40)
			s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hb.add_child(s)
		holder.add_child(hb)

	if lvl % 10 == 0:
		var chest := TextureRect.new()
		chest.texture = load("res://assets/icons/chest.png")
		chest.custom_minimum_size = Vector2(92, 92)
		chest.size = chest.custom_minimum_size
		chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest.position = Vector2(box * 0.5 - 46, -86)
		chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(chest)
		UI.idle_bob(chest, 6.0, 1.8)

	if is_current:
		var halo := Control.new()
		halo.set_script(preload("res://scripts/Halo.gd"))
		halo.size = Vector2(box, box)
		halo.position = Vector2.ZERO
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(halo)
		holder.move_child(halo, 0)
		var glow := CPUParticles2D.new()
		glow.position = Vector2(box * 0.5, box * 0.5)
		glow.emitting = true
		glow.amount = 14
		glow.lifetime = 1.4
		glow.preprocess = 1.0
		glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		glow.emission_sphere_radius = 52.0
		glow.direction = Vector2(0, -1)
		glow.spread = 40.0
		glow.initial_velocity_min = 18.0
		glow.initial_velocity_max = 46.0
		glow.gravity = Vector2(0, -22)
		glow.scale_amount_min = 2.0
		glow.scale_amount_max = 5.0
		glow.color = Color(0.75, 1.0, 0.5, 0.75)
		holder.add_child(glow)

	btn.disabled = not unlocked
	if unlocked:
		btn.pressed.connect(func() -> void:
			Audio.play("tap")
			Game.set_meta("goto_level", lvl)
			Transition.change_scene("res://scenes/LevelScene.tscn"))
	return holder


func _scroll_to_current() -> void:
	var idx := (Game.current_level - 1) % PAGE
	var area := content.custom_minimum_size
	var margin := 250.0
	var step := (area.y - margin * 2.0) / float(PAGE - 1)
	var y := area.y - margin - step * float(idx)
	scroll.scroll_vertical = int(clampf(y - 1100.0, 0.0, area.y - 1920.0))


func next_world() -> void:
	if (page + 1) * PAGE < Game.total_levels():
		page += 1
		Audio.play("tap")
		_build_nodes()


func prev_world() -> void:
	if page > 0:
		page -= 1
		Audio.play("tap")
		_build_nodes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Transition.change_scene("res://scenes/HomeScene.tscn")
