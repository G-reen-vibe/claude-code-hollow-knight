extends CanvasLayer
## In-fight HUD: masks, soul orb, boss health bar, run timer and title banners.
## All widgets are built and painted in code.

var player: Player
var boss: BossBase

var _boss_frac := 1.0
var _banner_tw: Tween

var root_ctl: Control
var banner: Label
var sub: Label
var timer_lbl: Label
var boss_lbl: Label


func _ready() -> void:
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctl)
	root_ctl.draw.connect(_paint)

	banner = _mk_label(64, Color(0.93, 0.95, 0.98))
	banner.offset_top = 240.0
	banner.offset_bottom = 330.0
	banner.modulate.a = 0.0

	sub = _mk_label(24, Color(0.7, 0.74, 0.8))
	sub.offset_top = 330.0
	sub.offset_bottom = 370.0
	sub.modulate.a = 0.0

	timer_lbl = _mk_label(20, Color(0.85, 0.88, 0.92))
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_lbl.anchor_left = 1.0
	timer_lbl.offset_left = -280.0
	timer_lbl.offset_right = -24.0
	timer_lbl.offset_top = 18.0
	timer_lbl.offset_bottom = 48.0

	boss_lbl = _mk_label(22, Color(0.88, 0.9, 0.94))
	boss_lbl.offset_top = 648.0
	boss_lbl.offset_bottom = 676.0


func _mk_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.anchor_right = 1.0
	root_ctl.add_child(l)
	return l


func bind_player(p: Player) -> void:
	player = p


func bind_boss(b: BossBase) -> void:
	boss = b
	_boss_frac = 1.0


func show_banner(text: String, subtext := "", dur := 1.8) -> void:
	banner.text = text
	sub.text = subtext
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	banner.modulate.a = 0.0
	sub.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.25)
	_banner_tw.tween_interval(dur)
	_banner_tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	_banner_tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	root_ctl.queue_redraw()
	var prefix := "%d / %d    " % [Game.index + 1, Game.roster.size()] if Game.mode == "rush" else ""
	timer_lbl.text = prefix + Game.fmt_time(Game.run_time)
	if is_instance_valid(boss):
		var target := float(boss.hp) / maxf(1.0, float(boss.max_hp))
		_boss_frac = lerpf(_boss_frac, target, 0.15)
		boss_lbl.text = boss.boss_title
		boss_lbl.visible = boss.active or boss.dead
	else:
		boss_lbl.visible = false


func _paint() -> void:
	var d := root_ctl
	if is_instance_valid(player):
		# soul orb
		var c := Vector2(46, 52)
		d.draw_circle(c, 24.0, Color(0.05, 0.07, 0.12, 0.8))
		var frac := float(player.soul) / float(Player.SOUL_MAX)
		if frac > 0.0:
			d.draw_circle(c, 20.0 * sqrt(frac), Color(0.85, 0.92, 1.0))
		d.draw_arc(c, 23.0, 0, TAU, 40, Color(0.75, 0.8, 0.9, 0.9), 3.0)
		# masks
		for i in player.max_hp:
			var p := Vector2(92 + i * 34, 44)
			if i < player.hp:
				d.draw_circle(p, 12.0, Color(0.93, 0.95, 0.97))
				d.draw_arc(p, 12.5, 0, TAU, 24, Color(0.6, 0.68, 0.78), 2.0)
			else:
				d.draw_circle(p, 12.0, Color(0.1, 0.12, 0.18, 0.7))
				d.draw_arc(p, 12.5, 0, TAU, 24, Color(0.3, 0.34, 0.42), 2.0)
	# boss health bar
	if is_instance_valid(boss) and (boss.active or boss.dead):
		var bar := Rect2(340, 690, 600, 10)
		d.draw_rect(Rect2(bar.position - Vector2(3, 3), bar.size + Vector2(6, 6)), Color(0, 0, 0, 0.55))
		d.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_boss_frac, 0.0, 1.0), bar.size.y)),
			Color(0.85, 0.55, 0.3))
		d.draw_rect(bar, Color(0.9, 0.92, 0.96, 0.35), false, 2.0)
