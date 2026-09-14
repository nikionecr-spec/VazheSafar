extends Control
## ============================================================================
##  صحنهٔ گیم‌پلی — چیدمان درشت و گرافیکی
##  ● تابلو کلمات با کاشی‌های بزرگ (۷۸×۹۲) و گرادیان گرم
##  ● چرخ حروف ۷۴۰px با مرکزِ زنده که همان لحظه کلمهٔ در ساخت را نشان می‌دهد
##  ● دکمه‌های درشت بُر زدن و راهنما در پایین، با برچسب قیمت
##  ● جِوییس: تکانِ صفحه، جرقه، پرواز سکه، صداهای نرم
## ============================================================================

const UI := preload("res://scripts/UIKit.gd")
const ArtL := preload("res://scripts/Art.gd")
const WheelScript := preload("res://scripts/LetterWheel.gd")
const IconBtn := preload("res://scripts/IconButton.gd")

const CELL := Vector2(88, 104)
const CELL_SEP := 8
const ROW_SEP := 26
const ROW_LIMIT := 10          # مجموع حروف هر ردیف تابلویی

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
var board_card: Control
var coin_label: Label
var preview: Label
var hint_label: Label
var progress_label: Label
var bonus_badge: Control
var bonus_label: Label
var _hint_btn: IconBtn
var _shuffle_btn: IconBtn
var _idle_tip: Label


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
	wheel.word_changed.connect(_on_word_changed)
	Game.coins_changed.connect(func(v):
		if is_instance_valid(coin_label):
			coin_label.text = Game.fa_num_grouped(v))
	Audio.start_music("level")
	_update_progress()


# ==================================================================== chrome
func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg_level.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(UI.vignette(0.30))

	# ---- هدر
	var back := UI.back_button(122)
	back.position = Vector2(24, 40)
	add_child(back)
	var back_hit := _hit(Vector2(122, 122), Vector2(24, 40), _on_back_pressed)
	add_child(back_hit)

	var plaque := UI.title_plaque("مرحلهٔ " + Game.fa_num(level_id), Vector2(470, 116), 44)
	plaque.position = Vector2(305, 42)
	add_child(plaque)

	var coin := UI.coin_pill(Vector2(240, 96), false)
	coin.position = Vector2(812, 52)
	add_child(coin)
	coin_label = coin.get_meta("value_label")
	coin_label.text = Game.fa_num_grouped(Game.coins)

	progress_label = UI.outlined_label("", 30, Color("#fff3d2"), Color("#4a2c10"), 7)
	progress_label.position = Vector2(300, 170)
	progress_label.size = Vector2(480, 48)
	add_child(progress_label)

	# ---- تابلو کلمات
	var board_tex := TextureRect.new()
	board_tex.texture = load("res://assets/art/board_panel.png")
	board_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_tex.stretch_mode = TextureRect.STRETCH_SCALE
	board_tex.position = Vector2(60, 212)
	board_tex.size = Vector2(960, 646)
	board_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_tex)
	board_card = board_tex
	board = Control.new()
	board.position = Vector2(92, 306)
	board.size = Vector2(896, 520)
	board.custom_minimum_size = board.size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	# ---- چرخ حروف
	var wheel_ctrl := Control.new()
	wheel_ctrl.set_script(WheelScript)
	wheel = wheel_ctrl as LetterWheel
	wheel.position = Vector2(170, 906)
	wheel.size = Vector2(740, 740)
	wheel.custom_minimum_size = wheel.size
	var tiles := Control.new()
	tiles.name = "Tiles"
	tiles.set_anchors_preset(Control.PRESET_FULL_RECT)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_ctrl.add_child(tiles)
	add_child(wheel_ctrl)
	_wheel_backdrop()

	# ---- پیش‌نمایش کلمه در مرکز چرخ (زنده و درشت)
	preview = UI.outlined_label("", 76, Color("#4a3117"), Color("#fdf1cf"), 9)
	preview.position = Vector2(280, 1218)
	preview.size = Vector2(520, 116)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)

	_idle_tip = UI.outlined_label("حرف‌ها را با کشیدن انگشت به هم وصل کن", 28,
		Color("#fff3d6"), Color("#4a2c10"), 7)
	_idle_tip.position = Vector2(230, 892)
	_idle_tip.size = Vector2(620, 52)
	_idle_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_idle_tip)

	# ---- نشان کلمهٔ جایزه‌ای
	bonus_badge = Control.new()
	var bsize := Vector2(360, 92)
	bonus_badge.custom_minimum_size = bsize
	bonus_badge.size = bsize
	bonus_badge.position = Vector2(360, 1000)
	var bt := ArtL.wooden_panel(bsize, 26, 8, Color("#ffcf5a"), Color("#d99a1f"))
	bonus_badge.add_child(bt)
	bonus_label = UI.label("", 40, Color("#4a3117"))
	bonus_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	bonus_badge.add_child(bonus_label)
	bonus_badge.visible = false
	bonus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bonus_badge.z_index = 20
	add_child(bonus_badge)

	# ---- بُر زدن (چپ) و راهنما (راست)
	_shuffle_btn = IconBtn.new()
	_shuffle_btn.icon_path = "res://assets/icons/shuffle.png"
	_shuffle_btn.caption = "بُر زدن"
	_shuffle_btn.icon_size = 118.0
	_shuffle_btn.float_phase = 0.2
	_shuffle_btn.position = Vector2(28, 1686)
	_shuffle_btn.pressed.connect(_on_shuffle)
	add_child(_shuffle_btn)

	_hint_btn = IconBtn.new()
	_hint_btn.icon_path = "res://assets/icons/hint.png"
	_hint_btn.caption = "راهنما"
	_hint_btn.icon_size = 118.0
	_hint_btn.float_phase = 0.7
	_hint_btn.position = Vector2(902, 1686)
	_hint_btn.pressed.connect(_on_hint_pressed)
	add_child(_hint_btn)

	hint_label = UI.outlined_label(Game.fa_num(Game.HINT_COST), 30,
		Color("#fff0cd"), Color("#4a2c10"), 6)
	hint_label.position = Vector2(884, 1642)
	hint_label.size = Vector2(150, 44)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)


