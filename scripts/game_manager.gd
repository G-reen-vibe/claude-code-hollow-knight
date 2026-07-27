extends Node
## Autoload "Game": run state for the boss rush, scene flow, screen shake and hitstop.

signal screen_shake(amount: float)

var roster: Array = [
	{"scene": "res://scenes/bosses/gruz_mother.tscn", "title": "Gruz Mother"},
	{"scene": "res://scenes/bosses/false_knight.tscn", "title": "False Knight"},
	{"scene": "res://scenes/bosses/hornet.tscn", "title": "Hornet"},
	{"scene": "res://scenes/bosses/soul_master.tscn", "title": "Soul Master"},
	{"scene": "res://scenes/bosses/hollow_knight.tscn", "title": "The Hollow Knight"},
]

var mode := "rush"  # "rush" | "single"
var index := 0
var deaths := 0
var run_time := 0.0
var timing := false
var victory := false

var _hitstopping := false


func _process(delta: float) -> void:
	if timing:
		run_time += delta


func start_rush() -> void:
	mode = "rush"
	index = 0
	deaths = 0
	run_time = 0.0
	victory = false
	timing = false
	_go("res://scenes/arena.tscn")


func start_single(boss_index: int) -> void:
	mode = "single"
	index = boss_index
	deaths = 0
	run_time = 0.0
	victory = false
	timing = false
	_go("res://scenes/arena.tscn")


func current_boss() -> Dictionary:
	return roster[index]


## Advances to the next boss; returns true if there is one.
func advance() -> bool:
	if mode == "single":
		return false
	index += 1
	return index < roster.size()


func finish_run() -> void:
	victory = true
	timing = false
	_go("res://scenes/results.tscn")


func to_menu() -> void:
	timing = false
	_go("res://scenes/main_menu.tscn")


func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)


func shake(amount: float) -> void:
	screen_shake.emit(amount)


func hitstop(dur := 0.08) -> void:
	if _hitstopping:
		return
	_hitstopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstopping = false


func fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%02d:%05.2f" % [m, s]
