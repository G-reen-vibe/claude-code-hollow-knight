extends Node
## Autoload "Sfx": procedurally generated sound effects (no audio assets needed).

const RATE := 22050

var _streams := {}
var _players: Array = []
var _idx := 0


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_gen_all()


func play(sound: String, vol := 0.0) -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = vol
	p.play()


func _make(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var time := float(i) / RATE
		var t := float(i) / n
		var s: float = clampf(fn.call(time, t), -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _gen_all() -> void:
	_streams["jump"] = _make(0.18, func(time, t):
		return sin(TAU * lerpf(240.0, 520.0, t) * time) * (1.0 - t) * 0.4)
	_streams["dash"] = _make(0.16, func(_time, t):
		return (randf() * 2.0 - 1.0) * pow(1.0 - t, 2.0) * 0.45)
	_streams["slash"] = _make(0.12, func(time, t):
		return ((randf() * 2.0 - 1.0) * 0.6 + sin(TAU * lerpf(900.0, 300.0, t) * time) * 0.4) * pow(1.0 - t, 1.5) * 0.5)
	_streams["hit"] = _make(0.15, func(time, t):
		return (sin(TAU * 160.0 * time) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * pow(1.0 - t, 2.0) * 0.8)
	_streams["hurt"] = _make(0.3, func(time, t):
		return (signf(sin(TAU * 110.0 * time)) * 0.5 + (randf() * 2.0 - 1.0) * 0.3) * pow(1.0 - t, 1.5) * 0.7)
	_streams["heal"] = _make(0.4, func(time, t):
		return (sin(TAU * 660.0 * time) + sin(TAU * 990.0 * time)) * 0.22 * sin(PI * t))
	_streams["cast"] = _make(0.25, func(time, t):
		return sin(TAU * lerpf(300.0, 900.0, t) * time) * (1.0 - t) * 0.4)
	_streams["boss_die"] = _make(0.8, func(time, t):
		return ((randf() * 2.0 - 1.0) * 0.5 + sin(TAU * lerpf(220.0, 60.0, t) * time) * 0.5) * pow(1.0 - t, 1.2) * 0.8)
	_streams["land"] = _make(0.1, func(time, t):
		return sin(TAU * 90.0 * time) * pow(1.0 - t, 2.0) * 0.5)
	_streams["click"] = _make(0.06, func(time, t):
		return sin(TAU * 800.0 * time) * (1.0 - t) * 0.35)
