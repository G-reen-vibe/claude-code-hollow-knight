extends BossBase
## Hornet: fast duelist. Lunges, boomerang needle throws, diving strikes
## and a burst of gossamer threads.

var _needle: Polygon2D
var _t := 0.0


func _build_visual() -> void:
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-14, -18), Vector2(14, -18), Vector2(18, 26), Vector2(0, 20), Vector2(-18, 26)
	]), Color(0.55, 0.12, 0.15))
	Vfx.poly(visual, Vfx.circle(11.0, 16, 1.05), Color(0.93, 0.95, 0.97), Vector2(0, -26))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-4, -33), Vector2(-13, -50), Vector2(-8, -32)
	]), Color(0.93, 0.95, 0.97))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(4, -33), Vector2(13, -50), Vector2(8, -32)
	]), Color(0.93, 0.95, 0.97))
	Vfx.poly(visual, Vfx.circle(2.2, 8), Color(0.08, 0.08, 0.1), Vector2(-4, -26))
	Vfx.poly(visual, Vfx.circle(2.2, 8), Color(0.08, 0.08, 0.1), Vector2(4, -26))
	_needle = Vfx.poly(visual, PackedVector2Array([
		Vector2(0, -2), Vector2(34, -1), Vector2(40, 0), Vector2(34, 1), Vector2(0, 2)
	]), Color(0.8, 0.82, 0.88), Vector2(8, -6))


func _tick(delta: float) -> void:
	_t += delta
	if active and not dead:
		visual.position.y = sin(_t * 6.0) * 2.0


func _brain() -> void:
	while true:
		if not await alive_wait(randf_range(0.35, 0.7)):
			return
		_face(player.global_position.x - global_position.x)
		match randi() % 4:
			0:
				if not await _lunge():
					return
			1:
				if not await _needle_throw():
					return
			2:
				if not await _dive():
					return
			3:
				if not await _thread_burst():
					return


func _lunge() -> bool:
	_shiver(0.3)
	if not await alive_wait(0.32):
		return false
	Sfx.play("dash")
	spawn_melee(Vector2(30, -8), Vector2(70, 42), 0.3)
	var t := 0.0
	while t < 0.3:
		velocity.x = facing * 950.0
		if not await frame():
			return false
		t += get_physics_process_delta_time()
		if is_on_wall():
			break
	velocity.x = 0.0
	return true


func _needle_throw() -> bool:
	_shiver(0.25)
	if not await alive_wait(0.3):
		return false
	Sfx.play("cast")
	var dir := Vector2(facing, 0.0)
	_needle.visible = false
	spawn_projectile(global_position + dir * 30.0 + Vector2(0, -10), dir * 900.0,
		{"style": "shard", "radius": 12.0, "lifetime": 1.45, "die_on_wall": false,
		"color": Color(0.85, 0.87, 0.92), "accel": -dir * 1400.0})
	var ok := await alive_wait(1.5)
	_needle.visible = true
	return ok


func _dive() -> bool:
	velocity = Vector2(facing * 160.0, -820.0)
	Sfx.play("jump", -4.0)
	if not await alive_wait(0.42):
		return false
	velocity = Vector2.ZERO
	_face(player.global_position.x - global_position.x)
	if not await alive_wait(0.15):
		return false
	var dir := (player.global_position - global_position).normalized()
	if dir.y < 0.2:
		dir = Vector2(signf(dir.x) if dir.x != 0.0 else float(facing), 0.6).normalized()
	Sfx.play("dash")
	spawn_melee(Vector2(24, 4), Vector2(60, 50), 0.5)
	var t := 0.0
	while t < 0.6 and not is_on_floor():
		velocity = dir * 980.0
		if not await frame():
			return false
		t += get_physics_process_delta_time()
	velocity = Vector2.ZERO
	Game.shake(6.0)
	Sfx.play("land", -4.0)
	return true


func _thread_burst() -> bool:
	_shiver(0.4)
	if not await alive_wait(0.45):
		return false
	Sfx.play("cast")
	for i in 10:
		var a := TAU * i / 10.0
		spawn_projectile(global_position, Vector2.from_angle(a) * 260.0,
			{"style": "shard", "radius": 9.0, "lifetime": 0.85, "die_on_wall": true,
			"clashable": true, "color": Color(0.9, 0.9, 0.95)})
	return true
