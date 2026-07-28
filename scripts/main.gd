class_name Main
extends Node2D
## Game root: owns the dungeon, player, camera and UI; handles run start,
## death, victory and restart.

@onready var dungeon: Dungeon = $Dungeon
@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera
@onready var hud = $UI/HUD
@onready var inventory = $UI/Inventory
@onready var overlay: Control = $UI/Overlay
@onready var overlay_title: Label = $UI/Overlay/Panel/VBox/Title
@onready var overlay_body: Label = $UI/Overlay/Panel/VBox/Body

func _ready() -> void:
	add_to_group("main")
	overlay.visible = false
	Game.start_run()
	dungeon.start(player)
	dungeon.room_changed.connect(_on_room_changed)
	player.died.connect(_on_player_died)
	Game.boss_defeated.connect(func(): hud.flash_message("The Giant Spider falls!"))
	hud.setup(player)
	inventory.setup(player)
	_on_room_changed(dungeon.current)

func _on_room_changed(room: Room) -> void:
	# Camera is static per-room: center on the room (rooms are viewport-ish
	# sized; use limits to keep inside).
	camera.position = room.size_px() / 2.0
	var zoom := minf(1280.0 / room.size_px().x, 720.0 / room.size_px().y)
	camera.zoom = Vector2(zoom, zoom) * 1.0
	hud.on_room_changed(room, dungeon.depth)

func _on_player_died() -> void:
	overlay_title.text = "You Died"
	overlay_body.text = "The forest claims another apprentice.\nRooms cleared: %d    Gold: %d\n\nPress R to try again." % [Game.rooms_cleared, Game.gold]
	overlay.visible = true

func show_victory() -> void:
	overlay_title.text = "Floor Cleared!"
	overlay_body.text = "The Giant Spider is slain — the way deeper stands open.\n(This build ends at the first boss.)\n\nRooms cleared: %d    Gold: %d\n\nPress R to play again." % [Game.rooms_cleared, Game.gold]
	overlay.visible = true
	get_tree().paused = false

func open_inventory_fuse_mode() -> void:
	inventory.open(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if inventory.visible:
			inventory.close()
		else:
			inventory.open(false)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		if overlay.visible or player.dead:
			get_tree().reload_current_scene()
