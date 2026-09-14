extends Control
class_name LetterWheel
## Circular letter selector: swipe to connect, with a glowing animated trail,
## ripple feedback, tile pop and per-letter rising musical notes.

signal word_submitted(word: String)
signal word_changed(word: String)

const TILE_R := 78.0
const HIT_R := 98.0

var letters: PackedStringArray = []
var _tiles: Array = []
var _selection: Array[int] = []
var _dragging := false
var _pointer := Vector2.ZERO
var _center := Vector2.ZERO
var _radius := 0.0
var _trail := Color("#f7b24a")
var _disabled := false
var _pulse := 0.0
var _ripples: Array = []       # {pos, t}

static var _tex_idle: Texture2D
static var _tex_sel: Texture2D


func _ready() -> void:
	resized.connect(_layout)
	set_process(true)
	_layout()


func _process(delta: float) -> void:
	_pulse += delta
	var dirty := false
	for r in _ripples:
		r["t"] += delta
		dirty = true
	_ripples = _ripples.filter(func(r): return r["t"] < 0.55)
	if dirty or not _selection.is_empty():
		queue_redraw()


func set_letters(new_letters: Array) -> void:
	letters = PackedStringArray()
	for l in new_letters:
		letters.append(String(l))
	_rebuild()


func set_disabled(v: bool) -> void:
	_disabled = v
	if v:
		_clear()


func _rebuild() -> void:
	for t in _tiles:
		if is_instance_valid(t["node"]):
			t["node"].queue_free()
	_tiles.clear()
	_selection.clear()
	for i in letters.size():
		var node := _make_tile(letters[i])
		$Tiles.add_child(node)
		_tiles.append({"letter": letters[i], "pos": Vector2.ZERO,
			"node": node, "selected": false})
	_layout()
	# entrance: tiles fly in from the centre
	for i in _tiles.size():
		var n: Control = _tiles[i]["node"]
		n.scale = Vector2(0.2, 0.2)
		n.modulate.a = 0.0
		var tw := n.create_tween().set_parallel()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector2.ONE, 0.45).set_delay(0.05 * i)
		tw.tween_property(n, "modulate:a", 1.0, 0.3).set_delay(0.05 * i)


func _make_tile(letter: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(TILE_R * 2, TILE_R * 2)
	holder.size = holder.custom_minimum_size
	holder.pivot_offset = Vector2(TILE_R, TILE_R)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var disc := TextureRect.new()
	disc.name = "Disc"
	disc.texture = _tile_tex(false)
	disc.size = holder.size
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = letter
	lbl.size = holder.size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font",
		load("res://assets/fonts/Vazirmatn-Black.ttf"))
	lbl.add_theme_font_size_override("font_size", 80)
	lbl.add_theme_color_override("font_color", Color("#5b3a1c"))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder


static func _tile_tex(selected: bool) -> Texture2D:
	if selected and _tex_sel:
		return _tex_sel
	if not selected and _tex_idle:
		return _tex_idle
	var size := int(TILE_R * 2)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(TILE_R, TILE_R)
	var base := Color("#f9b93a") if selected else Color("#fdf4dc")
	var edge := Color("#b9761a") if selected else Color("#cbb082")
	for y in size:
		for x in size:
			var pp := Vector2(x + 0.5, y + 0.5)
			var d := pp.distance_to(c)
			if d > TILE_R:
				continue
			var a := clampf((TILE_R - d) / 1.6, 0.0, 1.0)
			var col: Color
			if d > TILE_R - 6.0:
				col = edge
			else:
				var ny := float(y) / float(size)
				col = base.lerp(base.darkened(0.22), ny)
				# specular blob upper-left
				var sd := pp.distance_to(c + Vector2(-TILE_R * 0.3, -TILE_R * 0.34))
				var spec := clampf(1.0 - sd / (TILE_R * 0.62), 0.0, 1.0)
				col = col.lerp(Color.WHITE, spec * 0.42)
				# bottom inner shade for roundness
				var bd := pp.distance_to(c + Vector2(0, TILE_R * 0.55))
				var sh := clampf(1.0 - bd / (TILE_R * 0.8), 0.0, 1.0)
				col = col.lerp(edge, sh * 0.22)
			col.a = a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	if selected:
		_tex_sel = tex
	else:
		_tex_idle = tex
	return tex


func _layout() -> void:
	_center = size * 0.5
	_radius = minf(size.x, size.y) * 0.5 - TILE_R - 2.0
	var n := _tiles.size()
	for i in n:
		var ang := -PI / 2.0 + TAU * float(i) / float(maxi(n, 1))
		var p := _center + Vector2(cos(ang), sin(ang)) * _radius
		_tiles[i]["pos"] = p
		var node: Control = _tiles[i]["node"]
		node.position = p - Vector2(TILE_R, TILE_R)
	queue_redraw()


# ------------------------------------------------------------------ input
func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_dragging = true
			_pointer = event.position
			_try_select(event.position)
		elif _dragging:
			_dragging = false
			_submit()
		accept_event()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _dragging:
			_pointer = event.position
			_try_select(_pointer)
			queue_redraw()
			accept_event()


func _try_select(pos: Vector2) -> void:
	for i in _tiles.size():
		if pos.distance_to(_tiles[i]["pos"]) <= HIT_R:
			if _selection.has(i):
				if _selection.size() >= 2 and _selection[_selection.size() - 2] == i:
					_deselect_last()
				return
			_select(i)
			return


