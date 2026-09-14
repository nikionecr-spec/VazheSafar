extends Control
## Soft rotating god-rays overlay for a warm, alive background.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta * 0.08
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(size.x * 0.72, -120.0)
	var count := 9
	for i in count:
		var a := _t + TAU * float(i) / float(count)
		var w := 0.055 + 0.03 * sin(_t * 2.1 + float(i))
		var len := 2600.0
		var p1 := origin + Vector2(cos(a - w), sin(a - w)) * len
		var p2 := origin + Vector2(cos(a + w), sin(a + w)) * len
		var alpha := 0.035 + 0.022 * sin(_t * 1.7 + float(i) * 1.3)
		draw_colored_polygon(PackedVector2Array([origin, p1, p2]),
			Color(1.0, 0.96, 0.72, maxf(alpha, 0.0)))