func _wheel_backdrop() -> void:
	var glow := ArtL.glow_disc(900, Color(1.0, 0.93, 0.72))
	glow.position = Vector2(90, 826)
	glow.modulate.a = 0.40
	add_child(glow)
	var sh := ArtL.ground_shadow(670, 120, 0.32)
	sh.position = Vector2(245, 1584)
	add_child(sh)
	var disc := TextureRect.new()
	disc.texture = ArtL.wheel_texture(512)
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.stretch_mode = TextureRect.STRETCH_SCALE
	disc.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	disc.size = Vector2(816, 816)
	disc.position = Vector2(540, 1276) - disc.size * 0.5
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(disc)
	# چرخ باید روی زمینه بیفتد (وگرنه کاشی‌ها پوشیده می‌شوند)
	move_child(disc, wheel.get_index())


func _hit(size: Vector2, pos: Vector2, cb: Callable) -> Control:
	var hit := Control.new()
	hit.position = pos
	hit.size = size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			cb.call())
	return hit


# ------------------------------------------------------------------- board
func _build_board() -> void:
	for c in board.get_children():
		c.queue_free()
	_slots.clear()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", ROW_SEP)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.add_child(vb)

	var rows: Array = []
	var cur: Array = []
	var cur_cells := 0
	for w in answers:
		var cells: int = String(w).length()
		if cur_cells + cells > ROW_LIMIT and cur.size() > 0:
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
		hb.add_theme_constant_override("separation", 30)
		vb.add_child(hb)
		for w in row:
			hb.add_child(_make_word_slots(String(w)))


func _make_word_slots(word: String) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", CELL_SEP)
	var labels: Array = []
	for i in range(word.length() - 1, -1, -1):
		var cell := _make_cell(word[i])
		hb.add_child(cell)
		labels.insert(0, cell)
	_slots[word] = labels
	return hb


