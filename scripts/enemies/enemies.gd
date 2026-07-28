## Chapter 1 enemy roster: the dark-forest cavern's spiders, worms and
## corrupted eyes. Each subclass tunes stats and overrides _ai().

class_name Enemies

## Small spider: skitters at the player in quick bursts.
class SmallSpider extends EnemyBase:
	var _burst_timer := 0.0
	func _init() -> void:
		max_hp = 14.0; speed = 150.0; contact_damage = 6.0
		gold_min = 1; gold_max = 2
		sprite_name = "spider_small"; sprite_scale = 2.0
	func _ai(delta: float) -> void:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.9 + Game.rng.randf() * 0.5
		# Skitter: move hard for the first 60% of each burst, pause after.
		if _burst_timer > 0.36 and player != null and is_instance_valid(player):
			velocity = (player.global_position - global_position).normalized() * speed * _slow_mult
			sprite.rotation = velocity.angle() if velocity.length() > 1.0 else sprite.rotation
		else:
			velocity = Vector2.ZERO

## Brood spider: slow tank; releases two small spiders on death.
class BroodSpider extends EnemyBase:
	func _init() -> void:
		max_hp = 45.0; speed = 55.0; contact_damage = 12.0
		gold_min = 3; gold_max = 5
		sprite_name = "spider_big"; sprite_scale = 2.2
	func die() -> void:
		if dead:
			return
		var parent := get_parent()
		var pos := global_position
		super.die()
		for i in range(2):
			var s := SmallSpider.new()
			s.position = pos + Vector2(Game.rng.randf_range(-18, 18), Game.rng.randf_range(-18, 18))
			parent.add_child(s)
			var room := parent as Room
			if room != null:
				room.register_enemy(s)

## Wandering worm: burrows in a telegraphed line lunge (mini version of the
## chapter's Wandering Worm miniboss behavior).
class Worm extends EnemyBase:
	var _state := "crawl"   # crawl | windup | lunge | recover
	var _t := 0.0
	var _lunge_dir := Vector2.ZERO
	func _init() -> void:
		max_hp = 26.0; speed = 55.0; contact_damage = 12.0
		gold_min = 2; gold_max = 4
		sprite_name = "worm"; sprite_scale = 2.0
	func _ai(delta: float) -> void:
		if player == null or not is_instance_valid(player) or player.get("dead"):
			velocity = Vector2.ZERO
			return
		var to_player := player.global_position - global_position
		_t -= delta
		match _state:
			"crawl":
				velocity = to_player.normalized() * speed * _slow_mult
				if to_player.length() < 260.0 and _t <= 0.0:
					_state = "windup"; _t = 0.45
			"windup":
				velocity = Vector2.ZERO
				sprite.modulate = Color(1.6, 1.2, 1.2)
				if _t <= 0.0:
					_state = "lunge"; _t = 0.5
					_lunge_dir = (player.global_position - global_position).normalized()
			"lunge":
				velocity = _lunge_dir * 400.0 * _slow_mult
				if _t <= 0.0 or get_slide_collision_count() > 0:
					_state = "recover"; _t = 0.7
			"recover":
				velocity = Vector2.ZERO
				if _t <= 0.0:
					_state = "crawl"; _t = 0.4
		sprite.flip_h = to_player.x < 0.0

## Corrupted eye: drifts and bounces around, spitting tracking bolts.
class CorruptedEye extends EnemyBase:
	var _drift := Vector2.ZERO
	var _shoot_timer := 1.4
	func _init() -> void:
		max_hp = 16.0; speed = 90.0; contact_damage = 5.0
		gold_min = 2; gold_max = 3
		sprite_name = "eye"; sprite_scale = 2.0
	func _ready() -> void:
		super._ready()
		_drift = Vector2.from_angle(Game.rng.randf() * TAU) * speed
	func _ai(delta: float) -> void:
		# Bounce off walls like a restless eyeball.
		if get_slide_collision_count() > 0:
			var n := get_slide_collision(0).get_normal()
			_drift = _drift.bounce(n)
		velocity = _drift * _slow_mult
		_shoot_timer -= delta
		if _shoot_timer <= 0.0 and player != null and is_instance_valid(player) and not player.get("dead"):
			var d := player.global_position - global_position
			if d.length() < 460.0:
				_shoot_timer = 1.8 + Game.rng.randf() * 0.6
				var bolt := Enemies.EnemyBolt.spawn(get_parent(), global_position, d.normalized(), 8.0, 190.0)
				bolt.homing = 1.6
		sprite.rotation = lerp_angle(sprite.rotation, velocity.angle() * 0.15, 3.0 * delta)

## Simple hostile bolt used by ranged enemies and the boss. Optional homing.
class EnemyBolt extends Area2D:
	var dir := Vector2.RIGHT
	var speed := 240.0
	var damage := 9.0
	var life := 3.5
	var homing := 0.0
	var slow_on_hit := 0.0
	var slow_time := 0.0
	static func spawn(parent: Node, pos: Vector2, p_dir: Vector2, p_damage: float, p_speed: float, tex := "proj_enemy_bolt") -> EnemyBolt:
		var b := EnemyBolt.new()
		b.dir = p_dir.normalized()
		b.damage = p_damage
		b.speed = p_speed
		b.position = pos
		b.collision_layer = 16
		b.collision_mask = 1 | 8
		var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 5.0
		shape.shape = circ
		b.add_child(shape)
		var spr := Sprite2D.new()
		spr.texture = Art.tex(tex)
		spr.scale = Vector2(1.8, 1.8)
		b.add_child(spr)
		parent.add_child(b)
		b.body_entered.connect(b._on_body)
		return b
	func _physics_process(delta: float) -> void:
		if homing > 0.0:
			var players := get_tree().get_nodes_in_group("player")
			if not players.is_empty() and not players[0].get("dead"):
				var want: Vector2 = (players[0].global_position - global_position).normalized()
				dir = dir.slerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
		position += dir * speed * delta
		life -= delta
		if life <= 0.0:
			queue_free()
	func _on_body(body: Node) -> void:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			if slow_on_hit > 0.0 and body.has_method("apply_web_slow"):
				body.apply_web_slow(slow_on_hit, slow_time)
			queue_free()
		elif body is StaticBody2D or body.is_in_group("walls"):
			queue_free()
