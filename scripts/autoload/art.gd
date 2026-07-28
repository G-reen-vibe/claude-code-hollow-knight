extends Node
## Procedural pixel-art generator. All game sprites are built at runtime from
## code so the project ships zero binary assets. Textures are cached by name.

var _cache: Dictionary = {}

func tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var img := _build(name)
	var t := ImageTexture.create_from_image(img)
	_cache[name] = t
	return t

func _build(name: String) -> Image:
	match name:
		"player":
			return _wizard(Color(0.36, 0.55, 0.95), Color(0.95, 0.85, 0.7))
		"wand":
			return _wand_sprite()
		"spider_small":
			return _spider(12, Color(0.35, 0.3, 0.4))
		"spider_big":
			return _spider(20, Color(0.28, 0.24, 0.34))
		"worm":
			return _worm()
		"eye":
			return _eye()
		"boss_spider":
			return _boss_spider()
		"coin":
			return _disc(8, Color(1.0, 0.85, 0.25), Color(0.85, 0.6, 0.1))
		"heart":
			return _heart()
		"mana_orb":
			return _disc(6, Color(0.4, 0.6, 1.0), Color(0.2, 0.35, 0.8))
		"chest":
			return _chest()
		"portal":
			return _portal()
		"spell_frame":
			return _frame(Color(0.5, 0.45, 0.6))
		"floor_tile":
			return _floor_tile()
		"wall_tile":
			return _wall_tile()
		"shrine":
			return _shrine()
		"bench":
			return _bench()
		"fountain":
			return _fountain()
		_:
			if name.begins_with("proj_"):
				return _projectile(name.trim_prefix("proj_"))
			if name.begins_with("icon_"):
				return _spell_icon(name.trim_prefix("icon_"))
			if name.begins_with("door_"):
				return _door_icon(name.trim_prefix("door_"))
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	return img

func _blank(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			_px(img, ix, iy, c)

func _circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for iy in range(int(cy - r) - 1, int(cy + r) + 2):
		for ix in range(int(cx - r) - 1, int(cx + r) + 2):
			if Vector2(ix - cx, iy - cy).length() <= r:
				_px(img, ix, iy, c)

func _line(img: Image, from: Vector2, to: Vector2, c: Color) -> void:
	var steps := int(from.distance_to(to)) + 1
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / steps)
		_px(img, int(p.x), int(p.y), c)

func _wizard(robe: Color, skin: Color) -> Image:
	var img := _blank(16, 16)
	var robe_dark := robe.darkened(0.3)
	_rect(img, 4, 0, 8, 2, robe_dark)
	_rect(img, 6, 0, 4, 1, robe)
	_rect(img, 2, 3, 12, 2, robe_dark)
	_rect(img, 5, 5, 6, 3, skin)
	_px(img, 6, 6, Color.BLACK)
	_px(img, 9, 6, Color.BLACK)
	_rect(img, 4, 8, 8, 6, robe)
	_rect(img, 3, 10, 10, 4, robe)
	_rect(img, 4, 14, 8, 1, robe_dark)
	_rect(img, 4, 11, 8, 1, robe_dark)
	return img

func _wand_sprite() -> Image:
	var img := _blank(16, 6)
	_rect(img, 0, 2, 12, 2, Color(0.5, 0.33, 0.2))
	_rect(img, 11, 1, 4, 4, Color(0.3, 0.75, 1.0))
	_px(img, 12, 2, Color(0.8, 0.95, 1.0))
	return img

