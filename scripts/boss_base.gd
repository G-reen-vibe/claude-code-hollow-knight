extends CharacterBody2D
class_name BossBase
## Base for all bosses: health, hit flash, death sequence, async "brain" helpers,
## and spawn helpers for projectiles and melee hitboxes.

signal health_changed(hp: int, max_hp: int)
signal defeated

const ProjectileScene := preload("res://scenes/projectile.tscn")

@export var boss_title := "Boss"
@export var max_hp := 300
@export var gravity_on := true

const GRAVITY := 1800.0
const MAX_FALL := 1100.0

var hp: int
var player: Node2D = null
var active := false
var dead := false
var facing := -1
var visual: Node2D

var _flash := 0.0


func _ready() -> void:
	hp = max_hp
	add_to_group("boss")
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_visual()
	_face(float(facing))


func _build_visual() -> void:
	pass


func activate(p: Node2D) -> void:
	player = p
	active = true
	health_changed.emit(hp, max_hp)
	_face(p.global_position.x - global_position.x)
	_brain()


## Override: the boss's async attack loop.
func _brain() -> void:
	pass


## Await helpers for brains. Each returns false when the fight is over.
func alive_wait(t: float) -> bool:
	await get_tree().create_timer(t).timeout
	return not dead and active


func frame() -> bool:
	await get_tree().physics_frame
	return not dead and active


func wait_until_landed(max_t := 3.0) -> bool:
	for i in 3:
		if not await frame():
			return false
	var t := 0.0
	while not is_on_floor() and t < max_t:
		if not await frame():
			return false
		t += get_physics_process_delta_time()
	return true


func _face(dx: float) -> void:
	if absf(dx) < 0.01:
		return
	facing = 1 if dx > 0.0 else -1
	if visual:
		visual.scale.x = facing


func take_hit(dmg: int, dir: Vector2) -> void:
	if dead:
		return
	hp = maxi(hp - dmg, 0)
	_flash = 0.15
	health_changed.emit(hp, max_hp)
	Sfx.play("hit", -4.0)
	Vfx.burst(self, Vector2(dir.x * -10.0, dir.y * -10.0), Color(1.0, 0.95, 0.75), 8, 200.0)
	_on_hurt(dir)
	if hp <= 0:
		_die()


func _on_hurt(_dir: Vector2) -> void:
	pass


func _die() -> void:
	dead = true
	active = false
	velocity = Vector2.ZERO
	for c in get_children():
		if c is Area2D:
			c.set_deferred("monitoring", false)
			c.set_deferred("monitorable", false)
			if c.is_in_group("enemy_attack"):
				c.remove_from_group("enemy_attack")
	set_collision_layer_value(3, false)
	Sfx.play("boss_die")
	Game.shake(18.0)
	Game.hitstop(0.35)
	Vfx.burst(self, Vector2.ZERO, Color(1.0, 0.85, 0.4), 40, 400.0)
	Vfx.burst(self, Vector2.ZERO, Color(0.9, 0.95, 1.0), 24, 260.0)
	defeated.emit()
	var tw := create_tween()
	tw.tween_property(visual, "modulate", Color(1, 1, 1, 0), 1.2)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not dead and _flash > 0.0:
		_flash -= delta
		var bright := int(_flash * 30.0) % 2 == 0
		visual.modulate = Color(2, 2, 2, 1) if bright else Color(1, 1, 1, 1)
	elif not dead:
		visual.modulate = Color(1, 1, 1, 1)
	if dead:
		return
	if gravity_on and not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_tick(delta)


## Override: per-frame animation while alive.
func _tick(_delta: float) -> void:
	pass


func _shiver(dur: float) -> void:
	var tw := create_tween()
	for i in int(dur / 0.05):
		tw.tween_property(visual, "position", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.05)
	tw.tween_property(visual, "position", Vector2.ZERO, 0.05)


func spawn_projectile(pos: Vector2, vel: Vector2, cfg: Dictionary = {}) -> Projectile:
	var p: Projectile = ProjectileScene.instantiate()
	p.position = pos
	p.velocity = vel
	for k in cfg:
		p.set(k, cfg[k])
	get_parent().add_child(p)
	return p


## Short-lived melee hitbox, offset is mirrored by facing. Attached to the boss.
func spawn_melee(offset: Vector2, size: Vector2, dur: float, dmg := 1) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 16
	a.collision_mask = 0
	a.monitoring = false
	a.add_to_group("enemy_attack")
	a.set_meta("damage", dmg)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	a.add_child(cs)
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2),
		Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)
	])
	vis.color = Color(1, 1, 1, 0.16)
	a.add_child(vis)
	a.position = Vector2(offset.x * facing, offset.y)
	add_child(a)
	var t := get_tree().create_timer(dur)
	t.timeout.connect(func():
		if is_instance_valid(a):
			a.queue_free())
	return a
