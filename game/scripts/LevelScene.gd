extends Control
## Gameplay screen: a tidy crossword board + a big swipe letter wheel.
##
## v1.2 layout pass
##   * the board is a real centred grid: every row spans the same width and the
##     cell size is computed from the widest row, so nothing looks ragged
##   * the wheel is bigger (870 px) and the word being built is drawn *inside*
##     the wheel, right under the player's finger
##   * combo feedback + gem skip give the loop a second reward channel

const UI := preload("res://scripts/UIKit.gd")
const WheelScript := preload("res://scripts/LetterWheel.gd")
const IconBtn := preload("res://scripts/IconButton.gd")

const BOARD_RECT := Rect2(96, 236, 888, 496)
const WHEEL_POS := Vector2(150, 878)
const WHEEL_SIZE := Vector2(780, 780)
const SHAKE_TIME := 0.2

var level_id := 1
var level_data: Dictionary = {}
var answers: Array = []
var found: Dictionary = {}
var bonus_found: Array = []
var hints_used := 0
var _slots: Dictionary = {}
var _finished := false
var _perfect := true          # no wrong attempts this level
var _cell_style_cache: Dictionary = {}

var wheel: LetterWheel
var board: Control
var coin_label: Label
var preview: Label
var bonus_badge: Control
var bonus_label: Label
var combo_chip: Control
var combo_label: Label


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
		return a.length() > b.length() if a.length() != b.length() else a < b)

	Game.combo = 0
	_build_ui()
	_build_board()
	wheel.set_letters(level_data.get("letters", []))
	wheel.word_submitted.connect(_on_word)
	wheel.word_changed.connect(_on_word_changed)
	Game.coins_changed.connect(func(v): coin_label.text = Game.fa_num_grouped(v))
	Game.combo_changed.connect(_on_combo_changed)
	Audio.set_section("level")
	_refresh_combo()
	if Game.daily_bonus_ready():
		await get_tree().create_timer(0.4).timeout
		if is_inside_tree() and not _finished:
			_toast("جایزهٔ اولین مرحلهٔ امروز: سکه دوبرابر!")


