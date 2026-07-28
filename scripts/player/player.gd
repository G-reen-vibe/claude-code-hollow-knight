class_name Player
extends CharacterBody2D
## The apprentice wizard: WASD movement, mouse aim, hold-to-cast, space dash.

signal health_changed(hp: float, max_hp: float)
signal mana_changed(mana: float, max_mana: float)
signal wand_changed
signal died

const BASE_SPEED := 220.0
const DASH_SPEED := 620.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.9
const INVULN_TIME := 0.7

var max_hp := 100.0
var hp := 100.0
var wands: Array = []          # up to 2 wands, Q swaps
var active_wand_index := 0
var spell_bag: Array = []      # spell instances not slotted in a wand
var dead := false

var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.ZERO
var _invuln := 0.0
var _fire_held := false
var _web_slow_mult := 1.0
var _web_slow_timer := 0.0
## Test hook: when set, overrides mouse aim in headless runs.
var aim_override := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite
@onready var wand_sprite: Sprite2D = $WandPivot/WandSprite

func _ready() -> void:
	add_to_group("player")
	sprite.texture = Art.tex("player")
	wand_sprite.texture = Art.tex("wand")
	max_hp = 100.0 + RelicDB.bonus("max_hp")
	hp = max_hp
	if wands.is_empty():
		# Default loadout: a weak starter wand and 6x Magic Bullet — three
		# slotted, three in the backpack.
		var w := Wand.new("Apprentice Wand", 3, 100.0, 16.0, 0.1, 0.5)
		for i in range(3):
			w.place_spell(i, SpellDB.make_instance("magic_bullet"))
		wands.append(w)
		for i in range(3):
			spell_bag.append(SpellDB.make_instance("magic_bullet"))
	health_changed.emit(hp, max_hp)
	wand_changed.emit()

func active_wand() -> Wand:
	return wands[active_wand_index]

func _physics_process(delta: float) -> void:
	if dead:
		return
	_invuln = maxf(0.0, _invuln - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	for w in wands:
		w.tick(delta)
	mana_changed.emit(active_wand().mana, active_wand().mana_max + RelicDB.bonus("max_mana"))

	if _web_slow_timer > 0.0:
		_web_slow_timer -= delta
		if _web_slow_timer <= 0.0:
			_web_slow_mult = 1.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = input_dir * BASE_SPEED * RelicDB.mult("speed_mult") * _web_slow_mult
		if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and input_dir != Vector2.ZERO:
			_dash_timer = DASH_TIME
			_dash_cd = DASH_COOLDOWN
			_dash_dir = input_dir.normalized()
			_invuln = maxf(_invuln, DASH_TIME + 0.05)
			Sfx.play("dash")
	move_and_slide()

	var aim := aim_direction()
	$WandPivot.rotation = aim.angle()
	sprite.flip_h = aim.x < 0.0

	if Input.is_action_pressed("fire") or _fire_held:
		_try_cast(aim)

	# Blink while invulnerable.
	sprite.modulate.a = 0.5 if _invuln > 0.0 and int(_invuln * 20.0) % 2 == 0 else 1.0

func aim_direction() -> Vector2:
	if aim_override != Vector2.ZERO:
		return aim_override.normalized()
	var mouse := get_global_mouse_position()
	var d := mouse - global_position
	return d.normalized() if d.length() > 2.0 else Vector2.RIGHT

func _try_cast(aim: Vector2) -> void:
	var w := active_wand()
	var shots := w.cast_step()
	if shots.is_empty():
		return
	_spawn_shots(shots, aim)
	# Replica Glove etc.: chance to duplicate the entire cast for free.
	var echo_chance := RelicDB.echo_chance()
	if echo_chance > 0.0 and Game.rng.randf() < echo_chance:
		_spawn_shots(shots, aim)
	Sfx.play("shoot", 0.9 + randf() * 0.2)

func _spawn_shots(shots: Array, aim: Vector2) -> void:
	var muzzle: Vector2 = global_position + aim * 18.0
	for shot in shots:
		var count: int = shot.get("count", 1)
		var spread: float = deg_to_rad(shot.get("spread_deg", 0.0))
		for i in range(count):
			var ang := 0.0
			if count > 1:
				ang = lerpf(-spread, spread, float(i) / float(count - 1))
			Projectile.spawn(get_parent(), muzzle, aim.rotated(ang), shot)

func _input(event: InputEvent) -> void:
	if dead:
		return
	if event.is_action_pressed("swap_wand") and wands.size() > 1:
		active_wand_index = (active_wand_index + 1) % wands.size()
		active_wand().reset_sequence()
		wand_changed.emit()

func take_damage(amount: float) -> void:
	if dead or _invuln > 0.0:
		return
	hp -= amount
	_invuln = INVULN_TIME
	Sfx.play("hurt")
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()

## Entangled by boss webs: heavy movement slow for a short time.
func apply_web_slow(strength: float, time: float) -> void:
	_web_slow_mult = minf(_web_slow_mult, 1.0 - strength)
	_web_slow_timer = maxf(_web_slow_timer, time)

func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)

func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	sprite.modulate = Color(0.5, 0.5, 0.5, 0.6)
	died.emit()
	Game.on_player_died()

## ---- inventory API used by the UI ----

func pickup_spell(spell_id: String) -> void:
	var inst := SpellDB.make_instance(spell_id)
	# Auto-slot into the first free slot of the active wand, else the bag.
	var w := active_wand()
	for i in range(w.slot_count):
		if w.slots[i] == null:
			w.place_spell(i, inst)
			wand_changed.emit()
			return
	spell_bag.append(inst)
	wand_changed.emit()

func pickup_wand(w: Wand) -> void:
	if wands.size() < 2:
		wands.append(w)
	else:
		# Replace inactive wand; dump its spells into the bag.
		var idx := (active_wand_index + 1) % 2
		var old: Wand = wands[idx]
		for s in old.slots:
			if s != null:
				spell_bag.append(s)
		wands[idx] = w
	wand_changed.emit()
