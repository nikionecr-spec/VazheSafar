extends SceneTree
## Automated gameplay test: plays several levels by submitting real words,
## verifies board reveal, scoring, stars, persistence and the win popup.

var failures := 0
var G: Node


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		print("  FAIL  ", msg)


func _run() -> void:
	G = root.get_node("/root/Game")
	print("=== data integrity ===")
	ok(G.total_levels() == 100, "100 levels loaded (got %d)" % G.total_levels())
	ok(G.worlds.size() == 10, "10 worlds")
	ok(G.dictionary.size() > 500, "bonus dictionary %d words" % G.dictionary.size())

	var bad := 0
	for i in range(1, G.total_levels() + 1):
		var lv: Dictionary = G.get_level(i)
		var pool := {}
		for l in lv["letters"]:
			pool[l] = true
		for w in lv["words"]:
			for ch in String(w):
				if not pool.has(ch):
					bad += 1
					print("    level %d: word %s uses letter %s not in wheel" % [i, w, ch])
		if lv["words"].size() < 3:
			bad += 1
	ok(bad == 0, "every answer is buildable from its wheel letters")

	var dupes := 0
	for i in range(1, G.total_levels() + 1):
		var ws: Array = G.get_level(i)["words"]
		var seen := {}
		for w in ws:
			if seen.has(w):
				dupes += 1
			seen[w] = true
	ok(dupes == 0, "no duplicate answers within a level")

	print("=== playing levels 1..5 ===")
	G.reset_progress()
	var start_coins: int = int(G.coins)

	for target in range(1, 6):
		G.set_meta("goto_level", target)
		var scene: Node = load("res://scenes/LevelScene.tscn").instantiate()
		root.add_child(scene)
		for i in 12:
			await process_frame

		ok(scene.level_id == target, "level %d loaded" % target)
		var words: Array = scene.answers.duplicate()
		ok(words.size() >= 3, "level %d has %d answers" % [target, words.size()])

		# submit a wrong word first
		scene._on_word("زززز")
		await process_frame
		ok(scene.found.size() == 0, "invalid word rejected")

		# now solve it properly
		for w in words:
			scene._on_word(String(w))
			for i in 3:
				await process_frame

		ok(scene.found.size() == words.size(),
			"all %d words found in level %d" % [words.size(), target])
		ok(scene._finished, "level %d flagged complete" % target)

		# board fully revealed?
		var hidden := 0
		for w in scene._slots.keys():
			for cell in scene._slots[w]:
				if not bool(cell.get_meta("revealed")):
					hidden += 1
		ok(hidden == 0, "every board cell revealed")

		await create_timer(0.9).timeout
		for i in 5:
			await process_frame

		ok(G.stars_for(target) == 3, "3 stars for hint-free level %d" % target)
		ok(G.current_level == target + 1, "level %d unlocked" % (target + 1))

		# win popup present?
		var popup_found := false
		for c in scene.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("WinPopup.gd"):
				popup_found = true
		ok(popup_found, "win popup shown")

		scene.queue_free()
		await process_frame

	ok(G.coins > start_coins, "coins increased: %d -> %d" % [start_coins, G.coins])
	ok(G.player_level >= 1 and G.xp >= 0, "xp/level tracked")

	print("=== hint system ===")
	G.set_meta("goto_level", 6)
	var s2: Node = load("res://scenes/LevelScene.tscn").instantiate()
	root.add_child(s2)
	for i in 12:
		await process_frame
	var before: int = G.coins
	s2._on_hint_pressed()
	await process_frame
	ok(G.coins == before - G.HINT_COST, "hint charged %d coins" % G.HINT_COST)
	var revealed := 0
	for w in s2._slots.keys():
		for cell in s2._slots[w]:
			if bool(cell.get_meta("revealed")):
				revealed += 1
	ok(revealed >= 1, "hint revealed a letter")
	s2.queue_free()
	await process_frame

	print("=== persistence ===")
	G.save_game()
	var coins_now: int = G.coins
	var lvl_now: int = G.current_level
	G.coins = 0
	G.current_level = 1
	G.load_game()
	ok(G.coins == coins_now, "coins persisted (%d)" % G.coins)
	ok(G.current_level == lvl_now, "progress persisted (level %d)" % G.current_level)

	print("=== bonus words ===")
	G.set_meta("goto_level", 1)
	var s3: Node = load("res://scenes/LevelScene.tscn").instantiate()
	root.add_child(s3)
	for i in 12:
		await process_frame
	# find a dictionary word buildable from the wheel that is NOT an answer
	var pool := {}
	for l in s3.level_data["letters"]:
		pool[l] = true
	var candidate := ""
	for w in G.dictionary.keys():
		var sw := String(w)
		if sw.length() < 3 or s3.answers.has(sw):
			continue
		var fits := true
		for ch in sw:
			if not pool.has(ch):
				fits = false
				break
		if fits:
			candidate = sw
			break
	if candidate != "":
		var c0: int = G.coins
		s3._on_word(candidate)
		await process_frame
		ok(s3.bonus_found.has(candidate), "bonus word '%s' accepted" % candidate)
		ok(G.coins == c0 + 5, "bonus word paid 5 coins")
	else:
		print("  SKIP  no bonus candidate for level 1")
	s3.queue_free()

	print("=== quests & daily ===")
	G.reset_progress()
	G.daily = {"last_claim": "", "streak": 0}
	var d: int = int(G.claim_daily())
	ok(d > 0, "daily reward claimed: %d" % d)
	ok(not G.can_claim_daily(), "daily locked until tomorrow")

	print("")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
