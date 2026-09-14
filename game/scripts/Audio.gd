extends Node
## ============================================================================
##  صدای واژه‌سفر — نسخهٔ ۲
##  ● جلوه‌ها: «کالیمبا/ماریمبا مخملی» — سینوسی + هارمونیک‌های نرم + فضای کوتاه
##    (به‌جای صدای تیز سنتور): کوتاه، گرم، با تغییرات ریز تصادفی تا خسته‌کننده نباشد
##  ● موسیقی: هر بخش موسیقی خودش را دارد — خانه/نقشه/مرحله/فروشگاه/جایزه‌ها
##    همه در خانوادهٔ دو ماژور و پنتاتونیک (حس گرم و بی‌اضطراب) با ضربان آرام
##  ● دوکِ خودکار: هنگام پخش جلوه‌های مهم، موسیقی لحظه‌ای کم می‌شود
## ============================================================================

const SR := 24000.0

# ------------------------------------------------------------------ players
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _mus_a: AudioStreamPlayer
var _mus_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_idle: AudioStreamPlayer
var _cache: Dictionary = {}
var _tracks: Dictionary = {}          # name -> AudioStreamWAV
var _threads: Dictionary = {}         # name -> Thread
var _current_track := ""
var _target_vol_db := -9.0
var _duck := 0.0
var _rng := RandomNumberGenerator.new()

# پنتاتونیک دو ماژور (نت‌های گرم و بدون نیم‌پرده → همیشه خوش‌صدا)
const PENTA := [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33,
		659.25, 784.00, 880.00, 1046.50, 1174.66]


func _ready() -> void:
	_rng.seed = 90210
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx.append(p)
	_mus_a = AudioStreamPlayer.new()
	_mus_b = AudioStreamPlayer.new()
	for m in [_mus_a, _mus_b]:
		m.bus = "Master"
		m.volume_db = -80.0
		add_child(m)
	_music_active = _mus_a
	_music_idle = _mus_b
	set_process(true)
	_build_sfx()


# ============================================================ synthesis core
## تُن نرمِ کالیمبا/ماریمبا: پایه + دو هارمونیک ملایم + پاکت نمایی
func _mallet(freq: float, dur: float, vol: float, bright: float = 0.22,
		decay: float = 7.0) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var attack := 0.0035
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-decay * t)
		if t < attack:
			env *= t / attack
		var ph: float = TAU * freq * t
		var s: float = sin(ph)
		s += sin(ph * 2.0) * bright
		s += sin(ph * 3.01) * bright * 0.34
		s += sin(ph * 4.98) * bright * 0.12
		# ضربهٔ بسیار کوتاه برای حس «چوب/فلز نرم»
		if t < 0.012:
			s += sin(ph * 6.4) * 0.10 * (1.0 - t / 0.012)
		out[i] = s * env * vol * 0.62
	return out


## ضربهٔ مخملی (بازخورد دکمه): نویز فیلترشده + بدنهٔ کم‌فرکانس، بسیار کوتاه
func _felt_tap(freq: float, dur: float, vol: float, damp: float = 0.22) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-46.0 * t) * minf(1.0, t / 0.0015)
		var white := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, white, damp + 0.5 * (t / dur))
		var body: float = sin(TAU * freq * t) * 0.55
		out[i] = (body + lp * 0.75) * env * vol
	return out