func _spider(size: int, base: Color) -> Image:
	var img := _blank(size + 6, size)
	var cx := (size + 6) / 2.0
	var cy := size / 2.0
	var r := size * 0.32
	# legs
	var leg := base.darkened(0.25)
	for i in range(4):
		var yo := -r + i * (2.0 * r / 3.0)
		_line(img, Vector2(cx, cy + yo * 0.5), Vector2(cx - r - 3, cy + yo), leg)
		_line(img, Vector2(cx, cy + yo * 0.5), Vector2(cx + r + 3, cy + yo), leg)
	# abdomen + head
	_circle(img, cx + r * 0.5, cy, r, base)
	_circle(img, cx - r * 0.7, cy, r * 0.65, base.lightened(0.12))
	# eyes
	_px(img, int(cx - r * 0.9), int(cy - 1), Color(0.9, 0.2, 0.2))
	_px(img, int(cx - r * 0.9), int(cy + 1), Color(0.9, 0.2, 0.2))
	# marking
	_px(img, int(cx + r * 0.5), int(cy), base.lightened(0.3))
	return img

func _worm() -> Image:
	var img := _blank(20, 12)
	var body := Color(0.72, 0.5, 0.42)
	for i in range(5):
		_circle(img, 3 + i * 3.5, 6 + sin(i * 1.2) * 2.0, 3.2 - i * 0.25, body.darkened(i * 0.05))
	# face segment
	_circle(img, 3, 6, 3.4, body.lightened(0.1))
	_px(img, 2, 5, Color.BLACK)
	_px(img, 2, 7, Color.BLACK)
	return img

func _eye() -> Image:
	var img := _blank(14, 14)
	_circle(img, 7, 7, 6, Color(0.85, 0.8, 0.75))
	_circle(img, 7, 7, 3.2, Color(0.55, 0.2, 0.55))
	_circle(img, 7, 7, 1.5, Color.BLACK)
	_circle(img, 5.5, 5.5, 1.0, Color(1, 1, 1, 0.8))
	# bloodshot veins
	_line(img, Vector2(1, 4), Vector2(4, 6), Color(0.8, 0.3, 0.3, 0.7))
	_line(img, Vector2(12, 9), Vector2(10, 8), Color(0.8, 0.3, 0.3, 0.7))
	return img

func _boss_spider() -> Image:
	var img := _blank(56, 44)
	var base := Color(0.3, 0.22, 0.35)
	var leg := base.darkened(0.3)
	var cx := 30.0
	var cy := 22.0
	# 8 legs
	for i in range(4):
		var yo := -12.0 + i * 8.0
		_line(img, Vector2(cx - 4, cy + yo * 0.4), Vector2(cx - 24, cy + yo), leg)
		_line(img, Vector2(cx - 4, cy + yo * 0.4 + 1), Vector2(cx - 24, cy + yo + 1), leg)
		_line(img, Vector2(cx + 4, cy + yo * 0.4), Vector2(cx + 24, cy + yo), leg)
		_line(img, Vector2(cx + 4, cy + yo * 0.4 + 1), Vector2(cx + 24, cy + yo + 1), leg)
	# abdomen
	_circle(img, cx + 8, cy, 13, base)
	# skull marking on abdomen
	_circle(img, cx + 8, cy - 1, 4, Color(0.85, 0.82, 0.75))
	_px(img, int(cx + 6), int(cy - 2), base)
	_px(img, int(cx + 10), int(cy - 2), base)
	_rect(img, int(cx + 6), int(cy + 2), 5, 1, Color(0.85, 0.82, 0.75))
	# cephalothorax
	_circle(img, cx - 8, cy, 8, base.lightened(0.12))
	# eye cluster
	for e in [[-12.0, -3.0], [-12.0, 0.0], [-12.0, 3.0], [-9.0, -2.0], [-9.0, 2.0], [-6.0, 0.0]]:
		_circle(img, cx + e[0], cy + e[1], 1.2, Color(0.95, 0.25, 0.2))
	# fangs
	_line(img, Vector2(cx - 15, cy - 2), Vector2(cx - 18, cy - 4), Color(0.9, 0.9, 0.85))
	_line(img, Vector2(cx - 15, cy + 2), Vector2(cx - 18, cy + 4), Color(0.9, 0.9, 0.85))
	return img

func _disc(size: int, bright: Color, dark: Color) -> Image:
	var img := _blank(size, size)
	_circle(img, size / 2.0, size / 2.0, size / 2.0 - 0.5, dark)
	_circle(img, size / 2.0, size / 2.0, size / 2.0 - 1.5, bright)
	return img

