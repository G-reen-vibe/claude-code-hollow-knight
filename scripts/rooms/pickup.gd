class_name Pickup
extends Area2D
## Coins, hearts and mana orbs that drift toward the player when close.

var kind := "coin"
var value := 1.0
var _magnet_range := 90.0
var _vel := Vector2.ZERO

static func spawn_coin(parent: Node, pos: Vector2) -> Pickup:
	return _spawn(parent, pos, "coin", 1.0)

static func spawn_heart(parent: Node, pos: Vector2) -> Pickup:
	return _spawn(parent, pos, "heart", 15.0)

static func spawn_mana(parent: Node, pos: Vector2) -> Pickup:
	return _spawn(parent, pos, "mana_orb", 25.0)

static func _spawn(parent: Node, pos: Vector2, p_kind: String, p_value: float) -> Pickup:
	var p := Pickup.new()
	p.kind = p_kind
	p.value = p_value
	p.position = pos
	p._vel = Vector2(randf_range(-60, 60), randf_range(-60, 60))
	var spr := Sprite2D.new()
	spr.texture = Art.tex(p_kind)
	spr.scale = Vector2(1.6, 1.6)
	p.add_child(spr)
	parent.add_child(p)
	return p

func _physics_process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var pl: Node2D = players[0]
		var d := pl.global_position.distance_to(global_position)
		if d < _magnet_range:
			_vel = _vel.lerp((pl.global_position - global_position).normalized() * 320.0, clampf(8.0 * delta, 0, 1))
		if d < 16.0:
			_collect(pl)
			return
	_vel = _vel.lerp(Vector2.ZERO, clampf(3.0 * delta, 0, 1))
	position += _vel * delta

func _collect(pl: Node) -> void:
	match kind:
		"coin":
			Game.add_gold(int(value))
		"heart":
			if pl.has_method("heal"):
				pl.heal(value)
			Sfx.play("pickup")
		"mana_orb":
			if pl.has_method("active_wand"):
				var w = pl.active_wand()
				w.mana = minf(w.mana_max, w.mana + value)
			Sfx.play("pickup")
	queue_free()
