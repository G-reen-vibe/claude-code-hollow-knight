class_name EnemyBase
extends CharacterBody2D
## Shared enemy behavior: health, contact damage, knockback, status effects
## (slow, stacking poison, damage-amplification marks), loot drops, death FX.
## Subclasses implement _ai(delta).

signal enemy_died(enemy)

var max_hp := 20.0
var hp := 20.0
var speed := 90.0
var contact_damage := 8.0
var gold_min := 1
var gold_max := 3
var sprite_name := "spider_small"
var sprite_scale := 2.0
var dead := false

var _knockback := Vector2.ZERO
var _slow_mult := 1.0
var _slow_timer := 0.0
var _flash := 0.0
# Poison: array of {dps, time} stacks.
var _poison_stacks: Array = []
# Amp: damage-taken multiplier from Magic Bullet marks.
var _amp := 0.0
var _amp_timer := 0.0

var sprite: Sprite2D
var player: Node2D

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 8   # walls
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = max_hp

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 7.0 * sprite_scale
	shape.shape = circ
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.texture = Art.tex(sprite_name)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(sprite)

	# Hurtbox so player projectiles (Area2D) can overlap us.
	var hurt := Area2D.new()
	hurt.add_to_group("enemy_hurtbox")
	hurt.collision_layer = 2
	hurt.collision_mask = 4
	var hshape := CollisionShape2D.new()
	hshape.shape = circ
	hurt.add_child(hshape)
	add_child(hurt)

	# Contact damage zone against the player.
	var touch := Area2D.new()
	touch.collision_layer = 16
	touch.collision_mask = 1
	var tshape := CollisionShape2D.new()
	tshape.shape = circ
	touch.add_child(tshape)
	add_child(touch)
	touch.body_entered.connect(_on_touch)

	_find_player()

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	player = players[0] if not players.is_empty() else null

func _physics_process(delta: float) -> void:
	if dead:
		return
	if player == null or not is_instance_valid(player) or player.get("dead"):
		_find_player()
	_flash = maxf(0.0, _flash - delta)
	_update_status(delta)
	_ai(delta)
	velocity += _knockback
	_knockback = _knockback.lerp(Vector2.ZERO, clampf(10.0 * delta, 0.0, 1.0))
	move_and_slide()

func _update_status(delta: float) -> void:
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_mult = 1.0
	if _amp_timer > 0.0:
		_amp_timer -= delta
		if _amp_timer <= 0.0:
			_amp = 0.0
	var poison_dps := 0.0
	for i in range(_poison_stacks.size() - 1, -1, -1):
		var stack: Dictionary = _poison_stacks[i]
		stack["time"] -= delta
		if stack["time"] <= 0.0:
			_poison_stacks.remove_at(i)
		else:
			poison_dps += stack["dps"]
	if poison_dps > 0.0:
		_damage_raw(poison_dps * delta, false)
	# Tint priority: hit flash > poison > chill.
	if _flash > 0.0:
		sprite.modulate = Color(4, 4, 4)
	elif not _poison_stacks.is_empty():
		sprite.modulate = Color(0.6, 1.0, 0.5)
	elif _slow_timer > 0.0:
		sprite.modulate = Color(0.7, 0.85, 1.0)
	else:
		sprite.modulate = Color.WHITE

## Override in subclasses. Default: walk straight at the player.
func _ai(_delta: float) -> void:
	if player != null and is_instance_valid(player) and not player.get("dead"):
		velocity = (player.global_position - global_position).normalized() * speed * _slow_mult
	else:
		velocity = Vector2.ZERO

func _on_touch(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)

func take_damage(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	amount *= 1.0 + _amp
	_flash = 0.08
	_knockback += dir.normalized() * 55.0
	_spawn_damage_number(amount)
	_damage_raw(amount, true)

func _damage_raw(amount: float, _from_hit: bool) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		die()

func apply_slow(strength: float, time: float) -> void:
	_slow_mult = minf(_slow_mult, 1.0 - strength)
	_slow_timer = maxf(_slow_timer, time)

## Stacking poison damage-over-time (Venom Crystal).
func apply_poison(dps: float, time: float) -> void:
	_poison_stacks.append({"dps": dps, "time": time})

## Stacking damage-amplification mark (Magic Bullet), capped at +60%.
func apply_amp(amount: float, time: float) -> void:
	_amp = minf(_amp + amount, 0.6)
	_amp_timer = maxf(_amp_timer, time)

func _spawn_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(ceil(amount)))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	label.z_index = 50
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-6, -22)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y - 18.0, 0.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(label.queue_free)

func die() -> void:
	if dead:
		return
	dead = true
	Sfx.play("die", 0.9 + randf() * 0.3)
	_drop_loot()
	enemy_died.emit(self)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(sprite_scale * 1.4, 0.1), 0.15)
	tw.tween_callback(queue_free)
	collision_layer = 0
	set_physics_process(false)

func _drop_loot() -> void:
	var n := Game.rng.randi_range(gold_min, gold_max)
	n = int(round(n * RelicDB.mult("gold_mult")))
	for i in range(n):
		Pickup.spawn_coin(get_parent(), global_position + Vector2(Game.rng.randf_range(-10, 10), Game.rng.randf_range(-10, 10)))
	if Game.rng.randf() < 0.06:
		Pickup.spawn_heart(get_parent(), global_position)
