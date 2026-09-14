extends Control
## Gameplay screen: crossword-style answer board + swipe letter wheel.

const UI := preload("res://scripts/UIKit.gd")
const WheelScript := preload("res://scripts/LetterWheel.gd")

var level_id := 1
var level_data: Dictionary = {}
var answers: Array = []
var found: Dictionary = {}
var bonus_found: Array = []
var hints_used := 0
var _slots: Dictionary = {}
var _finished := false

var wheel: LetterWheel
var board: Control
var coin_label: Label
var preview: Label
var bonus_badge: Control
var bonus_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	level_id = int(Game.get_meta("goto_level", 0))
	if level_id <= 0:
		level_id = Game.current_level
	Game.set_meta("goto_level", 0)
	level_data = Game.get_level(level_id)
	if level_data.is_empty():
		level_data = Game.get_level(1)
		level_id = 1
	answers = level_data.get("words", []).duplicate()
	answers.sort_custom(func(a, b):
		return a.length() < b.length() if a.length() != b.length() else a < b)

	_build_ui()
	_build_board()
	wheel.set_letters(level_data.get("letters", []))
	wheel.word_submitted.connect(_on_word)
	wheel.word_changed.connect(func(w): preview.text = w)
	Game.coins_changed.connect(func(v): coin_label.text = Game.fa_num_grouped(v))
	Audio.start_music()


# ------------------------------------------------------------------- chrome
func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_level.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# back button
	var back := UI.icon_button("res://assets/icons/btn_back.png", 100)
	back.position = Vector2(36, 60)
	back.pressed.connect(_on_back_pressed)
	add_child(back)

	# level title plaque
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", UI.wood_panel(30, 6))
	plaque.position = Vector2(330, 58)
	plaque.custom_minimum_size = Vector2(420, 104)
	plaque.add_child(UI.outlined_label("مرحله " + Game.fa_num(level_id), 48,
		Color("#ffe9b8"), Color("#3f2609"), 8))
	add_child(plaque)

	# coins
	var coinp := PanelContainer.new()
	coinp.add_theme_stylebox_override("panel", UI.gold_pill(30))
	coinp.position = Vector2(790, 66)
	coinp.custom_minimum_size = Vector2(250, 86)
	var chb := HBoxContainer.new()
	chb.add_theme_constant_override("separation", 8)
	chb.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_label = UI.label(Game.fa_num_grouped(Game.coins), 34, Color("#5b3a1c"))
	chb.add_child(coin_label)
	var ci := TextureRect.new()
	ci.texture = load("res://assets/icons/coin.png")
	ci.custom_minimum_size = Vector2(56, 56)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chb.add_child(ci)
	coinp.add_child(chb)
	add_child(coinp)

	# answer board parchment
	var parch := PanelContainer.new()
	var sb := UI.cream_panel(34)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	parch.add_theme_stylebox_override("panel", sb)
	parch.position = Vector2(60, 230)
	parch.custom_minimum_size = Vector2(960, 620)
	add_child(parch)

	board = Control.new()
	board.custom_minimum_size = Vector2(910, 560)
	parch.add_child(board)

	# current-word preview
	preview = UI.outlined_label("", 64, Color("#fff3d4"), Color("#5b3a1c"), 10)
	preview.position = Vector2(90, 900)
	preview.size = Vector2(900, 90)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)

	# bonus word badge
	bonus_badge = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#f7b731")
	bsb.set_corner_radius_all(24)
	bsb.border_color = Color("#c2801a")
	bsb.set_border_width_all(3)
	bsb.content_margin_left = 26
	bsb.content_margin_right = 26
	bsb.content_margin_top = 10
	bsb.content_margin_bottom = 10
	bonus_badge.add_theme_stylebox_override("panel", bsb)
	bonus_badge.position = Vector2(360, 830)
	bonus_label = UI.label("", 34, Color("#5b3a1c"))
	bonus_badge.add_child(bonus_label)
	bonus_badge.visible = false
	bonus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bonus_badge)

	# the wheel
	var wheel_ctrl := Control.new()
	wheel_ctrl.set_script(WheelScript)
	wheel = wheel_ctrl as LetterWheel
	wheel.position = Vector2(190, 1020)
	wheel.size = Vector2(700, 700)
	wheel.custom_minimum_size = wheel.size
	var tiles := Control.new()
	tiles.name = "Tiles"
	tiles.set_anchors_preset(Control.PRESET_FULL_RECT)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_ctrl.add_child(tiles)
	add_child(wheel_ctrl)
	_wheel_backdrop()

	# shuffle + hint
	var shuffle := UI.icon_button("res://assets/icons/shuffle.png", 120)
	shuffle.position = Vector2(50, 1730)
	shuffle.pressed.connect(func(): wheel.shuffle_letters())
	add_child(shuffle)
	add_child(_caption("بُر زدن", Vector2(52, 1846)))

	var hint_holder := Control.new()
	hint_holder.position = Vector2(910, 1730)
	var hint := UI.icon_button("res://assets/icons/hint.png", 120)
	hint.pressed.connect(_on_hint_pressed)
	hint_holder.add_child(hint)
	var price := PanelContainer.new()
	price.add_theme_stylebox_override("panel", UI.gold_pill(20))
	price.position = Vector2(4, 96)
	var phb := HBoxContainer.new()
	phb.add_theme_constant_override("separation", 4)
	phb.alignment = BoxContainer.ALIGNMENT_CENTER
	phb.add_child(UI.label(Game.fa_num(Game.HINT_COST), 26, Color("#5b3a1c")))
	var pc := TextureRect.new()
	pc.texture = load("res://assets/icons/coin.png")
	pc.custom_minimum_size = Vector2(32, 32)
	pc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	phb.add_child(pc)
	price.add_child(phb)
	price.custom_minimum_size = Vector2(112, 44)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_holder.add_child(price)
	add_child(hint_holder)


