extends Node
## Procedural audio: soft UI clicks, satisfying word chimes, and an
## Iranian-flavoured santur/tar background loop in Dastgah-e Shur.
## Everything is synthesised at runtime - no audio files shipped.

const SR := 32000.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _music: AudioStreamPlayer
var _cache: Dictionary = {}
var _music_built := false


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -13.0
	add_child(_music)
	_build_sfx()


# ============================================================ synthesis core
func _env(t: float, dur: float, attack: float, decay: float,
		sustain: float = 0.0, release: float = 0.05) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	var d := t - attack
	if d < decay:
		var k := d / maxf(decay, 0.0001)
		return lerpf(1.0, sustain, k) if sustain > 0.0 else (1.0 - k)
	if sustain > 0.0:
		var rem := dur - attack - decay
		if rem > 0.0:
			var rt := (t - attack - decay) / rem
			return sustain * (1.0 - rt)
	return 0.0


## Plucked-string voice (Karplus-Strong style) - the santur / tar timbre.
func _pluck(freq: float, dur: float, vol: float, bright: float = 0.5,
		damp: float = 0.996) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var N := int(SR / maxf(freq, 20.0))
	if N < 2:
		N = 2
	var buf := PackedFloat32Array()
	buf.resize(N)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0) & 0x7FFFFFFF
	# excite with filtered noise; less noise = mellower
	var prev := 0.0
	for i in N:
		var white := rng.randf_range(-1.0, 1.0)
		prev = lerpf(prev, white, bright)
		buf[i] = prev
	var idx := 0
	for i in n:
		var cur: float = buf[idx]
		var nxt: float = buf[(idx + 1) % N]
		var avg: float = (cur + nxt) * 0.5 * damp
		buf[idx] = avg
		out[i] = cur * vol
		idx = (idx + 1) % N
	# gentle fade tail so loops never click
	var fade := int(SR * 0.02)
	for i in range(maxi(n - fade, 0), n):
		out[i] *= float(n - i) / float(fade)
	return out


## Soft sine/triangle bell with adjustable body - for UI feedback.
func _bell(freqs: Array, dur: float, vol: float, attack: float = 0.004,
		decay_pow: float = 5.0, wave := "sine") -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-decay_pow * t) * minf(1.0, t / attack)
		var s := 0.0
		for j in freqs.size():
			var f: float = float(freqs[j])
			var amp: float = 1.0 / (1.0 + float(j) * 0.8)
			match wave:
				"tri":
					var x: float = fmod(t * f, 1.0)
					s += ((4.0 * x - 1.0) if x < 0.5 else (3.0 - 4.0 * x)) * amp
				_:
					s += sin(t * f * TAU) * amp
		out[i] = s * env * vol / float(freqs.size())
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
		offset: int) -> PackedFloat32Array:
	var need := offset + b.size()
	if a.size() < need:
		a.resize(need)
	for i in b.size():
		a[offset + i] = a[offset + i] + b[i]
	return a


# ================================================================ SFX bank
# Dastgah-e Shur scale (D): D Eb F G A Bb C - the classic Persian mode.
const SHUR := [293.66, 311.13, 349.23, 392.00, 440.00, 466.16, 523.25,
			   587.33, 622.25, 698.46, 784.00, 880.00]


func _build_sfx() -> void:
	# --- letter selection: rising santur pluck up the Shur scale
	for i in 12:
		var s := _pluck(SHUR[i], 0.42, 0.36, 0.42, 0.9955)
		_cache["letter_%d" % i] = _to_wav(s)

	# --- button press: soft rounded "tok", no harshness
	var down := _bell([520.0, 780.0], 0.075, 0.20, 0.002, 42.0, "sine")
	_cache["btn_down"] = _to_wav(down)
	var up := _bell([880.0, 1320.0], 0.10, 0.15, 0.003, 30.0, "sine")
	_cache["btn_up"] = _to_wav(up)
	_cache["tap"] = _to_wav(_bell([700.0, 1050.0], 0.09, 0.18, 0.002, 34.0))

	# --- correct word: warm ascending santur arpeggio
	var okm := PackedFloat32Array()
	var notes := [440.0, 523.25, 659.25, 880.0]
	for i in notes.size():
		okm = _mix(okm, _pluck(float(notes[i]), 0.75, 0.30, 0.35, 0.9968),
			int(SR * 0.055 * float(i)))
	_cache["word_ok"] = _to_wav(okm)

	# --- bonus word: brighter, with a shimmer on top
	var bm := PackedFloat32Array()
	var bnotes := [523.25, 698.46, 880.0, 1046.5, 1318.5]
	for i in bnotes.size():
		bm = _mix(bm, _pluck(float(bnotes[i]), 0.85, 0.26, 0.5, 0.9972),
			int(SR * 0.05 * float(i)))
	bm = _mix(bm, _bell([2093.0, 2637.0], 0.5, 0.07, 0.01, 5.0), int(SR * 0.1))
	_cache["word_bonus"] = _to_wav(bm)

	# --- wrong word: soft low thud, not an annoying buzz
	_cache["word_bad"] = _to_wav(_bell([196.0, 155.0], 0.20, 0.20, 0.006, 14.0, "tri"))
	_cache["already"] = _to_wav(_bell([466.0, 587.0], 0.16, 0.13, 0.004, 16.0))

	# --- coins: bright metallic ting
	_cache["coin"] = _to_wav(_bell([1567.0, 2093.0, 2637.0], 0.36, 0.17, 0.002, 11.0))

	# --- star: sparkling rise
	var st := PackedFloat32Array()
	for i in 3:
		st = _mix(st, _bell([880.0 * pow(1.26, float(i)),
			1320.0 * pow(1.26, float(i))], 0.5, 0.14, 0.004, 7.0),
			int(SR * 0.07 * float(i)))
	_cache["star"] = _to_wav(st)

	# --- level win: full Shur cadence on santur
	var win := PackedFloat32Array()
	var wseq := [293.66, 349.23, 440.00, 523.25, 587.33, 698.46]
	for i in wseq.size():
		win = _mix(win, _pluck(float(wseq[i]), 1.5, 0.30, 0.4, 0.9980),
			int(SR * 0.085 * float(i)))
	_cache["win"] = _to_wav(win)

	_cache["hint"] = _to_wav(_bell([1318.5, 1760.0], 0.42, 0.15, 0.004, 7.0))
	_cache["unlock"] = _to_wav(_pluck(587.33, 1.0, 0.30, 0.45, 0.9975))

	# --- shuffle: airy swish
	var n := int(SR * 0.33)
	var sw := PackedFloat32Array()
	sw.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env: float = sin(PI * clampf(t / 0.33, 0.0, 1.0)) * 0.22
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.06 + 0.5 * (t / 0.33))
		sw[i] = lp * env
	_cache["shuffle"] = _to_wav(sw)

	# --- swipe drag tick (very quiet, plays as the finger crosses a letter)
	_cache["swipe"] = _to_wav(_bell([1200.0], 0.045, 0.07, 0.001, 60.0))