func _select(i: int) -> void:
	_selection.append(i)
	_tiles[i]["selected"] = true
	var node: Control = _tiles[i]["node"]
	node.get_node("Disc").texture = _tile_tex(true)
	node.get_node("Label").add_theme_color_override("font_color", Color.WHITE)
	node.get_node("Label").add_theme_constant_override("outline_size", 6)
	node.get_node("Label").add_theme_color_override("font_outline_color",
		Color("#9a5d12"))
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(1.22, 1.22), 0.1)
	tw.tween_property(node, "scale", Vector2(1.08, 1.08), 0.16)
	_ripples.append({"pos": _tiles[i]["pos"], "t": 0.0})
	Audio.play_letter(_selection.size() - 1)
	Audio.vibrate(11)
	word_changed.emit(current_word())
	queue_redraw()


func _deselect_last() -> void:
	if _selection.is_empty():
		return
	var i: int = _selection.pop_back()
	_tiles[i]["selected"] = false
	var node: Control = _tiles[i]["node"]
	node.get_node("Disc").texture = _tile_tex(false)
	var lbl: Label = node.get_node("Label")
	lbl.add_theme_color_override("font_color", Color("#5b3a1c"))
	lbl.add_theme_constant_override("outline_size", 0)
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "scale", Vector2.ONE, 0.14)
	Audio.play("swipe")
	word_changed.emit(current_word())
	queue_redraw()


func _clear() -> void:
	while not _selection.is_empty():
		var i: int = _selection.pop_back()
		_tiles[i]["selected"] = false
		var node: Control = _tiles[i]["node"]
		node.get_node("Disc").texture = _tile_tex(false)
		var lbl: Label = node.get_node("Label")
		lbl.add_theme_color_override("font_color", Color("#5b3a1c"))
		lbl.add_theme_constant_override("outline_size", 0)
		var tw := node.create_tween()
		tw.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(node, "scale", Vector2.ONE, 0.14)
	_dragging = false
	word_changed.emit("")
	queue_redraw()


func current_word() -> String:
	var w := ""
	for i in _selection:
		w += String(_tiles[i]["letter"])
	return w


func _submit() -> void:
	var w := current_word()
	_clear()
	if w.length() >= 2:
		word_submitted.emit(w)


func flash(color: Color) -> void:
	_trail = color
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_callback(func():
		_trail = Color("#f7b24a")
		queue_redraw())


## Green success pulse travelling along the tiles that formed the word.
func celebrate(indices: Array) -> void:
	for k in indices.size():
		var idx: int = indices[k]
		if idx < 0 or idx >= _tiles.size():
			continue
		var node: Control = _tiles[idx]["node"]
		var tw := node.create_tween()
		tw.tween_interval(0.04 * k)
		tw.tween_property(node, "modulate", Color(1.5, 2.0, 1.3), 0.1)
		tw.tween_property(node, "modulate", Color.WHITE, 0.25)


func shuffle_letters() -> void:
	_clear()
	var arr: Array = []
	for l in letters:
		arr.append(l)
	arr.shuffle()
	var nodes: Array = []
	for t in _tiles:
		nodes.append(t["node"])
	letters = PackedStringArray()
	for i in arr.size():
		letters.append(String(arr[i]))
		_tiles[i]["letter"] = String(arr[i])
		var n: Control = nodes[i]
		var tw := n.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(n, "scale", Vector2(0.1, 0.1), 0.16).set_delay(i * 0.025)
		tw.tween_callback(func():
			n.get_node("Label").text = String(arr[i]))
		tw.tween_property(n, "scale", Vector2.ONE, 0.34)
	Audio.play("shuffle")
	Audio.vibrate(20)


func highlight_letter(letter: String) -> void:
	for t in _tiles:
		if String(t["letter"]) == letter:
			var node: Control = t["node"]
			var tw := node.create_tween().set_loops(3)
			tw.tween_property(node, "modulate", Color(1.6, 1.5, 0.7), 0.16)
			tw.tween_property(node, "modulate", Color.WHITE, 0.16)
			return


func index_of_letters(word: String) -> Array:
	var used := {}
	var out: Array = []
	for ch in word:
		for i in _tiles.size():
			if used.has(i):
				continue
			if String(_tiles[i]["letter"]) == ch:
				used[i] = true
				out.append(i)
				break
	return out


# -------------------------------------------------------------------- draw
func _draw() -> void:
	# selection ripples
	for r in _ripples:
		var k: float = float(r["t"]) / 0.55
		var rad: float = lerpf(TILE_R * 0.7, TILE_R * 1.9, k)
		var a: float = (1.0 - k) * 0.4
		draw_arc(r["pos"], rad, 0.0, TAU, 32,
			Color(_trail.r, _trail.g, _trail.b, a), 5.0, true)

	if _selection.is_empty():
		return

	var pts: PackedVector2Array = []
	for i in _selection:
		pts.append(_tiles[i]["pos"])
	if _dragging:
		pts.append(_pointer)

	if pts.size() >= 2:
		var glow := 0.22 + 0.10 * sin(_pulse * 7.0)
		draw_polyline(pts, Color(_trail.r, _trail.g, _trail.b, glow), 40.0, true)
		draw_polyline(pts, Color(_trail.r, _trail.g, _trail.b, 0.42), 26.0, true)
		draw_polyline(pts, _trail, 15.0, true)
		draw_polyline(pts, Color(1, 1, 1, 0.55), 6.0, true)

	for i in _selection:
		var p: Vector2 = _tiles[i]["pos"]
		draw_circle(p, 19.0, Color(_trail.r, _trail.g, _trail.b, 0.45))
		draw_circle(p, 12.0, _trail)
		draw_circle(p, 5.0, Color(1, 1, 1, 0.8))

	# leading dot follows the finger
	if _dragging:
		var d := 13.0 + 2.5 * sin(_pulse * 9.0)
		draw_circle(_pointer, d, Color(1, 1, 1, 0.55))
		draw_circle(_pointer, d * 0.55, _trail)
