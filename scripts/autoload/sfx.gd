extends Node
## Tiny procedural sound engine: synthesizes short retro blips at startup so the
## repo carries no audio files. Safe under --headless (playback just no-ops).

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

const MIX_RATE := 22050

func _ready() -> void:
	_streams["shoot"] = _synth(0.08, 880.0, -320.0, 0.25, 0.4)
	_streams["hit"] = _synth(0.09, 220.0, -120.0, 0.3, 0.9)
	_streams["hurt"] = _synth(0.18, 160.0, -60.0, 0.35, 0.7)
	_streams["die"] = _synth(0.3, 300.0, -400.0, 0.3, 0.6)
	_streams["coin"] = _synth(0.1, 1400.0, 600.0, 0.2, 0.1)
	_streams["pickup"] = _synth(0.15, 700.0, 500.0, 0.25, 0.1)
	_streams["door"] = _synth(0.25, 130.0, -30.0, 0.3, 0.8)
	_streams["dash"] = _synth(0.1, 500.0, 900.0, 0.2, 0.5)
	_streams["boss_roar"] = _synth(0.6, 110.0, -40.0, 0.4, 0.95)
	_streams["merge"] = _synth(0.3, 500.0, 700.0, 0.25, 0.15)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play(name: String, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()

func _synth(dur: float, freq: float, sweep: float, vol: float, noise: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var f := freq + sweep * t
		phase += f / MIX_RATE
		var env := (1.0 - float(i) / n)
		var square := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var s := lerpf(square, rng.randf_range(-1, 1), noise) * env * vol
		var v := int(clampf(s, -1, 1) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
