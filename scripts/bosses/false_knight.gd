extends BossBase
## False Knight: armored heavyweight. Leaps, mace slams with shockwaves,
## and hop barrages. Enrages below 40% health.

var _arm: Node2D


func _build_visual() -> void:
	# armored bulk
	Vfx.poly(visual, Vfx.circle(44.0, 20, 1.1), Color(0.35, 0.37, 0.42), Vector2(0, -6))
	Vfx.poly(visual, Vfx.circle(34.0, 20, 0.8), Color(0.28, 0.30, 0.35), Vector2(0, 30))
	# maggot head peeking out of the helmet
	Vfx.poly(visual, Vfx.circle(10.0, 14), Color(0.92, 0.94, 0.96), Vector2(6, -50))
	Vfx.poly(visual, Vfx.circle(2.5, 8), Color(0.1, 0.1, 0.12), Vector2(9, -51))
	# pauldron
	Vfx.poly(visual, Vfx.circle(18.0, 14, 0.9), Color(0.45, 0.47, 0.52), Vector2(24, -30))
	# arm + mace
	_arm = Node2D.new()
	_arm.position = Vector2(28, -26)
	visual.add_child(_arm)
	Vfx.poly(_arm, PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(5, 52), Vector2(-5, 52)
	]), Color(0.4, 0.42, 0.47))
	Vfx.poly(_arm, Vfx.circle(20.0, 12), Color(0.5, 0.35, 0.2), Vector2(0, 66))
	Vfx.poly(_arm, Vfx.circle(13.0, 10), Color(0.62, 0.45, 0.25), Vector2(0, 66))
	_arm.rotation = -0.9


func _brain() -> void:
	while true:
		if not await alive_wait(randf_range(0.5, 0.9)):
			return
		_face(player.global_position.x - global_position.x)
		var enraged := hp < int(max_hp * 0.4)
		match randi() % 3:
			0:
				if not await _leap():
					return
			1:
				if not await _mace_slam(enraged):
					return
			2:
				if not await _hop_barrage(enraged):
					return


func _leap() -> bool:
	var dx := player.global_position.x - global_position.x
	velocity = Vector2(clampf(dx * 1.6, -520.0, 520.0), -760.0)
	Sfx.play("jump", -3.0)
	if not await wait_until_landed():
		return false
	velocity.x = 0.0
	Game.shake(8.0)
	Sfx.play("land")
	spawn_melee(Vector2(0, 30), Vector2(130, 44), 0.15)
	return true


func _mace_slam(enraged: bool) -> bool:
	_face(player.global_position.x - global_position.x)
	var raise := create_tween()
	raise.tween_property(_arm, "rotation", -2.6, 0.3 if enraged else 0.45)
	if not await alive_wait(0.38 if enraged else 0.55):
		return false
	var slam := create_tween()
	slam.tween_property(_arm, "rotation", 0.9, 0.08)
	if not await alive_wait(0.09):
		return false
	Game.shake(10.0)
	Sfx.play("hit")
	spawn_melee(Vector2(56, 6), Vector2(96, 96), 0.18)
	spawn_projectile(Vector2(global_position.x + facing * 60.0, 584.0), Vector2(facing * 520.0, 0.0),
		{"style": "wave", "radius": 16.0, "lifetime": 2.0, "color": Color(0.9, 0.7, 0.4)})
	if enraged:
		spawn_projectile(Vector2(global_position.x - facing * 60.0, 584.0), Vector2(-facing * 520.0, 0.0),
			{"style": "wave", "radius": 16.0, "lifetime": 2.0, "color": Color(0.9, 0.7, 0.4)})
	if not await alive_wait(0.5):
		return false
	var back := create_tween()
	back.tween_property(_arm, "rotation", -0.9, 0.3)
	return true


func _hop_barrage(enraged: bool) -> bool:
	var n := 4 if enraged else 3
	for i in n:
		var dx := player.global_position.x - global_position.x
		_face(dx)
		velocity = Vector2(clampf(dx * 2.0, -420.0, 420.0), -560.0)
		Sfx.play("jump", -6.0)
		if not await wait_until_landed():
			return false
		velocity.x = 0.0
		Game.shake(6.0)
		Sfx.play("land")
		var dirs: Array = [-1.0, 1.0] if enraged else [signf(dx) if dx != 0.0 else 1.0]
		for d in dirs:
			spawn_projectile(Vector2(global_position.x + 44.0 * d, 584.0), Vector2(400.0 * d, 0.0),
				{"style": "wave", "radius": 14.0, "lifetime": 1.6, "color": Color(0.9, 0.7, 0.4)})
		if not await alive_wait(0.22):
			return false
	return true
