class_name Vfx
## Small helpers for building vector-style visuals and particle bursts in code.


static func circle(radius: float, segments := 20, squash := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * squash))
	return pts


static func poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p


static func burst(host: Node2D, local_pos: Vector2, color: Color, amount := 24, speed := 300.0) -> void:
	var parent := host.get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = color
	p.position = host.global_position + local_pos
	p.finished.connect(p.queue_free)
	parent.add_child(p)
