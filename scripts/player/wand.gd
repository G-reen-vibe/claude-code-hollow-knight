class_name Wand
extends RefCounted
## A wand is a rack of spell slots cast in sequence, Magicraft-style. Holding
## fire walks the cast cursor left-to-right through the slots. Enhancement
## (modifier) spells switch on when the cursor passes them and stay active for
## ALL projectile spells to their right, until the sequence loops. Duplicate
## modifiers with the same id do not stack. Each wand owns its own mana pool
## and regen; after the last slot the wand pays a recharge pause and loops.

var display_name := "Apprentice Wand"
var slot_count := 3
var slots: Array = []          # Array[Dictionary or null] — spell instances
var mana_max := 100.0
var mana := 100.0
var mana_regen := 16.0         # per second
var base_cast_delay := 0.1     # wand's own delay between casts
var recharge_time := 0.5       # extra pause after the sequence loops

var _cursor := 0
var _cooldown := 0.0
var _active_mods: Array = []   # modifiers passed so far this sequence

func _init(p_name := "Apprentice Wand", p_slots := 3, p_mana := 100.0, p_regen := 16.0, p_delay := 0.1, p_recharge := 0.5) -> void:
	display_name = p_name
	slot_count = p_slots
	mana_max = p_mana
	mana = p_mana
	mana_regen = p_regen
	base_cast_delay = p_delay
	recharge_time = p_recharge
	slots.resize(slot_count)

func effective_mana_max() -> float:
	return mana_max + RelicDB.bonus("max_mana")

func tick(delta: float) -> void:
	mana = minf(effective_mana_max(), mana + mana_regen * RelicDB.mult("mana_regen_mult") * delta)
	_cooldown = maxf(0.0, _cooldown - delta)

func can_cast() -> bool:
	return _cooldown <= 0.0

func reset_sequence() -> void:
	_cursor = 0
	_active_mods.clear()

## Attempt one cast step. Returns a list of shot definitions to spawn (empty
## when a modifier slot was processed or nothing could be cast).
func cast_step() -> Array:
	if _cooldown > 0.0:
		return []
	if _filled_count() == 0:
		return []
	var safety := slot_count + 1
	while safety > 0:
		safety -= 1
		if _cursor >= slot_count:
			_loop_sequence()
			return []
		var spell = slots[_cursor]
		if spell == null:
			_cursor += 1
			continue
		if not SpellDB.is_projectile(spell):
			# Enhancement: activate (dedup by id) and keep walking; costs mana.
			if not _try_pay(spell, []):
				_cooldown = 0.1
				return []
			_activate_mod(spell)
			_cursor += 1
			continue
		# Projectile: pay (modifiers may discount), fire, set delay.
		var mods := _mods_for(spell)
		if not _try_pay(spell, mods):
			_cooldown = 0.1
			return []
		_cursor += 1
		var shots := _build_shots(spell, mods)
		_cooldown = _resolve_delay(spell, mods)
		if _cursor >= slot_count:
			_cursor = 0
			_active_mods.clear()
			_cooldown += recharge_time
		return shots
	_loop_sequence()
	return []

func _loop_sequence() -> void:
	_cursor = 0
	_active_mods.clear()
	_cooldown = maxf(_cooldown, recharge_time)

func _filled_count() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n

func _try_pay(spell: Dictionary, mods: Array) -> bool:
	var cost: float = spell.get("mana", 0.0)
	for m in mods:
		cost *= m.get("mana_mult", 1.0)
	if mana < cost:
		return false
	mana -= cost
	return true

func _activate_mod(mod: Dictionary) -> void:
	var pieces := [mod]
	for extra in mod.get("stacked_mods", []):
		pieces.append(extra)
	for piece in pieces:
		var pid: String = piece.get("id", piece.get("name", ""))
		var dupe := false
		for existing in _active_mods:
			if existing.get("id", existing.get("name", "")) == pid:
				dupe = true
				break
		if not dupe:
			_active_mods.append(piece)

## Modifiers affecting one projectile spell: everything activated to its left
## this sequence, plus any modifiers baked in by Workshop fusion.
func _mods_for(spell: Dictionary) -> Array:
	var mods := _active_mods.duplicate()
	for m in spell.get("baked_mods", []):
		mods.append(m)
	return mods

func _resolve_delay(spell: Dictionary, mods: Array) -> float:
	var d: float = base_cast_delay + spell.get("cast_delay", 0.2)
	for m in mods:
		d *= m.get("delay_mult", 1.0)
	return d

## Build concrete shot stat blocks, applying modifiers and merged payloads.
func _build_shots(spell: Dictionary, mods: Array) -> Array:
	var shots: Array = []
	var payloads: Array = [spell]
	for p in spell.get("extra_payloads", []):
		payloads.append(p)
	for payload in payloads:
		var count: int = payload.get("count", 1)
		var damage: float = payload.get("damage", 1.0)
		var speed: float = payload.get("speed", 400.0)
		var spread := 0.0
		var pierce: int = payload.get("pierce", 0)
		var bounce: int = payload.get("bounce", 0)
		var homing: float = payload.get("homing_strength", 0.0)
		var poison := 0.0
		var poison_time := 0.0
		var split_children := 0
		for m in mods:
			count += m.get("add_count", 0)
			damage *= m.get("damage_mult", 1.0)
			speed *= m.get("speed_mult", 1.0)
			spread = maxf(spread, m.get("spread_deg", 0.0))
			pierce += m.get("add_pierce", 0)
			bounce += m.get("add_bounce", 0)
			homing = maxf(homing, m.get("homing", 0.0))
			poison = maxf(poison, m.get("poison", 0.0))
			poison_time = maxf(poison_time, m.get("poison_time", 0.0))
			split_children += m.get("split_children", 0)
		damage *= RelicDB.mult("damage_mult")
		damage *= 1.0 + RelicDB.coin_damage_bonus()
		var shot := {
			"proj": payload.get("proj", "proj_bullet"),
			"damage": damage,
			"speed": speed,
			"lifetime": payload.get("lifetime", 1.5),
			"count": count,
			"spread_deg": spread if count > 1 else 0.0,
			"pierce": pierce,
			"bounce": bounce,
			"homing": homing,
			"explode_radius": payload.get("explode_radius", 0.0),
			"slow": payload.get("slow", 0.0),
			"slow_time": payload.get("slow_time", 0.0),
			"amp": payload.get("amp", 0.0),
			"amp_time": payload.get("amp_time", 0.0),
			"growth": payload.get("growth", 0.0),
			"poison": poison,
			"poison_time": poison_time,
			"split_children": split_children,
		}
		shots.append(shot)
	return shots

## ---- inventory helpers ----

func place_spell(index: int, inst) -> bool:
	if index < 0 or index >= slot_count:
		return false
	slots[index] = inst
	reset_sequence()
	return true

func remove_spell(index: int):
	if index < 0 or index >= slot_count:
		return null
	var s = slots[index]
	slots[index] = null
	reset_sequence()
	return s
