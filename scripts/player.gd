extends CharacterBody2D
class_name Player
## The Knight: run, jump, double jump, dash, 4-way nail with pogo,
## soul gain, Focus healing and Vengeful Spirit casting.

signal health_changed(hp: int, max_hp: int)
signal soul_changed(soul: int)
signal died

const FireballScene := preload("res://scenes/fireball.tscn")

const SPEED := 340.0
const ACCEL := 3600.0
const AIR_ACCEL := 2400.0
const JUMP_VELOCITY := -640.0
const GRAVITY := 1850.0
const MAX_FALL := 980.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const AIR_JUMPS := 1
const DASH_SPEED := 800.0
const DASH_TIME := 0.2
const DASH_COOLDOWN := 0.45
const NAIL_DAMAGE := 21
const NAIL_COOLDOWN := 0.34
const NAIL_ACTIVE_TIME := 0.14
const POGO_VELOCITY := -580.0
const RECOIL := 140.0
const IFRAME_TIME := 1.3
const HURT_STUN := 0.22
const FOCUS_TIME := 0.9
const SOUL_MAX := 99
const SOUL_PER_HIT := 11
const FOCUS_COST := 33
const CAST_COST := 33

var max_hp := 5
var hp := max_hp
var soul := 0
var facing := 1
var dead := false

var _coyote := 0.0
var _jump_buf := 0.0
var _air_jumps_left := AIR_JUMPS
var _dash_t := 0.0
var _dash_cd := 0.0
var _air_dash_ok := true
var _attack_cd := 0.0
var _nail_t := 0.0
var _nail_dir := Vector2.RIGHT
var _hit_this_swing: Array = []
var _iframes := 0.0
var _stun := 0.0
var _focus_t := 0.0
var _focusing := false
var _was_floor := false
var _land_t := 0.0

@onready var nail: Area2D = $Nail
@onready var nail_shape: CollisionShape2D = $Nail/Shape
@onready var hurtbox: Area2D = $Hurtbox
@onready var visual: Node2D = $Visual


func _ready() -> void:
	_build_visual()
	health_changed.emit(hp, max_hp)
	soul_changed.emit(soul)


func _build_visual() -> void:
	# dark cloak body
	Vfx.poly(visual, Vfx.circle(15.0, 16, 1.1), Color(0.1, 0.11, 0.16), Vector2(0, 3))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-13, 0), Vector2(13, 0), Vector2(9, 22), Vector2(0, 18), Vector2(-9, 22)
	]), Color(0.07, 0.08, 0.12), Vector2(0, 1))
	# pale mask
	Vfx.poly(visual, Vfx.circle(11.0, 16, 1.1), Color(0.93, 0.95, 0.97), Vector2(0, -14))
	# horns
	Vfx.poly(visual, PackedVector2Array([
		Vector2(-3, -21), Vector2(-14, -42), Vector2(-8, -22)
	]), Color(0.93, 0.95, 0.97))
	Vfx.poly(visual, PackedVector2Array([
		Vector2(3, -21), Vector2(14, -42), Vector2(8, -22)
	]), Color(0.93, 0.95, 0.97))
	# eyes
	Vfx.poly(visual, Vfx.circle(2.6, 8, 1.3), Color(0.05, 0.06, 0.1), Vector2(-4.5, -14))
	Vfx.poly(visual, Vfx.circle(2.6, 8, 1.3), Color(0.05, 0.06, 0.1), Vector2(4.5, -14))


func _physics_process(delta: float) -> void:
	queue_redraw()
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		return

	_tick_timers(delta)
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		_air_jumps_left = AIR_JUMPS
		_air_dash_ok = true
	if on_floor and not _was_floor:
		Sfx.play("land", -8.0)
		_land_t = 0.15
	_was_floor = on_floor

	_update_focus(delta, on_floor)

	var axis := Input.get_axis("move_left", "move_right")
	if _stun > 0.0:
		pass  # knocked back; keep momentum
	elif _dash_t > 0.0:
		velocity.x = facing * DASH_SPEED
		velocity.y = 0.0
	else:
		var target := 0.0 if _focusing else axis * SPEED
		var acc := ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target, acc * delta)
		if axis != 0.0 and not _focusing:
			facing = 1 if axis > 0.0 else -1

		if Input.is_action_just_pressed("jump"):
			_jump_buf = JUMP_BUFFER
		if _jump_buf > 0.0 and not _focusing:
			if _coyote > 0.0:
				_do_jump()
			elif _air_jumps_left > 0:
				_air_jumps_left -= 1
				_do_jump()
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= 0.42

		if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 \
				and (on_floor or _air_dash_ok) and not _focusing:
			_start_dash(on_floor)
		if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0 and not _focusing:
			_start_attack(on_floor)
		if Input.is_action_just_pressed("cast") and soul >= CAST_COST and not _focusing:
			_cast()

	if _dash_t <= 0.0:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_process_nail()
	_process_hurt()
	_animate()


