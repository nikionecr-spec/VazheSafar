extends Node
## Global game state, persistence and level data. Autoloaded as `Game`.

const SAVE_PATH := "user://savegame.json"
const LEVELS_PATH := "res://data/levels.json"

signal coins_changed(value: int)
signal stars_changed(value: int)
signal xp_changed(xp: int, level: int)
signal level_completed(level_id: int, stars: int)

# ---------------------------------------------------------------- static data
var worlds: Array = []
var levels: Array = []
var dictionary: Dictionary = {}      # word -> true, for bonus-word lookup

# ---------------------------------------------------------------- player save
var coins: int = 500
var player_name: String = "کاربر عزیز"
var player_level: int = 1
var xp: int = 0
var current_level: int = 1           # highest unlocked
var stars: Dictionary = {}           # level_id(String) -> stars(int)
var found_bonus: Dictionary = {}     # level_id(String) -> Array[String]
var settings := {
	"music": true,
	"sfx": true,
	"vibration": true,
	"theme": "spring",
}
var daily := {"last_claim": "", "streak": 0}
var quests: Array = []
var stats := {"words_found": 0, "bonus_found": 0, "hints_used": 0, "levels_done": 0}

const XP_PER_LEVEL := 800
const HINT_COST := 80
const REVEAL_COST := 150


func _ready() -> void:
	_load_levels()
	load_game()
	_ensure_quests()


# ------------------------------------------------------------------ level data
func _load_levels() -> void:
	var f := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if f == null:
		push_error("levels.json missing")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("levels.json malformed")
		return
	worlds = parsed.get("worlds", [])
	levels = parsed.get("levels", [])
	for w in parsed.get("dictionary", []):
		dictionary[w] = true


func get_level(id: int) -> Dictionary:
	if id >= 1 and id <= levels.size():
		return levels[id - 1]
	return {}


func total_levels() -> int:
	return levels.size()


func world_of(level_id: int) -> Dictionary:
	var idx: int = clampi((level_id - 1) / 10, 0, maxi(worlds.size() - 1, 0))
	return worlds[idx] if worlds.size() > 0 else {}


func stars_for(level_id: int) -> int:
	return int(stars.get(str(level_id), 0))


func is_unlocked(level_id: int) -> bool:
	return level_id <= current_level


func total_stars() -> int:
	var t := 0
	for k in stars:
		t += int(stars[k])
	return t


# ------------------------------------------------------------------ economy
func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)
	save_game()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	save_game()
	return true


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= XP_PER_LEVEL:
		xp -= XP_PER_LEVEL
		player_level += 1
	xp_changed.emit(xp, player_level)


func xp_ratio() -> float:
	return float(xp) / float(XP_PER_LEVEL)


# ------------------------------------------------------------------ progress
func complete_level(level_id: int, earned_stars: int, bonus_words: Array) -> void:
	var prev := stars_for(level_id)
	if earned_stars > prev:
		stars[str(level_id)] = earned_stars
		stars_changed.emit(total_stars())
	if bonus_words.size() > 0:
		var list: Array = found_bonus.get(str(level_id), [])
		for w in bonus_words:
			if not list.has(w):
				list.append(w)
		found_bonus[str(level_id)] = list
	if level_id == current_level and current_level < total_levels():
		current_level += 1
	if prev == 0:
		stats["levels_done"] = int(stats.get("levels_done", 0)) + 1
	var lv := get_level(level_id)
	var reward: int = int(lv.get("reward", 20))
	add_coins(reward + earned_stars * 5)
	add_xp(40 + earned_stars * 10)
	_progress_quest("levels", 1)
	level_completed.emit(level_id, earned_stars)
	save_game()


func register_word_found(is_bonus: bool) -> void:
	if is_bonus:
		stats["bonus_found"] = int(stats.get("bonus_found", 0)) + 1
		_progress_quest("bonus", 1)
	else:
		stats["words_found"] = int(stats.get("words_found", 0)) + 1
		_progress_quest("words", 1)


# ------------------------------------------------------------------ quests
func _ensure_quests() -> void:
	if quests.size() > 0:
		return
	quests = [
		{"id": "words", "text": "۲۰ کلمه پیدا کن", "goal": 20, "progress": 0,
		 "reward": 100, "claimed": false},
		{"id": "levels", "text": "۳ مرحله را کامل کن", "goal": 3, "progress": 0,
		 "reward": 150, "claimed": false},
		{"id": "bonus", "text": "۵ کلمه جایزه‌ای پیدا کن", "goal": 5, "progress": 0,
		 "reward": 120, "claimed": false},
	]
	save_game()


func _progress_quest(id: String, amount: int) -> void:
	for q in quests:
		if q["id"] == id and not q["claimed"]:
			q["progress"] = mini(int(q["progress"]) + amount, int(q["goal"]))


func claim_quest(id: String) -> bool:
	for q in quests:
		if q["id"] == id and not q["claimed"] and int(q["progress"]) >= int(q["goal"]):
			q["claimed"] = true
			add_coins(int(q["reward"]))
			return true
	return false


# ------------------------------------------------------------------ daily
func can_claim_daily() -> bool:
	var today := Time.get_date_string_from_system()
	return String(daily.get("last_claim", "")) != today


func claim_daily() -> int:
	if not can_claim_daily():
		return 0
	daily["streak"] = int(daily.get("streak", 0)) + 1
	daily["last_claim"] = Time.get_date_string_from_system()
	var amount: int = 50 + mini(int(daily["streak"]), 7) * 25
	add_coins(amount)
	return amount


# ------------------------------------------------------------------ save/load
func save_game() -> void:
	var data := {
		"coins": coins, "player_name": player_name, "player_level": player_level,
		"xp": xp, "current_level": current_level, "stars": stars,
		"found_bonus": found_bonus, "settings": settings, "daily": daily,
		"quests": quests, "stats": stats, "version": 1,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	coins = int(d.get("coins", coins))
	player_name = String(d.get("player_name", player_name))
	player_level = int(d.get("player_level", player_level))
	xp = int(d.get("xp", xp))
	current_level = int(d.get("current_level", current_level))
	stars = d.get("stars", {})
	found_bonus = d.get("found_bonus", {})
	var s: Dictionary = d.get("settings", {})
	for k in s:
		settings[k] = s[k]
	daily = d.get("daily", daily)
	quests = d.get("quests", [])
	stats = d.get("stats", stats)


func reset_progress() -> void:
	coins = 500
	player_level = 1
	xp = 0
	current_level = 1
	stars = {}
	found_bonus = {}
	quests = []
	stats = {"words_found": 0, "bonus_found": 0, "hints_used": 0, "levels_done": 0}
	_ensure_quests()
	save_game()
	coins_changed.emit(coins)
	stars_changed.emit(0)


# ------------------------------------------------------------------ utils
const FA_DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

static func fa_num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for c in s:
		out += FA_DIGITS[int(c)]
	return ("-" if n < 0 else "") + out


static func fa_num_grouped(n: int) -> String:
	var s := str(absi(n))
	var grouped := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		grouped = s[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "٬" + grouped
	var out := ""
	for c in grouped:
		out += FA_DIGITS[int(c)] if c.is_valid_int() else c
	return out
