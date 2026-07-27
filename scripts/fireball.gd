extends Area2D
## Vengeful Spirit: the Knight's spell. Pierces bosses, dies on walls.

const SPEED := 620.0
const DAMAGE := 30

var dir := 1

var _hit: Array = []
var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position.x += dir * SPEED * delta
	_t += delta
	queue_redraw()
	if _t > 1.4:
		queue_free()
		return
	for a in get_overlapping_areas():
		if a.is_in_group("boss_hurtbox") and not a in _hit:
			_hit.append(a)
			var b := a.get_parent()
			if b and b.has_method("take_hit"):
				b.take_hit(DAMAGE, Vector2(dir, 0))
			Game.shake(4.0)


func _on_body(_body: Node) -> void:
	Vfx.burst(self, Vector2.ZERO, Color(0.75, 0.9, 1.0), 16, 240.0)
	queue_free()


func _draw() -> void:
	var wob := sin(_t * 30.0) * 2.0
	draw_circle(Vector2(-dir * 16.0, wob), 8.0, Color(0.5, 0.75, 1.0, 0.25))
	draw_circle(Vector2(-dir * 8.0, wob * 0.5), 11.0, Color(0.6, 0.8, 1.0, 0.45))
	draw_circle(Vector2.ZERO, 13.0, Color(0.75, 0.9, 1.0, 0.9))
	draw_circle(Vector2.ZERO, 7.0, Color(1, 1, 1, 1))
	# trailing eyes of the spirit
	draw_circle(Vector2(3, -3), 2.0, Color(0.2, 0.35, 0.6))
	draw_circle(Vector2(3, 3), 2.0, Color(0.2, 0.35, 0.6))
