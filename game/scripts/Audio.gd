extends Node
## Procedural audio engine — v1.2 "soft" pass.
##
## Design notes (after listening to how top casual word games sound):
##   * UI feedback is a *soft mallet* family (marimba / kalimba / music-box):
##     sine-ish partials, 5-8 ms attack, exponential decay, very few harmonics.
##     Nothing is a bright metal bell and nothing has a sharp transient.
##   * Negative feedback is a low, muffled "mm" — never a buzzer. Players must
##     barely register failure so the loop stays pleasant.
##   * Every payload sound (word, coin, star) has a short diffuse tail, which is
##     what makes cheap synths feel "produced".
##   * Music is per-section: each screen gets its own tempo/key/instrument mix,
##     generated on a worker thread and cross-faded in. No audio files shipped.
##
## Everything here is synthesised at runtime (0 bytes of audio assets).

const SR := 32000.0

# ------------------------------------------------------------------ players
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _cache: Dictionary = {}
var _tracks: Dictionary = {}          # section -> AudioStreamWAV
var _pending_raw: PackedFloat32Array  # filled by the worker thread
var _pending_name := ""
var _thread: Thread
var _section := ""
var _want_section := ""

# ------------------------------------------------------------- music specs
## tempo (bpm), scale (Hz), instrument mix, density — one identity per screen
const SPECS := {
	"home": {
		"bpm": 62.0, "key": 261.63, "mode": [0, 2, 4, 7, 9, 12, 14, 16],
		"lead": 0.42, "pad": 0.55, "bass": 0.40, "sparkle": 0.16, "bars": 8,
	},
	"map": {
		"bpm": 72.0, "key": 293.66, "mode": [0, 2, 3, 5, 7, 9, 10, 12],
		"lead": 0.34, "pad": 0.60, "bass": 0.42, "sparkle": 0.22, "bars": 8,
	},
	"level": {
		"bpm": 56.0, "key": 220.0, "mode": [0, 2, 3, 7, 9, 12, 14, 15],
		"lead": 0.20, "pad": 0.72, "bass": 0.34, "sparkle": 0.05, "bars": 8,
	},
	"shop": {
		"bpm": 92.0, "key": 329.63, "mode": [0, 2, 4, 5, 7, 9, 11, 12],
		"lead": 0.46, "pad": 0.34, "bass": 0.44, "sparkle": 0.30, "bars": 8,
	},
	"quests": {
		"bpm": 84.0, "key": 349.23, "mode": [0, 2, 4, 7, 9, 12, 14, 16],
		"lead": 0.44, "pad": 0.40, "bass": 0.40, "sparkle": 0.34, "bars": 8,
	},
	"library": {
		"bpm": 58.0, "key": 246.94, "mode": [0, 2, 3, 5, 7, 10, 12, 14],
		"lead": 0.30, "pad": 0.66, "bass": 0.32, "sparkle": 0.10, "bars": 8,
	},
	"themes": {
		"bpm": 76.0, "key": 311.13, "mode": [0, 3, 5, 7, 10, 12, 15, 17],
		"lead": 0.40, "pad": 0.46, "bass": 0.38, "sparkle": 0.26, "bars": 8,
	},
	"settings": {
		"bpm": 60.0, "key": 233.08, "mode": [0, 2, 4, 5, 7, 9, 11, 12],
		"lead": 0.26, "pad": 0.60, "bass": 0.30, "sparkle": 0.06, "bars": 8,
	},
}


func _ready() -> void:
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	for m in 2:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Master"
		mp.volume_db = -60.0
		add_child(mp)
		if m == 0:
			_music_a = mp
		else:
			_music_b = mp
	_music_active = _music_a
	add_child(_make_builder_timer())
	_build_sfx()


func _make_builder_timer() -> Timer:
	var t := Timer.new()
	t.name = "MusicBuilder"
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(_poll_builder)
	return t