func _heart() -> Image:
	var img := _blank(10, 10)
	var c := Color(0.9, 0.2, 0.3)
	_circle(img, 3, 3.5, 2.5, c)
	_circle(img, 7, 3.5, 2.5, c)
	for y in range(4, 9):
		var half := 9 - y
		_rect(img, 5 - half, y, half * 2, 1, c)
	return img

func _chest() -> Image:
	var img := _blank(18, 14)
	var wood := Color(0.55, 0.36, 0.2)
	var gold := Color(1.0, 0.84, 0.3)
	_rect(img, 1, 3, 16, 10, wood)
	_rect(img, 1, 3, 16, 3, wood.lightened(0.15))
	_rect(img, 1, 6, 16, 1, gold)
	_rect(img, 8, 6, 3, 4, gold)
	return img

func _portal() -> Image:
	var img := _blank(28, 36)
	for y in range(36):
		for x in range(28):
			var d := Vector2((x - 14) / 12.0, (y - 18) / 16.0).length()
			if d < 1.0:
				var c := Color(0.5, 0.2, 0.9).lerp(Color(0.9, 0.7, 1.0), 1.0 - d)
				if d > 0.85:
					c = Color(0.3, 0.1, 0.5)
				_px(img, x, y, c)
	return img

func _frame(c: Color) -> Image:
	var img := _blank(20, 20)
	_rect(img, 0, 0, 20, 20, c)
	_rect(img, 1, 1, 18, 18, Color(0.12, 0.1, 0.16))
	return img

