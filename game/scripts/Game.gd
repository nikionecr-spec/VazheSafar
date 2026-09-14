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
	"music_volume": 0.85,
	"sfx_volume": 1.0,
}
var daily := {"last_claim": "", "streak": 0, "best_streak": 0}
var quests: Array = []
var stats := {"words_found": 0, "bonus_found": 0, "hints_used": 0, "levels_done": 0}

# --------------------------------------------------------------- engagement
## Everything below exists to make the "one more level" loop feel good:
## combo streaks, an unpredictable reward chest, gems, achievements and a
## visible countdown to the next reward. (Behavioural design, kept honest:
## no fake timers, no paywalls in the loop.)
const CHEST_EVERY := 5
var gems: int = 0
var combo: int = 0                     # correct words in a row (session only)
var best_combo: int = 0
var chest_progress: int = 0            # completed levels toward the next chest
var daily_bonus_used: String = ""      # date of the last "first level of the day" bonus
var last_play_day: String = ""
var last_reward: Dictionary = {}       # breakdown for the win popup

const XP_PER_LEVEL := 800
const HINT_COST := 80
const REVEAL_COST := 150
const GEM_PRICE := 5                   # gems to buy one skip of a hard word

signal combo_changed(value: int)
signal gems_changed(value: int)
signal chest_changed(progress: int, goal: int)


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
	var total_reward := reward + earned_stars * 5
	# first level of the day pays double — a daily hook, not a paywall
	var daily_extra := 0
	if daily_bonus_ready():
		daily_extra = total_reward
		daily_bonus_used = Time.get_date_string_from_system()
	add_coins(total_reward + daily_extra)
	mark_played_today()
	last_reward = {
		"base": reward, "stars": earned_stars, "daily": daily_extra,
		"total": total_reward + daily_extra,
		"chest_left": chest_levels_left(),
	}

	# progress toward the next surprise chest
	chest_progress += 1
	if chest_progress >= CHEST_EVERY:
		chest_progress = CHEST_EVERY      # stays full until the player opens it
	chest_changed.emit(chest_progress, CHEST_EVERY)

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


# ------------------------------------------------------------------ combo
## Called for every correct word. Returns the coin multiplier the caller
## should apply — small, escalating, and reset the moment the player errs.
func register_correct_word() -> int:
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_changed.emit(combo)
	if combo >= 12:
		return 3
	if combo >= 8:
		return 2
	if combo >= 5:
		return 1
	return 0                      # 0 = no bonus yet


func combo_multiplier() -> float:
	if combo >= 12:
		return 3.0
	if combo >= 8:
		return 2.0
	if combo >= 5:
		return 1.5
	return 1.0


func break_combo() -> void:
	if combo > 0:
		combo = 0
		combo_changed.emit(0)


func combo_tier() -> int:
	if combo >= 12:
		return 3
	if combo >= 8:
		return 2
	if combo >= 5:
		return 1
	return 0


# ------------------------------------------------------------------ chest
func chest_goal() -> int:
	return CHEST_EVERY


func chest_levels_left() -> int:
	return maxi(0, CHEST_EVERY - chest_progress)


## Variable-ratio reward: the size is rolled, so the anticipation is real.
func roll_chest() -> Dictionary:
	var r := randf()
	if r < 0.05:
		return {"coins": 600, "gems": 5, "label": "جایزهٔ نادر!"}
	if r < 0.22:
		return {"coins": 350, "gems": 3, "label": "عالی بود!"}
	if r < 0.60:
		return {"coins": 220, "gems": 2, "label": "خوب بود!"}
	return {"coins": 120, "gems": 1, "label": "صندوقچه باز شد"}


func claim_chest() -> Dictionary:
	var reward := roll_chest()
	add_coins(int(reward["coins"]))
	gems += int(reward["gems"])
	gems_changed.emit(gems)
	chest_progress = 0
	chest_changed.emit(chest_progress, CHEST_EVERY)
	save_game()
	return reward


func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	gems_changed.emit(gems)
	save_game()
	return true


# ---------------------------------------------------------- free coin bag
## A free, time-gated coin bag with a random payout: gives the player a reason
## to come back a few times a day without paying anything.
const FREE_BAG_COOLDOWN := 3 * 3600
var free_bag_at: int = 0


func free_bag_wait() -> int:
	var elapsed := int(Time.get_unix_time_from_system()) - free_bag_at
	return maxi(0, FREE_BAG_COOLDOWN - elapsed)


func free_bag_ready() -> bool:
	return free_bag_wait() <= 0


func claim_free_bag() -> int:
	if not free_bag_ready():
		return 0
	var r := randf()
	var amount := 120 if r < 0.55 else (220 if r < 0.88 else 400)
	free_bag_at = int(Time.get_unix_time_from_system())
	add_coins(amount)
	save_game()
	return amount