# ============================================================ synthesis core
## A soft mallet voice: marimba / kalimba / music-box depending on `bright`.
##   bright 0.15 -> warm marimba   0.55 -> glassy music box
func _mallet(freq: float, dur: float, vol: float, bright: float = 0.3,
		detune := 0.0) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [
		[1.0, 1.0, 0.0],
		[2.0, 0.10 + bright * 0.34, -0.0016],
		[2.99, 0.03 + bright * 0.16, -0.0040],
		[4.95, 0.012 + bright * 0.10, -0.0062],
	]
	var atk := 0.006
	var k := 2.9 + (1.0 - bright) * 0.7
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-k * t) * minf(1.0, t / atk)
		var s := 0.0
		for p in partials:
			var mult: float = float(p[0]) + float(p[2])
			var amp: float = float(p[1])
			s += sin((freq * mult + detune) * TAU * t) * amp
		out[i] = s * env * vol * 0.5
	# mallet contact noise: 6 ms of very quiet filtered noise
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq) & 0x7FFFFFFF
	var lp := 0.0
	var clicks := int(SR * 0.008)
	for i in clicks:
		var t := float(i) / SR
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.45)
		out[i] += lp * (1.0 - t / 0.008) * vol * 0.05 * bright
	return out


## Long soft pad tone — the "air" under melodies.
func _pad(freq: float, dur: float, vol: float, phase := 0.0) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var atk := 0.55
	var rel := 0.9
	for i in n:
		var t := float(i) / SR
		var env: float = minf(1.0, t / atk)
		if t > dur - rel:
			env *= maxf(0.0, (dur - t) / rel)
		env *= env if env < 1.0 else 1.0
		var s := sin(freq * TAU * t + phase) * 0.6
		s += sin(freq * 1.5 * TAU * t + 0.3) * 0.16
		s += sin(freq * 2.0 * TAU * t + 0.6) * 0.10
		s += sin(freq * 0.5 * TAU * t) * 0.22
		out[i] = s * env * vol
	return out


## Muffled, non-punishing "no" tone.
func _muted(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-9.0 * t) * minf(1.0, t / 0.012)
		var s := sin(freq * TAU * t) * 0.7 + sin(freq * 1.5 * TAU * t) * 0.12
		out[i] = s * env * vol
	return out


## Short diffuse tail so short sounds sit in a room instead of a vacuum.
func _space(src: PackedFloat32Array, amount: float = 0.22) -> PackedFloat32Array:
	var n := src.size() + int(SR * 0.42)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in src.size():
		out[i] += src[i]
	for tap in [[0.075, 0.62], [0.145, 0.36], [0.235, 0.22]]:
		var off := int(SR * float(tap[0]))
		var g: float = float(tap[1]) * amount
		for i in src.size():
			out[mini(off + i, n - 1)] += src[i] * g
	# fade tail
	var fade := int(SR * 0.12)
	for i in range(maxi(n - fade, 0), n):
		out[i] *= float(n - i) / float(fade)
	return out


