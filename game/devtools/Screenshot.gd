extends SceneTree
## Headless-ish screenshot harness: loads each scene, waits, saves a PNG.

const SHOTS := [
	["res://scenes/HomeScene.tscn", "home"],
	["res://scenes/ProfileScene.tscn", "profile"],
	["res://scenes/MapScene.tscn", "map"],
	["res://scenes/LevelScene.tscn", "level"],
	["res://scenes/ShopScene.tscn", "shop"],
	["res://scenes/QuestsScene.tscn", "quests"],
	["res://scenes/SettingsScene.tscn", "settings"],
	["res://scenes/ThemesScene.tscn", "themes"],
	["res://scenes/LibraryScene.tscn", "library"],
]

var out_dir := "user://shots"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	for entry in SHOTS:
		var path: String = entry[0]
		var name: String = entry[1]
		var packed: PackedScene = load(path)
		var inst: Node = packed.instantiate()
		root.add_child(inst)
		# let layout, tweens and textures settle
		for i in 25:
			await process_frame
		await create_timer(0.6).timeout
		for i in 5:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out_dir + "/" + name + ".png")
		print("saved ", name, " ", img.get_size())
		inst.queue_free()
		await process_frame
	quit()