func _floor_tile() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := Color(0.13, 0.15, 0.12)
	img.fill(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(14):
		var x := rng.randi_range(0, 15)
		var y := rng.randi_range(0, 15)
		_px(img, x, y, base.lightened(0.07))
	# mossy flecks for the dark-forest cavern look
	for i in range(4):
		_px(img, rng.randi_range(0, 15), rng.randi_range(0, 15), Color(0.16, 0.24, 0.14))
	_rect(img, 0, 0, 16, 1, base.darkened(0.2))
	_rect(img, 0, 0, 1, 16, base.darkened(0.2))
	return img

func _wall_tile() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := Color(0.24, 0.28, 0.24)
	img.fill(base)
	_rect(img, 0, 0, 16, 2, base.lightened(0.15))
	_rect(img, 0, 14, 16, 2, base.darkened(0.3))
	_rect(img, 7, 2, 1, 12, base.darkened(0.2))
	_rect(img, 0, 7, 16, 1, base.darkened(0.2))
	return img

func _shrine() -> Image:
	var img := _blank(20, 24)
	var stone := Color(0.5, 0.5, 0.58)
	_rect(img, 4, 16, 12, 6, stone)
	_rect(img, 6, 8, 8, 8, stone.lightened(0.1))
	_circle(img, 10, 5, 4, Color(0.4, 0.9, 0.9))
	return img

func _bench() -> Image:
	var img := _blank(24, 18)
	var wood := Color(0.45, 0.32, 0.22)
	_rect(img, 2, 8, 20, 8, wood)
	_rect(img, 2, 8, 20, 2, wood.lightened(0.2))
	_rect(img, 3, 16, 3, 2, wood.darkened(0.3))
	_rect(img, 18, 16, 3, 2, wood.darkened(0.3))
	# glowing crucible
	_circle(img, 12, 6, 4, Color(0.6, 0.3, 0.9))
	_circle(img, 12, 6, 2, Color(0.9, 0.7, 1.0))
	return img

func _fountain() -> Image:
	var img := _blank(24, 20)
	var stone := Color(0.55, 0.55, 0.62)
	_rect(img, 2, 12, 20, 6, stone)
	_rect(img, 4, 14, 16, 3, Color(0.35, 0.6, 0.95))
	_rect(img, 9, 4, 6, 8, stone.darkened(0.15))
	_circle(img, 12, 3, 3, Color(0.5, 0.75, 1.0))
	return img

func _projectile(kind: String) -> Image:
	var img: Image
	match kind:
		"bullet":
			img = _blank(12, 6)
			_rect(img, 0, 2, 8, 2, Color(0.55, 0.75, 1.0, 0.7))
			_circle(img, 8, 3, 2.5, Color(0.35, 0.55, 1.0))
			_px(img, 8, 2, Color.WHITE)
		"arrow":
			img = _blank(14, 6)
			_rect(img, 0, 2, 10, 2, Color(0.4, 0.9, 0.65))
			_line(img, Vector2(10, 0), Vector2(13, 3), Color(0.8, 1.0, 0.9))
			_line(img, Vector2(10, 5), Vector2(13, 3), Color(0.8, 1.0, 0.9))
		"nova":
			img = _blank(14, 14)
			_circle(img, 7, 7, 6, Color(0.95, 0.4, 0.1))
			_circle(img, 7, 7, 3.5, Color(1.0, 0.8, 0.2))
		"bubble":
			img = _blank(14, 14)
			_circle(img, 7, 7, 6, Color(0.45, 0.7, 0.95, 0.75))
			_circle(img, 7, 7, 4.5, Color(0.6, 0.85, 1.0, 0.55))
			_circle(img, 5, 5, 1.5, Color.WHITE)
		"butterfly":
			img = _blank(12, 10)
			var w := Color(0.9, 0.55, 0.9)
			_circle(img, 3.5, 3, 2.5, w)
			_circle(img, 8.5, 3, 2.5, w)
			_circle(img, 3.5, 7, 2.0, w.darkened(0.15))
			_circle(img, 8.5, 7, 2.0, w.darkened(0.15))
			_rect(img, 5, 2, 2, 7, Color(0.4, 0.25, 0.4))
		"web":
			img = _blank(10, 10)
			var c := Color(0.92, 0.92, 0.88)
			_line(img, Vector2(0, 5), Vector2(9, 5), c)
			_line(img, Vector2(5, 0), Vector2(5, 9), c)
			_line(img, Vector2(1, 1), Vector2(8, 8), c)
			_line(img, Vector2(8, 1), Vector2(1, 8), c)
			_circle(img, 5, 5, 1.5, c)
		"enemy_bolt":
			img = _blank(10, 10)
			_circle(img, 5, 5, 4, Color(0.9, 0.25, 0.55))
			_circle(img, 4, 4, 1.5, Color(1.0, 0.7, 0.85))
		"venom":
			img = _blank(10, 10)
			_circle(img, 5, 5, 4, Color(0.45, 0.8, 0.25))
			_circle(img, 4, 4, 1.5, Color(0.8, 1.0, 0.5))
		_:
			img = _blank(8, 8)
			_circle(img, 4, 4, 3, Color.WHITE)
	return img

func _spell_icon(kind: String) -> Image:
	var img := _blank(16, 16)
	match kind:
		"bullet":
			_rect(img, 2, 7, 9, 2, Color(0.55, 0.75, 1.0))
			_circle(img, 11, 8, 3, Color(0.35, 0.55, 1.0))
		"arrow":
			_line(img, Vector2(2, 13), Vector2(13, 2), Color(0.4, 0.9, 0.65))
			_line(img, Vector2(13, 2), Vector2(9, 3), Color(0.8, 1.0, 0.9))
			_line(img, Vector2(13, 2), Vector2(12, 6), Color(0.8, 1.0, 0.9))
		"nova":
			_circle(img, 8, 8, 6, Color(0.95, 0.4, 0.1))
			_circle(img, 8, 8, 3, Color(1.0, 0.8, 0.2))
		"bubble":
			_circle(img, 8, 8, 6, Color(0.45, 0.7, 0.95))
			_circle(img, 6, 6, 2, Color.WHITE)
		"butterfly":
			_circle(img, 5, 6, 3, Color(0.9, 0.55, 0.9))
			_circle(img, 11, 6, 3, Color(0.9, 0.55, 0.9))
			_rect(img, 7, 4, 2, 9, Color(0.4, 0.25, 0.4))
		"volley":
			_rect(img, 2, 3, 10, 2, Color(0.95, 0.8, 0.3))
			_rect(img, 2, 7, 12, 2, Color(0.95, 0.8, 0.3))
			_rect(img, 2, 11, 10, 2, Color(0.95, 0.8, 0.3))
		"track":
			_circle(img, 8, 8, 6, Color(1.0, 0.55, 0.75))
			_circle(img, 8, 8, 4, Color(0.12, 0.1, 0.16))
			_circle(img, 8, 8, 2, Color(1.0, 0.55, 0.75))
		"venom":
			_circle(img, 8, 6, 4, Color(0.45, 0.8, 0.25))
			_line(img, Vector2(8, 10), Vector2(8, 13), Color(0.45, 0.8, 0.25))
		"rebound":
			_rect(img, 2, 10, 4, 2, Color(0.5, 1.0, 0.9))
			_rect(img, 6, 6, 4, 2, Color(0.5, 1.0, 0.9))
			_rect(img, 10, 10, 4, 2, Color(0.5, 1.0, 0.9))
		"split":
			_rect(img, 2, 7, 5, 2, Color(0.9, 0.9, 0.9))
			_rect(img, 8, 3, 6, 2, Color(0.9, 0.6, 0.3))
			_rect(img, 8, 11, 6, 2, Color(0.9, 0.6, 0.3))
		"saving":
			_circle(img, 8, 8, 6, Color(0.35, 0.65, 1.0))
			_rect(img, 5, 7, 6, 2, Color.WHITE)
		"power":
			_circle(img, 8, 8, 6, Color(1.0, 0.3, 0.3))
			_rect(img, 7, 4, 2, 8, Color.WHITE)
			_rect(img, 4, 7, 8, 2, Color.WHITE)
		_:
			_circle(img, 8, 8, 5, Color.GRAY)
	return img

## Small glyphs shown on exit doors previewing the next room's reward type.
func _door_icon(kind: String) -> Image:
	var img := _blank(14, 14)
	match kind:
		"combat":
			_line(img, Vector2(2, 11), Vector2(11, 2), Color(0.9, 0.9, 0.95))
			_line(img, Vector2(3, 12), Vector2(12, 3), Color(0.9, 0.9, 0.95))
			_rect(img, 2, 9, 3, 3, Color(0.7, 0.5, 0.3))
		"spell":
			_circle(img, 7, 7, 5, Color(0.6, 0.4, 0.95))
			_circle(img, 7, 7, 2, Color(0.9, 0.8, 1.0))
		"gold":
			_circle(img, 7, 7, 5, Color(1.0, 0.85, 0.25))
			_rect(img, 6, 4, 2, 6, Color(0.85, 0.6, 0.1))
		"relic":
			_rect(img, 3, 6, 8, 6, Color(0.55, 0.36, 0.2))
			_rect(img, 6, 8, 2, 2, Color(1.0, 0.84, 0.3))
		"shop":
			_rect(img, 3, 5, 8, 7, Color(0.85, 0.7, 0.4))
			_rect(img, 5, 2, 4, 3, Color(0.85, 0.7, 0.4))
		"workshop":
			_circle(img, 7, 8, 4, Color(0.6, 0.3, 0.9))
			_rect(img, 3, 11, 8, 2, Color(0.45, 0.32, 0.22))
		"fountain":
			_circle(img, 7, 5, 3, Color(0.5, 0.75, 1.0))
			_rect(img, 3, 9, 8, 3, Color(0.35, 0.6, 0.95))
		"boss":
			_circle(img, 7, 7, 6, Color(0.7, 0.15, 0.2))
			_px(img, 5, 6, Color.WHITE)
			_px(img, 9, 6, Color.WHITE)
			_rect(img, 5, 10, 5, 1, Color.WHITE)
		_:
			_circle(img, 7, 7, 5, Color.GRAY)
	return img
