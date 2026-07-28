extends Node
## Passive relics (run-long artifacts), modeled on Magicraft's relic pool.
## Effects are queried by the systems they touch via mult()/bonus().

const RELICS := {
	"replica_glove": {
		"name": "Replica Glove",
		"desc": "25% chance to duplicate a cast for free.",
		"price": 65,
		"echo_chance": 0.25,
	},
	"prospectors_pickaxe": {
		"name": "Prospector's Pickaxe",
		"desc": "+1% spell damage per 3 coins held.",
		"price": 55,
		"coin_damage": true,
	},
	"endless_chest": {
		"name": "Endless Chest",
		"desc": "Chests may spawn another chest when opened.",
		"price": 50,
		"chest_chance": 0.3,
	},
	"tome_of_vigor": {
		"name": "Tome of Vigor",
		"desc": "+20 max health.",
		"price": 50,
		"max_hp": 20.0,
	},
	"azure_crystal": {
		"name": "Azure Crystal",
		"desc": "+25 max mana on every wand.",
		"price": 50,
		"max_mana": 25.0,
	},
	"siphon_ring": {
		"name": "Siphon Ring",
		"desc": "Mana regenerates 40% faster.",
		"price": 60,
		"mana_regen_mult": 1.4,
	},
	"sharp_focus": {
		"name": "Sharp Focus",
		"desc": "All spells deal 15% more damage.",
		"price": 70,
		"damage_mult": 1.15,
	},
	"swift_boots": {
		"name": "Swift Boots",
		"desc": "Move 15% faster.",
		"price": 45,
		"speed_mult": 1.15,
	},
	"lucky_coin": {
		"name": "Lucky Coin",
		"desc": "Enemies drop 30% more gold.",
		"price": 40,
		"gold_mult": 1.3,
	},
	"blood_pact": {
		"name": "Blood Pact",
		"desc": "Heal 2 HP when a room is cleared.",
		"price": 55,
		"heal_on_clear": 2.0,
	},
}

func get_relic(id: String) -> Dictionary:
	return RELICS.get(id, {})

func all_ids() -> Array:
	return RELICS.keys()

func random_relic_id(rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var pool: Array = []
	for id in RELICS:
		if not (id in exclude):
			pool.append(id)
	if pool.is_empty():
		pool = RELICS.keys()
	return pool[rng.randi_range(0, pool.size() - 1)]

## Aggregate a numeric multiplier across owned relics (e.g. "damage_mult").
func mult(key: String) -> float:
	var m := 1.0
	for id in Game.relics:
		var r := get_relic(id)
		if r.has(key):
			m *= r[key]
	return m

## Aggregate an additive bonus across owned relics (e.g. "max_hp").
func bonus(key: String) -> float:
	var b := 0.0
	for id in Game.relics:
		var r := get_relic(id)
		if r.has(key):
			b += r[key]
	return b

## Prospector's Pickaxe: +1% damage per 3 coins currently held.
func coin_damage_bonus() -> float:
	for id in Game.relics:
		if get_relic(id).get("coin_damage", false):
			return 0.01 * (Game.gold / 3.0)
	return 0.0

## Total chance to duplicate a cast (Replica Glove etc.).
func echo_chance() -> float:
	var c := 0.0
	for id in Game.relics:
		c += get_relic(id).get("echo_chance", 0.0)
	return minf(c, 0.9)