func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		var u: int = v if v >= 0 else v + 65536
		data[i * 2] = u & 0xFF
		data[i * 2 + 1] = (u >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _mix(a: PackedFloat32Array, b: PackedFloat32Array,
		offset: int, gain: float = 1.0) -> PackedFloat32Array:
	var need := offset + b.size()
	if a.size() < need:
		a.resize(need)
	for i in b.size():
		a[offset + i] = a[offset + i] + b[i] * gain
	return a


# ================================================================ SFX bank
## Major pentatonic, 12 steps up — letters feel like a rising music box.
const LETTERS := [392.00, 440.00, 493.88, 587.33, 659.25, 783.99,
	880.00, 987.77, 1174.66, 1318.51, 1567.98, 1760.00]


func _build_sfx() -> void:
	# --- letters: soft kalimba, one step up the pentatonic per letter
	for i in 12:
		var s := _mallet(LETTERS[i], 0.62, 0.30, 0.30 + 0.012 * float(i))
		_cache["letter_%d" % i] = _to_wav(_space(s, 0.18))

	# --- soft UI taps
	_cache["btn_down"] = _to_wav(_space(_mallet(523.25, 0.16, 0.26, 0.18), 0.12))
	_cache["btn_up"] = _to_wav(_space(_mallet(783.99, 0.22, 0.20, 0.24), 0.16))
	_cache["tap"] = _to_wav(_space(_mallet(659.25, 0.18, 0.22, 0.20), 0.14))
	_cache["tab"] = _to_wav(_space(_mallet(440.00, 0.24, 0.24, 0.16), 0.18))
	_cache["swipe"] = _to_wav(_mallet(1244.5, 0.09, 0.07, 0.5))

	# --- correct word: warm marimba triad, gently rising
	var ok := PackedFloat32Array()
	var okn := [523.25, 659.25, 783.99]
	for i in okn.size():
		ok = _mix(ok, _mallet(float(okn[i]), 0.95, 0.30, 0.28), int(SR * 0.06 * float(i)))
	ok = _mix(ok, _pad(261.63, 1.1, 0.05), 0)
	_cache["word_ok"] = _to_wav(_space(ok, 0.26))
	_cache["word_ok_hi"] = _to_wav(_space(ok, 0.0))

	# --- bonus word: sparkling kalimba cascade
	var bw := PackedFloat32Array()
	var bwn := [659.25, 783.99, 987.77, 1174.66, 1567.98]
	for i in bwn.size():
		bw = _mix(bw, _mallet(float(bwn[i]), 1.0, 0.24, 0.42 + 0.03 * float(i)),
			int(SR * 0.055 * float(i)))
	bw = _mix(bw, _pad(392.0, 1.3, 0.05), 0)
	_cache["word_bonus"] = _to_wav(_space(bw, 0.30))

	# --- wrong / duplicate: soft, low, forgettable
	_cache["word_bad"] = _to_wav(_space(_muted(155.56, 0.26, 0.26), 0.10))
	_cache["already"] = _to_wav(_space(_muted(233.08, 0.20, 0.18), 0.12))

	# --- coins: soft metallic ting (two sines, quick decay, shimmer tail)
	var coin := PackedFloat32Array()
	coin = _mix(coin, _mallet(1318.51, 0.42, 0.20, 0.55), 0)
	coin = _mix(coin, _mallet(1975.53, 0.34, 0.12, 0.6), int(SR * 0.02))
	_cache["coin"] = _to_wav(_space(coin, 0.22))

	# --- star: rising sparkle
	var st := PackedFloat32Array()
	for i in 3:
		st = _mix(st, _mallet(880.0 * pow(1.25, float(i)), 0.7, 0.17, 0.5),
			int(SR * 0.08 * float(i)))
	_cache["star"] = _to_wav(_space(st, 0.26))

	# --- level win: warm 6-note cadence over a soft pad
	var win := PackedFloat32Array()
	var wn := [392.00, 440.00, 523.25, 659.25, 783.99, 1046.50]
	for i in wn.size():
		win = _mix(win, _mallet(float(wn[i]), 1.7, 0.27, 0.30 + 0.04 * float(i)),
			int(SR * 0.10 * float(i)))
	win = _mix(win, _pad(196.0, 2.6, 0.10), 0)
	win = _mix(win, _pad(293.66, 2.6, 0.06), 0)
	_cache["win"] = _to_wav(_space(win, 0.30))

	# --- hint: airy shimmer
	var hint := PackedFloat32Array()
	hint = _mix(hint, _mallet(1567.98, 0.6, 0.16, 0.62), 0)
	hint = _mix(hint, _mallet(2093.0, 0.55, 0.11, 0.66), int(SR * 0.05))
	_cache["hint"] = _to_wav(_space(hint, 0.30))
	_cache["unlock"] = _to_wav(_space(_mallet(587.33, 1.2, 0.26, 0.34), 0.26))

	# --- combo / streak: small rising pair, pitch chosen by the caller
	var combo := PackedFloat32Array()
	combo = _mix(combo, _mallet(783.99, 0.5, 0.22, 0.45), 0)
	combo = _mix(combo, _mallet(987.77, 0.5, 0.18, 0.5), int(SR * 0.07))
	_cache["combo"] = _to_wav(_space(combo, 0.24))
	_cache["streak"] = _to_wav(_space(combo, 0.28))

	# --- chest open: soft wooden knock + coin shower
	var ch := PackedFloat32Array()
	ch = _mix(ch, _muted(110.0, 0.22, 0.30), 0)
	for i in 6:
		ch = _mix(ch, _mallet(1174.66 * pow(1.058, float(i)), 0.5, 0.13, 0.5),
			int(SR * (0.10 + 0.055 * float(i))))
	_cache["chest"] = _to_wav(_space(ch, 0.30))

	# --- level up
	var lu := PackedFloat32Array()
	for i in 4:
		lu = _mix(lu, _mallet(523.25 * pow(1.2, float(i)), 1.1, 0.22, 0.4),
			int(SR * 0.07 * float(i)))
	_cache["levelup"] = _to_wav(_space(lu, 0.30))

	# --- shuffle: soft airy swish
	var n := int(SR * 0.35)
	var sw := PackedFloat32Array()
	sw.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env: float = sin(PI * clampf(t / 0.35, 0.0, 1.0)) * 0.16
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.05 + 0.35 * (t / 0.35))
		sw[i] = lp * env
	_cache["shuffle"] = _to_wav(sw)