# ------------------------------------------------------------------- chrome
func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_level.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scrim := UI.gradient_panel(1080, 340, Color(0.14, 0.08, 0.03, 0.55),
		Color(0.14, 0.08, 0.03, 0.0), 0, Color(0, 0, 0, 0), 0, 0.0)
	add_child(scrim)

	# ---- top bar
	var back := IconBtn.new()
	back.icon_path = "res://assets/icons/btn_back.png"
	back.icon_size = 124.0
	back.position = Vector2(28, 44)
	back.pressed.connect(_on_back_pressed)
	add_child(back)

	var plaque := UI.glass_card(30, Color(0.30, 0.18, 0.07, 0.80), 22)
	plaque.position = Vector2(330, 44)
	plaque.custom_minimum_size = Vector2(420, 112)
	plaque.add_child(UI.outlined_label("مرحله " + Game.fa_num(level_id), 50,
		Color("#ffe9b8"), Color("#3f2609"), 8))
	add_child(plaque)

	var coinp := UI.currency_pill("res://assets/icons/coin.png",
		Game.fa_num_grouped(Game.coins), Vector2(280, 104))
	coinp.position = Vector2(770, 48)
	coin_label = _find_label(coinp)
	add_child(coinp)

	# ---- answer board on its parchment
	var parch := TextureRect.new()
	parch.texture = load("res://assets/art/board_panel.png")
	parch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parch.stretch_mode = TextureRect.STRETCH_SCALE
	parch.position = Vector2(50, 196)
	parch.size = Vector2(980, 576)
	parch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(parch)

	board = Control.new()
	board.position = BOARD_RECT.position
	board.size = BOARD_RECT.size
	board.custom_minimum_size = board.size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	# ---- combo chip
	combo_chip = UI.glass_card(28, Color(0.92, 0.60, 0.10, 0.94), 18)
	combo_chip.position = Vector2(370, 796)
	combo_chip.custom_minimum_size = Vector2(340, 78)
	combo_chip.size = Vector2(340, 78)
	combo_label = UI.label("زنجیره ×۲", 38, Color.WHITE, UI.FONT_BLACK)
	combo_chip.add_child(combo_label)
	combo_chip.visible = false
	combo_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combo_chip)

	# ---- wheel (with the live word in its centre)
	var wheel_ctrl := Control.new()
	wheel_ctrl.set_script(WheelScript)
	wheel_ctrl.position = WHEEL_POS
	wheel_ctrl.size = WHEEL_SIZE
	wheel_ctrl.custom_minimum_size = WHEEL_SIZE
	var tiles := Control.new()
	tiles.name = "Tiles"
	tiles.set_anchors_preset(Control.PRESET_FULL_RECT)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_ctrl.add_child(tiles)
	add_child(wheel_ctrl)
	wheel = wheel_ctrl as LetterWheel
	_wheel_backdrop()

	preview = UI.outlined_label("", 78, Color("#fff6dd"), Color("#4a2c10"), 12)
	preview.position = Vector2(WHEEL_POS.x + 150, WHEEL_POS.y + 322)
	preview.size = Vector2(480, 136)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)

	# ---- bonus badge (word toast above the wheel)
	bonus_badge = UI.glass_card(24, Color(0.98, 0.72, 0.20, 0.96), 20)
	bonus_badge.position = Vector2(340, 812)
	bonus_badge.custom_minimum_size = Vector2(400, 90)
	bonus_label = UI.label("", 40, Color("#4a2c10"), UI.FONT_BLACK)
	bonus_badge.add_child(bonus_label)
	bonus_badge.visible = false
	bonus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bonus_badge)

	# ---- bottom controls
	var shuffle := IconBtn.new()
	shuffle.icon_path = "res://assets/icons/shuffle.png"
	shuffle.caption = "بُر زدن"
	shuffle.icon_size = 156.0
	shuffle.position = Vector2(30, 1660)
	shuffle.pressed.connect(func(): wheel.shuffle_letters())
	add_child(shuffle)

	var hint_holder := Control.new()
	hint_holder.position = Vector2(890, 1660)
	var hint := IconBtn.new()
	hint.icon_path = "res://assets/icons/hint.png"
	hint.icon_size = 156.0
	hint.float_phase = 0.6
	hint.pressed.connect(_on_hint_pressed)
	hint_holder.add_child(hint)
	var price := UI.glass_card(20, Color(1, 1, 1, 0.92), 10)
	price.position = Vector2(30, 134)
	var phb := HBoxContainer.new()
	phb.add_theme_constant_override("separation", 4)
	phb.alignment = BoxContainer.ALIGNMENT_CENTER
	phb.add_child(UI.label(Game.fa_num(Game.HINT_COST), 26, UI.INK))
	var pc := TextureRect.new()
	pc.texture = load("res://assets/icons/coin.png")
	pc.custom_minimum_size = Vector2(30, 30)
	pc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	phb.add_child(pc)
	price.add_child(phb)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_holder.add_child(price)
	add_child(hint_holder)

	# gem skip: reveal one whole word instantly
	var gem := Control.new()
	gem.position = Vector2(376, 1684)
	gem.size = Vector2(328, 108)
	gem.mouse_filter = Control.MOUSE_FILTER_STOP
	var gface := UI.gradient_panel(328, 108, Color("#8bb8e8"), Color("#3f6ea8"), 30,
		Color(1, 1, 1, 0.4), 2, 0.18)
	gem.add_child(gface)
	var ghb := HBoxContainer.new()
	ghb.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghb.alignment = BoxContainer.ALIGNMENT_CENTER
	ghb.add_theme_constant_override("separation", 8)
	var gi := TextureRect.new()
	gi.texture = load("res://assets/icons/gem.png")
	gi.custom_minimum_size = Vector2(52, 52)
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghb.add_child(gi)
	ghb.add_child(UI.label("آشکار کردن کلمه  •  " + Game.fa_num(Game.GEM_PRICE), 28,
		Color.WHITE, UI.FONT_BLACK))
	gem.add_child(ghb)
	gem.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_on_gem_skip(gem))
	add_child(gem)


func _find_label(node: Node) -> Label:
	for c in node.get_children():
		if c is Label:
			return c
		var r := _find_label(c)
		if r != null:
			return r
	return null


func _wheel_backdrop() -> void:
	var disc := TextureRect.new()
	disc.texture = load("res://assets/art/wheel_base.png")
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	disc.position = WHEEL_POS - Vector2(28, 28)
	disc.size = WHEEL_SIZE + Vector2(56, 56)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(disc)
	move_child(disc, wheel.get_index())


