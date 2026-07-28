## Interactable props: spell pedestals, relic stands, treasure chests, shop
## stands, workshop fusion bench, healing fountain, victory portal.
## Each shows a prompt when the player is near and activates on "interact".

class_name Interactables

class InteractableBase extends Area2D:
	var prompt_text := "E: interact"
	## When set, taking this offer removes the linked one (choice pedestals).
	var exclusive_with: Node = null
	var _label: Label
	var _player_near := false
	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 34.0
		shape.shape = circ
		add_child(shape)
		_label = Label.new()
		_label.text = prompt_text
		_label.add_theme_font_size_override("font_size", 11)
		_label.position = Vector2(-60, -56)
		_label.size = Vector2(120, 30)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.visible = false
		add_child(_label)
		body_entered.connect(func(b):
			if b.is_in_group("player"):
				_player_near = true
				_label.visible = true)
		body_exited.connect(func(b):
			if b.is_in_group("player"):
				_player_near = false
				_label.visible = false)
	func _unhandled_input(event: InputEvent) -> void:
		if _player_near and event.is_action_pressed("interact"):
			var players := get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				activate(players[0])
	func consume() -> void:
		if exclusive_with != null and is_instance_valid(exclusive_with):
			exclusive_with.queue_free()
		queue_free()
	func activate(_player: Node) -> void:
		pass

class SpellPedestal extends InteractableBase:
	var spell_id := ""
	var price := 0
	static func spawn(parent: Node, pos: Vector2, p_spell: String, p_price: int) -> SpellPedestal:
		var p := SpellPedestal.new()
		p.spell_id = p_spell
		p.price = p_price
		p.position = pos
		parent.add_child(p)
		return p
	func _ready() -> void:
		var def := SpellDB.get_spell(spell_id)
		if price == 0:
			prompt_text = "E: take %s\n%s" % [def.get("name", "?"), def.get("desc", "")]
		else:
			prompt_text = "E: buy %s (%dg)\n%s" % [def.get("name", "?"), price, def.get("desc", "")]
		super._ready()
		var frame := Sprite2D.new()
		frame.texture = Art.tex("spell_frame")
		frame.scale = Vector2(2, 2)
		add_child(frame)
		var icon := Sprite2D.new()
		icon.texture = Art.tex(def.get("icon", "icon_bullet"))
		icon.scale = Vector2(1.8, 1.8)
		add_child(icon)
	func activate(player: Node) -> void:
		if price > 0 and not Game.try_spend(price):
			Sfx.play("hurt", 2.0)
			return
		player.pickup_spell(spell_id)
		Sfx.play("pickup")
		consume()

class RelicStand extends InteractableBase:
	var relic_id := ""
	var price := 0
	static func spawn(parent: Node, pos: Vector2, p_relic: String, p_price: int) -> RelicStand:
		var s := RelicStand.new()
		s.relic_id = p_relic
		s.price = p_price
		s.position = pos
		parent.add_child(s)
		return s
	func _ready() -> void:
		var def := RelicDB.get_relic(relic_id)
		if price == 0:
			prompt_text = "E: take %s\n%s" % [def.get("name", "?"), def.get("desc", "")]
		else:
			prompt_text = "E: %s (%dg)\n%s" % [def.get("name", "?"), price, def.get("desc", "")]
		super._ready()
		var spr := Sprite2D.new()
		spr.texture = Art.tex("shrine")
		spr.scale = Vector2(2, 2)
		add_child(spr)
	func activate(_player: Node) -> void:
		if price > 0 and not Game.try_spend(price):
			Sfx.play("hurt", 2.0)
			return
		Game.gain_relic(relic_id)
		consume()

class TreasureChest extends InteractableBase:
	var opened := false
	static func spawn(parent: Node, pos: Vector2) -> TreasureChest:
		var c := TreasureChest.new()
		c.position = pos
		parent.add_child(c)
		return c
	func _ready() -> void:
		prompt_text = "E: open chest"
		super._ready()
		var spr := Sprite2D.new()
		spr.texture = Art.tex("chest")
		spr.scale = Vector2(2, 2)
		add_child(spr)
	func activate(_player: Node) -> void:
		if opened:
			return
		opened = true
		Sfx.play("pickup")
		var relic := RelicDB.random_relic_id(Game.rng, Game.relics)
		Game.gain_relic(relic)
		for i in range(Game.rng.randi_range(4, 7)):
			Pickup.spawn_coin(get_parent(), global_position + Vector2(Game.rng.randf_range(-24, 24), Game.rng.randf_range(10, 30)))
		# Endless Chest relic: chance to spawn another chest.
		var chest_chance := 0.0
		for id in Game.relics:
			chest_chance += RelicDB.get_relic(id).get("chest_chance", 0.0)
		if Game.rng.randf() < chest_chance:
			TreasureChest.spawn(get_parent(), global_position + Vector2(60, 0))
		var def := RelicDB.get_relic(relic)
		_label.text = "%s!" % def.get("name", "Relic")
		_label.visible = true
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(self):
				queue_free())

