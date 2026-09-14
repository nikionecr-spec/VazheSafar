extends Control
## ============================================================================
##  نقشهٔ سفر — مسیر سنگیِ پیچ‌درپیچ با گره‌های درشت
##  ● تیتر دنیا روی پلاک چوبی + فلش‌های بزرگ صفحه‌بندی
##  ● گره‌های مرحله: درشت، با شمارهٔ خوانا، ستاره، قفل و صندوقچه
##  ● نوار پایین همیشه در دسترس (رفت‌وآمد سریع بین بخش‌ها)
## ============================================================================

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")
const PathScript := preload("res://scripts/PathLine.gd")
const IconBtn := preload("res://scripts/IconButton.gd")
const PAGE := 10

var page := 0
var nodes_layer: Control
var path_layer: Control
var coin_label: Label
var world_label: Label
var progress_label: Label
var scroll: ScrollContainer
var content: Control
var _coin_pill: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	page = (Game.current_level - 1) / PAGE
	_build_chrome()
	_build_nodes()
	await get_tree().process_frame
	_scroll_to_current()
	Audio.start_music("map")


# ------------------------------------------------------------------- chrome
func _build_chrome() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_map.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	scroll = ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = UI.SCREEN
	scroll.custom_minimum_size = UI.SCREEN
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	content = Control.new()
	content.custom_minimum_size = Vector2(1080, 2700)
	content.size = content.custom_minimum_size
	scroll.add_child(content)

	path_layer = Control.new()
	path_layer.set_script(PathScript)
	path_layer.size = content.custom_minimum_size
	path_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(path_layer)

	nodes_layer = Control.new()
	nodes_layer.size = content.custom_minimum_size
	content.add_child(nodes_layer)

	# ---- هدر شیشه‌ای بالای صفحه (ثابت روی اسکرول)
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(1080, 190)
	top.size = Vector2(1080, 190)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var top_bg := TextureRect.new()
	top_bg.texture = ArtL.rounded_texture(256, 48, 22, Color(0.16, 0.09, 0.03, 0.55),
		Color(0.10, 0.05, 0.02, 0.75))
	top_bg.size = Vector2(1080, 210)
	top_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_bg.stretch_mode = TextureRect.STRETCH_SCALE
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_bg)

	var back := UI.back_button(122)
	back.position = Vector2(24, 42)
	top.add_child(back)
	_hit(top, Vector2(122, 122), Vector2(24, 42),
		func(): Transition.change_scene("res://scenes/HomeScene.tscn"))

	var plaque := UI.title_plaque("نقشهٔ سفر", Vector2(560, 116), 42)
	plaque.position = Vector2(266, 44)
	top.add_child(plaque)
	world_label = plaque.get_children()[1] as Label
	world_label.text = String(Game.world_of(Game.current_level).get("name", "نقشهٔ سفر"))

	_coin_pill = UI.coin_pill(Vector2(240, 96), false)
	_coin_pill.position = Vector2(812, 54)
	top.add_child(_coin_pill)
	coin_label = _coin_pill.get_meta("value_label")
	coin_label.text = Game.fa_num_grouped(Game.coins)
	Game.coins_changed.connect(func(v):
		if is_instance_valid(coin_label):
			coin_label.text = Game.fa_num_grouped(v))

	# ---- فلش‌های صفحه‌بندی دنیا
	var prev := _pager("‹", Vector2(28, 196), prev_world)
	var nxt := _pager("›", Vector2(1080 - 128, 196), next_world)
	add_child(prev)
	add_child(nxt)

	progress_label = UI.outlined_label("", 28, Color("#fff3d2"), Color("#4a2c10"), 6)
	progress_label.position = Vector2(390, 168)
	progress_label.size = Vector2(300, 46)
	add_child(progress_label)

	# ---- نوار پایین
	add_child(UI.vignette(0.40))
	var nav := UI.bottom_nav(_nav_items(), 0, _on_nav)
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


func _pager(glyph: String, pos: Vector2, cb: Callable) -> Control:
	var holder := Control.new()
	holder.position = pos
	holder.size = Vector2(100, 100)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := ArtL.gold_ring(100, 6, Color("#fdf3d8"))
	holder.add_child(ring)
	var l := UI.label(glyph, 64, UI.TEXT_DARK)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(l)
	var hit := Control.new()
	hit.size = Vector2(100, 100)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			Audio.play("tap")
			cb.call())
	holder.add_child(hit)
	return holder


func _hit(parent: Control, size: Vector2, pos: Vector2, cb: Callable) -> void:
	var hit := Control.new()
	hit.position = pos
	hit.size = size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			Audio.play("tap")
			cb.call())
	parent.add_child(hit)