# ------------------------------------------------------------------- board
## Packs the answers into balanced rows, then renders every row at the same
## width so the board reads as a designed grid instead of loose word blocks.
func _build_board() -> void:
	for c in board.get_children():
		c.queue_free()
	_slots.clear()

	const MAX_CELLS := 11
	var rows: Array = []
	var cur: Array = []
	var cur_cells := 0
	for w in answers:
		var cells: int = String(w).length() + 1
		if cur_cells + cells > MAX_CELLS and cur.size() > 0:
			rows.append(cur)
			cur = []
			cur_cells = 0
		cur.append(String(w))
		cur_cells += cells
	if cur.size() > 0:
		rows.append(cur)

	# widest row decides the cell size, so long words still fit on one line
	var widest := 1
	for r in rows:
		var n := 0
		for w in r:
			n += String(w).length()
		widest = maxi(widest, n)

	var sep := 26.0
	var gap_between := 8.0
	var target := board.size.x
	var cell_w: float = floor((target - sep * 2.0 - gap_between * float(widest)) / float(widest))
	cell_w = clampf(cell_w, 50.0, 88.0)
	var cell_h: float = cell_w * 1.16

	# vertical rhythm: rows are evenly distributed inside the board rect
	var n_rows := rows.size()
	var row_h: float = cell_h
	var v_space: float = board.size.y - row_h * float(n_rows)
	var v_gap: float = clampf(v_space / float(maxi(n_rows - 1, 1)), 12.0, 46.0)
	var total_h: float = row_h * float(n_rows) + v_gap * float(maxi(n_rows - 1, 0))
	var start_y: float = maxf((board.size.y - total_h) * 0.5, 0.0)

	for i in n_rows:
		var row: Array = rows[i]
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.size = Vector2(target, row_h)
		hb.position = Vector2(0, start_y + (row_h + v_gap) * float(i))
		# stretch every row to the same visual width
		var letters := 0
		for w in row:
			letters += String(w).length()
		var blocks := row.size()
		var used: float = cell_w * float(letters) + gap_between * float(maxi(letters - blocks, 0))
		var slack: float = maxf(target - used, 0.0)
		var extra: float = slack / float(maxi(blocks + 1, 1))
		hb.add_theme_constant_override("separation", int(gap_between + extra))
		board.add_child(hb)
		for w in row:
			hb.add_child(_make_word_slots(String(w), cell_w, cell_h))


func _make_word_slots(word: String, cell_w: float, cell_h: float) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	var labels: Array = []
	for i in range(word.length() - 1, -1, -1):
		var cell := _make_cell(word[i], cell_w, cell_h)
		hb.add_child(cell)
		labels.insert(0, cell)
	_slots[word] = labels
	return hb


func _make_cell(letter: String, cell_w: float, cell_h: float) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(cell_w, cell_h)
	p.add_theme_stylebox_override("panel", _cell_style(false))
	p.set_meta("letter", letter)
	p.set_meta("revealed", false)

	var lbl := Label.new()
	lbl.name = "L"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load(UI.FONT_BLACK))
	lbl.add_theme_font_size_override("font_size", int(cell_w * 0.62))
	lbl.add_theme_color_override("font_color", Color("#7a5b38"))
	_lbl_soft_shadow(lbl)
	p.add_child(lbl)
	return p


func _lbl_soft_shadow(l: Label) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	l.add_theme_stylebox_override("normal", sb)


## One soft tile style for both states (cached: two StyleBoxes per level).
func _cell_style(revealed: bool, hint: bool = false) -> StyleBoxFlat:
	var key := "%s_%s" % [revealed, hint]
	if _cell_style_cache.has(key):
		return _cell_style_cache[key]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	if hint:
		sb.bg_color = Color("#ffe6a8")
		sb.border_color = Color("#e0a93c")
	else:
		sb.bg_color = Color("#f6ecd2") if not revealed else Color("#77c94b")
		sb.border_color = Color("#e2d3b0") if not revealed else Color("#4f9a2c")
	sb.set_border_width_all(2)
	sb.border_width_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.10)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	_cell_style_cache[key] = sb
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
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_outline_color", Color("#3f8a1e"))
		cell.add_theme_stylebox_override("panel", _cell_style(true))
		if animate:
			cell.pivot_offset = cell.size * 0.5
			var tw := cell.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(i * 0.055)
			tw.tween_property(cell, "scale", Vector2.ONE, 0.32).from(Vector2(0.6, 0.6))


