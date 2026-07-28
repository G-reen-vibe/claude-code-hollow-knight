class_name Room
extends Node2D
## One dungeon room: a fully walled rectangle. Progression is forward-only,
## Magicraft-style: once the room's objective is done (combat cleared, or
## instantly for reward rooms), exit doors appear along the east wall — one
## per offered next-room type, each showing a preview icon of its reward.

signal cleared
signal exit_chosen(room_type: String)

const TILE := 32
const W := 34   # tiles wide
const H := 20   # tiles high

var room_type := "combat"
var locked := false
var enemies_alive := 0
var is_cleared := false
var exits_open := false

var _exit_nodes: Array = []

func size_px() -> Vector2:
	return Vector2(W * TILE, H * TILE)

func build(p_type: String) -> void:
	room_type = p_type
	_build_floor()
	_build_walls()

func _build_floor() -> void:
	var floor_tex := Art.tex("floor_tile")
	for y in range(H):
		for x in range(W):
			var s := Sprite2D.new()
			s.texture = floor_tex
			s.scale = Vector2(2, 2)
			s.position = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			s.z_index = -10
			add_child(s)

func _wall_segment(x: int, y: int, w: int, h: int) -> void:
	var body := StaticBody2D.new()
	body.add_to_group("walls")
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w * TILE, h * TILE)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(x * TILE + w * TILE / 2.0, y * TILE + h * TILE / 2.0)
	add_child(body)
	var wall_tex := Art.tex("wall_tile")
	for iy in range(h):
		for ix in range(w):
			var s := Sprite2D.new()
			s.texture = wall_tex
			s.scale = Vector2(2, 2)
			s.z_index = -5
			body.add_child(s)
			s.position = Vector2((x + ix) * TILE + TILE / 2.0, (y + iy) * TILE + TILE / 2.0) - body.position

func _build_walls() -> void:
	_wall_segment(0, 0, W, 1)
	_wall_segment(0, H - 1, W, 1)
	_wall_segment(0, 1, 1, H - 2)
	_wall_segment(W - 1, 1, 1, H - 2)

func player_spawn() -> Vector2:
	return Vector2(3.0 * TILE, size_px().y / 2.0)

func register_enemy(e: Node) -> void:
	enemies_alive += 1
	e.enemy_died.connect(func(_e):
		enemies_alive -= 1
		if enemies_alive <= 0 and locked:
			_on_cleared())

func lock() -> void:
	locked = true

func _on_cleared() -> void:
	locked = false
	is_cleared = true
	Game.rooms_cleared += 1
	var heal := RelicDB.bonus("heal_on_clear")
	if heal > 0.0:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			players[0].heal(heal)
	Sfx.play("door", 1.3)
	cleared.emit()

## Show exit doors on the east wall, one per offered room type.
func open_exits(offers: Array) -> void:
	if exits_open:
		return
	exits_open = true
	var n := offers.size()
	for i in range(n):
		var frac := float(i + 1) / float(n + 1)
		var pos := Vector2(size_px().x - 1.5 * TILE, size_px().y * frac)
		_exit_nodes.append(_make_exit(pos, offers[i]))
	Sfx.play("door")

const TYPE_LABELS := {
	"combat": "Battle",
	"spell": "Spell",
	"gold": "Gold",
	"relic": "Relic",
	"shop": "Shop",
	"workshop": "Workshop",
	"fountain": "Fountain",
	"boss": "BOSS",
}

func _make_exit(pos: Vector2, type: String) -> Node2D:
	var door := Area2D.new()
	door.collision_layer = 0
	door.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE * 1.4, TILE * 2.0)
	shape.shape = rect
	door.add_child(shape)
	door.position = pos
	# Door slab visual.
	var slab := ColorRect.new()
	slab.size = Vector2(TILE * 1.2, TILE * 2.0)
	slab.position = -slab.size / 2.0
	slab.color = Color(0.45, 0.15, 0.2) if type == "boss" else Color(0.35, 0.26, 0.16)
	door.add_child(slab)
	# Reward preview icon + label above the door.
	var icon := Sprite2D.new()
	icon.texture = Art.tex("door_" + type)
	icon.scale = Vector2(2, 2)
	icon.position = Vector2(0, -TILE * 1.7)
	door.add_child(icon)
	var label := Label.new()
	label.text = TYPE_LABELS.get(type, type)
	label.add_theme_font_size_override("font_size", 11)
	label.position = Vector2(-24, -TILE * 1.2)
	label.size = Vector2(48, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	door.add_child(label)
	add_child(door)
	door.body_entered.connect(func(body):
		if body.is_in_group("player") and exits_open:
			exits_open = false
			exit_chosen.emit(type))
	return door
