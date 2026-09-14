extends Control
class_name LetterWheel
## Circular letter selector with swipe-to-connect input and a drawn trail.

signal word_submitted(word: String)
signal word_changed(word: String)

const TILE_RADIUS := 62.0
const HIT_RADIUS := 78.0

var letters: PackedStringArray = []
var _tiles: Array = []            # {letter, pos, node, selected}
var _selection: Array[int] = []
var _dragging := false
var _pointer := Vector2.ZERO
var _wheel_center := Vector2.ZERO
var _wheel_radius := 0.0
var _trail_color := Color("#f4a93c")
var _disabled := false

@onready var _tile_layer: Control = $Tiles


func _ready() -> void:
	resized.connect(_layout)
	_layout()


func set_letters(new_letters: Array) -> void:
	letters = PackedStringArray()
	for l in new_letters:
		letters.append(String(l))
	_rebuild()


func set_disabled(v: bool) -> void:
	_disabled = v
	if v:
		_clear_selection()


func _rebuild() -> void:
	for t in _tiles:
		if is_instance_valid(t["node"]):
			t["node"].queue_free()
	_tiles.clear()
	_selection.clear()
	for i in letters.size():
		var node := _make_tile(letters[i])
		_tile_layer.add_child(node)
		_tiles.append({"letter": letters[i], "pos": Vector2.ZERO,
			"node": node, "selected": false})
	_layout()


func _make_tile(letter: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(TILE_RADIUS * 2, TILE_RADIUS * 2)
	holder.size = holder.custom_minimum_size
	holder.pivot_offset = Vector2(TILE_RADIUS, TILE_RADIUS)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var disc := TextureRect.new()
	disc.name = "Disc"
	disc.texture = _tile_texture(false)
	disc.size = holder.size
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
	lbl.add_theme_font_size_override("font_size", 62)
	lbl.add_theme_color_override("font_color", Color("#5b3a1c"))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder


static func _tile_texture(selected: bool) -> Texture2D:
	var key := "sel" if selected else "idle"
	var size := int(TILE_RADIUS * 2)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(TILE_RADIUS, TILE_RADIUS)
	var base := Color("#f7b731") if selected else Color("#fdf3d8")
	var edge := Color("#c2801a") if selected else Color("#d9bd88")
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > TILE_RADIUS:
				continue
			var a := clampf((TILE_RADIUS - d) / 1.5, 0.0, 1.0)
			var col: Color
			if d > TILE_RADIUS - 5.0:
				col = edge
			else:
				# soft top-light gradient + inner shading
				var ny := float(y) / float(size)
				col = base.lerp(base.darkened(0.18), ny)
				col = col.lerp(Color.WHITE, clampf(0.22 * (1.0 - ny * 1.6), 0.0, 0.22))
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _layout() -> void:
	var s := size
	_wheel_center = s * 0.5
	_wheel_radius = minf(s.x, s.y) * 0.5 - TILE_RADIUS - 12.0
	var n := _tiles.size()
	for i in n:
		var ang := -PI / 2.0 + TAU * float(i) / float(maxi(n, 1))
		var p := _wheel_center + Vector2(cos(ang), sin(ang)) * _wheel_radius
		_tiles[i]["pos"] = p
		var node: Control = _tiles[i]["node"]
		node.position = p - Vector2(TILE_RADIUS, TILE_RADIUS)
	queue_redraw()


# ------------------------------------------------------------------- input
func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if pressed:
			_dragging = true
			_pointer = pos
			_try_select_at(pos)
		else:
			if _dragging:
				_dragging = false
				_submit()
		accept_event()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _dragging:
			_pointer = event.position
			_try_select_at(_pointer)
			queue_redraw()
			accept_event()


func _try_select_at(pos: Vector2) -> void:
	for i in _tiles.size():
		if pos.distance_to(_tiles[i]["pos"]) <= HIT_RADIUS:
			if _selection.has(i):
				# backtrack: dragging onto the previous tile removes the last one
				if _selection.size() >= 2 and _selection[_selection.size() - 2] == i:
					_deselect_last()
				return
			_select(i)
			return


func _select(i: int) -> void:
	_selection.append(i)
	_tiles[i]["selected"] = true
	var node: Control = _tiles[i]["node"]
	node.get_node("Disc").texture = _tile_texture(true)
	node.get_node("Label").add_theme_color_override("font_color", Color("#ffffff"))
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.16, 1.16), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12)
	Audio.play_letter(_selection.size() - 1)
	Audio.vibrate(12)
	word_changed.emit(current_word())
	queue_redraw()


func _deselect_last() -> void:
	if _selection.is_empty():
		return
	var i: int = _selection.pop_back()
	_tiles[i]["selected"] = false
	var node: Control = _tiles[i]["node"]
	node.get_node("Disc").texture = _tile_texture(false)
	node.get_node("Label").add_theme_color_override("font_color", Color("#5b3a1c"))
	word_changed.emit(current_word())
	queue_redraw()


func _clear_selection() -> void:
	while not _selection.is_empty():
		_deselect_last()
	_dragging = false
	queue_redraw()


func current_word() -> String:
	var w := ""
	for i in _selection:
		w += String(_tiles[i]["letter"])
	return w


func _submit() -> void:
	var w := current_word()
	_clear_selection()
	if w.length() >= 2:
		word_submitted.emit(w)


func flash(color: Color) -> void:
	_trail_color = color
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(func() -> void:
		_trail_color = Color("#f4a93c")
		queue_redraw())


func shuffle_letters() -> void:
	_clear_selection()
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
		nodes[i].get_node("Label").text = String(arr[i])
		nodes[i].scale = Vector2(0.4, 0.4)
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(nodes[i], "scale", Vector2.ONE, 0.3).set_delay(i * 0.03)
	Audio.play("shuffle")


func highlight_letter(letter: String) -> void:
	for t in _tiles:
		if String(t["letter"]) == letter:
			var node: Control = t["node"]
			var tw := create_tween().set_loops(3)
			tw.tween_property(node, "modulate", Color(1.4, 1.4, 0.8), 0.18)
			tw.tween_property(node, "modulate", Color.WHITE, 0.18)
			return


# -------------------------------------------------------------------- draw
func _draw() -> void:
	if _selection.is_empty():
		return
	var pts: PackedVector2Array = []
	for i in _selection:
		pts.append(_tiles[i]["pos"])
	if _dragging:
		pts.append(_pointer)
	if pts.size() >= 2:
		# glow underlay then the solid line
		draw_polyline(pts, Color(_trail_color.r, _trail_color.g, _trail_color.b, 0.28),
			26.0, true)
		draw_polyline(pts, _trail_color, 13.0, true)
	for i in _selection:
		draw_circle(_tiles[i]["pos"], 15.0, _trail_color)