# ------------------------------------------------------------------ gameplay
func _on_word_changed(w: String) -> void:
	if preview == null:
		return
	preview.text = w
	preview.modulate.a = 1.0 if w != "" else 0.0
	pass


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
		Audio.vibrate(22)
		wheel.flash(Color("#8fd66a"))
		wheel.celebrate(wheel.index_of_letters(word))
		_reveal_word(word)
		_word_burst(word)
		_shake_screen(4.0, 0.16)
		Game.register_word_found(false)
		var tier := Game.register_correct_word()
		if tier > 0:
			var bonus := 5 * tier
			Game.add_coins(bonus)
			_fly_coins(wheel.position + wheel.size * 0.5, 3 + tier)
			Audio.play("combo", 1.0 + 0.08 * float(tier))
			_toast("زنجیره ×%s  —  +%s سکه" % [Game.fa_num(Game.combo), Game.fa_num(bonus)])
		_check_complete()
	elif word.length() >= 3 and Game.dictionary.has(word) and not bonus_found.has(word):
		bonus_found.append(word)
		Audio.play("word_bonus")
		Audio.vibrate(28)
		wheel.flash(Color("#f7b731"))
		Game.register_word_found(true)
		Game.add_coins(5)
		_show_bonus(word)
		wheel.celebrate(wheel.index_of_letters(word))
		_fly_coins(wheel.position + wheel.size * 0.5, 6)
	else:
		_perfect = false
		Audio.play("word_bad")
		Audio.vibrate(30)
		Game.break_combo()
		wheel.flash(Color("#e0665a"))
		_shake_screen(6.0, 0.2)
		# gentle nudge instead of a hard error
		_toast("این کلمه نبود — دوباره امتحان کن" if word.length() >= 3
			else "کلمه باید حداقل ۳ حرف باشد")


func _on_combo_changed(value: int) -> void:
	_refresh_combo()
	if value >= 12:
		Audio.play("levelup")
		_toast("زنجیرهٔ طلایی! سکه‌ها سه‌برابر شد")


func _refresh_combo() -> void:
	if combo_chip == null:
		return
	var tier := Game.combo_tier()
	combo_chip.visible = Game.combo >= 5
	if not combo_chip.visible:
		return
	combo_label.text = "زنجیره ×" + Game.fa_num(Game.combo)
	combo_chip.pivot_offset = combo_chip.size * 0.5
	var tw := combo_chip.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(combo_chip, "scale", Vector2(1.12, 1.12), 0.12)
	tw.tween_property(combo_chip, "scale", Vector2.ONE, 0.22)
	if tier >= 2:
		combo_chip.modulate = Color(1.0, 0.85, 0.55)
	elif tier == 1:
		combo_chip.modulate = Color.WHITE


func _pulse_word(word: String) -> void:
	for cell in _slots.get(word, []):
		var tw := create_tween()
		tw.tween_property(cell, "modulate", Color(1.35, 1.35, 1.35), 0.12)
		tw.tween_property(cell, "modulate", Color.WHITE, 0.12)


func _show_bonus(word: String) -> void:
	bonus_label.text = word + "  +۵"
	bonus_badge.visible = true
	bonus_badge.modulate.a = 0.0
	var start_y := bonus_badge.position.y
	var tw := create_tween()
	tw.tween_property(bonus_badge, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(bonus_badge, "position:y", start_y - 46, 0.9)
	tw.tween_property(bonus_badge, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		bonus_badge.visible = false
		bonus_badge.position.y = start_y)


# -------------------------------------------------------------------- hints
func _on_hint_pressed() -> void:
	if _finished:
		return
	if not Game.spend_coins(Game.HINT_COST):
		_toast("سکه کافی نداری!")
		Audio.play("word_bad")
		return
	hints_used += 1
	_perfect = false
	Game.stats["hints_used"] = int(Game.stats.get("hints_used", 0)) + 1
	Audio.play("hint")
	var word := _next_unfinished_word()
	if word == "":
		_toast("همهٔ حروف پیدا شده‌اند!")
		return
	_reveal_letter_in(word)


func _on_gem_skip(node: Control) -> void:
	if _finished:
		return
	if not Game.spend_gems(Game.GEM_PRICE):
		_toast("جواهر کافی نداری — %s جواهر لازم است" % Game.fa_num(Game.GEM_PRICE))
		Audio.play("word_bad")
		return
	var word := _next_unfinished_word()
	if word == "":
		_toast("کلمه‌ای باقی نمانده!")
		return
	hints_used += 1
	_perfect = false
	Audio.play("unlock")
	_pulse_node(node)
	for cell in _slots[word]:
		cell.set_meta("revealed", true)
		var lbl: Label = cell.get_node("L")
		lbl.text = String(cell.get_meta("letter"))
		lbl.add_theme_color_override("font_color", Color("#fff0c0"))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_outline_color", Color("#c07a17"))
		cell.add_theme_stylebox_override("panel", _cell_style(false, true))
		cell.pivot_offset = cell.size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cell, "scale", Vector2.ONE, 0.3).from(Vector2(0.6, 0.6))
	_auto_complete(word)
	_check_complete()


