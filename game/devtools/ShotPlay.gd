extends SceneTree
var G: Node
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	G = root.get_node("/root/Game")
	G.reset_progress()
	DirAccess.make_dir_recursive_absolute("user://shots")
	G.set_meta("goto_level", 3)
	var s: Node = load("res://scenes/LevelScene.tscn").instantiate()
	root.add_child(s)
	for i in 15: await process_frame
	# solve two words, then mid-drag on a third
	var ws: Array = s.answers
	s._on_word(String(ws[0]))
	for i in 10: await process_frame
	s._on_word(String(ws[1]))
	for i in 20: await process_frame
	# simulate an in-progress swipe on the wheel
	var wh = s.wheel
	wh._dragging = true
	var third := String(ws[2])
	for ch in third.substr(0, max(2, third.length()-1)):
		for i in wh._tiles.size():
			if String(wh._tiles[i]["letter"]) == ch and not wh._selection.has(i):
				wh._select(i); break
	if wh._selection.size() > 0:
		wh._pointer = wh._tiles[wh._selection[wh._selection.size()-1]]["pos"] + Vector2(40, 60)
	wh.queue_redraw()
	s.preview.text = wh.current_word()
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://shots/play.png")
	print("saved play")
	# win popup shot
	for w in ws: s._on_word(String(w))
	await create_timer(1.8).timeout
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://shots/win.png")
	print("saved win")
	quit()
