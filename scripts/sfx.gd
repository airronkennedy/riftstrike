extends Node
## Synth sound effects (no audio files), ported from the web game's WebAudio tones.
## Each tone/noise burst is rendered once to a small AudioStreamWAV and cached.

const RATE := 22050
var muted := false
var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _pending := [] # [time_left_ms, callable]
var _last_hit := 0

func _ready() -> void:
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _process(delta: float) -> void:
	if _pending.is_empty():
		return
	var ms := delta * 1000.0
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i][0] -= ms
		if _pending[i][0] <= 0.0:
			var cb: Callable = _pending[i][1]
			_pending.remove_at(i)
			cb.call()

func later(ms: float, cb: Callable) -> void:
	_pending.append([ms, cb])

func _play(s: AudioStreamWAV) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func tone(freq: float, dur: float, type: String = "square", vol: float = 0.05, slide: float = 0.0) -> void:
	if muted:
		return
	freq = roundf(freq / 5.0) * 5.0
	var key := "t%s|%d|%d|%d|%d" % [type, int(freq), int(dur * 1000), int(vol * 1000), int(slide * 100)]
	var s: AudioStreamWAV = _cache.get(key)
	if s == null:
		var n := int((dur + 0.02) * RATE)
		var buf := PackedFloat32Array()
		buf.resize(n)
		var ph := 0.0
		var f1 := maxf(30.0, freq * slide) if slide > 0.0 else freq
		for i in n:
			var t := float(i) / RATE
			var k := minf(1.0, t / dur)
			var f := freq * pow(f1 / freq, k)
			ph += f / RATE
			var x := ph - floorf(ph)
			var v := 0.0
			match type:
				"square": v = 1.0 if x < 0.5 else -1.0
				"sawtooth": v = 2.0 * x - 1.0
				"triangle": v = 4.0 * absf(x - 0.5) - 1.0
				_: v = sin(TAU * x)
			var g := vol * pow(0.0001 / vol, k) if t < dur else 0.0
			buf[i] = v * g * 1.6
		s = _wav(buf)
		_cache[key] = s
	_play(s)

func noise(dur: float, vol: float = 0.08, fc: float = 2400.0) -> void:
	if muted:
		return
	var key := "n%d|%d|%d" % [int(dur * 1000), int(vol * 1000), int(fc)]
	var s: AudioStreamWAV = _cache.get(key)
	if s == null:
		var n := int(dur * RATE)
		var buf := PackedFloat32Array()
		buf.resize(n)
		var a := 1.0 - exp(-TAU * fc / RATE)
		var y1 := 0.0
		var y2 := 0.0
		for i in n:
			var k := float(i) / n
			y1 += a * (randf() * 2.0 - 1.0 - y1)
			y2 += a * (y1 - y2)
			buf[i] = y2 * 1.8 * vol * pow(0.0001 / vol, k) * 1.6
		s = _wav(buf)
		_cache[key] = s
	_play(s)

func hit() -> void:
	var t := Time.get_ticks_msec()
	if t - _last_hit < 35:
		return
	_last_hit = t
	noise(0.07, 0.07, 1800)
	tone(randf_range(150, 220), 0.06, "square", 0.025, 0.5)

func special() -> void:
	tone(330, 0.18, "sawtooth", 0.04, 2.2); noise(0.18, 0.08, 900)

func boom() -> void:
	noise(0.35, 0.14, 500); tone(90, 0.3, "sine", 0.09, 0.4)

func shoot() -> void:
	tone(900, 0.05, "triangle", 0.02, 0.6)

func ko() -> void:
	tone(420, 0.22, "square", 0.035, 0.35)

func fight() -> void:
	tone(392, 0.1, "square", 0.05)
	later(90, func(): tone(523, 0.18, "square", 0.05))

func win() -> void:
	var fs := [523, 659, 784, 1046]
	for i in fs.size():
		var f: float = fs[i]
		later(i * 110, func(): tone(f, 0.18, "square", 0.045))

func lose() -> void:
	var fs := [392, 330, 262, 196]
	for i in fs.size():
		var f: float = fs[i]
		later(i * 140, func(): tone(f, 0.22, "triangle", 0.05))

## Pre-render the common sounds so the first hit has no hitch.
func warm() -> void:
	var m := muted
	muted = false
	for p in _players:
		p.volume_db = -80.0
	hit(); special(); boom(); shoot(); ko()
	for f in [392, 523, 659, 784, 1046, 330, 262, 196, 440, 880, 220]:
		tone(f, 0.1, "square", 0.05)
	for p in _players:
		p.stop()
		p.volume_db = 0.0
	muted = m