## زنگ نرم (سکه/ستاره) — سینوسی با هارمونیک پنجم و دنبالهٔ کوتاه
func _soft_bell(freqs: Array, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var env: float = exp(-6.5 * t) * minf(1.0, t / 0.002)
		var s := 0.0
		for j in freqs.size():
			var f: float = float(freqs[j])
			var amp: float = 1.0 / (1.0 + float(j) * 1.1)
			s += sin(TAU * f * t) * amp
			s += sin(TAU * f * 2.0 * t) * amp * 0.10 * exp(-9.0 * t)
		out[i] = s * env * vol / float(maxi(freqs.size(), 1))
	return out


## فضای کوتاه و گرم (شبیه اتاق چوبی) — چند بازتاب محو
func _room(x: PackedFloat32Array, wet: float = 0.22) -> PackedFloat32Array:
	var taps := [[0.019, 0.55], [0.031, 0.40], [0.047, 0.28], [0.071, 0.18]]
	var out := x.duplicate()
	for tap in taps:
		var off := int(SR * float(tap[0]))
		var g: float = float(tap[1]) * wet
		for i in range(0, x.size()):
			var j := i + off
			if j >= out.size():
				break
			out[j] += x[i] * g
	return out


func _mix_at(a: PackedFloat32Array, b: PackedFloat32Array, offset: int,
		gain: float = 1.0) -> PackedFloat32Array:
	var need := offset + b.size()
	if a.size() < need:
		a.resize(need)
	for i in b.size():
		a[offset + i] += b[i] * gain
	return a


func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: int = clampi(int(clampf(samples[i], -1.0, 1.0) * 32767.0), -32768, 32767)
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


# ============================================================== SFX bank
func _build_sfx() -> void:
	# --- حروف: نردبان پنتاتونیک (۱۲ نت) با تیمبر نرمِ کالیمبا
	for i in 12:
		var s := _mallet(float(PENTA[i]), 0.78, 0.40, 0.24, 6.2)
		s = _room(s, 0.16)
		_cache["letter_%d" % i] = _to_wav(s)

	# --- دکمه‌ها: ضربه‌های مخملی کوتاه
	_cache["btn_down"] = _to_wav(_felt_tap(420.0, 0.070, 0.30, 0.20))
	var up := _felt_tap(660.0, 0.055, 0.22, 0.32)
	up = _room(up, 0.12)
	_cache["btn_up"] = _to_wav(up)
	_cache["tap"] = _to_wav(_felt_tap(520.0, 0.060, 0.26, 0.26))
	_cache["swipe"] = _to_wav(_felt_tap(900.0, 0.040, 0.12, 0.5))

	# --- کلمهٔ درست: آرپژ گرم دو ماژور (سه نت، نرم و صعودی)
	var okm := PackedFloat32Array()
	var triad := [523.25, 659.25, 784.00]
	for i in triad.size():
		okm = _mix_at(okm, _mallet(float(triad[i]), 0.9, 0.38, 0.20, 5.4),
			int(SR * 0.062 * float(i)))
	okm = _mix_at(okm, _soft_bell([1567.98], 0.5, 0.10), int(SR * 0.10))
	_cache["word_ok"] = _to_wav(_room(okm, 0.24))

	# --- کلمهٔ جایزه‌ای: صعود پنج‌نتی + جرقهٔ ریز
	var bm := PackedFloat32Array()
	var bseq := [523.25, 659.25, 784.00, 880.00, 1046.50]
	for i in bseq.size():
		bm = _mix_at(bm, _mallet(float(bseq[i]), 0.85, 0.34, 0.30, 5.8),
			int(SR * 0.052 * float(i)))
	bm = _mix_at(bm, _soft_bell([2093.0, 2637.0], 0.6, 0.09), int(SR * 0.16))
	_cache["word_bonus"] = _to_wav(_room(bm, 0.28))

	# --- خطا: کوفتهٔ نرم و کم (هرگز گوش‌آزار نیست)
	var bad := PackedFloat32Array()
	bad = _mix_at(bad, _mallet(180.0, 0.28, 0.34, 0.06, 11.0), 0)
	bad = _mix_at(bad, _mallet(146.83, 0.30, 0.22, 0.04, 12.0), int(SR * 0.012))
	bad = _mix_at(bad, _felt_tap(240.0, 0.09, 0.16, 0.10), 0)
	_cache["word_bad"] = _to_wav(_room(bad, 0.14))
	_cache["already"] = _to_wav(_room(_mallet(392.0, 0.30, 0.20, 0.14, 9.0), 0.16))

	# --- سکه و ستاره
	var coin := _soft_bell([1318.5, 1975.5], 0.42, 0.30)
	_cache["coin"] = _to_wav(_room(coin, 0.22))
	var st := PackedFloat32Array()
	for i in 3:
		st = _mix_at(st, _soft_bell([880.0 * pow(1.25, float(i))], 0.5, 0.28),
			int(SR * 0.065 * float(i)))
	_cache["star"] = _to_wav(_room(st, 0.26))

	# --- بردِ مرحله: کادنس گرم دو ماژور با شناوری نرم
	var win := PackedFloat32Array()
	var wseq := [523.25, 659.25, 784.00, 880.00, 1046.50, 1318.5]
	for i in wseq.size():
		win = _mix_at(win, _mallet(float(wseq[i]), 1.6, 0.34, 0.22, 4.2),
			int(SR * 0.088 * float(i)))
	win = _mix_at(win, _soft_bell([523.25, 659.25, 784.00], 2.0, 0.14), int(SR * 0.02))
	_cache["win"] = _to_wav(_room(win, 0.34))

	_cache["hint"] = _to_wav(_room(_soft_bell([1046.5, 1568.0], 0.5, 0.26), 0.22))
	_cache["unlock"] = _to_wav(_room(_mallet(587.33, 1.0, 0.28, 0.24, 4.6), 0.24))

	# --- بُر زدن: نسیم نرم نویزی
	var n := int(SR * 0.36)
	var sw := PackedFloat32Array()
	sw.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env: float = sin(PI * clampf(t / 0.36, 0.0, 1.0)) * 0.18
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.05 + 0.42 * (t / 0.36))
		sw[i] = lp * env
	_cache["shuffle"] = _to_wav(sw)


