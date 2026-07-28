extends Control
## Inventory panel: rearrange spells between wand slots and backpack by
## clicking two positions to swap. At a Workshop bench it opens in FUSE mode:
## select two spells to merge them into one (irreversible).

var player: Player
var fuse_mode := false
## Selected position: {"where": "wand"/"bag", "wand": int, "index": int} or {}.
var _selected: Dictionary = {}

@onready var title: Label = $Panel/VBox/Title
@onready var hint: Label = $Panel/VBox/Hint
@onready var wand_box: VBoxContainer = $Panel/VBox/Wands
@onready var bag_grid: GridContainer = $Panel/VBox/BagScroll/BagGrid

func setup(p: Player) -> void:
	player = p
	visible = false

func open(p_fuse: bool) -> void:
	fuse_mode = p_fuse
	_selected = {}
	visible = true
	get_tree().paused = true
	title.text = "Workshop — Fusion Bench" if fuse_mode else "Spell Inventory"
	hint.text = ("Select TWO spells to fuse into one. Fusion is permanent."
		if fuse_mode else "Click two positions to swap spells. Esc/Tab to close.")
	_rebuild()

func close() -> void:
	visible = false
	get_tree().paused = false
	player.active_wand().reset_sequence()
	player.wand_changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE)):
		close()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for c in wand_box.get_children():
		c.queue_free()
	for c in bag_grid.get_children():
		c.queue_free()
	for wi in range(player.wands.size()):
		var w: Wand = player.wands[wi]
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s%s  (MP %d/%d)" % [w.display_name, " [active]" if wi == player.active_wand_index else "", int(w.mana), int(w.effective_mana_max())]
		name_label.custom_minimum_size = Vector2(230, 0)
		row.add_child(name_label)
		for si in range(w.slot_count):
			row.add_child(_make_slot_button(w.slots[si], {"where": "wand", "wand": wi, "index": si}))
		wand_box.add_child(row)
	for bi in range(player.spell_bag.size()):
		bag_grid.add_child(_make_slot_button(player.spell_bag[bi], {"where": "bag", "wand": -1, "index": bi}))
	# Pad the bag with a couple of empty drop targets.
	for i in range(2):
		bag_grid.add_child(_make_slot_button(null, {"where": "bag", "wand": -1, "index": player.spell_bag.size() + i}))

func _make_slot_button(spell, pos: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.expand_icon = true
	if spell != null:
		b.icon = Art.tex(spell.get("icon", "icon_bullet"))
		b.tooltip_text = "%s (MP %d)\n%s" % [spell.get("name", "?"), int(spell.get("mana", 0)), spell.get("desc", "")]
	else:
		b.icon = Art.tex("spell_frame")
		b.modulate = Color(1, 1, 1, 0.5)
		if fuse_mode:
			b.disabled = true
	if _selected == pos:
		b.modulate = Color(1.5, 1.4, 0.6)
	b.pressed.connect(func(): _on_slot_clicked(spell, pos))
	return b

func _on_slot_clicked(spell, pos: Dictionary) -> void:
	if fuse_mode and spell == null:
		return
	if _selected.is_empty():
		if fuse_mode or spell != null:
			_selected = pos
		_rebuild()
		return
	if _selected == pos:
		_selected = {}
		_rebuild()
		return
	if fuse_mode:
		_fuse(_selected, pos)
	else:
		_swap(_selected, pos)
	_selected = {}
	_rebuild()

func _get_at(pos: Dictionary):
	if pos["where"] == "wand":
		return player.wands[pos["wand"]].slots[pos["index"]]
	return player.spell_bag[pos["index"]] if pos["index"] < player.spell_bag.size() else null

func _set_at(pos: Dictionary, spell) -> void:
	if pos["where"] == "wand":
		player.wands[pos["wand"]].slots[pos["index"]] = spell
		player.wands[pos["wand"]].reset_sequence()
	else:
		if pos["index"] < player.spell_bag.size():
			if spell == null:
				player.spell_bag.remove_at(pos["index"])
			else:
				player.spell_bag[pos["index"]] = spell
		elif spell != null:
			player.spell_bag.append(spell)

func _swap(a: Dictionary, b: Dictionary) -> void:
	var sa = _get_at(a)
	var sb = _get_at(b)
	# Order matters when both touch the bag (removals shift indices): write
	# the higher bag index first.
	if a["where"] == "bag" and b["where"] == "bag":
		if a["index"] < b["index"]:
			var t := a; a = b; b = t
			var ts = sa; sa = sb; sb = ts
	_set_at(a, sb)
	_set_at(b, sa)

func _fuse(a: Dictionary, b: Dictionary) -> void:
	var sa = _get_at(a)
	var sb = _get_at(b)
	if sa == null or sb == null:
		return
	var merged := SpellDB.merge(sa, sb)
	# Consume source b first (set null), then place merged at a.
	_set_at(b, null)
	# Bag removal may have shifted a's index; re-locate sa if it lives in bag.
	if a["where"] == "bag":
		var idx := player.spell_bag.find(sa)
		if idx >= 0:
			player.spell_bag[idx] = merged
		else:
			player.spell_bag.append(merged)
	else:
		_set_at(a, merged)
	Sfx.play("merge")
	hint.text = "Fused into: %s" % merged.get("name", "?")