func _wheel_backdrop() -> void:
	var disc := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#a3713c")
	sb.set_corner_radius_all(350)
	sb.border_color = Color("#7a5024")
	sb.set_border_width_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	disc.add_theme_stylebox_override("panel", sb)
	disc.position = wheel.position
	disc.size = wheel.size
	disc.custom_minimum_size = wheel.size
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(disc)
	move_child(disc, wheel.get_index())


func _caption(text: String, pos: Vector2) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.22, 0.08, 0.82)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.add_child(UI.label(text, 24, Color("#fff0cf")))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# ------------------------------------------------------------------- board
func _build_board() -> void:
	for c in board.get_children():
		c.queue_free()
	_slots.clear()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.add_child(vb)

	var rows: Array = []
	var cur: Array = []
	var cur_cells := 0
	for w in answers:
		var cells: int = String(w).length()
		if cur_cells + cells > 11 and cur.size() > 0:
			rows.append(cur)
			cur = []
			cur_cells = 0
		cur.append(w)
		cur_cells += cells + 1
	if cur.size() > 0:
		rows.append(cur)

	for row in rows:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 26)
		vb.add_child(hb)
		for w in row:
			hb.add_child(_make_word_slots(String(w)))


func _make_word_slots(word: String) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 7)
	var labels: Array = []
	for i in range(word.length() - 1, -1, -1):
		var cell := _make_cell(word[i])
		hb.add_child(cell)
		labels.insert(0, cell)
	_slots[word] = labels
	return hb


func _make_cell(letter: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(62, 72)
	p.add_theme_stylebox_override("panel", _cell_style(Color("#e8d9b0"),
		Color("#cbb488")))
	p.set_meta("letter", letter)
	p.set_meta("revealed", false)

	var lbl := Label.new()
	lbl.name = "L"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load(UI.FONT_BLACK))
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color("#5b3a1c"))
	p.add_child(lbl)
	return p


static func _cell_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.13)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


func _reveal_word(word: String, animate: bool = true) -> void:
	var cells: Array = _slots.get(word, [])
	for i in cells.size():
		var cell: Panel = cells[i]
		if bool(cell.get_meta("revealed")):
			continue
		cell.set_meta("revealed", true)
		var lbl: Label = cell.get_node("L")
		lbl.text = String(cell.get_meta("letter"))
		cell.add_theme_stylebox_override("panel",
			_cell_style(Color("#8fd66a"), Color("#5da13c")))
		lbl.add_theme_color_override("font_color", Color.WHITE)
		if animate:
			cell.pivot_offset = cell.size * 0.5
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(i * 0.05)
			tw.tween_property(cell, "scale", Vector2.ONE, 0.3).from(Vector2(0.55, 0.55))


