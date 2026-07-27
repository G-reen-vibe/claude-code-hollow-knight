extends Node
## Verifies the boss-rush flow inside the arena: intro activation, defeat,
## advancing to the next boss and healing the player between fights.
## Run with: godot --headless --path . res://tests/test_rush_flow.tscn

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		fails += 1
		printerr("FAIL: ", msg)


func _ready() -> void:
	Game.mode = "rush"
	Game.index = 0
	Game.deaths = 0
	Game.run_time = 0.0
	var arena: Node2D = load("res://scenes/arena.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	var boss1: BossBase = arena.boss
	check(boss1 != null and boss1.boss_title == "Gruz Mother", "first boss is Gruz Mother")

	var t := 0.0
	while is_instance_valid(boss1) and not boss1.active and t < 3.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check(is_instance_valid(boss1) and boss1.active, "boss activates after intro banner")
	check(Game.timing, "run timer starts with the fight")

	arena.player.hp = 3  # chip damage; should be healed before the next fight
	boss1.take_hit(99999, Vector2.RIGHT)
	check(boss1.dead, "boss dies from lethal hit")

	await get_tree().create_timer(3.2, true, false, true).timeout
	check(Game.index == 1, "rush advances to the next boss")
	check(is_instance_valid(arena.boss) and arena.boss.boss_title == "False Knight",
		"second boss spawns in the same arena")
	check(arena.player.hp == arena.player.max_hp, "player fully healed between fights")

	await get_tree().create_timer(0.5, true, false, true).timeout
	if fails == 0:
		print("ALL RUSH FLOW TESTS PASSED")
	else:
		printerr(str(fails) + " RUSH FLOW TESTS FAILED")
	get_tree().quit(1 if fails > 0 else 0)