func _tick_timers(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_jump_buf = maxf(_jump_buf - delta, 0.0)
	_dash_t = maxf(_dash_t - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_nail_t = maxf(_nail_t - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	_land_t = maxf(_land_t - delta, 0.0)


func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	_jump_buf = 0.0
	_coyote = 0.0
	Sfx.play("jump", -6.0)


func _start_dash(on_floor: bool) -> void:
	_dash_t = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	if not on_floor:
		_air_dash_ok = false
	Sfx.play("dash", -4.0)


func _start_attack(on_floor: bool) -> void:
	_attack_cd = NAIL_COOLDOWN
	_nail_t = NAIL_ACTIVE_TIME
	_hit_this_swing.clear()
	var dir := Vector2(facing, 0)
	if Input.is_action_pressed("look_up"):
		dir = Vector2.UP
	elif Input.is_action_pressed("look_down") and not on_floor:
		dir = Vector2.DOWN
	_nail_dir = dir
	nail.rotation = dir.angle()
	nail.monitoring = true
	nail_shape.disabled = false
	Sfx.play("slash", -4.0)


func _process_nail() -> void:
	if _nail_t <= 0.0:
		if nail.monitoring:
			nail.set_deferred("monitoring", false)
			nail_shape.set_deferred("disabled", true)
		return
	for a in nail.get_overlapping_areas():
		if a in _hit_this_swing:
			continue
		if a.is_in_group("boss_hurtbox"):
			_hit_this_swing.append(a)
			var target := a.get_parent()
			if target and target.has_method("take_hit"):
				target.take_hit(NAIL_DAMAGE, _nail_dir)
			gain_soul(SOUL_PER_HIT)
			_on_nail_connect()
		elif a.is_in_group("clashable"):
			_hit_this_swing.append(a)
			if a.has_method("nail_clash"):
				a.nail_clash()
			_on_nail_connect()


func _on_nail_connect() -> void:
	if _nail_dir == Vector2.DOWN:
		velocity.y = POGO_VELOCITY
		_air_dash_ok = true
		_air_jumps_left = AIR_JUMPS
	elif _nail_dir.y == 0.0:
		velocity.x = -_nail_dir.x * RECOIL
	Game.hitstop(0.06)
	Game.shake(3.0)


func gain_soul(amount: int) -> void:
	soul = mini(soul + amount, SOUL_MAX)
	soul_changed.emit(soul)


func _cast() -> void:
	soul -= CAST_COST
	soul_changed.emit(soul)
	var f := FireballScene.instantiate()
	f.dir = facing
	f.position = global_position + Vector2(facing * 24.0, -6.0)
	get_parent().add_child(f)
	Sfx.play("cast", -3.0)
	Game.shake(2.0)


func _update_focus(delta: float, on_floor: bool) -> void:
	var want := Input.is_action_pressed("focus") and on_floor and _stun <= 0.0 \
			and _dash_t <= 0.0 and soul >= FOCUS_COST and hp < max_hp
	if want:
		if not _focusing:
			_focusing = true
			_focus_t = 0.0
		_focus_t += delta
		if _focus_t >= FOCUS_TIME:
			soul -= FOCUS_COST
			hp = mini(hp + 1, max_hp)
			soul_changed.emit(soul)
			health_changed.emit(hp, max_hp)
			_focus_t = 0.0
			Sfx.play("heal")
			Vfx.burst(self, Vector2(0, -10), Color(1.0, 1.0, 1.0, 0.8), 12, 160.0)
	else:
		_focusing = false


func _process_hurt() -> void:
	if _iframes > 0.0 or dead:
		return
	for a in hurtbox.get_overlapping_areas():
		if a.is_in_group("enemy_attack"):
			take_damage(int(a.get_meta("damage", 1)), a.global_position)
			break


func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead or _iframes > 0.0:
		return
	hp = maxi(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	_focusing = false
	_iframes = IFRAME_TIME
	_stun = HURT_STUN
	_dash_t = 0.0
	var dir := signf(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector2(dir * 300.0, -240.0)
	Sfx.play("hurt")
	Game.hitstop(0.25)
	Game.shake(10.0)
	Vfx.burst(self, Vector2.ZERO, Color(0.9, 0.4, 0.35), 14, 220.0)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	_focusing = false
	hurtbox.set_deferred("monitoring", false)
	Vfx.burst(self, Vector2(0, -10), Color(0.85, 0.92, 1.0), 36, 380.0)
	visual.visible = false
	Sfx.play("boss_die")
	Game.shake(14.0)
	died.emit()


func full_restore() -> void:
	hp = max_hp
	soul = SOUL_MAX
	health_changed.emit(hp, max_hp)
	soul_changed.emit(soul)


func _animate() -> void:
	var squash := _land_t / 0.15 * 0.18
	if _dash_t > 0.0:
		visual.scale = Vector2(facing * 1.25, 0.82)
	else:
		visual.scale = Vector2(facing * (1.0 + squash), 1.0 - squash)
	visual.rotation = -velocity.x / SPEED * 0.05 if is_on_floor() else 0.0
	if _iframes > 0.0:
		visual.visible = fmod(_iframes, 0.12) > 0.05
	elif not dead:
		visual.visible = true


func _draw() -> void:
	if _nail_t > 0.0:
		var a := _nail_dir.angle()
		var alpha := _nail_t / NAIL_ACTIVE_TIME
		draw_arc(_nail_dir * 26.0, 40.0, a - 1.2, a + 1.2, 14, Color(1, 1, 1, alpha * 0.9), 5.0)
		draw_arc(_nail_dir * 26.0, 30.0, a - 0.9, a + 0.9, 12, Color(0.8, 0.9, 1, alpha * 0.5), 3.0)
	if _focusing and _focus_t > 0.02:
		var fr := _focus_t / FOCUS_TIME
		draw_arc(Vector2(0, -8), 30.0 + 3.0 * sin(fr * 14.0), -PI / 2.0, -PI / 2.0 + TAU * fr, 24, Color(1, 1, 1, 0.85), 3.0)
