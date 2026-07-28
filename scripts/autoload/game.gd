extends Node
## Global run state: gold, relics, run flow signals. Reset per run.

signal gold_changed(amount: int)
signal relic_gained(relic_id: String)
signal boss_defeated
signal player_died

var gold: int = 0
var relics: Array[String] = []
var rooms_cleared: int = 0
var run_active: bool = false
var rng := RandomNumberGenerator.new()

## Set false by the headless test harness to make runs deterministic.
var randomize_runs: bool = true

func start_run() -> void:
	gold = 0
	relics = []
	rooms_cleared = 0
	run_active = true
	if randomize_runs:
		rng.randomize()
	else:
		rng.seed = 1337
	gold_changed.emit(gold)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	if amount > 0:
		Sfx.play("coin")

func try_spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func gain_relic(relic_id: String) -> void:
	relics.append(relic_id)
	relic_gained.emit(relic_id)
	Sfx.play("pickup")

func has_relic(relic_id: String) -> bool:
	return relic_id in relics

func relic_count(relic_id: String) -> int:
	return relics.count(relic_id)

func on_boss_defeated() -> void:
	run_active = false
	boss_defeated.emit()

func on_player_died() -> void:
	run_active = false
	player_died.emit()
