extends Control
## Title screen: start the full pantheon or practice a single boss.


func _ready() -> void:
	$Center/VBox/RushBtn.pressed.connect(_on_rush)
	var list := $Center/VBox/BossList
	for i in Game.roster.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, Game.roster[i].title]
		b.pressed.connect(_on_single.bind(i))
		list.add_child(b)
	$Center/VBox/QuitBtn.pressed.connect(_on_quit)
	$Center/VBox/RushBtn.grab_focus()


func _on_rush() -> void:
	Sfx.play("click")
	Game.start_rush()


func _on_single(i: int) -> void:
	Sfx.play("click")
	Game.start_single(i)


func _on_quit() -> void:
	get_tree().quit()
