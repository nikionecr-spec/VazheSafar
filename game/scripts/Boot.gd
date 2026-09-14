extends Control
## Splash screen: shows the logo, warms up the audio cache, then enters Home.

func _ready() -> void:
	var logo: TextureRect = $Center/Logo
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2(0.75, 0.75)
	logo.modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.6)
	tw.parallel().tween_property(logo, "modulate:a", 1.0, 0.45)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		Transition.change_scene("res://scenes/HomeScene.tscn"))
