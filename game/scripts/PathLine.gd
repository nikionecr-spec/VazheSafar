extends Control
## Draws the stepping-stone trail connecting level nodes on the map.

func _draw() -> void:
	var pts: PackedVector2Array = get_meta("points", PackedVector2Array())
	if pts.size() < 2:
		return

	# Catmull-Rom style smoothing through the node centres
	var smooth: PackedVector2Array = []
	var n := pts.size()
	for i in range(n - 1):
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for s in 16:
			var t := float(s) / 16.0
			var t2 := t * t
			var t3 := t2 * t
			var pos := 0.5 * ((2.0 * p1) + (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			smooth.append(pos)
	smooth.append(pts[n - 1])

	# soft shadow, warm stone body, bright inner highlight
	draw_polyline(smooth, Color(0.35, 0.25, 0.12, 0.35), 46.0, true)
	draw_polyline(smooth, Color(0.99, 0.96, 0.88, 0.85), 38.0, true)
	draw_polyline(smooth, Color(1.0, 1.0, 0.96, 0.95), 24.0, true)

	# stepping stones along the trail
	for i in range(0, smooth.size(), 7):
		draw_circle(smooth[i], 9.0, Color(0.82, 0.73, 0.58, 0.75))
