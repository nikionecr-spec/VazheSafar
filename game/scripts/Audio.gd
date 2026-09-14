extends Node
## Procedurally synthesised SFX + ambient music. Autoloaded as `Audio`.
## No external audio files needed - everything is generated at runtime.

const SR := 22050.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _music: AudioStreamPlayer
var _cache: Dictionary = {}


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -14.0
	add_child(_music)
	_build_cache()


# ------------------------------------------------------------- synthesis core
func _tone(freqs: Array, dur: float, vol: float = 0.4, decay: float = 6.0,
		wave: String = "sine", vibrato: float = 0.0) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-decay * t)
		# soft attack to avoid clicks
		env *= minf(1.0, t / 0.008)
		var s := 0.0
		for f_raw in freqs:
			var f: float = float(f_raw)
			if vibrato > 0.0:
				f += sin(t * TAU * 5.5) * vibrato
			var ph: float = t * f
			match wave:
				"square":
					s += 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
				"saw":
					s += 2.0 * fmod(ph, 1.0) - 1.0
				"tri":
					var x: float = fmod(ph, 1.0)
					s += (4.0 * x - 1.0) if x < 0.5 else (3.0 - 4.0 * x)
				_:
					s += sin(ph * TAU)
		s /= float(freqs.size())
		var v: int = clampi(int(s * env * vol * 32767.0), -32768, 32767)
		var u: int = v if v >= 0 else v + 65536
		data[i * 2] = u & 0xFF
		data[i * 2 + 1] = (u >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.stereo = false
	w.data = data
	return w


func _noise(dur: float, vol: float, decay: float, lp: float = 0.35) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var last := 0.0
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-decay * t) * minf(1.0, t / 0.005)
		var raw := rng.randf_range(-1.0, 1.0)
		last = lerpf(last, raw, lp)
		var v: int = clampi(int(last * env * vol * 32767.0), -32768, 32767)
		var u: int = v if v >= 0 else v + 65536
		data[i * 2] = u & 0xFF
		data[i * 2 + 1] = (u >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.stereo = false
	w.data = data
	return w


func _build_cache() -> void:
	# pentatonic ladder for letter selection - each next letter rises in pitch
	var scale := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7, 1318.5]
	for i in scale.size():
		_cache["letter_%d" % i] = _tone([scale[i]], 0.16, 0.30, 9.0, "tri")
	_cache["word_ok"] = _tone([659.25, 830.6, 987.77], 0.45, 0.34, 4.0, "sine")
	_cache["word_bonus"] = _tone([880.0, 1108.7, 1318.5, 1760.0], 0.55, 0.32, 3.2, "sine")
	_cache["word_bad"] = _tone([196.0, 185.0], 0.22, 0.26, 11.0, "tri")
	_cache["already"] = _tone([440.0], 0.14, 0.20, 12.0, "sine")
	_cache["tap"] = _tone([1046.5], 0.07, 0.22, 22.0, "sine")
	_cache["coin"] = _tone([1318.5, 1975.5], 0.28, 0.26, 9.0, "sine")
	_cache["star"] = _tone([1046.5, 1318.5, 1567.98], 0.5, 0.3, 4.0, "sine")
	_cache["win"] = _tone([523.25, 659.25, 783.99, 1046.5], 0.9, 0.32, 2.2, "sine")
	_cache["hint"] = _tone([1567.98, 2093.0], 0.3, 0.22, 8.0, "sine")
	_cache["shuffle"] = _noise(0.26, 0.22, 10.0, 0.5)
	_cache["unlock"] = _tone([392.0, 523.25, 659.25, 783.99], 0.7, 0.3, 3.0, "tri")


func play(name: String, pitch: float = 1.0) -> void:
	if not Game.settings.get("sfx", true):
		return
	var stream: AudioStreamWAV = _cache.get(name)
	if stream == null:
		return
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


func play_letter(index: int) -> void:
	play("letter_%d" % (index % 8))


func vibrate(ms: int = 20) -> void:
	if Game.settings.get("vibration", true) and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)


# ------------------------------------------------------------------- music
func start_music() -> void:
	if not Game.settings.get("music", true):
		return
	if _music.playing:
		return
	if not _cache.has("music_loop"):
		_cache["music_loop"] = _make_music()
	_music.stream = _cache["music_loop"]
	_music.play()


func stop_music() -> void:
	_music.stop()


func _make_music() -> AudioStreamWAV:
	# gentle 16-second arpeggio loop in C major, warm and unobtrusive
	var dur := 16.0
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var chords := [
		[261.63, 329.63, 392.0],      # C
		[220.0, 261.63, 329.63],      # Am
		[174.61, 220.0, 261.63],      # F
		[196.0, 246.94, 293.66],      # G
	]
	var step := 0.25
	for i in n:
		var t := float(i) / SR
		var bar: int = int(t / 4.0) % chords.size()
		var chord: Array = chords[bar]
		var s := 0.0
		# arpeggio
		var k: int = int(t / step)
		var local: float = t - float(k) * step
		var note: float = float(chord[k % chord.size()]) * (2.0 if (k % 8) >= 4 else 1.0)
		var env: float = exp(-4.0 * local) * minf(1.0, local / 0.01)
		s += sin(note * TAU * t) * env * 0.35
		# soft pad
		for f_raw in chord:
			s += sin(float(f_raw) * 0.5 * TAU * t) * 0.06
		# fade the loop seams
		var fade: float = minf(1.0, minf(t, dur - t) / 0.5)
		var v: int = clampi(int(s * fade * 0.5 * 32767.0), -32768, 32767)
		var u: int = v if v >= 0 else v + 65536
		data[i * 2] = u & 0xFF
		data[i * 2 + 1] = (u >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.stereo = false
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	w.data = data
	return w
