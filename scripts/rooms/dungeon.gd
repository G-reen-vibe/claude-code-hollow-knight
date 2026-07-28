class_name Dungeon
extends Node2D
## Drives the run: a forward-only chain of rooms. Each cleared room offers a
## choice of exit doors previewing the next room's reward type; the floor ends
## at a fixed depth with the boss door. No backtracking.

signal room_changed(room: Room)

const BOSS_DEPTH := 8            # boss door is guaranteed at this depth

var depth := 0
var current: Room
var player: Player

## Reward room types that can appear behind non-combat doors.
const REWARD_TYPES := ["spell", "gold", "relic", "shop", "workshop", "fountain"]

func start(p_player: Player) -> void:
	player = p_player
	depth = 0
	_build_room("start")

func _build_room(type: String) -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	# Purge cross-room leftovers (projectiles, pickups parented to old room
	# are freed with it; global-parented strays are grouped).
	var room := Room.new()
	add_child(room)
	room.build(type)
	current = room
	room.exit_chosen.connect(_on_exit_chosen)
	player.global_position = room.player_spawn()

	_populate(room, type)
	if not room.locked:
		_offer_exits(room)
	else:
		room.cleared.connect(func(): _offer_exits(room))
	room_changed.emit(room)

func _on_exit_chosen(type: String) -> void:
	depth += 1
	call_deferred("_build_room", type)

## Decide which doors the cleared room offers.
func _offer_exits(room: Room) -> void:
	if room.room_type == "boss":
		return   # victory portal handles the rest
	var next_depth := depth + 1
	if next_depth >= BOSS_DEPTH:
		room.open_exits(["boss"])
		return
	var offers: Array = []
	# Always one combat path; 1-2 alternates drawn without repeats.
	offers.append("combat")
	var pool := REWARD_TYPES.duplicate()
	pool.shuffle()
	var extra := 1 + (Game.rng.randi() % 2)
	for i in range(extra):
		offers.append(pool[i])
	# Reward rooms funnel back toward combat: never two reward doors of the
	# same type, and order shuffled so combat isn't always the top door.
	offers.shuffle()
	room.open_exits(offers)

func _populate(room: Room, type: String) -> void:
	match type:
		"start":
			_populate_start(room)
		"combat":
			_populate_combat(room)
		"spell":
			_populate_spell(room)
		"gold":
			_populate_gold(room)
		"relic":
			_populate_relic(room)
		"shop":
			_populate_shop(room)
		"workshop":
			_populate_workshop(room)
		"fountain":
			_populate_fountain(room)
		"boss":
			_populate_boss(room)

func _populate_start(room: Room) -> void:
	# A free spell pedestal to teach pickups.
	Interactables.SpellPedestal.spawn(room, room.size_px() / 2.0 + Vector2(0, -60), SpellDB.random_spell_id(Game.rng, 0.4), 0)

func _populate_combat(room: Room) -> void:
	var budget := 3 + depth
	var pool := [
		{"cls": Enemies.SmallSpider, "cost": 1, "min_depth": 0},
		{"cls": Enemies.CorruptedEye, "cost": 2, "min_depth": 1},
		{"cls": Enemies.BroodSpider, "cost": 2, "min_depth": 2},
		{"cls": Enemies.Worm, "cost": 3, "min_depth": 3},
	]
	var spent := 0
	var safety := 40
	while spent < budget and safety > 0:
		safety -= 1
		var pick: Dictionary = pool[Game.rng.randi_range(0, pool.size() - 1)]
		if pick["min_depth"] > depth or pick["cost"] > budget - spent:
			continue
		spent += pick["cost"]
		var e: EnemyBase = pick["cls"].new()
		var margin := 4.0 * Room.TILE
		e.position = Vector2(
			Game.rng.randf_range(room.size_px().x * 0.4, room.size_px().x - margin),
			Game.rng.randf_range(margin, room.size_px().y - margin))
		room.add_child(e)
		room.register_enemy(e)
	room.lock()
	# Cleared combat rooms drop a reward: a coin burst.
	room.cleared.connect(func():
		for i in range(Game.rng.randi_range(3, 5)):
			Pickup.spawn_coin(room, room.size_px() / 2.0 + Vector2(Game.rng.randf_range(-30, 30), Game.rng.randf_range(-30, 30))))

func _populate_spell(room: Room) -> void:
	# Choice of two free spells (taking one removes the other).
	var mid := room.size_px() / 2.0
	var a := SpellDB.random_spell_id(Game.rng, 0.65)
	var b := SpellDB.random_spell_id(Game.rng, 0.35)
	var pa := Interactables.SpellPedestal.spawn(room, mid + Vector2(-90, 0), a, 0)
	var pb := Interactables.SpellPedestal.spawn(room, mid + Vector2(90, 0), b, 0)
	pa.exclusive_with = pb
	pb.exclusive_with = pa

func _populate_gold(room: Room) -> void:
	var mid := room.size_px() / 2.0
	for i in range(Game.rng.randi_range(10, 16)):
		Pickup.spawn_coin(room, mid + Vector2(Game.rng.randf_range(-120, 120), Game.rng.randf_range(-80, 80)))
	Interactables.TreasureChest.spawn(room, mid + Vector2(0, -100))

func _populate_relic(room: Room) -> void:
	# Choice of relics: one free, one priced (higher value in spirit).
	var mid := room.size_px() / 2.0
	var r1 := RelicDB.random_relic_id(Game.rng, Game.relics)
	var r2 := RelicDB.random_relic_id(Game.rng, Game.relics + [r1])
	var s1 := Interactables.RelicStand.spawn(room, mid + Vector2(-90, 0), r1, 0)
	var s2 := Interactables.RelicStand.spawn(room, mid + Vector2(90, 0), r2, RelicDB.get_relic(r2).get("price", 50) / 2)
	s1.exclusive_with = s2
	s2.exclusive_with = s1

func _populate_shop(room: Room) -> void:
	var mid := room.size_px() / 2.0
	var offers: Array = []
	for i in range(2):
		offers.append({"kind": "spell", "id": SpellDB.random_spell_id(Game.rng)})
	offers.append({"kind": "relic", "id": RelicDB.random_relic_id(Game.rng, Game.relics)})
	offers.append({"kind": "heal", "id": ""})
	for i in range(offers.size()):
		var x := mid.x + (i - 1.5) * 140.0
		Interactables.ShopItem.spawn(room, Vector2(x, mid.y), offers[i])

func _populate_workshop(room: Room) -> void:
	Interactables.WorkshopBench.spawn(room, room.size_px() / 2.0)

func _populate_fountain(room: Room) -> void:
	Interactables.HealingFountain.spawn(room, room.size_px() / 2.0)

func _populate_boss(room: Room) -> void:
	var boss := GiantSpider.new()
	boss.position = Vector2(room.size_px().x * 0.72, room.size_px().y / 2.0)
	room.add_child(boss)
	room.register_enemy(boss)
	room.lock()
	Sfx.play("boss_roar")
	room.cleared.connect(func():
		Interactables.VictoryPortal.spawn(room, room.size_px() / 2.0)
		Game.on_boss_defeated())