# ==================================================================== SFX play
func play(sound: String, pitch: float = 1.0) -> void:
	if not Game.settings.get("sfx", true):
		return
	var stream: AudioStreamWAV = _cache.get(sound)
	if stream == null:
		return
	var p := _sfx[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx.size()
	p.stream = stream
	# تغییرات ریز تصادفی → حس زنده و غیرتکراری
	p.pitch_scale = pitch * _rng.randf_range(0.985, 1.018)
	p.volume_db = 0.0
	p.play()
	if sound == "word_ok" or sound == "word_bonus" or sound == "win" or sound == "star":
		duck_for(0.45, 1.6)


func play_letter(index: int) -> void:
	play("letter_%d" % clampi(index, 0, 11))


## موسیقی را لحظه‌ای خفیف می‌کند (شفاف‌شدن جلوه‌ها)
func duck_for(amount: float, seconds: float) -> void:
	_duck = maxf(_duck, amount)
	var t := get_tree().create_timer(seconds)
	t.timeout.connect(func(): _duck = maxf(0.0, _duck - amount))


func vibrate(ms: int = 20) -> void:
	if Game.settings.get("vibration", true) and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)


# ================================================================== music
const TRACK_VOL := {
	"home": -8.0, "map": -10.5, "level": -14.0, "shop": -10.0,
	"quests": -11.0, "calm": -12.0,
}


func start_music(track := "") -> void:
	if track == "":
		track = _track_for_scene()
	set_track(track)


func _track_for_scene() -> String:
	var path := ""
	var sc := get_tree().current_scene
	if sc != null:
		path = sc.scene_file_path
	if path.contains("Home"):
		return "home"
	if path.contains("Map"):
		return "map"
	if path.contains("Level"):
		return "level"
	if path.contains("Shop"):
		return "shop"
	if path.contains("Quest"):
		return "quests"
	return "calm"


## تعویض نرمِ موسیقیِ هر بخش (کراس‌فید)
func set_track(name: String) -> void:
	if _current_track == name:
		return
	_current_track = name
	_target_vol_db = float(TRACK_VOL.get(name, -11.0))
	if not Game.settings.get("music", true):
		return
	if not _tracks.has(name):
		_request_build(name)
		return
	_crossfade_to(_tracks[name])


func _request_build(name: String) -> void:
	if _threads.has(name):
		return
	var th := Thread.new()
	th.start(_build_track_thread.bind(name))
	_threads[name] = th


func _build_track_thread(name: String) -> AudioStreamWAV:
	# ساخته‌شدن سنگین در پس‌زمینه تا گیم‌پلی قطع نشود
	var stream := _make_track(name)
	return stream


func _process(_delta: float) -> void:
	# تکمیل ساختِ پس‌زمینه
	if not _threads.is_empty():
		for name in _threads.keys():
			var th: Thread = _threads[name]
			if th.is_alive():
				continue
			var stream: AudioStreamWAV = th.wait_to_finish()
			_threads.erase(name)
			_tracks[name] = stream
			if name == _current_track and Game.settings.get("music", true):
				_crossfade_to(stream)
	# تنظیم بلندی با در نظر گرفتن دوک
	var want: float = _target_vol_db
	if not Game.settings.get("music", true):
		want = -80.0
	elif _duck > 0.0:
		want = _target_vol_db - 6.5 * _duck
	if _music_active != null:
		_music_active.volume_db = lerpf(_music_active.volume_db, want, 0.06)


func _crossfade_to(stream: AudioStreamWAV) -> void:
	var old := _music_active
	var next := _music_idle
	next.stream = stream
	next.volume_db = -60.0
	next.play()
	_music_active = next
	_music_idle = old
	var tw := create_tween()
	tw.tween_property(next, "volume_db", _target_vol_db, 0.9)
	if old.playing:
		var tw2 := create_tween()
		tw2.tween_property(old, "volume_db", -60.0, 0.9)
		tw2.tween_callback(old.stop)


