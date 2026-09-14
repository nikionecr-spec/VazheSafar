extends SceneTree
## Renders every music track and a few sound effects to WAV so you can listen
## to them outside the game:  xvfb-run -a godot --path game --script devtools/AudioPreview.gd
## Files land in the app user folder: ~/.local/share/godot/app_userdata/<name>/audio/

const SECTIONS := ["home", "map", "level", "shop", "quests", "library", "themes", "settings"]
const SFX := ["letter_0", "letter_5", "btn_down", "btn_up", "word_ok", "word_bonus",
	"word_bad", "coin", "star", "win", "hint", "shuffle", "chest", "combo"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://audio")
	var au: Node = root.get_node("/root/Audio")
	for s in SECTIONS:
		var raw: PackedFloat32Array = au.call("_compose", s)
		var stream: AudioStreamWAV = au.call("_to_wav", raw, true)
		_write("user://audio/music_%s.wav" % s, stream)
		print("music_%s.wav   %.1f s" % [s, float(stream.data.size() / 2) / 32000.0])
	for key in SFX:
		var cache: Dictionary = au.get("_cache")
		var st: AudioStreamWAV = cache.get(key)
		if st != null:
			_write("user://audio/sfx_%s.wav" % key, st)
			print("sfx_%s.wav" % key)
	print("done — files in user://audio")
	quit()


func _write(path: String, stream: AudioStreamWAV) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(_wav_header(stream))
	f.store_buffer(stream.data)
	f.close()


func _wav_header(stream: AudioStreamWAV) -> PackedByteArray:
	var data_size := stream.data.size()
	var h := PackedByteArray()
	h.append_array("RIFF".to_ascii_buffer())
	h.append_array(_le32(36 + data_size))
	h.append_array("WAVEfmt ".to_ascii_buffer())
	h.append_array(_le32(16))
	h.append_array(_le16(1))
	h.append_array(_le16(1))
	h.append_array(_le32(stream.mix_rate))
	h.append_array(_le32(stream.mix_rate * 2))
	h.append_array(_le16(2))
	h.append_array(_le16(16))
	h.append_array("data".to_ascii_buffer())
	h.append_array(_le32(data_size))
	return h


func _le32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)
	b.append((v >> 16) & 0xFF)
	b.append((v >> 24) & 0xFF)
	return b


func _le16(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)
	return b
