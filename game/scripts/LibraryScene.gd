extends SubScene
## ============================================================================
##  کتابخانهٔ واژه‌ها — جستجو + دسته‌بندی مرحله‌به‌مرحله با چیپ‌های رنگی
##  (قفل‌شکنِ جمع‌آوری: هرچه بیشتر بازی کنی، قفسه پُرتر می‌شود)
## ============================================================================


var _search := ""
var _search_box: LineEdit


func _init() -> void:
	screen_title = "کتابخانه"
	section = "library"
	nav_key = "library"


func build_body() -> void:
	var found_levels: Array = []
	var total_main := 0
	var total_bonus := 0
	for i in range(1, Game.total_levels() + 1):
		if Game.stars_for(i) > 0:
			found_levels.append(i)
			total_main += Game.get_level(i).get("words", []).size()
			total_bonus += (Game.found_bonus.get(str(i), []) as Array).size()

	# ---------------- نوار جستجو + آمار
	var head := card(168, 30, Color("#fdf6e6"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	UI.card_add(head, col, 24.0)
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "جستجوی واژه…"
	_search_box.text = _search
	_search_box.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_search_box.add_theme_font_override("font", load(UI.FONT_BOLD))
	_search_box.add_theme_font_size_override("font_size", 34)
	_search_box.add_theme_color_override("font_color", UI.TEXT_DARK)
	_search_box.add_theme_color_override("font_placeholder_color", UI.INK_SOFT)
	_search_box.custom_minimum_size = Vector2(0, 76)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fffdf7")
	sb.set_corner_radius_all(22)
	sb.border_color = Color("#dcc79a")
	sb.set_border_width_all(3)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	_search_box.add_theme_stylebox_override("normal", sb)
	_search_box.add_theme_stylebox_override("focus", sb)
	_search_box.text_changed.connect(func(t: String) -> void:
		_search = t
		rebuild())
	col.add_child(_search_box)
	col.add_child(UI.right_label("کشف‌شده: %s واژهٔ جدول  •  %s واژهٔ جایزه‌ای  •  از %s مرحله"
		% [Game.fa_num(total_main), Game.fa_num(total_bonus), Game.fa_num(found_levels.size())],
		26, UI.INK_SOFT))

	if found_levels.is_empty():
		var empty := card(320, 30, Color("#fdf6e6"))
		var ecol := VBoxContainer.new()
		ecol.alignment = BoxContainer.ALIGNMENT_CENTER
		ecol.add_theme_constant_override("separation", 14)
		UI.card_add(empty, ecol, 30.0)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/icons/book.png")
		ic.custom_minimum_size = Vector2(150, 150)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ecol.add_child(ic)
		ecol.add_child(UI.label("هنوز قفسه‌ات خالی است!", 38, UI.TEXT_DARK))
		ecol.add_child(UI.label("اولین مرحله را تمام کن تا واژه‌ها اینجا جمع شوند.",
			28, UI.INK_SOFT))
		return

	var shown := 0
	for lvl in found_levels:
		var data := Game.get_level(lvl)
		var main_words: Array = data.get("words", [])
		var bonus_words: Array = Game.found_bonus.get(str(lvl), [])
		var matched: Array = []
		for w in main_words:
			if _matches(String(w)):
				matched.append([String(w), false])
		for w in bonus_words:
			if _matches(String(w)):
				matched.append([String(w), true])
		if _search != "" and matched.is_empty():
			continue
		shown += 1

		var c := card(0, 30, Color("#fdf6e6"))
		var col2 := VBoxContainer.new()
		col2.add_theme_constant_override("separation", 14)
		UI.card_add(c, col2, 26.0)

		var headrow := HBoxContainer.new()
		headrow.add_theme_constant_override("separation", 12)
		var lvl_l := UI.label("مرحلهٔ " + Game.fa_num(lvl), 40, UI.TEXT_DARK)
		lvl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lvl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		headrow.add_child(lvl_l)
		headrow.add_child(UI.star_row(Game.stars_for(lvl), 40))
		col2.add_child(headrow)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		for m in matched:
			flow.add_child(_chip(String(m[0]), bool(m[1])))
		col2.add_child(flow)

	if shown == 0:
		var none := card(180, 30, Color("#fdf6e6"))
		var nl := VBoxContainer.new()
		nl.alignment = BoxContainer.ALIGNMENT_CENTER
		UI.card_add(none, nl, 24.0)
		nl.add_child(UI.label("واژه‌ای با «" + _search + "» پیدا نشد.", 34, UI.TEXT_DARK))
		nl.add_child(UI.label("املای دیگری را امتحان کن.", 26, UI.INK_SOFT))


func _matches(word: String) -> bool:
	if _search.strip_edges() == "":
		return true
	return word.contains(_search.strip_edges())


## چیپِ واژه با رنگ و قاب گرافیکی (سبز = جدول، طلایی = جایزه‌ای)
func _chip(word: String, bonus: bool) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := UI.label(word, 34, Color("#1f4a12") if not bonus else Color("#6b4308"))
	var pad_x := 34.0
	var size := Vector2(ArtL.text_width(word, 34) + pad_x * 2.0, 74)
	holder.custom_minimum_size = size
	holder.size = size
	var tex := TextureRect.new()
	tex.texture = ArtL.rounded_texture(int(size.x * 0.5), 40, 20,
		Color("#dff5cd") if not bonus else Color("#ffeaa8"),
		Color("#bfe6a5") if not bonus else Color("#f6cf6a"),
		Color("#8dc46a") if not bonus else Color("#d9a93c"), 2.0, 0.28, 0.10)
	tex.size = size
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tex)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	return holder