func stop_music() -> void:
	_target_vol_db = -80.0
	for m in [_mus_a, _mus_b]:
		if m != null and m.playing:
			var tw := create_tween()
			tw.tween_property(m, "volume_db", -60.0, 0.5)
			tw.tween_callback(m.stop)


func set_music_enabled(on: bool) -> void:
	if on:
		_target_vol_db = float(TRACK_VOL.get(_current_track, -11.0))
		if _tracks.has(_current_track):
			_crossfade_to(_tracks[_current_track])
		else:
			_request_build(_current_track)
	else:
		stop_music()


# ===================================================== per-screen composition
## ساخت موسیقی هر بخش: پیشروی آکورد، آرپژ ملایم، پد گرم و ضربانِ نرم
## همه در دو ماژور (یا لا مینور ملایم برای صفحهٔ فروشگاه) تا حس یکدست بدهد.
func _make_track(name: String) -> AudioStreamWAV:
	var spec := _track_spec(name)
	var bpm: float = float(spec["bpm"])
	var bars: int = int(spec["bars"])
	var beat: float = 60.0 / bpm
	var bar_len: float = beat * 4.0
	var dur: float = bar_len * float(bars)
	var n := int(SR * dur)
	var mix := PackedFloat32Array()
	mix.resize(n)

	var prog: Array = spec["chords"]      # [[root, third, fifth], ...]
	var melody: Array = spec["melody"]    # الگوهای نت (اندیس در مقیاس)
	var scale: Array = spec["scale"]
	var pad_gain: float = float(spec.get("pad", 0.05))
	var arp_gain: float = float(spec.get("arp", 0.10))
	var mel_gain: float = float(spec.get("mel", 0.12))
	var perc_gain: float = float(spec.get("perc", 0.06))

	# --- پدِ گرم: آکورد هر میزان، حمله و رهاشدن نرم
	for b in bars:
		var chord: Array = prog[b % prog.size()]
		var start := int(SR * bar_len * float(b))
		for j in chord.size():
			var f: float = float(chord[j]) * (0.5 if j == 0 else 1.0)
			var note := _pad_note(f, bar_len * 1.15, pad_gain * (1.0 - 0.22 * float(j)))
			mix = _mix_at(mix, note, start + int(SR * 0.01 * float(j)))

	# --- آرپژ ملایم روی آکورد (حس سفر و آرامش)
	var arp_step: float = beat * 0.5
	var t := 0.0
	var k := 0
	while t < dur - 0.4:
		var b := int(t / bar_len)
		var chord: Array = prog[b % prog.size()]
		var pick: float = float(chord[k % chord.size()]) * (2.0 if k % 4 == 2 else 1.0)
		mix = _mix_at(mix, _mallet(pick, 1.0, arp_gain, 0.16, 6.4), int(SR * t))
		t += arp_step
		k += 1

	# --- ملودی: عبارت‌های کوتاه با فاصله‌های نفس‌گیر
	var pos: float = beat * 0.5
	var mi := 0
	while pos < dur - 1.2:
		var phrase: Array = melody[mi % melody.size()]
		for step in phrase:
			var idxn: int = int(step)
			if idxn >= 0:
				var f: float = float(scale[idxn % scale.size()])
				var accent: bool = (pos - floor(pos / bar_len) * bar_len) < 0.05
				mix = _mix_at(mix, _mallet(f, 1.4, mel_gain * (1.15 if accent else 1.0), 0.20, 5.2),
					int(SR * pos))
			pos += beat * 0.5
			if pos >= dur - 1.2:
				break
		pos += beat * float(1 + mi % 2)   # نفس بین عبارت‌ها
		mi += 1

	# --- ضربان نرم (طبلِ کف‌دستی محو) روی ضرب‌های ۱ و ۳
	if perc_gain > 0.0:
		var bt := 0.0
		while bt < dur:
			mix = _mix_at(mix, _felt_tap(96.0, 0.22, perc_gain, 0.08), int(SR * bt))
			mix = _mix_at(mix, _felt_tap(150.0, 0.10, perc_gain * 0.5, 0.14),
				int(SR * (bt + beat * 2.0)))
			bt += bar_len

	# --- نرمال‌سازی + دوختِ بی‌صدای لوپ
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(mix[i]))
	var gain: float = (0.86 / peak) if peak > 0.001 else 1.0
	var fade := int(SR * 0.35)
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