# -------------------------------------------------------------------- nodes
func _build_nodes() -> void:
	for c in nodes_layer.get_children():
		c.queue_free()
	var w: Dictionary = Game.worlds[clampi(page, 0, Game.worlds.size() - 1)]
	world_label.text = String(w.get("name", "نقشهٔ سفر"))

	var first := page * PAGE + 1
	var last := mini(first + PAGE - 1, Game.total_levels())
	var count := last - first + 1
	var area := content.custom_minimum_size
	var margin := 330.0
	var step := (area.y - margin * 2.0 - 260.0) / float(maxi(count - 1, 1))
	var points: PackedVector2Array = []

	for i in count:
		var lvl := first + i
		var t := float(i) / float(maxi(count - 1, 1))
		var x := area.x * 0.5 + sin(t * PI * 2.6) * area.x * 0.26
		var y := area.y - margin - step * float(i) - 120.0
		points.append(Vector2(x, y))
		var nd := _make_node(lvl, Vector2(x, y))
		nodes_layer.add_child(nd)
		nd.scale = Vector2(0.3, 0.3)
		nd.modulate.a = 0.0
		var ntw := nd.create_tween().set_parallel()
		ntw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ntw.tween_property(nd, "scale", Vector2.ONE, 0.5).set_delay(0.05 * float(i))
		ntw.tween_property(nd, "modulate:a", 1.0, 0.32).set_delay(0.05 * float(i))

	path_layer.set_meta("points", points)
	path_layer.queue_redraw()

	var done := 0
	for k in range(first, last + 1):
		if Game.stars_for(k) > 0:
			done += 1
	progress_label.text = "%s از %s مرحله" % [Game.fa_num(done), Game.fa_num(count)]


func _make_node(lvl: int, pos: Vector2) -> Control:
	var unlocked := Game.is_unlocked(lvl)
	var st := Game.stars_for(lvl)
	var is_current := lvl == Game.current_level
	var box := 152.0

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(box, box)
	holder.size = Vector2(box, box)
	holder.position = pos - Vector2(box, box) * 0.5
	holder.pivot_offset = Vector2(box, box) * 0.5

	if is_current:
		var glow := ArtL.glow_disc(box * 2.3, Color("#b6ff7a"))
		glow.position = -Vector2(box * 0.65, box * 0.65)
		glow.modulate.a = 0.75
		holder.add_child(glow)

	var shadow := ArtL.ground_shadow(box * 1.1, box * 0.4, 0.35)
	shadow.position = Vector2(-box * 0.05, box * 0.68)
	holder.add_child(shadow)

	var tex := TextureRect.new()
	var base := Color("#59c236") if is_current else (Color("#f6e0a8") if unlocked else Color("#b9b3a6"))
	var edge := Color("#2f7a1c") if is_current else (Color("#c89328") if unlocked else Color("#8a8478"))
	tex.texture = ArtL.tile_texture(150, base, edge, is_current)
	tex.size = Vector2(box, box)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	holder.add_child(tex)

	var lbl := UI.outlined_label(Game.fa_num(lvl) if unlocked else "", 58,
		Color.WHITE if (unlocked or is_current) else Color(0.9, 0.9, 0.9),
		Color("#2f4a19") if is_current else (Color("#8a5a10") if unlocked else Color("#55504a")), 7)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_top = -6
	holder.add_child(lbl)

	if not unlocked:
		var lock := Control.new()
		lock.set_script(load("res://scripts/LockIcon.gd"))
		lock.size = Vector2(box, box)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lock)

	if st > 0:
		var hb := UI.star_row(st, 40)
		hb.position = Vector2(box * 0.5 - 66, box - 16)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(hb)

	if lvl % 10 == 0:
		var chest := TextureRect.new()
		chest.texture = load("res://assets/icons/chest.png")
		chest.custom_minimum_size = Vector2(110, 110)
		chest.size = chest.custom_minimum_size
		chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest.position = Vector2(box * 0.5 - 55, -100)
		chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(chest)
		UI.idle_bob(chest, 8.0, 1.9)

	if is_current:
		var p := CPUParticles2D.new()
		p.position = Vector2(box * 0.5, box * 0.5)
		p.emitting = true
		p.amount = 16
		p.lifetime = 1.5
		p.preprocess = 1.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 60.0
		p.direction = Vector2(0, -1)
		p.spread = 40.0
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 54.0
		p.gravity = Vector2(0, -26)
		p.scale_amount_min = 2.0
		p.scale_amount_max = 5.5
		p.color = Color(0.78, 1.0, 0.55, 0.8)
		holder.add_child(p)
		var pulse := holder.create_tween().set_loops()
		pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(holder, "scale", Vector2(1.06, 1.06), 0.9)
		pulse.tween_property(holder, "scale", Vector2.ONE, 0.9)

	var btn := Button.new()
	btn.size = Vector2(box, box)
	btn.custom_minimum_size = btn.size
	btn.flat = true
	btn.disabled = not unlocked
	btn.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, empty)
	holder.add_child(btn)
	if unlocked:
		btn.pressed.connect(func() -> void:
			Audio.play("tap")
			Game.set_meta("goto_level", lvl)
			Transition.change_scene("res://scenes/LevelScene.tscn"))
	return holder


func _scroll_to_current() -> void:
	var idx := (Game.current_level - 1) % PAGE
	var area := content.custom_minimum_size
	var margin := 330.0
	var step := (area.y - margin * 2.0 - 260.0) / float(PAGE - 1)
	var y := area.y - margin - step * float(idx) - 120.0
	scroll.scroll_vertical = int(clampf(y - 1200.0, 0.0, area.y - UI.SCREEN.y))


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
