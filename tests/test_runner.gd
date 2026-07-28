extends Node
## Headless test suite. Run with:
##   godot --headless --path . res://tests/TestRunner.tscn
## Exits 0 on success, 1 on any failure.

var _failures: Array[String] = []
var _passes := 0

func _ready() -> void:
	Game.randomize_runs = false
	await _run_all()
	print("==========================================")
	print("PASS: %d   FAIL: %d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: " + f)
	print("==========================================")
	get_tree().quit(0 if _failures.is_empty() else 1)

func check(cond: bool, name: String) -> void:
	if cond:
		_passes += 1
		print("  ok - " + name)
	else:
		_failures.append(name)
		print("  FAIL - " + name)

func _run_all() -> void:
	print("== Wand engine ==")
	_test_wand_basic_cast()
	_test_modifier_applies_right()
	_test_modifier_no_same_id_stack()
	_test_mana_gating()
	print("== Spell fusion ==")
	_test_merge_projectiles()
	_test_merge_proj_mod()
	_test_merge_same_id_levels()
	print("== Relics ==")
	_test_relics()
	print("== Combat simulation ==")
	await _test_projectile_kills_enemy()
	await _test_poison_and_amp()
	print("== Boss fight ==")
	await _test_boss_behavior()
	print("== Full run integration ==")
	await _test_full_run()

# ---------- unit: wand ----------

func _drain(w: Wand, max_steps := 20) -> Array:
	# Step the wand until it produces shots or gives up.
	for i in range(max_steps):
		w._cooldown = 0.0
		var shots := w.cast_step()
		if not shots.is_empty():
			return shots
	return []

func _test_wand_basic_cast() -> void:
	Game.start_run()
	var w := Wand.new("Test", 3, 100.0, 20.0, 0.1, 0.4)
	w.place_spell(0, SpellDB.make_instance("magic_bullet"))
	var shots := _drain(w)
	check(shots.size() == 1, "single bullet produces one shot")
	check(absf(w.mana - 97.0) < 0.01, "mana deducted by bullet cost")
	check(shots[0]["damage"] == 6.0, "base damage carried")
	check(shots[0]["amp"] > 0.0, "magic bullet carries amp debuff")

func _test_modifier_applies_right() -> void:
	Game.start_run()
	var w := Wand.new("Test", 3, 200.0, 20.0, 0.1, 0.4)
	w.place_spell(0, SpellDB.make_instance("volley"))
	w.place_spell(1, SpellDB.make_instance("magic_bullet"))
	w.place_spell(2, SpellDB.make_instance("bings_arrow"))
	var first := _drain(w)
	check(first.size() == 1 and first[0]["count"] == 3, "volley boosts first projectile to its right (count 3)")
	var second := _drain(w)
	check(second.size() == 1 and second[0]["count"] == 3, "volley persists for ALL spells to its right")
	check(second[0]["pierce"] == 1, "arrow keeps its innate pierce")
	# After looping, a spell placed LEFT of the modifier is unaffected.
	var w2 := Wand.new("Test2", 3, 200.0, 20.0, 0.1, 0.4)
	w2.place_spell(0, SpellDB.make_instance("magic_bullet"))
	w2.place_spell(1, SpellDB.make_instance("volley"))
	w2.place_spell(2, SpellDB.make_instance("bings_arrow"))
	var s1 := _drain(w2)
	check(s1[0]["count"] == 1, "spell left of modifier is unaffected")
	var s2 := _drain(w2)
	check(s2[0]["count"] == 3, "spell right of modifier is affected")

func _test_modifier_no_same_id_stack() -> void:
	Game.start_run()
	var w := Wand.new("Test", 3, 200.0, 20.0, 0.1, 0.4)
	w.place_spell(0, SpellDB.make_instance("volley"))
	w.place_spell(1, SpellDB.make_instance("volley"))
	w.place_spell(2, SpellDB.make_instance("magic_bullet"))
	var shots := _drain(w)
	check(shots[0]["count"] == 3, "duplicate same-id modifiers do not stack")

func _test_mana_gating() -> void:
	Game.start_run()
	var w := Wand.new("Test", 1, 10.0, 0.0, 0.1, 0.4)
	w.mana = 2.0
	w.place_spell(0, SpellDB.make_instance("magic_bullet"))
	w._cooldown = 0.0
	var shots := w.cast_step()
	check(shots.is_empty(), "cast stalls when mana is insufficient")
	w.mana = 5.0
	w._cooldown = 0.0
	shots = w.cast_step()
	check(shots.size() == 1, "cast succeeds once mana regenerates")

