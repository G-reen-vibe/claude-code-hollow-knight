extends Control
## In-game HUD: health/mana bars, gold, depth, active wand slot rack, boss bar.

var player: Player
var boss: GiantSpider

@onready var hp_bar: ProgressBar = $TopLeft/HpBar
@onready var hp_label: Label = $TopLeft/HpBar/HpLabel
@onready var mana_bar: ProgressBar = $TopLeft/ManaBar
@onready var mana_label: Label = $TopLeft/ManaBar/ManaLabel
@onready var gold_label: Label = $TopLeft/GoldLabel
@onready var depth_label: Label = $TopRight/DepthLabel
@onready var slot_rack: HBoxContainer = $Bottom/SlotRack
@onready var wand_label: Label = $Bottom/WandLabel
@onready var boss_bar: ProgressBar = $BossBar
@onready var boss_label: Label = $BossBar/BossLabel
@onready var message: Label = $Message

func setup(p: Player) -> void:
	player = p
	player.health_changed.connect(_on_health)
	player.mana_changed.connect(_on_mana)
	player.wand_changed.connect(_rebuild_rack)
	Game.gold_changed.connect(func(g): gold_label.text = "Gold: %d" % g)
	Game.relic_gained.connect(func(id): flash_message("Relic: %s" % RelicDB.get_relic(id).get("name", id)))
	_on_health(player.hp, player.max_hp)
	gold_label.text = "Gold: %d" % Game.gold
	boss_bar.visible = false
	message.text = ""
	_rebuild_rack()

func _on_health(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = maxf(hp, 0.0)
	hp_label.text = "%d / %d" % [int(maxf(hp, 0)), int(max_hp)]

func _on_mana(mana: float, max_mana: float) -> void:
	mana_bar.max_value = max_mana
	mana_bar.value = mana
	mana_label.text = "%d / %d" % [int(mana), int(max_mana)]

func on_room_changed(room: Room, depth: int) -> void:
	depth_label.text = "Dark Forest — Room %d" % (depth + 1)
	boss = null
	boss_bar.visible = false
	# Watch for a boss in this room.
	await get_tree().process_frame
	if not is_instance_valid(room):
		return
	for e in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e):
			boss = e
			boss_bar.visible = true
			boss_label.text = boss.boss_name
			boss_bar.max_value = boss.max_hp
	if room.room_type == "boss":
		flash_message("The Giant Spider skitters from the dark...")

func _process(_delta: float) -> void:
	if boss != null and is_instance_valid(boss) and not boss.dead:
		boss_bar.value = maxf(boss.hp, 0.0)
	elif boss_bar.visible and (boss == null or not is_instance_valid(boss) or boss.dead):
		boss_bar.visible = false

func _rebuild_rack() -> void:
	for c in slot_rack.get_children():
		c.queue_free()
	var w := player.active_wand()
	wand_label.text = "%s   [Tab] inventory  [Q] swap wand" % w.display_name
	for i in range(w.slot_count):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(44, 44)
		var tex := TextureRect.new()
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(40, 40)
		var s = w.slots[i]
		if s != null:
			tex.texture = Art.tex(s.get("icon", "icon_bullet"))
			panel.tooltip_text = "%s\n%s" % [s.get("name", "?"), s.get("desc", "")]
		else:
			tex.texture = Art.tex("spell_frame")
			tex.modulate = Color(1, 1, 1, 0.4)
		panel.add_child(tex)
		slot_rack.add_child(panel)

func flash_message(text: String) -> void:
	message.text = text
	message.modulate.a = 1.0
	var tw := message.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(message, "modulate:a", 0.0, 0.7)
