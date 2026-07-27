extends Control
## Post-run results: completion title, total time and death count.


func _ready() -> void:
	var title := $Center/VBox/Title as Label
	if Game.mode == "rush":
		title.text = "PANTHEON COMPLETE"
	else:
		title.text = str(Game.current_boss().title).to_upper() + " VANQUISHED"
	($Center/VBox/TimeLabel as Label).text = "Time    " + Game.fmt_time(Game.run_time)
	($Center/VBox/DeathLabel as Label).text = "Deaths    %d" % Game.deaths
	$Center/VBox/MenuBtn.pressed.connect(_on_menu)
	$Center/VBox/MenuBtn.grab_focus()


func _on_menu() -> void:
	Sfx.play("click")
	Game.to_menu()
