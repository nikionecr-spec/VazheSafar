extends Control
## Simple vector padlock drawn for locked level nodes.

func _draw() -> void:
	var c := size * 0.5
	var col := Color(0.86, 0.86, 0.86, 0.95)
	var dark := Color(0.42, 0.42, 0.42, 0.9)
	var body := Rect2(c.x - 21, c.y - 4, 42, 32)
	# shackle
	draw_arc(Vector2(c.x, c.y - 6), 14.0, PI, TAU, 24, dark, 7.0, true)
	draw_arc(Vector2(c.x, c.y - 6), 14.0, PI, TAU, 24, col, 5.0, true)
	# body
	draw_rect(body.grow(2.0), dark, true)
	draw_rect(body, col, true)
	# keyhole
	draw_circle(Vector2(c.x, c.y + 9), 5.0, dark)
	draw_rect(Rect2(c.x - 2, c.y + 9, 4, 10), dark, true)
