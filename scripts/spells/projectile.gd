class_name Projectile
extends Area2D
## Generic player projectile driven by a stats dictionary from Wand.cast_step().
## Supports pierce, wall bounce, homing, impact explosions, poison/amp/slow
## status application, in-flight damage growth (Water Bubble) and on-impact
## splitting (Split enhancement).

var stats: Dictionary = {}
var direction := Vector2.RIGHT
var _life := 0.0
var _age := 0.0
var _pierce_left := 0
var _bounce_left := 0
var _hit_targets: Array = []

static func spawn(parent: Node, pos: Vector2, dir: Vector2, p_stats: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.stats = p_stats
	p.direction = dir.normalized()
	p.position = pos
	p.rotation = dir.angle()
	p._life = p_stats.get("lifetime", 1.5)
	p._pierce_left = p_stats.get("pierce", 0)
	p._bounce_left = p_stats.get("bounce", 0)
	p.collision_layer = 4
	p.collision_mask = 2 | 8   # enemies + walls
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 5.0
	shape.shape = circ
	p.add_child(shape)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(p_stats.get("proj", "proj_bullet"))
	spr.scale = Vector2(2, 2)
	p.add_child(spr)
	parent.add_child(p)
	p.body_entered.connect(p._on_body)
	p.area_entered.connect(p._on_area)
	return p

func current_damage() -> float:
	return stats.get("damage", 1.0) + stats.get("growth", 0.0) * _age

func _physics_process(delta: float) -> void:
	var homing: float = stats.get("homing", 0.0)
	if homing > 0.0:
		var target := _nearest_enemy()
		if target != null:
			var want := (target.global_position - global_position).normalized()
			direction = direction.slerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
			rotation = direction.angle()
	position += direction * stats.get("speed", 400.0) * delta
	_age += delta
	if stats.get("growth", 0.0) > 0.0:
		var s := 2.0 * (1.0 + _age * 0.35)
		for c in get_children():
			if c is Sprite2D:
				c.scale = Vector2(s, s)
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 1e12
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead"):
			continue
		var d: float = e.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _on_area(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		_hit_enemy(area.get_parent())

func _on_body(body: Node) -> void:
	if body.is_in_group("enemies"):
		_hit_enemy(body)
	elif body is StaticBody2D or body.is_in_group("walls"):
		if _bounce_left > 0:
			_bounce_left -= 1
			_bounce()
		else:
			_impact()

func _bounce() -> void:
	var normal := -direction
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position - direction * 12.0, global_position + direction * 12.0, 8)
	var hit := space.intersect_ray(q)
	if hit and hit.has("normal"):
		normal = hit["normal"]
	direction = direction.bounce(normal).normalized()
	rotation = direction.angle()
	position += direction * 4.0

func _hit_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy in _hit_targets:
		return
	_hit_targets.append(enemy)
	if enemy.has_method("take_damage"):
		enemy.take_damage(current_damage(), direction)
		if stats.get("slow", 0.0) > 0.0 and enemy.has_method("apply_slow"):
			enemy.apply_slow(stats["slow"], stats.get("slow_time", 1.0))
		if stats.get("poison", 0.0) > 0.0 and enemy.has_method("apply_poison"):
			enemy.apply_poison(stats["poison"], stats.get("poison_time", 3.0))
		if stats.get("amp", 0.0) > 0.0 and enemy.has_method("apply_amp"):
			enemy.apply_amp(stats["amp"], stats.get("amp_time", 3.0))
	if _pierce_left > 0:
		_pierce_left -= 1
	else:
		_impact()

func _impact() -> void:
	var radius: float = stats.get("explode_radius", 0.0)
	if radius > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e in _hit_targets or e.get("dead"):
				continue
			if e.global_position.distance_to(global_position) <= radius:
				if e.has_method("take_damage"):
					e.take_damage(current_damage() * 0.8, (e.global_position - global_position).normalized())
		_explosion_fx(radius)
	_spawn_split_children()
	Sfx.play("hit", 1.0 + randf() * 0.2)
	queue_free()

## Split enhancement: on impact the projectile bursts into weaker shards.
func _spawn_split_children() -> void:
	var n: int = stats.get("split_children", 0)
	if n <= 0:
		return
	var child_stats := stats.duplicate(true)
	child_stats["split_children"] = 0
	child_stats["damage"] = current_damage() * 0.5
	child_stats["lifetime"] = 0.5
	child_stats["explode_radius"] = 0.0
	child_stats["pierce"] = 0
	for i in range(n):
		var ang := direction.angle() + PI / 2.0 + (TAU * i / n)
		var child := Projectile.spawn(get_parent(), global_position, Vector2.from_angle(ang), child_stats)
		child._hit_targets = _hit_targets.duplicate()

func _explosion_fx(radius: float) -> void:
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.polygon = pts
	ring.color = Color(1.0, 0.6, 0.15, 0.5)
	get_parent().add_child(ring)
	ring.global_position = global_position
	var tw := ring.create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ring.queue_free)
