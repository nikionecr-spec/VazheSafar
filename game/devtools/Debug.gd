extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var inst: Node = load("res://scenes/MapScene.tscn").instantiate()
	root.add_child(inst)
	for i in 20: await process_frame
	var pl = inst.path_layer
	print("path_layer pos=",pl.position," size=",pl.size," vis=",pl.visible," z=",pl.z_index)
	print("meta points count=", (pl.get_meta("points", PackedVector2Array())).size())
	print("content size=", inst.content.size, " scrollv=", inst.scroll.scroll_vertical)
	quit()