func countdown_text(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%s:%s:%s" % [fa_num(h), _two(m), _two(s)]
	return "%s:%s" % [_two(m), _two(s)]


func _two(v: int) -> String:
	return ("۰" + fa_num(v)) if v < 10 else fa_num(v)


# ------------------------------------------------------- daily engagement
## First level finished today pays double — reasons to open the app daily.
func daily_bonus_ready() -> bool:
	return daily_bonus_used != Time.get_date_string_from_system()


func claim_daily_bonus(amount: int) -> int:
	if not daily_bonus_ready():
		return 0
	daily_bonus_used = Time.get_date_string_from_system()
	add_coins(amount)
	save_game()
	return amount


## 7-day streak strip for the quests screen.
func daily_strip() -> Array:
	var rewards := [75, 100, 125, 150, 175, 200, 300]
	var streak := int(daily.get("streak", 0))
	var day := streak % 7
	if can_claim_daily():
		day = streak % 7
	var out: Array = []
	for i in 7:
		out.append({
			"day": i + 1,
			"reward": rewards[i],
			"done": i < day,
			"current": i == day and can_claim_daily(),
			"big": i == 6,
		})
	return out


# ---------------------------------------------------------- achievements
func achievements() -> Array:
	var s := stats
	var found: int = int(s.get("words_found", 0))
	var bonus: int = int(s.get("bonus_found", 0))
	var done_lv: int = int(s.get("levels_done", 0))
	var st := total_stars()
	var out: Array = [
		{"id": "first", "title": "اولین قدم", "desc": "مرحله ۱ را کامل کن",
		 "value": mini(done_lv, 1), "goal": 1, "icon": "star_gold"},
		{"id": "words50", "title": "واژه‌یاب", "desc": "۵۰ کلمه پیدا کن",
		 "value": mini(found, 50), "goal": 50, "icon": "book"},
		{"id": "words250", "title": "کلمه‌ساز حرفه‌ای", "desc": "۲۵۰ کلمه پیدا کن",
		 "value": mini(found, 250), "goal": 250, "icon": "trophy"},
		{"id": "bonus25", "title": "شکارچی جایزه", "desc": "۲۵ کلمهٔ جایزه‌ای",
		 "value": mini(bonus, 25), "goal": 25, "icon": "gift"},
		{"id": "stars30", "title": "ستاره‌چین", "desc": "۳۰ ستاره جمع کن",
		 "value": mini(st, 30), "goal": 30, "icon": "star_gold"},
		{"id": "lv25", "title": "مسافر راه", "desc": "۲۵ مرحله را بگذران",
		 "value": mini(done_lv, 25), "goal": 25, "icon": "chest"},
		{"id": "combo10", "title": "زنجیرهٔ طلایی", "desc": "۱۰ کلمه پشت‌سرهم",
		 "value": mini(best_combo, 10), "goal": 10, "icon": "star_gold"},
		{"id": "streak7", "title": "هفت روز پیاپی", "desc": "۷ روز پشت‌سرهم بازی کن",
		 "value": mini(int(daily.get("best_streak", 0)), 7), "goal": 7, "icon": "gift"},
	]
	return out


func achievements_unlocked() -> int:
	var n := 0
	for a in achievements():
		if int(a["value"]) >= int(a["goal"]):
			n += 1
	return n


func player_title() -> String:
	var lv := player_level
	if lv >= 30:
		return "استاد واژه‌ها"
	if lv >= 20:
		return "کاشف کلمه‌ها"
	if lv >= 12:
		return "واژه‌ساز ماهر"
	if lv >= 6:
		return "رهروی راه"
	return "تازه‌کار"


func today_played() -> bool:
	return last_play_day == Time.get_date_string_from_system()


func mark_played_today() -> void:
	last_play_day = Time.get_date_string_from_system()


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
	daily["best_streak"] = maxi(int(daily.get("best_streak", 0)), int(daily["streak"]))
	daily["last_claim"] = Time.get_date_string_from_system()
	var amount: int = 50 + mini(int(daily["streak"]), 7) * 25
	add_coins(amount)
	return amount


# ------------------------------------------------------------------ save/load
func save_game() -> void:
	var data := {
		"coins": coins, "gems": gems, "player_name": player_name,
		"player_level": player_level,
		"xp": xp, "current_level": current_level, "stars": stars,
		"found_bonus": found_bonus, "settings": settings, "daily": daily,
		"quests": quests, "stats": stats, "version": 2,
		"chest_progress": chest_progress, "best_combo": best_combo,
		"daily_bonus_used": daily_bonus_used, "last_play_day": last_play_day,
		"free_bag_at": free_bag_at,
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
	gems = int(d.get("gems", gems))
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
	chest_progress = int(d.get("chest_progress", 0))
	best_combo = int(d.get("best_combo", 0))
	daily_bonus_used = String(d.get("daily_bonus_used", ""))
	last_play_day = String(d.get("last_play_day", ""))
	free_bag_at = int(d.get("free_bag_at", 0))


func reset_progress() -> void:
	coins = 500
	gems = 0
	player_level = 1
	xp = 0
	current_level = 1
	stars = {}
	found_bonus = {}
	quests = []
	combo = 0
	best_combo = 0
	chest_progress = 0
	daily_bonus_used = ""
	stats = {"words_found": 0, "bonus_found": 0, "hints_used": 0, "levels_done": 0}
	_ensure_quests()
	save_game()
	coins_changed.emit(coins)
	gems_changed.emit(gems)
	stars_changed.emit(0)
	chest_changed.emit(chest_progress, CHEST_EVERY)


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
