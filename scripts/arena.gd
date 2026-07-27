extends Node2D
## The fight arena: spawns the Knight and the current boss, runs the
## intro/defeat/death flow of the rush.

const PlayerScene := preload("res://scenes/player.tscn")

var player: Player
var boss: BossBase

@onready var hud = $HUD


func _ready() -> void:
	player = PlayerScene.instantiate()
	player.position = ($SpawnPlayer as Marker2D).position
	add_child(player)
	player.died.connect(_on_player_died)
	hud.bind_player(player)
	_start_fight()


func _start_fight() -> void:
	var info: Dictionary = Game.current_boss()
	boss = load(info.scene).instantiate()
	boss.position = ($SpawnBoss as Marker2D).position
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	hud.bind_boss(boss)
	var sub := "Foe %d of %d" % [Game.index + 1, Game.roster.size()] if Game.mode == "rush" else "Practice"
	hud.show_banner(boss.boss_title, sub)
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(boss) and not boss.dead and is_instance_valid(player) and not player.dead:
		boss.activate(player)
		Game.timing = true


func _on_boss_defeated() -> void:
	Game.timing = false
	hud.show_banner("VANQUISHED", "")
	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(player) or player.dead:
		return
	if Game.advance():
		player.full_restore()
		_start_fight()
	else:
		Game.finish_run()


func _on_player_died() -> void:
	Game.timing = false
	Game.deaths += 1
	if is_instance_valid(boss):
		boss.active = false
	hud.show_banner("DEFEATED", "Try again...")
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		Game.to_menu()
