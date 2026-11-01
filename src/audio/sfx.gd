class_name Sfx
extends RefCounted
## Procedurally synthesised sound effects.
##
## Aisle & Co. ships no third-party audio. Every effect is generated from a
## short recipe (sine partials, filtered noise, envelopes) the first time it's
## needed, then cached. Recipes are tuned to be soft and rounded — cosy, never
## shrill — and sit on dedicated buses so the settings sliders work.

const RATE := 22050
const BUSES := ["Music", "SFX", "UI", "Ambience"]

static var _streams: Dictionary = {}
static var _pool: Array[AudioStreamPlayer] = []
static var _pool3d: Array[AudioStreamPlayer3D] = []
static var _host: Node
static var _last_play: Dictionary = {}


static func init(host: Node) -> void:
	# A new host (scene reload) owns fresh players; drop the old ones.
	_host = host
	_pool.clear()
	_pool3d.clear()
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	# A touch of room on the shop sounds.
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.25
		rev.damping = 0.6
		rev.wet = 0.08
		rev.dry = 1.0
		AudioServer.add_bus_effect(sfx, rev)
	for i in 10:
		var p := AudioStreamPlayer.new()
		host.add_child(p)
		_pool.append(p)
	apply_volumes(Game.settings)


static func apply_volumes(s: Settings) -> void:
	_set_bus("Master", s.get_value("master_volume"))
	_set_bus("Music", s.get_value("music_volume"))
	_set_bus("SFX", s.get_value("sfx_volume"))
	_set_bus("UI", s.get_value("sfx_volume"))
	_set_bus("Ambience", s.get_value("ambience_volume"))


static func _set_bus(name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)


static func play(name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not is_instance_valid(_host) or _pool.is_empty() or not is_instance_valid(_pool[0]):
		return
	# Debounce identical sounds within 40 ms (e.g. many shoppers at once).
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -1000)) < 40:
		return
	_last_play[name] = now
	var p: AudioStreamPlayer = null
	for c in _pool:
		if not c.playing:
			p = c
			break
	if p == null:
		p = _pool[0]
	p.stream = stream(name)
	p.bus = "UI" if name.begins_with("ui_") or name in ["tick", "deny", "rotate", "undo"] else "SFX"
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()