func play(sound: String, pitch: float = 1.0) -> void:
	if not bool(Game.settings.get("sfx", true)):
		return
	var stream: AudioStreamWAV = _cache.get(sound)
	if stream == null:
		return
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = _sfx_db()
	p.play()


func play_letter(index: int) -> void:
	play("letter_%d" % clampi(index, 0, 11))


func _sfx_db() -> float:
	var v: float = float(Game.settings.get("sfx_volume", 1.0))
	return -60.0 if v <= 0.001 else linear_to_db(clampf(v, 0.0, 1.0))


func _music_db() -> float:
	var v: float = float(Game.settings.get("music_volume", 0.85))
	if v <= 0.001:
		return -60.0
	return linear_to_db(clampf(v, 0.0, 1.0)) - 7.0


func vibrate(ms: int = 20) -> void:
	if bool(Game.settings.get("vibration", true)) and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)


# ================================================================== music
## Ask for the music of a screen; called from every scene's _ready().
func set_section(name: String) -> void:
	if not bool(Game.settings.get("music", true)):
		_want_section = name
		return
	_want_section = name
	if name == _section and _music_active.playing:
		return
	if _tracks.has(name):
		_section = name
		_crossfade(_tracks[name])
		return
	_start_build(name)


func current_section() -> String:
	return _section


func start_music() -> void:
	var target := _want_section if _want_section != "" else "home"
	set_section(target)


func stop_music() -> void:
	_section = ""
	for p in [_music_a, _music_b]:
		if p:
			var mx: AudioStreamPlayer = p
			var tw: Tween = mx.create_tween()
			tw.tween_property(mx, "volume_db", -60.0, 0.4)
	_section_stopped = true


var _section_stopped := false


func set_music_enabled(on: bool) -> void:
	if on:
		_section = ""
		set_section(_want_section if _want_section != "" else "home")
	else:
		stop_music()


func _crossfade(stream: AudioStreamWAV) -> void:
	_section_stopped = false
	var outgoing := _music_active
	var incoming := _music_b if _music_active == _music_a else _music_a
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	_music_active = incoming
	var target_db := _music_db()
	var t1 := incoming.create_tween()
	t1.tween_property(incoming, "volume_db", target_db, 1.1)
	if outgoing and outgoing.playing:
		var t2 := outgoing.create_tween()
		t2.tween_property(outgoing, "volume_db", -60.0, 1.1)
		t2.tween_callback(func() -> void:
			if is_instance_valid(outgoing) and outgoing != _music_active:
				outgoing.stop())


# ------------------------------------------------------- background builder
func _start_build(name: String) -> void:
	if _thread != null and _thread.is_alive():
		return
	if not SPECS.has(name):
		name = "home"
	_pending_name = name
	_pending_raw = PackedFloat32Array()
	_thread = Thread.new()
	_thread.start(_build_track_thread.bind(name))


func _build_track_thread(name: String) -> void:
	var raw := _compose(name)
	call_deferred("_store_track", name, raw)


func _store_track(name: String, raw: PackedFloat32Array) -> void:
	if raw.is_empty():
		return
	_tracks[name] = _to_wav(raw, true)
	if _pending_name == name and _want_section == name:
		if bool(Game.settings.get("music", true)):
			_section = name
			_crossfade(_tracks[name])


func _poll_builder() -> void:
	if _thread != null and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	# if the wanted section was never built (thread was busy), retry
	if _want_section != "" and not _tracks.has(_want_section):
		if _thread == null:
			_start_build(_want_section)