## shortest unfinished word first — keeps hints useful
func _next_unfinished_word() -> String:
	var best := ""
	for w in answers:
		var ww := String(w)
		if found.has(ww):
			continue
		if best == "" or ww.length() < best.length():
			best = ww
	return best


func _reveal_letter_in(word: String) -> void:
	for cell in _slots[word]:
		if not bool(cell.get_meta("revealed")):
			cell.set_meta("revealed", true)
			var lbl: Label = cell.get_node("L")
			lbl.text = String(cell.get_meta("letter"))
			lbl.add_theme_color_override("font_color", Color("#8a5a12"))
			cell.add_theme_stylebox_override("panel", _cell_style(false, true))
			cell.pivot_offset = cell.size * 0.5
			var tw := create_tween().set_trans(Tween.TRANS_BACK)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "scale", Vector2.ONE, 0.3).from(Vector2(0.6, 0.6))
			wheel.highlight_letter(String(cell.get_meta("letter")))
			_auto_complete(word)
			return
	_toast("همهٔ حروف این کلمه باز شده‌اند")


func _auto_complete(word: String) -> void:
	for cell in _slots[word]:
		if not bool(cell.get_meta("revealed")):
			return
	if found.has(word):
		return
	found[word] = true
	Audio.play("word_ok")
	_toast("کلمه پیدا شد: " + word)
	_check_complete()


func _on_back_pressed() -> void:
	Audio.play("tap")
	Transition.change_scene("res://scenes/MapScene.tscn")


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
			Transition.change_scene("res://scenes/LevelScene.tscn")
		else:
			Transition.change_scene("res://scenes/MapScene.tscn"))
	popup.map_pressed.connect(func() -> void:
		Transition.change_scene("res://scenes/MapScene.tscn"))


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg, 30)
	add_child(t)
	t.position = Vector2(200, 700)


# ==================================================================== FX
var _shake_amount := 0.0
var _shake_time := 0.0


func _shake(node: Control) -> void:
	var base := node.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(node, "position:x", base.x + 10, 0.04)
		tw.tween_property(node, "position:x", base.x - 10, 0.04)
	tw.tween_property(node, "position", base, 0.04)


func _pulse_node(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(0.92, 0.92), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.24)


func _shake_screen(amount: float, time: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_time = maxf(_shake_time, time)
	set_process(true)


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var k: float = clampf(_shake_time / SHAKE_TIME, 0.0, 1.0)
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* _shake_amount * k
		if _shake_time <= 0.0:
			position = Vector2.ZERO
			_shake_amount = 0.0


func _word_burst(word: String) -> void:
	var cells: Array = _slots.get(word, [])
	if cells.is_empty():
		return
	var mid: Panel = cells[cells.size() / 2]
	var p := CPUParticles2D.new()
	p.position = mid.get_global_rect().get_center()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.7
	p.spread = 180.0
	p.initial_velocity_min = 110.0
	p.initial_velocity_max = 280.0
	p.gravity = Vector2(0, 460)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 6.0
	p.color = Color(0.72, 0.96, 0.52)
	add_child(p)
	get_tree().create_timer(1.3).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


func _fly_coins(from: Vector2, count: int) -> void:
	var target := Vector2(880, 100)
	for i in count:
		var c := TextureRect.new()
		c.texture = load("res://assets/icons/coin.png")
		c.custom_minimum_size = Vector2(52, 52)
		c.size = c.custom_minimum_size
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.position = from + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		c.pivot_offset = Vector2(26, 26)
		c.z_index = 40
		add_child(c)
		var mid := c.position.lerp(target, 0.45) + Vector2(randf_range(-160, 160), -220)
		var tw := c.create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.035 * i)
		tw.tween_property(c, "position", mid, 0.32)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(c, "position", target, 0.38)
		tw.parallel().tween_property(c, "scale", Vector2(0.5, 0.5), 0.38)
		tw.tween_callback(func():
			Audio.play("coin", randf_range(0.94, 1.12))
			if is_instance_valid(c):
				c.queue_free())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()
