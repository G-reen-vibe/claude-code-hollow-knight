class_name GiantSpider
extends EnemyBase
## Chapter 1's first boss: the Giant Spider (~650 HP on normal).
## Pattern set, faithful to the original fight:
##  - Linear Charge: telegraphed straight-line rush across the arena.
##  - Web Shot: a spread cluster of web projectiles that entangle (slow) you.
##  - Minion Spawn: periodically calls small spiders into the arena.
##  - Contact damage throughout.
## There are no hard phases — attack frequency and add pressure escalate as
## its health drops.

signal intensity_changed(tier: int)

var boss_name := "Giant Spider"

var _state := "stalk"     # stalk | charge_windup | charging | web_windup | recover
var _t := 0.0
var _charge_dir := Vector2.ZERO
var _web_timer := 3.0
var _charge_timer := 2.5
var _summon_timer := 7.0
var _telegraph: Line2D

func _init() -> void:
	max_hp = 650.0
	speed = 60.0
	contact_damage = 15.0
	gold_min = 25
	gold_max = 35
	sprite_name = "boss_spider"
	sprite_scale = 3.0

func _ready() -> void:
	super._ready()
	add_to_group("boss")

## 1 → 2 → 3 as HP falls; drives attack cadence.
func intensity() -> int:
	var frac := hp / max_hp
	return 1 if frac > 0.66 else (2 if frac > 0.33 else 3)

func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.get("dead"):
		velocity = Vector2.ZERO
		return
	var tier := intensity()
	var to_player := player.global_position - global_position
	_t -= delta

	match _state:
		"stalk":
			velocity = to_player.normalized() * speed * (1.0 + 0.25 * (tier - 1)) * _slow_mult
			sprite.flip_h = to_player.x < 0.0
			_web_timer -= delta
			_charge_timer -= delta
			_summon_timer -= delta
			if _charge_timer <= 0.0:
				_charge_timer = maxf(1.6, 4.0 - tier * 0.8) + Game.rng.randf() * 0.8
				_begin_charge()
			elif _web_timer <= 0.0:
				_web_timer = maxf(1.8, 4.2 - tier * 0.7)
				_state = "web_windup"
				_t = 0.35
				velocity = Vector2.ZERO
			if _summon_timer <= 0.0:
				_summon_timer = maxf(4.5, 9.0 - tier * 1.5)
				_summon_spiders(1 + tier)
		"charge_windup":
			velocity = Vector2.ZERO
			sprite.modulate = Color(1.7, 1.2, 1.2)
			if _t <= 0.0:
				_state = "charging"
				_t = 0.6
				sprite.modulate = Color.WHITE
				_clear_telegraph()
				Sfx.play("boss_roar", 1.4)
		"charging":
			velocity = _charge_dir * (430.0 + 40.0 * tier) * _slow_mult
			if _t <= 0.0 or get_slide_collision_count() > 0:
				_state = "recover"
				_t = 0.55 if tier < 3 else 0.35
		"web_windup":
			velocity = Vector2.ZERO
			sprite.modulate = Color(1.2, 1.2, 1.7)
			if _t <= 0.0:
				sprite.modulate = Color.WHITE
				_web_shot(intensity())
				_state = "recover"
				_t = 0.4
		"recover":
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if _t <= 0.0:
				_state = "stalk"

func _begin_charge() -> void:
	_state = "charge_windup"
	_t = 0.55
	_charge_dir = (player.global_position - global_position).normalized()
	# Telegraph line so the rush can be sidestepped.
	_telegraph = Line2D.new()
	_telegraph.width = 6.0
	_telegraph.default_color = Color(1.0, 0.3, 0.3, 0.35)
	_telegraph.add_point(Vector2.ZERO)
	_telegraph.add_point(_charge_dir.rotated(-rotation) * 500.0)
	add_child(_telegraph)

func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
		_telegraph = null

## Spread cluster of entangling web projectiles.
func _web_shot(tier: int) -> void:
	var dir := (player.global_position - global_position).normalized()
	var count := 4 + tier * 2
	var arc := 0.55 + 0.1 * tier
	for i in range(count):
		var ang := lerpf(-arc, arc, float(i) / float(count - 1))
		var b := Enemies.EnemyBolt.spawn(get_parent(), global_position, dir.rotated(ang), 7.0, 230.0, "proj_web")
		b.slow_on_hit = 0.55
		b.slow_time = 1.8

func _summon_spiders(count: int) -> void:
	var room := get_parent() as Room
	for i in range(count):
		var s := Enemies.SmallSpider.new()
		s.position = position + Vector2(Game.rng.randf_range(-90, 90), Game.rng.randf_range(-90, 90))
		get_parent().add_child(s)
		if room != null:
			room.register_enemy(s)
	Sfx.play("boss_roar", 1.8)

func die() -> void:
	_clear_telegraph()
	super.die()

func _drop_loot() -> void:
	super._drop_loot()
	Pickup.spawn_heart(get_parent(), global_position + Vector2(30, 0))
	Pickup.spawn_mana(get_parent(), global_position + Vector2(-30, 0))
