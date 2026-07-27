extends BossBase
## Gruz Mother: a fat flying bruiser. Charges, slams and bounces around the arena.

var _t := 0.0
var _wing_l: Polygon2D
var _wing_r: Polygon2D
var _mode := "hover"


func _build_visual() -> void:
	_wing_l = Vfx.poly(visual, PackedVector2Array([
		Vector2(0, 0), Vector2(-46, -34), Vector2(-14, 6)
	]), Color(0.75, 0.78, 0.85, 0.7), Vector2(-16, -26))
	_wing_r = Vfx.poly(visual, PackedVector2Array([
		Vector2(0, 0), Vector2(46, -34), Vector2(14, 6)
	]), Color(0.75, 0.78, 0.85, 0.7), Vector2(16, -26))
	Vfx.poly(visual, Vfx.circle(46.0, 24, 0.78), Color(0.42, 0.4, 0.48))
	Vfx.poly(visual, Vfx.circle(30.0, 20, 0.7), Color(0.55, 0.52, 0.58), Vector2(4, 12))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(38, -18), Vector2(52, -32), Vector2(44, -12)
	]), Color(0.3, 0.28, 0.35))
	Vfx.poly(visual, Vfx.circle(5.0, 10), Color(0.1, 0.08, 0.12), Vector2(38, -8))
	Vfx.poly(visual, Vfx.circle(5.0, 10), Color(0.1, 0.08, 0.12), Vector2(38, 4))


func _tick(delta: float) -> void:
	_t += delta
	if _wing_l:
		_wing_l.rotation = sin(_t * 26.0) * 0.5
		_wing_r.rotation = -sin(_t * 26.0) * 0.5
	if active and _mode == "hover" and player:
		_face(player.global_position.x - global_position.x)


func _brain() -> void:
	while true:
		if not await alive_wait(0.2):
			return
		if not await _hover(randf_range(0.8, 1.4)):
			return
		match randi() % 3:
			0:
				if not await _charge():
					return
			1:
				if not await _slam():
					return
			2:
				if not await _bounce_frenzy():
					return


func _hover(dur: float) -> bool:
	_mode = "hover"
	var t := 0.0
	while t < dur:
		if not await frame():
			return false
		t += get_physics_process_delta_time()
		var target := player.global_position + Vector2(0, -190)
		var to := target - global_position
		var want := to.normalized() * clampf(to.length() * 2.2, 0.0, 260.0)
		velocity = velocity.move_toward(want, 18.0)
	return true


func _charge() -> bool:
	_mode = "attack"
	var n := 2 if hp > max_hp / 2 else 3
	for i in n:
		var dir := (player.global_position - global_position).normalized()
		_face(dir.x)
		velocity = Vector2.ZERO
		_shiver(0.45)
		if not await alive_wait(0.5):
			return false
		Sfx.play("dash")
		velocity = dir * 720.0
		var t := 0.0
		while t < 0.8:
			if not await frame():
				return false
			t += get_physics_process_delta_time()
			if is_on_wall() or is_on_floor() or is_on_ceiling():
				Game.shake(6.0)
				Sfx.play("land")
				break
		velocity = Vector2.ZERO
		if not await alive_wait(0.25):
			return false
	return true


func _slam() -> bool:
	_mode = "attack"
	var t := 0.0
	while t < 0.9:
		if not await frame():
			return false
		t += get_physics_process_delta_time()
		var to := Vector2(player.global_position.x, 160.0) - global_position
		velocity = to * 4.0
		if to.length() < 20.0:
			break
	velocity = Vector2.ZERO
	_shiver(0.35)
	if not await alive_wait(0.4):
		return false
	velocity = Vector2(0, 1000)
	if not await wait_until_landed(1.5):
		return false
	Game.shake(12.0)
	Sfx.play("land")
	for d in [-1.0, 1.0]:
		spawn_projectile(Vector2(global_position.x + 34.0 * d, 584.0), Vector2(430.0 * d, 0.0),
			{"style": "wave", "radius": 16.0, "lifetime": 2.5, "color": Color(0.8, 0.75, 0.6)})
	if not await alive_wait(0.35):
		return false
	velocity = Vector2(0, -450)
	if not await alive_wait(0.45):
		return false
	velocity = Vector2.ZERO
	return true


func _bounce_frenzy() -> bool:
	_mode = "attack"
	var sgn := 1.0 if randf() < 0.5 else -1.0
	var v := Vector2(randf_range(0.6, 1.0) * sgn, randf_range(-0.8, -0.3)).normalized() * 540.0
	var t := 0.0
	while t < 3.0:
		velocity = v
		if not await frame():
			return false
		t += get_physics_process_delta_time()
		var changed := false
		if is_on_wall():
			v.x = -v.x
			changed = true
		if is_on_floor():
			v.y = -absf(v.y)
			changed = true
		if is_on_ceiling():
			v.y = absf(v.y)
			changed = true
		if changed:
			Sfx.play("land", -4.0)
			Game.shake(3.0)
	velocity = Vector2.ZERO
	return true