class ShopItem extends InteractableBase:
	var offer: Dictionary = {}
	var price := 0
	static func spawn(parent: Node, pos: Vector2, p_offer: Dictionary) -> ShopItem:
		var s := ShopItem.new()
		s.offer = p_offer
		s.position = pos
		parent.add_child(s)
		return s
	func _ready() -> void:
		var tex_name := "spell_frame"
		match offer["kind"]:
			"spell":
				var def := SpellDB.get_spell(offer["id"])
				price = def.get("price", 30)
				prompt_text = "E: %s — %dg\n%s" % [def.get("name", "?"), price, def.get("desc", "")]
				tex_name = def.get("icon", "icon_bullet")
			"relic":
				var def := RelicDB.get_relic(offer["id"])
				price = def.get("price", 50)
				prompt_text = "E: %s — %dg\n%s" % [def.get("name", "?"), price, def.get("desc", "")]
				tex_name = "shrine"
			"heal":
				price = 25
				prompt_text = "E: Restore 40 HP — %dg" % price
				tex_name = "heart"
		super._ready()
		var frame := Sprite2D.new()
		frame.texture = Art.tex("spell_frame")
		frame.scale = Vector2(2.4, 2.4)
		add_child(frame)
		var icon := Sprite2D.new()
		icon.texture = Art.tex(tex_name)
		icon.scale = Vector2(1.6, 1.6)
		add_child(icon)
		var tag := Label.new()
		tag.text = "%dg" % price
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		tag.position = Vector2(-10, 26)
		add_child(tag)
	func activate(player: Node) -> void:
		if not Game.try_spend(price):
			Sfx.play("hurt", 2.0)
			return
		match offer["kind"]:
			"spell":
				player.pickup_spell(offer["id"])
			"relic":
				Game.gain_relic(offer["id"])
			"heal":
				player.heal(40.0)
		Sfx.play("pickup")
		queue_free()

## Workshop synthesis bench: opens the inventory in fuse mode, where two
## spells can be merged into one hybrid (irreversible).
class WorkshopBench extends InteractableBase:
	static func spawn(parent: Node, pos: Vector2) -> WorkshopBench:
		var b := WorkshopBench.new()
		b.position = pos
		parent.add_child(b)
		return b
	func _ready() -> void:
		prompt_text = "E: use fusion bench\n(select two spells to fuse)"
		super._ready()
		var spr := Sprite2D.new()
		spr.texture = Art.tex("bench")
		spr.scale = Vector2(2.5, 2.5)
		add_child(spr)
	func activate(_player: Node) -> void:
		get_tree().call_group("main", "open_inventory_fuse_mode")

class HealingFountain extends InteractableBase:
	var used := false
	static func spawn(parent: Node, pos: Vector2) -> HealingFountain:
		var f := HealingFountain.new()
		f.position = pos
		parent.add_child(f)
		return f
	func _ready() -> void:
		prompt_text = "E: drink (restore 50 HP)"
		super._ready()
		var spr := Sprite2D.new()
		spr.texture = Art.tex("fountain")
		spr.scale = Vector2(2.5, 2.5)
		add_child(spr)
	func activate(player: Node) -> void:
		if used:
			return
		used = true
		player.heal(50.0)
		Sfx.play("pickup")
		_label.text = "The fountain runs dry."
		modulate = Color(0.7, 0.7, 0.75)

class VictoryPortal extends InteractableBase:
	static func spawn(parent: Node, pos: Vector2) -> VictoryPortal:
		var p := VictoryPortal.new()
		p.position = pos
		parent.add_child(p)
		return p
	func _ready() -> void:
		prompt_text = "E: descend (end of demo)"
		super._ready()
		var spr := Sprite2D.new()
		spr.texture = Art.tex("portal")
		spr.scale = Vector2(2, 2)
		add_child(spr)
	func activate(_player: Node) -> void:
		get_tree().call_group("main", "show_victory")