## A calm, loopable track: pad bed + bass + arpeggio lead + accents.
## Deterministic (seeded) so the same screen always sounds identical.
func _compose(name: String) -> PackedFloat32Array:
	var sp: Dictionary = SPECS[name]
	var bpm: float = float(sp["bpm"])
	var key: float = float(sp["key"])
	var mode: Array = sp["mode"]
	var bars: int = int(sp["bars"])
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var dur := bar * float(bars)
	var n := int(SR * dur)
	var mix := PackedFloat32Array()
	mix.resize(n)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) & 0x7FFFFFFF

	# --- pad bed: key + fifth + octave, one chord per bar
	for b in bars:
		var root_i: int = [0, 5, 3, 4][b % 4]
		var root: float = key * pow(2.0, float(mode[root_i % mode.size()]) / 12.0)
		var off := int(SR * bar * float(b))
		mix = _mix(mix, _pad(root, bar * 1.02, 0.055 * float(sp["pad"])), off)
		mix = _mix(mix, _pad(root * 1.4983, bar * 1.02, 0.035 * float(sp["pad"])),
			off + int(SR * 0.04))
		mix = _mix(mix, _pad(root * 2.0, bar * 0.9, 0.020 * float(sp["pad"])),
			off + int(SR * 0.12))

	# --- bass: soft, on beats 1 and 3
	for b in bars:
		var root_i: int = [0, 5, 3, 4][b % 4]
		var root: float = key * 0.5 * pow(2.0, float(mode[root_i % mode.size()]) / 12.0)
		for k in [0, 2]:
			var off := int(SR * (bar * float(b) + beat * float(k)))
			mix = _mix(mix, _mallet(root, beat * 1.6, 0.30 * float(sp["bass"]), 0.05), off)

	# --- lead: an 8-step phrase per bar, mostly on the pentatonic core
	var phrases := [
		[0, 1, 2, 4, 3, 2, 1, 0],
		[2, 3, 4, 5, 4, 3, 2, 1],
		[4, 5, 6, 5, 4, 2, 3, 4],
		[3, 2, 1, 2, 4, 3, 2, 0],
	]
	var step := beat * 0.5
	for b in bars:
		var ph: Array = phrases[(b + int(rng.randf() * 0.0)) % phrases.size()]
		if b % 4 == 3:
			ph = phrases[3]
		for k in 8:
			if bool(sp["lead"]) and rng.randf() < 0.10:
				continue
			var deg: int = int(ph[k])
			var f: float = key * pow(2.0, float(mode[deg % mode.size()]) / 12.0)
			if deg >= mode.size():
				f *= 2.0
			var vel: float = 0.36 * float(sp["lead"]) * (1.0 if k % 2 == 0 else 0.78)
			var off := int(SR * (bar * float(b) + step * float(k)))
			if off >= n:
				break
			mix = _mix(mix, _mallet(f, 1.05, vel, 0.30 + 0.04 * float(b % 3)), off)

	# --- sparkle accents
	var sparkle := float(sp["sparkle"])
	if sparkle > 0.01:
		for b in bars:
			var off := int(SR * (bar * float(b) + beat * 3.5))
			if rng.randf() < 0.55 and off < n:
				var f: float = key * 2.0 * pow(2.0, float(mode[rng.randi_range(2, 6)]) / 12.0)
				mix = _mix(mix, _mallet(f, 0.9, 0.16 * sparkle, 0.62), off)

	# --- soft pulse (very light, like a hand drum a room away)
	if name in ["shop", "quests", "map"]:
		var bt := 0.0
		while bt < dur - 0.1:
			var off := int(SR * bt)
			var hit_n := int(SR * 0.12)
			var hit := PackedFloat32Array()
			hit.resize(hit_n)
			for i in hit_n:
				var t := float(i) / SR
				hit[i] = sin(96.0 * TAU * t) * exp(-30.0 * t) * 0.05
			mix = _mix(mix, hit, off)
			bt += beat * 2.0

	# --- normalise + seamless loop seam
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(mix[i]))
	var gain: float = (0.80 / peak) if peak > 0.001 else 1.0
	var fade := int(SR * 1.2)
	for i in n:
		var g := gain
		if i < fade:
			g *= float(i) / float(fade)
		elif i > n - fade:
			g *= float(n - i) / float(fade)
		mix[i] = clampf(mix[i] * g, -1.0, 1.0)
	if mix.size() > n:
		mix.resize(n)
	return mix


func _exit_tree() -> void:
	## never leave the music worker running when the engine shuts down
	if _thread != null and _thread.is_alive():
		_thread.wait_to_finish()
	_thread = null
