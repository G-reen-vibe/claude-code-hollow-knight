extends BossBase
## The Hollow Knight: the final vessel. Slash combos, lunging stabs,
## infected blob barf, and void eruptions past half health.

var _arm: Node2D


func _build_visual() -> void:
	# cloak/body
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-16, -30), Vector2(16, -30), Vector2(22, 44), Vector2(0, 36), Vector2(-22, 44)
	]), Color(0.08, 0.09, 0.12))
	# mask
	Vfx.poly(visual, Vfx.circle(14.0, 16, 1.1), Color(0.92, 0.94, 0.96), Vector2(0, -40))
	Vfx.poly(visual, Vfx.circle(3.0, 8), Color(0.05, 0.05, 0.08), Vector2(-5, -40))
	Vfx.poly(visual, Vfx.circle(3.0, 8), Color(0.05, 0.05, 0.08), Vector2(5, -40))
	# crack in the mask
	Vfx.poly(visual, PackedVector2Array([
		Vector2(2, -52), Vector2(5, -44), Vector2(2, -38), Vector2(4, -46)
	]), Color(0.6, 0.62, 0.66))
	# horns
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-6, -50), Vector2(-26, -78), Vector2(-10, -48)
	]), Color(0.92, 0.94, 0.96))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(6, -50), Vector2(26, -78), Vector2(10, -48)
	]), Color(0.92, 0.94, 0.96))
	# arm + long nail
	_arm = Node2D.new()
	_arm.position = Vector2(14, -14)
	visual.add_child(_arm)
	Vfx.poly(_arm, PackedVector2Array([
		Vector2(6, -3), Vector2(72, -1.5), Vector2(82, 0), Vector2(72, 1.5), Vector2(6, 3)
	]), Color(0.75, 0.78, 0.84))
	_arm.rotation = 0.5


func _brain() -> void:
	while true:
		if not await alive_wait(randf_range(0.4, 0.75)):
			return
		_face(player.global_position.x - global_position.x)
		var p2 := hp < int(max_hp * 0.55)
		var p3 := hp < int(max_hp * 0.28)
		var moves := 4 if p2 else 3
		match randi() % moves:
			0:
				if not await _combo(p3):
					return
			1:
				if not await _lunge(p3):
					return
			2:
				if not await _blobs():
					return
			3:
				if not await _void_pillars():
					return


func _swing(dur := 0.12) -> void:
	var tw := create_tween()
	tw.tween_property(_arm, "rotation", -1.6, dur * 0.4)
	tw.tween_property(_arm, "rotation", 0.9, dur * 0.6)
	tw.tween_property(_arm, "rotation", 0.5, 0.15)


func _combo(fast: bool) -> bool:
	var gap := 0.16 if fast else 0.24
	for i in 3:
		_face(player.global_position.x - global_position.x)
		velocity.x = facing * 320.0
		_swing(0.14)
		Sfx.play("slash")
		spawn_melee(Vector2(48, -10), Vector2(84, 78), 0.16)
		if not await alive_wait(gap):
			return false
		velocity.x = 0.0
		if not await alive_wait(0.08):
			return false
	return true


func _lunge(fast: bool) -> bool:
	_shiver(0.3)
	if not await alive_wait(0.22 if fast else 0.34):
		return false
	var reps := 2 if fast else 1
	for i in reps:
		_face(player.global_position.x - global_position.x)
		Sfx.play("dash")
		_swing(0.3)
		spawn_melee(Vector2(42, -8), Vector2(88, 52), 0.34)
		var t := 0.0
		while t < 0.34:
			velocity.x = facing * 1050.0
			if not await frame():
				return false
			t += get_physics_process_delta_time()
			if is_on_wall():
				Game.shake(6.0)
				break
		velocity.x = 0.0
		if i < reps - 1:
			if not await alive_wait(0.2):
				return false
	return true


func _blobs() -> bool:
	_shiver(0.35)
	if not await alive_wait(0.4):
		return false
	Sfx.play("cast")
	for i in 6:
		var vx := randf_range(-460.0, 460.0)
		spawn_projectile(global_position + Vector2(0, -46), Vector2(vx, randf_range(-680.0, -480.0)),
			{"style": "orb", "radius": 11.0, "lifetime": 3.0, "accel": Vector2(0, 1300),
			"color": Color(0.9, 0.45, 0.15), "clashable": true})
	return true


func _void_pillars() -> bool:
	# self-stab: void erupts from the ground near the player
	_shiver(0.5)
	if not await alive_wait(0.55):
		return false
	Game.shake(10.0)
	Sfx.play("hurt")
	for i in 5:
		var x := clampf(player.global_position.x + randf_range(-260.0, 260.0), 120.0, 1160.0)
		spawn_projectile(Vector2(x, 610.0), Vector2(0, -820.0),
			{"style": "wave", "radius": 15.0, "lifetime": 1.6, "accel": Vector2(0, 1500),
			"die_on_wall": false, "color": Color(0.16, 0.1, 0.26)})
		if not await alive_wait(0.12):
			return false
	return true