static func play_at(name: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	## Positional variant for in-world events (registers, doors).
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	var p: AudioStreamPlayer3D = null
	for c in _pool3d:
		if not c.playing:
			p = c
			break
	if p == null:
		if _pool3d.size() >= 16:
			p = _pool3d[0]
		else:
			p = AudioStreamPlayer3D.new()
			p.unit_size = 14.0
			p.max_distance = 70.0
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			p.bus = "SFX"
			_host.add_child(p)
			_pool3d.append(p)
	p.stream = stream(name)
	p.global_position = pos
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()


static func stream(name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	var s := _make(name)
	_streams[name] = s
	return s


# --- Synthesis ----------------------------------------------------------------

static func _make(name: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	match name:
		"tick":
			buf = _tone([[2200.0, 1.0]], 0.025, 0.002, 160.0, 0.12)
		"ui_click":
			buf = _mix(_tone([[1500.0, 1.0]], 0.04, 0.002, 90.0, 0.18), _noise(0.02, 0.001, 200.0, 0.06, 0.4))
		"ui_open":
			buf = _sweep(520.0, 880.0, 0.12, 0.22)
		"ui_close":
			buf = _sweep(760.0, 430.0, 0.12, 0.2)
		"place":
			buf = _mix(_mix(_sweep(190.0, 95.0, 0.16, 0.7, 28.0), _noise(0.05, 0.001, 70.0, 0.25, 0.15)),
					_tone([[620.0, 1.0], [1240.0, 0.3]], 0.08, 0.001, 55.0, 0.25))
		"remove":
			buf = _mix(_sweep(420.0, 120.0, 0.22, 0.45, 14.0), _noise(0.18, 0.02, 14.0, 0.2, 0.5))
		"rotate":
			var a := _tone([[1700.0, 1.0]], 0.03, 0.001, 120.0, 0.12)
			buf = _concat(a, _silence(0.045), a)
		"deny":
			buf = _concat(_tone([[233.0, 1.0], [466.0, 0.35], [699.0, 0.15]], 0.09, 0.004, 22.0, 0.28),
					_tone([[196.0, 1.0], [392.0, 0.35], [588.0, 0.15]], 0.13, 0.004, 18.0, 0.28))
		"undo":
			buf = _sweep(900.0, 600.0, 0.09, 0.2)
		"scan":
			buf = _tone([[1880.0, 1.0], [3760.0, 0.12]], 0.085, 0.003, 30.0, 0.16)
		"register":
			buf = _mix(_bell([2093.0, 2637.0, 3136.0], 0.9, 0.16), _noise(0.12, 0.005, 25.0, 0.12, 0.9))
		"door_chime":
			buf = _mix(_bell([659.3], 1.4, 0.28), _delay(_bell([523.3], 1.4, 0.26), 0.36))
		"delivery":
			var beep := _tone([[988.0, 1.0], [1976.0, 0.2]], 0.16, 0.01, 6.0, 0.15)
			buf = _concat(beep, _silence(0.18), beep, _silence(0.18), beep)
		"shutter":
			buf = _rattle(1.6, 0.18)
		"coins":
			buf = _mix(_bell([2637.0], 0.35, 0.1), _delay(_bell([3136.0], 0.35, 0.09), 0.07))
		"day_end":
			buf = _mix(_mix(_bell([523.3, 1046.5], 1.4, 0.18), _delay(_bell([659.3, 1318.5], 1.3, 0.17), 0.16)),
					_delay(_bell([784.0, 1568.0], 1.6, 0.2), 0.32))
		"pick":
			buf = _mix(_tone([[340.0, 1.0], [680.0, 0.3]], 0.05, 0.002, 60.0, 0.16), _noise(0.03, 0.001, 120.0, 0.05, 0.3))
		"footstep":
			buf = _noise(0.05, 0.002, 90.0, 0.08, 0.1)
		_:
			buf = _tone([[440.0, 1.0]], 0.1, 0.005, 20.0, 0.2)
	return _to_wav(buf)


static func _tone(partials: Array, dur: float, attack: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / maxf(attack, 1e-4), 1.0) * exp(-t * decay * 0.1)
		var v := 0.0
		for p in partials:
			v += sin(TAU * p[0] * t) * p[1]
		out[i] = v * env * amp
	return _fade_tail(out)


static func _sweep(f0: float, f1: float, dur: float, amp: float, decay: float = 12.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t * t * (3.0 - 2.0 * t))
		phase += TAU * f / RATE
		var env := minf(float(i) / (0.004 * RATE), 1.0) * exp(-t * decay * 0.25)
		out[i] = (sin(phase) + 0.18 * sin(phase * 2.0)) * env * amp
	return _fade_tail(out)


static func _noise(dur: float, attack: float, decay: float, amp: float, smooth: float) -> PackedFloat32Array:
	## Low-passed noise; `smooth` 0..1 (higher = darker).
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / maxf(attack, 1e-4), 1.0) * exp(-t * decay * 0.1)
		y = lerpf(rng.randf_range(-1.0, 1.0), y, smooth)
		out[i] = y * env * amp
	return _fade_tail(out)


static func _bell(freqs: Array, dur: float, amp: float) -> PackedFloat32Array:
	## Struck-bell: each fundamental gets slightly inharmonic overtones.
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t) * exp(-t * 3.2)
			v += 0.35 * sin(TAU * f * 2.76 * t) * exp(-t * 7.0)
			v += 0.18 * sin(TAU * f * 5.4 * t) * exp(-t * 12.0)
		out[i] = v * amp * minf(t / 0.002, 1.0) / maxf(freqs.size(), 1)
	return _fade_tail(out)


static func _rattle(dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var clack := 0.5 + 0.5 * sin(TAU * 18.0 * t)
		y = lerpf(rng.randf_range(-1.0, 1.0), y, 0.55)
		var env := minf(t / 0.05, 1.0) * minf((dur - t) / 0.2, 1.0)
		out[i] = y * clack * clack * env * amp
	return out


static func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


static func _delay(a: PackedFloat32Array, dur: float) -> PackedFloat32Array:
	return _concat(_silence(dur), a)


static func _concat(a: PackedFloat32Array, b: PackedFloat32Array, c: PackedFloat32Array = PackedFloat32Array(),
		d: PackedFloat32Array = PackedFloat32Array(), e: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var out := a.duplicate()
	out.append_array(b)
	out.append_array(c)
	out.append_array(d)
	out.append_array(e)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out


static func _fade_tail(buf: PackedFloat32Array) -> PackedFloat32Array:
	var n := buf.size()
	var tail := mini(int(0.01 * RATE), n)
	for i in tail:
		buf[n - 1 - i] *= float(i) / tail
	return buf


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	# Safety limiter: layered recipes can sum past full scale; scale the whole
	# effect down rather than letting it clip.
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	if peak > 0.84:
		var g := 0.84 / peak
		for i in buf.size():
			buf[i] *= g
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var v := clampi(int(clampf(buf[i], -1.0, 1.0) * 32000.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