func _make_cell(letter: String) -> Control:
	var p := Control.new()
	p.custom_minimum_size = CELL
	p.size = CELL
	var bg := TextureRect.new()
	bg.name = "BG"
	bg.texture = ArtL.rounded_texture(80, 96, 18,
		Color("#efe3c4"), Color("#d8c8a0"), Color("#bfae86"), 3.0, 0.30, 0.16)
	bg.size = CELL
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bg)
	p.set_meta("letter", letter)
	p.set_meta("revealed", false)

	var lbl := Label.new()
	lbl.name = "L"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load(UI.FONT_BLACK))
	lbl.add_theme_font_size_override("font_size", 60)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.add_theme_color_override("font_color", Color("#6b4a12"))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	return p


func _cell_swap(cell: Control, top: Color, bottom: Color, edge: Color,
		text_color: Color, outline: Color, outline_size: int) -> void:
	var bg: TextureRect = cell.get_node("BG")
	bg.texture = ArtL.rounded_texture(80, 96, 18, top, bottom, edge, 3.0, 0.30, 0.14)
	var lbl: Label = cell.get_node("L")
	lbl.add_theme_color_override("font_color", text_color)
	lbl.add_theme_constant_override("outline_size", outline_size)
	lbl.add_theme_color_override("font_outline_color", outline)


func _reveal_word(word: String, animate: bool = true) -> void:
	var cells: Array = _slots.get(word, [])
	for i in cells.size():
		var cell: Control = cells[i]
		if bool(cell.get_meta("revealed")):
			continue
		cell.set_meta("revealed", true)
		var lbl: Label = cell.get_node("L")
		lbl.text = String(cell.get_meta("letter"))
		_cell_swap(cell, Color("#9ade71"), Color("#5fb63a"), Color("#3f8c1f"),
			Color.WHITE, Color("#2f7a1c"), 7)
		if animate:
			cell.pivot_offset = CELL * 0.5
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(i * 0.05)
			tw.tween_property(cell, "scale", Vector2.ONE, 0.30).from(Vector2(0.5, 0.5))


# ------------------------------------------------------------------ gameplay
func _on_word_changed(w: String) -> void:
	preview.text = w
	if _idle_tip:
		_idle_tip.visible = w.length() == 0


func _on_word(word: String) -> void:
	preview.text = ""
	_idle_tip.visible = true
	if _finished:
		return
	if answers.has(word):
		if found.has(word):
			Audio.play("already")
			wheel.flash(Color("#6fa8dc"))
			_pulse_word(word)
			_toast("«" + word + "» را قبلاً پیدا کرده‌ای")
			return
		found[word] = true
		Audio.play("word_ok")
		Audio.vibrate(25)
		wheel.flash(Color("#8fd66a"))
		wheel.celebrate(wheel.index_of_letters(word))
		_reveal_word(word)
		_word_burst(word)
		_shake_screen(5.0, 0.18)
		Game.register_word_found(false)
		_update_progress()
		_check_complete()
	elif word.length() >= 3 and Game.dictionary.has(word) and not bonus_found.has(word):
		bonus_found.append(word)
		Audio.play("word_bonus")
		Audio.vibrate(30)
		wheel.flash(Color("#f7b731"))
		Game.register_word_found(true)
		Game.add_coins(5)
		_show_bonus(word)
		wheel.celebrate(wheel.index_of_letters(word))
		_fly_coins(wheel.position + wheel.size * 0.5, 6)
	else:
		Audio.play("word_bad")
		Audio.vibrate(35)
		wheel.flash(Color("#e0665a"))
		_shake(preview)
		_shake_screen(7.0, 0.22)


func _update_progress() -> void:
	if progress_label:
		progress_label.text = "%s از %s کلمه پیدا شد" % [Game.fa_num(found.size()),
			Game.fa_num(answers.size())]


func _pulse_word(word: String) -> void:
	for cell in _slots.get(word, []):
		var tw := create_tween()
		tw.tween_property(cell, "modulate", Color(1.45, 1.45, 1.45), 0.12)
		tw.tween_property(cell, "modulate", Color.WHITE, 0.12)