func play(sound: String, pitch: float = 1.0) -> void:
	if not Game.settings.get("sfx", true):
		return
	var stream: AudioStreamWAV = _cache.get(sound)
	if stream == null:
		return
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


func play_letter(index: int) -> void:
	play("letter_%d" % clampi(index, 0, 11))


func vibrate(ms: int = 20) -> void:
	if Game.settings.get("vibration", true) and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)


# ================================================================== music
func start_music() -> void:
	if not Game.settings.get("music", true):
		return
	if _music.playing:
		return
	if not _music_built:
		_music.stream = _make_persian_loop()
		_music_built = true
	_music.play()


func stop_music() -> void:
	_music.stop()


func set_music_enabled(on: bool) -> void:
	if on:
		start_music()
	else:
		stop_music()


## A calm 24-second santur melody in Dastgah-e Shur over a tonic drone,
## with a soft daf-like pulse. Loops seamlessly.
func _make_persian_loop() -> AudioStreamWAV:
	var dur := 24.0
	var n := int(SR * dur)
	var mix := PackedFloat32Array()
	mix.resize(n)

	# --- tonic drone (D) with a fifth, very soft
	for i in n:
		var t := float(i) / SR
		var slow: float = 0.5 + 0.5 * sin(t * 0.22)
		var d: float = sin(146.83 * TAU * t) * 0.052
		d += sin(220.0 * TAU * t) * 0.032
		d += sin(293.66 * TAU * t) * 0.022 * slow
		mix[i] = d

	# --- santur melody: phrases built from the Shur scale
	var phrase_a := [440.0, 466.16, 523.25, 466.16, 440.0, 392.0, 349.23, 392.0]
	var phrase_b := [523.25, 587.33, 523.25, 466.16, 440.0, 392.0, 440.0, 0.0]
	var phrase_c := [349.23, 392.0, 440.0, 466.16, 523.25, 466.16, 440.0, 392.0]
	var phrase_d := [293.66, 349.23, 392.0, 440.0, 392.0, 349.23, 311.13, 293.66]
	var phrases := [phrase_a, phrase_b, phrase_c, phrase_d]

	var step := 0.375                       # eighth notes at ~80 bpm
	var pos := 0.0
	var pi_ := 0
	while pos < dur - 1.0:
		var ph: Array = phrases[pi_ % phrases.size()]
		for k in ph.size():
			var f: float = float(ph[k])
			if f <= 0.0:
				pos += step
				continue
			var off := int(SR * pos)
			if off >= n:
				break
			# main note
			var vol: float = 0.15 if (k % 4 == 0) else 0.115
			mix = _mix(mix, _pluck(f, 1.1, vol, 0.34, 0.9975), off)
			# octave shimmer on accents (santur has doubled strings)
			if k % 4 == 0:
				mix = _mix(mix, _pluck(f * 2.0, 0.7, 0.045, 0.3, 0.9965),
					off + int(SR * 0.012))
			pos += step
		pi_ += 1

	# --- daf-like soft pulse every bar
	var beat := step * 4.0
	var bt := 0.0
	while bt < dur:
		var off := int(SR * bt)
		if off < n:
			var bn := int(SR * 0.16)
			var rng := RandomNumberGenerator.new()
			rng.seed = int(bt * 97.0)
			var lp := 0.0
			var hit := PackedFloat32Array()
			hit.resize(bn)
			for i in bn:
				var t := float(i) / SR
				var env: float = exp(-26.0 * t)
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.10)
				# low body + noise skin
				hit[i] = (sin(82.0 * TAU * t) * 0.5 + lp * 0.5) * env * 0.085
			mix = _mix(mix, hit, off)
		bt += beat

	# --- normalise and smooth the loop seam
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(mix[i]))
	var gain: float = (0.88 / peak) if peak > 0.001 else 1.0
	var fade := int(SR * 0.6)
	for i in n:
		var g := gain
		if i < fade:
			g *= float(i) / float(fade)
		elif i > n - fade:
			g *= float(n - i) / float(fade)
		mix[i] = clampf(mix[i] * g, -1.0, 1.0)

	if mix.size() > n:
		mix.resize(n)
	return _to_wav(mix, true)