# ------------------------------------------------------------------ gameplay
func _on_word(word: String) -> void:
	preview.text = ""
	if _finished:
		return
	if answers.has(word):
		if found.has(word):
			Audio.play("already")
			wheel.flash(Color("#6fa8dc"))
			_pulse_word(word)
			return
		found[word] = true
		Audio.play("word_ok")
		Audio.vibrate(25)
		wheel.flash(Color("#8fd66a"))
		_reveal_word(word)
		Game.register_word_found(false)
		_check_complete()
	elif word.length() >= 3 and Game.dictionary.has(word) and not bonus_found.has(word):
		bonus_found.append(word)
		Audio.play("word_bonus")
		Audio.vibrate(30)
		wheel.flash(Color("#f7b731"))
		Game.register_word_found(true)
		Game.add_coins(5)
		_show_bonus(word)
	else:
		Audio.play("word_bad")
		wheel.flash(Color("#e0665a"))
		_shake(preview)


func _pulse_word(word: String) -> void:
	for cell in _slots.get(word, []):
		var tw := create_tween()
		tw.tween_property(cell, "modulate", Color(1.5, 1.5, 1.5), 0.12)
		tw.tween_property(cell, "modulate", Color.WHITE, 0.12)


func _show_bonus(word: String) -> void:
	bonus_label.text = word + "  +۵"
	bonus_badge.visible = true
	bonus_badge.modulate.a = 0.0
	var start_y := bonus_badge.position.y
	var tw := create_tween()
	tw.tween_property(bonus_badge, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(bonus_badge, "position:y", start_y - 40, 0.9)
	tw.tween_property(bonus_badge, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		bonus_badge.visible = false
		bonus_badge.position.y = start_y)


func _shake(node: Control) -> void:
	var base := node.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(node, "position:x", base.x + 10, 0.04)
		tw.tween_property(node, "position:x", base.x - 10, 0.04)
	tw.tween_property(node, "position", base, 0.04)


func _on_hint_pressed() -> void:
	if _finished:
		return
	if not Game.spend_coins(Game.HINT_COST):
		_toast("سکه کافی نداری!")
		Audio.play("word_bad")
		return
	hints_used += 1
	Game.stats["hints_used"] = int(Game.stats.get("hints_used", 0)) + 1
	Audio.play("hint")
	for w in answers:
		if found.has(w):
			continue
		for cell in _slots[String(w)]:
			if not bool(cell.get_meta("revealed")):
				cell.set_meta("revealed", true)
				var lbl: Label = cell.get_node("L")
				lbl.text = String(cell.get_meta("letter"))
				cell.add_theme_stylebox_override("panel",
					_cell_style(Color("#ffe08a"), Color("#e0a93c")))
				cell.pivot_offset = cell.size * 0.5
				var tw := create_tween().set_trans(Tween.TRANS_BACK)
				tw.set_ease(Tween.EASE_OUT)
				tw.tween_property(cell, "scale", Vector2.ONE, 0.3).from(Vector2(0.55, 0.55))
				wheel.highlight_letter(String(cell.get_meta("letter")))
				_check_word_auto_complete(String(w))
				return
	_toast("همه حروف پیدا شده‌اند!")


func _check_word_auto_complete(word: String) -> void:
	for cell in _slots[word]:
		if not bool(cell.get_meta("revealed")):
			return
	found[word] = true
	Audio.play("word_ok")
	_check_complete()


func _on_back_pressed() -> void:
	Audio.play("tap")
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")


func _check_complete() -> void:
	if found.size() < answers.size():
		return
	_finished = true
	wheel.set_disabled(true)
	var earned := 3
	if hints_used >= 3:
		earned = 1
	elif hints_used >= 1:
		earned = 2
	Audio.play("win")
	await get_tree().create_timer(0.55).timeout
	Game.complete_level(level_id, earned, bonus_found)
	_show_win_popup(earned)


func _show_win_popup(earned: int) -> void:
	var popup := preload("res://scenes/WinPopup.tscn").instantiate()
	add_child(popup)
	popup.setup(level_id, earned, int(level_data.get("reward", 20)), bonus_found.size())
	popup.next_pressed.connect(func() -> void:
		if level_id < Game.total_levels():
			Game.set_meta("goto_level", level_id + 1)
			get_tree().change_scene_to_file("res://scenes/LevelScene.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/MapScene.tscn"))
	popup.map_pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MapScene.tscn"))


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(340, 960)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()