# ---------- unit: fusion ----------

func _test_merge_projectiles() -> void:
	var a := SpellDB.make_instance("magic_bullet")
	var b := SpellDB.make_instance("bings_arrow")
	var m := SpellDB.merge(a, b)
	check(m.get("extra_payloads", []).size() == 1, "proj+proj fuse fires both payloads from one slot")
	var w := Wand.new("Test", 1, 200.0, 20.0, 0.1, 0.4)
	w.place_spell(0, m)
	var shots := _drain(w)
	check(shots.size() == 2, "fused projectile emits two shots")

func _test_merge_proj_mod() -> void:
	var a := SpellDB.make_instance("magic_bullet")
	var b := SpellDB.make_instance("track")
	var m := SpellDB.merge(a, b)
	check(m.get("baked_mods", []).size() == 1, "proj+modifier fuse bakes the modifier in")
	var w := Wand.new("Test", 1, 200.0, 20.0, 0.1, 0.4)
	w.place_spell(0, m)
	var shots := _drain(w)
	check(shots[0]["homing"] > 0.0, "baked Track grants homing")

func _test_merge_same_id_levels() -> void:
	var a := SpellDB.make_instance("magic_bullet")
	var b := SpellDB.make_instance("magic_bullet")
	var m := SpellDB.merge(a, b)
	check(m.get("level", 1) == 2, "fusing two identical spells levels up")
	check(m["damage"] > a["damage"], "leveled spell hits harder")

# ---------- unit: relics ----------

func _test_relics() -> void:
	Game.start_run()
	Game.gain_relic("sharp_focus")
	check(absf(RelicDB.mult("damage_mult") - 1.15) < 0.001, "Sharp Focus damage multiplier")
	Game.gain_relic("prospectors_pickaxe")
	Game.add_gold(30)
	check(absf(RelicDB.coin_damage_bonus() - 0.1) < 0.001, "Prospector's Pickaxe scales with gold")
	var w := Wand.new("Test", 1, 200.0, 20.0, 0.1, 0.4)
	w.place_spell(0, SpellDB.make_instance("magic_bullet"))
	var shots := _drain(w)
	check(shots[0]["damage"] > 6.0 * 1.14, "relic bonuses reach shot damage")
	Game.start_run()   # reset relics for later tests

# ---------- integration helpers ----------

func _make_arena() -> Node2D:
	var arena := Node2D.new()
	add_child(arena)
	return arena

func _wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

# ---------- integration: combat ----------

func _test_projectile_kills_enemy() -> void:
	Game.start_run()
	var arena := _make_arena()
	var spider := Enemies.SmallSpider.new()
	spider.position = Vector2(200, 0)
	arena.add_child(spider)
	var died := [false]
	spider.enemy_died.connect(func(_e): died[0] = true)
	# Fire bullets straight at it.
	var stats := {"proj": "proj_bullet", "damage": 10.0, "speed": 600.0, "lifetime": 1.0, "count": 1, "pierce": 0, "bounce": 0}
	for i in range(3):
		Projectile.spawn(arena, Vector2(0, 0), Vector2.RIGHT, stats)
		await _wait_frames(30)
	check(died[0], "projectiles damage and kill a small spider")
	var coins := 0
	for c in arena.get_children():
		if c is Pickup and c.kind == "coin":
			coins += 1
	check(coins >= 1, "dead spider drops gold")
	arena.queue_free()
	await _wait_frames(2)

func _test_poison_and_amp() -> void:
	Game.start_run()
	var arena := _make_arena()
	var spider := Enemies.BroodSpider.new()
	spider.position = Vector2(5000, 5000)   # far from any player influence
	arena.add_child(spider)
	await _wait_frames(2)
	var hp0 := spider.hp
	spider.apply_poison(10.0, 1.0)
	await _wait_frames(70)   # ~1.1s
	check(spider.hp < hp0 - 5.0, "poison ticks damage over time")
	var hp1 := spider.hp
	spider.apply_amp(0.5, 5.0)
	spider.take_damage(10.0)
	check(absf((hp1 - spider.hp) - 15.0) < 0.5, "amp mark increases damage taken by 50%")
	arena.queue_free()
	await _wait_frames(2)

# ---------- integration: boss ----------

