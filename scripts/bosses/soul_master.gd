extends BossBase
## Soul Master: floating sorcerer. Teleports, fires homing soul orbs
## and dive-slams the arena floor. Grows frantic below 45% health.

var _t := 0.0


func _build_visual() -> void:
	Vfx.poly(visual, Vfx.circle(34.0, 20, 1.15), Color(0.35, 0.2, 0.5), Vector2(0, 6))
	Vfx.poly(visual, Vfx.circle(40.0, 20, 0.5), Color(0.28, 0.15, 0.42), Vector2(0, 32))
	Vfx.poly(visual, Vfx.circle(15.0, 16, 1.05), Color(0.93, 0.94, 0.97), Vector2(0, -26))
	Vfx.poly(visual, Vfx.circle(3.0, 8), Color(0.1, 0.08, 0.14), Vector2(-6, -26))
	Vfx.poly(visual, Vfx.circle(3.0, 8), Color(0.1, 0.08, 0.14), Vector2(6, -26))
	# crown
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-14, -36), Vector2(-6, -54), Vector2(-2, -37)
	]), Color(0.85, 0.75, 0.4))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-2, -37), Vector2(4, -58), Vector2(8, -37)
	]), Color(0.85, 0.75, 0.4))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(8, -37), Vector2(16, -52), Vector2(18, -36)
	]), Color(0.85, 0.75, 0.4))


func _tick(delta: float) -> void:
	_t += delta
	if active and not dead:
		visual.position.y = sin(_t * 3.0) * 5.0
		if player:
			_face(player.global_position.x - global_position.x)


func _brain() -> void:
	while true:
		if not await alive_wait(randf_range(0.5, 0.8)):
			return
		var phase2 := hp < int(max_hp * 0.45)
		match randi() % 3:
			0:
				if not await _teleport_random():
					return
			1:
				if not await _orbs(4 if phase2 else 2):
					return
			2:
				if not await _dive_slam():
					return


func _fade_teleport(to: Vector2) -> bool:
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.18)
	if not await alive_wait(0.2):
		return false
	global_position = to
	velocity = Vector2.ZERO
	var tw2 := create_tween()
	tw2.tween_property(visual, "modulate:a", 1.0, 0.15)
	Sfx.play("cast", -4.0)
	if not await alive_wait(0.18):
		return false
	return true


func _teleport_random() -> bool:
	var x := randf_range(220.0, 1060.0)
	var y := randf_range(180.0, 340.0)
	return await _fade_teleport(Vector2(x, y))


func _orbs(n: int) -> bool:
	for i in n:
		_shiver(0.15)
		if not await alive_wait(0.3):
			return false
		spawn_projectile(global_position + Vector2(0, -20),
			(player.global_position - global_position).normalized() * 340.0,
			{"style": "orb", "radius": 12.0, "lifetime": 3.2, "die_on_wall": true,
			"clashable": true, "homing": player, "turn_speed": 2.4, "speed": 340.0,
			"color": Color(0.55, 0.75, 1.0)})
		Sfx.play("cast")
	return true


func _dive_slam() -> bool:
	if not await _fade_teleport(Vector2(clampf(player.global_position.x, 180.0, 1100.0), 150.0)):
		return false
	_shiver(0.3)
	if not await alive_wait(0.32):
		return false
	velocity = Vector2(0, 1150)
	if not await wait_until_landed(1.2):
		return false
	velocity = Vector2.ZERO
	Game.shake(12.0)
	Sfx.play("land")
	for d in [-1.0, 1.0]:
		spawn_projectile(Vector2(global_position.x + 34.0 * d, 584.0), Vector2(470.0 * d, 0.0),
			{"style": "wave", "radius": 16.0, "lifetime": 2.2, "color": Color(0.55, 0.75, 1.0)})
	if not await alive_wait(0.5):
		return false
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector2(global_position.x, 260.0), 0.5)
	if not await alive_wait(0.55):
		return false
	return true