## پد نرم: دو سینوس با لرزش آرام و پاکت کشیده
func _pad_note(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var k: float = t / dur
		var env: float = sin(PI * clampf(k, 0.0, 1.0))
		var vib: float = 1.0 + 0.0016 * sin(TAU * 4.5 * t)
		var s: float = sin(TAU * freq * vib * t) + 0.42 * sin(TAU * freq * 2.0 * vib * t)
		s += 0.16 * sin(TAU * freq * 3.0 * t)
		out[i] = s * env * vol * 0.5
	return out


func _track_spec(name: String) -> Dictionary:
	# دو ماژور: C D E F G A B — آکوردها به فرکانس
	var C5 := 523.25
	match name:
		"home":
			return {
				"bpm": 84.0, "bars": 8,
				"scale": [392.00, 440.00, 523.25, 587.33, 659.25, 784.00, 880.00],
				"chords": [[261.63, 329.63, 392.00], [349.23, 440.00, 523.25],
					[392.00, 493.88, 587.33], [261.63, 329.63, 392.00]],
				"melody": [[2, 3, 4, -1], [4, 3, 2, 1], [3, 4, 5, -1], [5, 4, 2, -1],
					[0, 1, 2, 3], [4, -1, 3, 2]],
				"pad": 0.055, "arp": 0.085, "mel": 0.115, "perc": 0.05,
			}
		"map":
			return {
				"bpm": 72.0, "bars": 8,
				"scale": [329.63, 392.00, 440.00, 523.25, 587.33, 659.25, 784.00],
				"chords": [[261.63, 329.63, 392.00], [293.66, 349.23, 440.00],
					[349.23, 440.00, 523.25], [261.63, 329.63, 392.00]],
				"melody": [[3, 2, 1, -1], [1, 2, 3, 4], [5, 4, 3, -1], [2, 1, 0, -1]],
				"pad": 0.07, "arp": 0.07, "mel": 0.10, "perc": 0.032,
			}
		"level":
			return {
				"bpm": 68.0, "bars": 6,
				"scale": [261.63, 329.63, 392.00, 440.00, 523.25, 587.33],
				"chords": [[261.63, 329.63, 392.00], [261.63, 329.63, 392.00],
					[349.23, 440.00, 523.25], [261.63, 329.63, 392.00]],
				"melody": [[2, -1, -1, -1], [-1, -1, 3, -1], [1, -1, -1, -1], [-1, 4, -1, -1]],
				"pad": 0.075, "arp": 0.045, "mel": 0.062, "perc": 0.024,
			}
		"shop":
			return {
				"bpm": 96.0, "bars": 8,
				"scale": [392.00, 440.00, 493.88, 587.33, 659.25, 784.00, 880.00],
				"chords": [[261.63, 329.63, 392.00], [392.00, 493.88, 587.33],
					[349.23, 440.00, 523.25], [392.00, 493.88, 587.33]],
				"melody": [[3, 4, 5, -1], [5, 4, 3, 2], [4, 3, 2, 1], [2, 3, 4, -1]],
				"pad": 0.045, "arp": 0.10, "mel": 0.11, "perc": 0.055,
			}
		"quests":
			return {
				"bpm": 80.0, "bars": 8,
				"scale": [392.00, 440.00, 523.25, 587.33, 659.25, 784.00, 880.00],
				"chords": [[349.23, 440.00, 523.25], [293.66, 349.23, 440.00],
					[261.63, 329.63, 392.00], [349.23, 440.00, 523.25]],
				"melody": [[4, 3, 2, 3], [-1, 2, 1, -1], [3, 2, 1, 2], [-1, 0, 1, -1]],
				"pad": 0.06, "arp": 0.075, "mel": 0.10, "perc": 0.04,
			}
		_:
			return {
				"bpm": 70.0, "bars": 6,
				"scale": [261.63, 293.66, 329.63, 392.00, 440.00, 523.25],
				"chords": [[261.63, 329.63, 392.00], [261.63, 329.63, 392.00],
					[293.66, 349.23, 440.00], [261.63, 329.63, 392.00]],
				"melody": [[2, -1, 1, -1], [-1, 3, -1, -1], [1, 2, -1, -1], [-1, -1, 0, -1]],
				"pad": 0.06, "arp": 0.06, "mel": 0.075, "perc": 0.028,
			}