func _test_boss_behavior() -> void:
	Game.start_run()
	var arena := _make_arena()
	# Fake player so the boss has a target.
	var fake_player := CharacterBody2D.new()
	fake_player.add_to_group("player")
	fake_player.position = Vector2(0, 0)
	var pshape := CollisionShape2D.new()
	var pcirc := CircleShape2D.new()
	pcirc.radius = 10
	pshape.shape = pcirc
	fake_player.add_child(pshape)
	arena.add_child(fake_player)
	var boss := GiantSpider.new()
	boss.position = Vector2(300, 0)
	arena.add_child(boss)
	await _wait_frames(2)
	check(boss.intensity() == 1, "boss starts at intensity 1")
	boss.take_damage(300.0)
	check(boss.intensity() == 2, "boss escalates at 66% HP")
	boss.take_damage(200.0)
	check(boss.intensity() == 3, "boss escalates again at 33% HP")
	# Let it act; webs/charges should appear within a few seconds.
	var saw_web := false
	var saw_charge := false
	for i in range(60 * 8):
		await get_tree().physics_frame
		if boss._state == "charging":
			saw_charge = true
		for c in arena.get_children():
			if c is Enemies.EnemyBolt:
				saw_web = true
		if saw_web and saw_charge:
			break
	check(saw_charge, "boss performs its linear charge")
	check(saw_web, "boss fires web/projectile volleys")
	var died := [false]
	boss.enemy_died.connect(func(_e): died[0] = true)
	boss.take_damage(500.0)
	check(died[0], "boss dies when HP is exhausted")
	arena.queue_free()
	await _wait_frames(2)

# ---------- integration: full run ----------

func _test_full_run() -> void:
	Game.randomize_runs = false
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main = main_scene.instantiate()
	add_child(main)
	await _wait_frames(5)
	var dungeon: Dungeon = main.get_node("Dungeon")
	var player: Player = main.get_node("Player")
	check(dungeon.current != null and dungeon.current.room_type == "start", "run begins in the start room")
	check(player.active_wand().slots[0] != null and player.active_wand().slots[0]["id"] == "magic_bullet", "starter wand is loaded with Magic Bullet")
	check(player.spell_bag.size() == 3, "three spare Magic Bullets in the backpack")
	check(dungeon.current.exits_open, "start room offers exit doors immediately")

	var boss_reached := false
	var victory := [false]
	Game.boss_defeated.connect(func(): victory[0] = true)

	# March through the floor: pick the first exit each time, clear rooms by
	# slaying enemies directly (the wand is separately unit-tested).
	for hop in range(24):
		var room := dungeon.current
		if room.room_type == "boss":
			boss_reached = true
			break
		if room.locked:
			# Kill in passes: brood spiders release hatchlings on death.
			for kill_pass in range(6):
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and not e.dead:
						e.take_damage(10000.0)
				await _wait_frames(10)
				if not room.locked:
					break
			check(dungeon.current.exits_open or dungeon.current.room_type == "boss", "combat room opens exits after clear (hop %d)" % hop)
		if not room.exits_open:
			await _wait_frames(10)
		# Walk into the first exit door.
		var chosen := [false]
		room.exit_chosen.connect(func(_t): chosen[0] = true)
		if room._exit_nodes.is_empty():
			check(false, "room has exit doors (hop %d)" % hop)
			break
		var door: Node2D = room._exit_nodes[0]
		player.global_position = door.global_position
		await _wait_frames(10)
		if not chosen[0] and room.exits_open:
			check(false, "walking into a door advances the run (hop %d)" % hop)
			break
		await _wait_frames(5)
	check(boss_reached, "floor funnels into the boss room by depth %d" % Dungeon.BOSS_DEPTH)

	if boss_reached:
		await _wait_frames(10)
		var bosses := get_tree().get_nodes_in_group("boss")
		check(bosses.size() == 1, "boss room contains the Giant Spider")
		if bosses.size() == 1:
			var boss: GiantSpider = bosses[0]
			# Kill adds first, then the boss.
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead:
					e.take_damage(10000.0)
			await _wait_frames(30)
			check(victory[0], "killing the Giant Spider wins the floor")
			var portal_found := false
			for c in dungeon.current.get_children():
				if c is Interactables.VictoryPortal:
					portal_found = true
			check(portal_found, "victory portal appears after the boss dies")
	main.queue_free()
	await _wait_frames(2)
