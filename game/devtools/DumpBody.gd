extends SceneTree
## debug helper: dumps the layout of a sub-scene body
var target := "res://scenes/SettingsScene.tscn"

func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		target = OS.get_cmdline_user_args()[0]
	_run.call_deferred()

func _run() -> void:
	var inst: Node = load(target).instantiate()
	root.add_child(inst)
	for i in 40:
		await process_frame
	await create_timer(1.2).timeout
	var body = inst.get("body")
	if body == null:
		print("no body on ", target)
		quit()
		return
	print("--- body children of ", target, " ---")
	for c in body.get_children():
		print("%-28s pos=%s size=%s a=%.2f vis=%s" % [c.get_class() + "#" + c.name,
			str(c.position), str(c.size), c.modulate.a, str(c.visible)])
	quit()
