extends Node
## Deterministic coverage of every boss attack move. Run with:
##   godot --headless --path . res://tests/test_attacks.tscn

var fails := 0
var player: Player


func _ready() -> void:
	await _run()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		fails += 1
		printerr("FAIL: ", msg)


func _spawn_boss(path: String, pos: Vector2) -> BossBase:
	var b: BossBase = load(path).instantiate()
	b.position = pos
	add_child(b)
	# arm the boss without starting its random brain
	b.player = player
	b.active = true
	return b


func _cleanup(b: BossBase) -> void:
	if is_instance_valid(b):
		b.queue_free()
	for c in get_children():
		if c is Projectile:
			c.queue_free()
	player.full_restore()
	player.position = Vector2(400, 560)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame


func _run() -> void:
	var floor_body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(4000, 100)
	cs.shape = rs
	floor_body.add_child(cs)
	floor_body.position = Vector2(640, 650)
	add_child(floor_body)

	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(400, 560)
	add_child(player)
	for i in 10:
		await get_tree().physics_frame

	var b: BossBase

	b = _spawn_boss("res://scenes/bosses/gruz_mother.tscn", Vector2(880, 300))
	check(await b._hover(0.3), "gruz hover")
	check(await b._charge(), "gruz charge")
	check(await b._slam(), "gruz slam")
	check(await b._bounce_frenzy(), "gruz bounce frenzy")
	await _cleanup(b)

	b = _spawn_boss("res://scenes/bosses/false_knight.tscn", Vector2(880, 540))
	check(await b._leap(), "false knight leap")
	check(await b._mace_slam(false), "false knight mace slam")
	check(await b._mace_slam(true), "false knight mace slam enraged")
	check(await b._hop_barrage(true), "false knight hop barrage enraged")
	await _cleanup(b)

	b = _spawn_boss("res://scenes/bosses/hornet.tscn", Vector2(880, 560))
	check(await b._lunge(), "hornet lunge")
	check(await b._needle_throw(), "hornet needle throw")
	check(await b._dive(), "hornet dive")
	check(await b._thread_burst(), "hornet thread burst")
	await _cleanup(b)

	b = _spawn_boss("res://scenes/bosses/soul_master.tscn", Vector2(880, 300))
	check(await b._teleport_random(), "soul master teleport")
	check(await b._orbs(2), "soul master orbs")
	check(await b._dive_slam(), "soul master dive slam")
	await _cleanup(b)

	b = _spawn_boss("res://scenes/bosses/hollow_knight.tscn", Vector2(880, 540))
	check(await b._combo(true), "hollow knight combo")
	check(await b._lunge(true), "hollow knight double lunge")
	check(await b._blobs(), "hollow knight blobs")
	check(await b._void_pillars(), "hollow knight void pillars")
	await _cleanup(b)

	await get_tree().create_timer(0.6, true, false, true).timeout
	if fails == 0:
		print("ALL ATTACK TESTS PASSED")
	else:
		printerr(str(fails) + " ATTACK TESTS FAILED")
	get_tree().quit(1 if fails > 0 else 0)
