extends Node2D
## Static painted backdrop for the arena: ruined pillars of Hallownest.


func _draw() -> void:
	# sky gradient
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)
	])
	var cols := PackedColorArray([
		Color(0.055, 0.075, 0.13), Color(0.055, 0.075, 0.13),
		Color(0.02, 0.028, 0.05), Color(0.02, 0.028, 0.05)
	])
	draw_polygon(pts, cols)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# distant ruined pillars
	for i in 9:
		var x := 40.0 + i * 140.0 + rng.randf_range(-30.0, 30.0)
		var w := rng.randf_range(26.0, 70.0)
		var h := rng.randf_range(180.0, 420.0)
		draw_rect(Rect2(x, 600.0 - h, w, h), Color(0.075, 0.095, 0.155, 0.8))
		draw_rect(Rect2(x - 6.0, 600.0 - h - 14.0, w + 12.0, 14.0), Color(0.09, 0.11, 0.18, 0.8))

	# hanging vines / chains
	for i in 14:
		var x := rng.randf_range(60.0, 1220.0)
		var l := rng.randf_range(40.0, 160.0)
		draw_line(Vector2(x, 40.0), Vector2(x, 40.0 + l), Color(0.08, 0.1, 0.16), 3.0)

	# floating dust motes
	for i in 30:
		var p := Vector2(rng.randf_range(80.0, 1200.0), rng.randf_range(80.0, 580.0))
		draw_circle(p, rng.randf_range(1.0, 2.5), Color(0.5, 0.6, 0.75, rng.randf_range(0.04, 0.12)))

	# floor
	draw_rect(Rect2(0, 600, 1280, 120), Color(0.09, 0.1, 0.16))
	draw_rect(Rect2(0, 600, 1280, 6), Color(0.16, 0.19, 0.28))

	# walls
	draw_rect(Rect2(0, 0, 80, 720), Color(0.08, 0.09, 0.15))
	draw_rect(Rect2(1200, 0, 80, 720), Color(0.08, 0.09, 0.15))
	draw_rect(Rect2(74, 0, 6, 720), Color(0.14, 0.16, 0.24))
	draw_rect(Rect2(1200, 0, 6, 720), Color(0.14, 0.16, 0.24))