func _show_bonus(word: String) -> void:
	bonus_label.text = word + "  +۵ سکه"
	bonus_badge.visible = true
	bonus_badge.modulate.a = 0.0
	bonus_badge.scale = Vector2(0.6, 0.6)
	bonus_badge.pivot_offset = bonus_badge.size * 0.5
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bonus_badge, "scale", Vector2.ONE, 0.3)
	tw.parallel().tween_property(bonus_badge, "modulate:a", 1.0, 0.16)
	tw.tween_interval(0.75)
	tw.tween_property(bonus_badge, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): bonus_badge.visible = false)


func _shake(node: Control) -> void:
	var base := node.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(node, "position:x", base.x + 12, 0.04)
		tw.tween_property(node, "position:x", base.x - 12, 0.04)
	tw.tween_property(node, "position", base, 0.04)


func _on_shuffle() -> void:
	if _finished:
		return
	wheel.shuffle_letters()


func _on_hint_pressed() -> void:
	if _finished:
		return
	if not Game.spend_coins(Game.HINT_COST):
		_toast("سکه کافی نداری! می‌توانی از فروشگاه بگیری")
		Audio.play("word_bad")
		_vibrate_warning()
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
				_cell_swap(cell, Color("#ffe08a"), Color("#efbe4a"), Color("#d9a02c"),
					Color("#6b4a12"), Color("#fdf1cf"), 6)
				cell.pivot_offset = CELL * 0.5
				var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(cell, "scale", Vector2.ONE, 0.3).from(Vector2(0.5, 0.5))
				wheel.highlight_letter(String(cell.get_meta("letter")))
				_check_word_auto_complete(String(w))
				return
	_toast("همهٔ حروف پیدا شده‌اند!")


func _vibrate_warning() -> void:
	Audio.vibrate(60)


func _check_word_auto_complete(word: String) -> void:
	for cell in _slots[word]:
		if not bool(cell.get_meta("revealed")):
			return
	if found.has(word):
		return
	found[word] = true
	Audio.play("word_ok")
	_update_progress()
	_check_complete()


func _on_back_pressed() -> void:
	Audio.play("tap")
	Transition.change_scene("res://scenes/MapScene.tscn")


func _toast(msg: String) -> void:
	var t := UI.make_toast(msg)
	add_child(t)
	t.position = Vector2(UI.SCREEN.x * 0.5 - t.size.x * 0.5, 760)


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
	await get_tree().create_timer(0.5).timeout
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


# ==================================================================== FX
var _shake_amount := 0.0
var _shake_time := 0.0


func _shake_screen(amount: float, time: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_time = maxf(_shake_time, time)
	set_process(true)


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var k: float = clampf(_shake_time / 0.2, 0.0, 1.0)
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* _shake_amount * k
		if _shake_time <= 0.0:
			position = Vector2.ZERO
			_shake_amount = 0.0


func _word_burst(word: String) -> void:
	var cells: Array = _slots.get(word, [])
	if cells.is_empty():
		return
	var mid: Control = cells[cells.size() / 2]
	var p := CPUParticles2D.new()
	p.position = mid.get_global_rect().get_center()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 20
	p.lifetime = 0.8
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 340.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(0.70, 0.96, 0.48)
	add_child(p)
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


func _fly_coins(from: Vector2, count: int) -> void:
	var target := Vector2(930, 100)
	for i in count:
		var c := TextureRect.new()
		c.texture = load("res://assets/icons/coin.png")
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.size = Vector2(58, 58)
		c.position = from + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		c.pivot_offset = Vector2(29, 29)
		c.z_index = 40
		add_child(c)
		var mid := c.position.lerp(target, 0.45) + Vector2(randf_range(-180, 180), -240)
		var tw := c.create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.035 * float(i))
		tw.tween_property(c, "position", mid, 0.32)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(c, "position", target, 0.38)
		tw.parallel().tween_property(c, "scale", Vector2(0.5, 0.5), 0.38)
		tw.tween_callback(func():
			Audio.play("coin", randf_range(0.94, 1.12))
			if is_instance_valid(c):
				c.queue_free())
