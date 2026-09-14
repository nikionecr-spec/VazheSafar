extends Control
## Pulsing glow ring drawn behind the current level node.

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _ready() -> void:
	set_process(true)

func _draw() -> void:
	var c := size * 0.5
	var base := minf(size.x, size.y) * 0.5
	for i in 3:
		var ph: float = _t * 0.9 + float(i) * 0.66
		var k: float = fmod(ph, 1.0)
		var r: float = base * (1.0 + k * 0.85)
		var a: float = (1.0 - k) * 0.42
		draw_arc(c, r, 0.0, TAU, 48, Color(0.55, 1.0, 0.42, a), 6.0, true)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2)
	draw_circle(c, base * 1.12, Color(0.6, 1.0, 0.45, 0.10 + pulse * 0.10))
