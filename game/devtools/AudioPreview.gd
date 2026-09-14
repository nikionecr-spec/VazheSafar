extends SceneTree
## موسیقی و جلوه‌های صوتی را به فایل WAV می‌ریزد تا بتوان بیرون از بازی گوش داد.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://audio")
	var au: Node = root.get_node("/root/Audio")
	var names := ["home", "map", "level", "shop", "quests", "calm"]
	for n in names:
		var track: AudioStreamWAV = au.call("_make_track", n)
		_write("user://audio/music_%s.wav" % n, track)
		print("music_%s.wav  %.1f s" % [n, float(track.data.size() / 2) / 24000.0])
	# چند جلوه
	var sfx := ["letter_0", "letter_5", "btn_down", "btn_up", "word_ok", "word_bonus",
		"word_bad", "coin", "star", "win", "hint", "shuffle"]
	for s in sfx:
		var st: AudioStreamWAV = au.get("_cache").get(s)
		if st != null:
			_write("user://audio/sfx_%s.wav" % s, st)
			print("sfx_%s.wav" % s)
	quit()

func _write(path: String, stream: AudioStreamWAV) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	# WAV header (16-bit mono)
	var data: PackedByteArray = stream.data
	var sr: int = stream.mix_rate
	var fh := PackedByteArray()
	fh.append_array("RIFF".to_ascii_buffer())
	_put32(fh, 36 + data.size())
	fh.append_array("WAVE".to_ascii_buffer())
	fh.append_array("fmt ".to_ascii_buffer())
	_put32(fh, 16)
	_put16(fh, 1)
	_put16(fh, 1)
	_put32(fh, sr)
	_put32(fh, sr * 2)
	_put16(fh, 2)
	_put16(fh, 16)
	fh.append_array("data".to_ascii_buffer())
	_put32(fh, data.size())
	f.store_buffer(fh)
	f.store_buffer(data)
	f.close()

func _put32(buf: PackedByteArray, v: int) -> void:
	buf.append(v & 0xFF); buf.append((v >> 8) & 0xFF)
	buf.append((v >> 16) & 0xFF); buf.append((v >> 24) & 0xFF)

func _put16(buf: PackedByteArray, v: int) -> void:
	buf.append(v & 0xFF); buf.append((v >> 8) & 0xFF)
