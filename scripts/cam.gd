extends Camera2D
## Arena camera: fixed framing with decaying screen shake.

var _sh := 0.0


func _ready() -> void:
	Game.screen_shake.connect(_on_shake)


func _on_shake(amount: float) -> void:
	_sh = maxf(_sh, amount)


func _process(delta: float) -> void:
	_sh = maxf(_sh - 40.0 * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _sh
