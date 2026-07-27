extends Area2D
class_name Projectile
## Generic boss projectile. Bosses set fields before add_child; visuals are drawn in code.
## Styles: "orb" (glowing ball), "shard" (needle/spike), "wave" (ground shockwave).

var velocity := Vector2.ZERO
var accel := Vector2.ZERO
var lifetime := 4.0
var damage := 1
var radius := 10.0
var color := Color(1.0, 0.55, 0.2)
var die_on_wall := true
var clashable := false
var homing: Node2D = null
var turn_speed := 0.0
var speed := 0.0
var style := "orb"


func _ready() -> void:
	add_to_group("enemy_attack")
	set_meta("damage", damage)
	if clashable:
		add_to_group("clashable")
	var c := CircleShape2D.new()
	c.radius = radius
	($Shape as CollisionShape2D).shape = c
	body_entered.connect(_on_body)
	if style == "shard":
		rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if homing != null and is_instance_valid(homing) and turn_speed > 0.0:
		var want := (homing.global_position - global_position).angle()
		var diff := wrapf(want - velocity.angle(), -PI, PI)
		var step := clampf(diff, -turn_speed * delta, turn_speed * delta)
		velocity = velocity.rotated(step)
		if speed > 0.0:
			velocity = velocity.normalized() * speed
	velocity += accel * delta
	position += velocity * delta
	if style == "shard":
		rotation = velocity.angle()


func _on_body(_body: Node) -> void:
	if die_on_wall:
		_pop()


func nail_clash() -> void:
	Sfx.play("hit", -6.0)
	_pop()


func _pop() -> void:
	Vfx.burst(self, Vector2.ZERO, color, 10, 160.0)
	queue_free()


func _draw() -> void:
	match style:
		"orb":
			draw_circle(Vector2.ZERO, radius + 5.0, Color(color.r, color.g, color.b, 0.25))
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.85))
		"shard":
			draw_colored_polygon(PackedVector2Array([
				Vector2(radius * 1.8, 0), Vector2(-radius, radius * 0.45), Vector2(-radius, -radius * 0.45)
			]), color)
			draw_circle(Vector2(-radius * 0.4, 0), radius * 0.35, Color(1, 1, 1, 0.6))
		"wave":
			draw_rect(Rect2(-radius * 0.5, -radius * 2.4, radius, radius * 2.4), color)
			draw_rect(Rect2(-radius * 0.95, -radius * 0.8, radius * 1.9, radius * 0.8), Color(color.r, color.g, color.b, 0.55))
