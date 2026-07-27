extends Node
## Headless integration tests. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits 0 on success, 1 on failure.

var fails := 0


func _ready() -> void:
	await _run()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		fails += 1
		printerr("FAIL: ", msg)


func _run() -> void:
	# all scenes load
	for p in [
		"res://scenes/main_menu.tscn", "res://scenes/results.tscn", "res://scenes/arena.tscn",
		"res://scenes/hud.tscn", "res://scenes/player.tscn", "res://scenes/fireball.tscn",
		"res://scenes/projectile.tscn",
	]:
		check(load(p) != null, p + " loads")

	# world floor for physics
	var floor_body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(4000, 100)
	cs.shape = rs
	floor_body.add_child(cs)
	floor_body.position = Vector2(640, 650)
	add_child(floor_body)

	# player basics
	var player: Player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(400, 560)
	add_child(player)
	for i in 30:
		await get_tree().physics_frame
	check(player.is_on_floor(), "player lands on floor")
	var hp0 := player.hp
	player.take_damage(1, player.global_position + Vector2(50, 0))
	check(player.hp == hp0 - 1, "player takes damage")
	check(player._iframes > 0.0, "player gains i-frames")
	player.take_damage(1, player.global_position)
	check(player.hp == hp0 - 1, "i-frames block repeat damage")
	player.gain_soul(50)
	check(player.soul == 50, "soul gain")
	player.gain_soul(200)
	check(player.soul == Player.SOUL_MAX, "soul caps at max")
	player.full_restore()
	check(player.hp == player.max_hp, "full restore heals")

	# let the damage hitstop (Engine.time_scale) fully restore before timing-sensitive checks
	await get_tree().create_timer(0.4, true, false, true).timeout
	check(Engine.time_scale == 1.0, "hitstop restores time scale")

	# fireball flies and survives a few frames
	var fb: Area2D = load("res://scenes/fireball.tscn").instantiate()
	fb.dir = 1
	fb.position = Vector2(500, 500)
	add_child(fb)
	for i in 10:
		await get_tree().physics_frame
	check(is_instance_valid(fb) and fb.position.x > 520.0, "fireball travels")
	if is_instance_valid(fb):
		fb.queue_free()

	# every boss: brain runs, takes damage, dies, emits defeated
	for info in Game.roster:
		var boss: BossBase = load(info.scene).instantiate()
		boss.position = Vector2(880, 500)
		add_child(boss)
		var defeated_flag := [false]
		boss.defeated.connect(func(): defeated_flag[0] = true)
		boss.activate(player)
		for i in 120:
			await get_tree().physics_frame
		check(is_instance_valid(boss) and not boss.dead, str(info.title) + " brain runs 120 frames")
		var bhp := boss.hp
		boss.take_hit(21, Vector2.RIGHT)
		check(boss.hp == bhp - 21, str(info.title) + " takes nail damage")
		boss.take_hit(99999, Vector2.RIGHT)
		check(boss.dead, str(info.title) + " dies")
		check(defeated_flag[0], str(info.title) + " emits defeated")
		for i in 40:
			await get_tree().physics_frame
		if is_instance_valid(boss):
			boss.queue_free()
		# clear any leftover projectiles from the fight
		for c in get_children():
			if c is Projectile:
				c.queue_free()
		player.full_restore()
		player.position = Vector2(400, 560)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame

	# player death signal
	var dead_flag := [false]
	player.died.connect(func(): dead_flag[0] = true)
	var guard := 0
	while player.hp > 0 and guard < 20:
		guard += 1
		player._iframes = 0.0
		player.take_damage(1, player.global_position + Vector2(10, 0))
	check(dead_flag[0], "player death signal fires")
	check(player.dead, "player marked dead")

	# let hitstop timers settle before quitting
	await get_tree().create_timer(0.6, true, false, true).timeout
	if fails == 0:
		print("ALL TESTS PASSED")
	else:
		printerr(str(fails) + " TESTS FAILED")
	get_tree().quit(1 if fails > 0 else 0)
