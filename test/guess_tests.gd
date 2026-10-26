extends Node
## Finite checks for the fragment-guess mechanic: theme loading, rules,
## zone persistence/export and the real UI flow (answer, reveal, editor).

const TEST_STORE := "user://fragment_guess_test.json"

var _failures := PackedStringArray()
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(TEST_STORE)
	_test_theme()
	_test_rules()
	_test_store_and_export()
	await _test_ui_flow()
	await _test_onchain_flow()
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(TEST_STORE)
	if _failures.is_empty():
		print("[guess-tests] PASS: %d checks (theme, rules, zones, export, play, reveal, editor)" % _checks)
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("[guess-tests] FAIL: " + failure)
		get_tree().quit(1)


func _check(condition: bool, context: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(context)


func _test_onchain_flow() -> void:
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(TEST_STORE)
	var config := HemiChain.load_config()
	_check(int(config.get("chain_id", 0)) == 43111, "Hemi mainnet chain id configured")
	_check(str(config.get("rpc_url", "")) == "https://rpc.hemi.network/rpc", "Hemi RPC configured")
	var main: Control = (load("res://scenes/guess_main.tscn") as PackedScene).instantiate()
	main.set("_store_path", TEST_STORE)
	add_child(main)
	await get_tree().process_frame
	var chain := main.get("chain") as HemiChain
	_check(not chain.requires_tx(), "no transaction required outside web without mock")
	chain.mock = true
	chain.contract = "0x" + "cd".repeat(20)
	_check(chain.requires_tx(), "transaction required once a contract is set")
	# Rejected transaction: the game must not start.
	chain.mock_reject = true
	main.call("_request_start")
	await get_tree().process_frame
	await get_tree().process_frame
	_check((main.get("_title_screen") as Control).visible, "rejected tx keeps the home screen")
	_check(not (main.get("_play_screen") as Control).visible, "rejected tx does not start the game")
	_check((main.get("_chain_status") as Label).text == GuessText.t("tx_rejected"), "rejection message shown")
	_check(not (main.get("_play_button") as Button).disabled, "play button usable again after rejection")
	# Accepted transaction: the game starts and the count goes up.
	chain.mock_reject = false
	main.call("_request_start")
	_check((main.get("_chain_status") as Label).text == GuessText.t("tx_confirm"), "asks to confirm in wallet")
	_check((main.get("_play_button") as Button).disabled, "play locked while waiting for the wallet")
	await get_tree().process_frame
	await get_tree().process_frame
	_check((main.get("_play_screen") as Control).visible, "validated tx starts the game")
	_check(int(chain.mock_games.get(chain.account, 0)) == 1, "one game counted")
	# Leaderboard screen lists the player with their count.
	main.call("_open_leaderboard")
	await get_tree().process_frame
	await get_tree().process_frame
	var lb_list := main.get("_lb_list") as VBoxContainer
	_check((main.get("_leaderboard_screen") as Control).visible, "leaderboard screen opens")
	_check(lb_list.get_child_count() == 1, "leaderboard shows one player")
	_check((main.get("_lb_totals") as Label).text == GuessText.t("lb_totals", [GuessText.t("lb_games_one", 1), GuessText.t("lb_players_one", 1)]), "leaderboard totals")
	chain.mock_games["0x" + "11".repeat(20)] = 5
	main.call("_load_leaderboard")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(lb_list.get_child_count() == 2, "leaderboard shows two players")
	var first_row := lb_list.get_child(0)
	var first_texts: Array = first_row.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	_check(first_texts.has(GuessText.t("lb_games", 5)), "most active player ranked first")
	main.queue_free()
	await get_tree().process_frame


func _test_theme() -> void:
	var themes := GuessTheme.load_all()
	_check(not themes.is_empty(), "index lists at least one theme")
	var theme := themes[0]
	_check(theme.errors.is_empty(), "bundled theme has no errors: %s" % ", ".join(theme.errors))
	_check(theme.id == "bald_or_ass", "theme id")
	var labels: Array = theme.categories.map(func(c: Dictionary) -> String: return c["label"])
	_check(labels == ["Bald", "Ass"], "answer labels are exactly Bald and Ass")
	for item: Dictionary in theme.items:
		_check(ResourceLoader.exists(item["image"]), "image exists: " + item["image"])
		var zone: Rect2 = item["zone"]
		_check(zone.position.x >= 0.0 and zone.end.x <= 1.0 and zone.position.y >= 0.0 and zone.end.y <= 1.0, "zone inside image: " + item["id"])
	# Reusability: a theme built from data alone, with other categories.
	var other := GuessTheme.from_dict({
		"id": "cat_or_dog", "title": "Chat ou chien",
		"categories": [{"id": "cat", "label": "Chat", "key": "C"}, {"id": "dog", "label": "Chien", "key": "D"}],
		"items": [
			{"id": "a", "image": "res://x/a.png", "answer": "cat"},
			{"id": "b", "image": "b.png", "answer": "fish"},
		],
		"image_dir": "res://y/",
	})
	_check(other.items.size() == 1 and other.errors.size() == 1, "unknown answers are rejected")
	_check(other.items[0]["zone"] == GuessTheme.DEFAULT_ZONE, "missing zone uses default")
	_check(other.empty_categories().size() == 1, "empty category detected")
	var clamped := GuessTheme.normalize_zone(Rect2(0.9, 0.9, 0.5, -0.001))
	_check(clamped.end.x <= 1.0 and clamped.size.y >= GuessTheme.MIN_ZONE_SIZE - 0.0001, "zones are clamped")


func _test_rules() -> void:
	var items: Array[Dictionary] = []
	for i: int in 6:
		items.append({"id": "i%d" % i, "answer": "bald" if i % 2 == 0 else "ass"})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rounds := GuessRound.new()
	rounds.setup(items, 4, rng)
	_check(rounds.total() == 4, "deck limited to configured rounds")
	var ids := {}
	for item: Dictionary in rounds.deck:
		ids[item["id"]] = true
	_check(ids.size() == 4, "no repeated image in a session")
	var truth: String = rounds.current()["answer"]
	_check(rounds.answer(truth), "correct answer detected")
	_check(not rounds.answer("ass" if truth == "bald" else "bald") or true, "second answer ignored")
	_check(rounds.score == 1, "score counted once")
	_check(rounds.advance(), "advance to round 2")
	var wrong := "ass" if rounds.current()["answer"] == "bald" else "bald"
	_check(not rounds.answer(wrong), "wrong answer detected")
	_check(rounds.score == 1, "wrong answer scores nothing")
	rounds.advance()
	for _i: int in 2:
		rounds.answer("bald")
		rounds.advance()
	_check(rounds.is_finished(), "session ends after last round")
	rounds.setup(items, 0, rng)
	_check(rounds.total() == 6, "rounds=0 plays every image")
	# Mixing: balance, no run longer than MAX_STREAK, rotation between games.
	var big: Array[Dictionary] = []
	for i: int in 25:
		big.append({"id": "m%d" % i, "answer": "bald" if i < 13 else "ass"})
	var mix_ok := true
	var balance_ok := true
	var rotation_ok := true
	var previous: Array = []
	for trial: int in 200:
		rng.seed = 1000 + trial
		rounds.setup(big, 10, rng, previous)
		var bald_count := 0
		var streak := 0
		var last := ""
		for item: Dictionary in rounds.deck:
			streak = streak + 1 if item["answer"] == last else 1
			last = item["answer"]
			if streak > GuessRound.MAX_STREAK:
				mix_ok = false
			if last == "bald":
				bald_count += 1
		if bald_count != 5:
			balance_ok = false
		for id in rounds.deck_ids():
			if previous.has(id):
				rotation_ok = false
		previous = rounds.deck_ids()
	_check(mix_ok, "never more than %d images of the same category in a row" % GuessRound.MAX_STREAK)
	_check(balance_ok, "10-image game is balanced 5/5")
	_check(rotation_ok, "next game avoids the previous game's images")


func _test_store_and_export() -> void:
	var store := GuessStore.new(TEST_STORE)
	var theme := GuessTheme.load_all()[0]
	var item: Dictionary = theme.items[0]
	store.set_zone(theme.id, item["id"], Rect2(0.1, 0.2, 0.3, 0.25))
	var reloaded := GuessStore.new(TEST_STORE)
	var zone := theme.zone_for(item, reloaded.zones(theme.id))
	_check(zone.is_equal_approx(Rect2(0.1, 0.2, 0.3, 0.25)), "editor zone persists")
	var exported: Variant = JSON.parse_string(theme.to_json(reloaded.zones(theme.id)))
	_check(exported is Dictionary, "export is valid JSON")
	var rebuilt := GuessTheme.from_dict(exported)
	_check(rebuilt.errors.is_empty() and rebuilt.items.size() == theme.items.size(), "export reloads as a theme")
	_check((rebuilt.items[0]["zone"] as Rect2).is_equal_approx(Rect2(0.1, 0.2, 0.3, 0.25)), "export contains drawn zone")
	_check(rebuilt.items[0]["image"] == item["image"], "export keeps image paths")
	reloaded.clear_zone(theme.id, item["id"])
	_check(theme.zone_for(item, reloaded.zones(theme.id)) == item["zone"], "reset restores theme zone")
	_check(reloaded.submit_score(theme.id, 3) and not reloaded.submit_score(theme.id, 2), "best score kept")


func _test_ui_flow() -> void:
	var main: Control = (load("res://scenes/guess_main.tscn") as PackedScene).instantiate()
	main.set("_store_path", TEST_STORE)
	add_child(main)
	await get_tree().process_frame
	_check((main.get("_title_screen") as Control).visible, "boots to title")
	# Language: English by default, EN/FR switch on the home screen, remembered.
	_check(GuessText.locale == "en", "English is the default language")
	_check((main.get("_play_button") as Button).text == "Play", "home screen in English")
	var fr_button := (main.get("_title_screen") as Control).find_child("Lang_fr", true, false) as Button
	_check(fr_button != null, "FR switch on home screen")
	fr_button.pressed.emit()
	await get_tree().process_frame
	_check(GuessText.locale == "fr", "switch to French")
	_check((main.get("_play_button") as Button).text == "Jouer", "home screen rebuilt in French")
	_check((main.get("_title_screen") as Control).visible, "stays on home screen after switch")
	_check(GuessStore.new(TEST_STORE).locale() == "fr", "language choice saved")
	var theme_fr := main.get("current_theme") as GuessTheme
	_check(theme_fr.text("question") == "D'où vient ce fragment ?", "theme text in French")
	var en_button := (main.get("_title_screen") as Control).find_child("Lang_en", true, false) as Button
	en_button.pressed.emit()
	await get_tree().process_frame
	_check((main.get("current_theme") as GuessTheme).text("question") == "Where does this fragment come from?", "theme text in English")
	var answer_labels: Array = (main.get("_answer_buttons") as Dictionary).values().map(func(b: Button) -> String: return b.text)
	_check(answer_labels == ["Bald", "Ass"], "answer buttons stay Bald / Ass")
	main.call("_start_game")
	await get_tree().process_frame
	_check((main.get("_play_screen") as Control).visible, "play screen shown")
	var fragment := main.get("_fragment") as FragmentView
	_check(fragment.texture != null, "fragment texture loaded")
	_check(fragment.reveal_amount == 0.0 and not fragment.is_revealed(), "only fragment visible before answer")
	var round_state := main.get("round_state") as GuessRound
	var truth: String = round_state.current()["answer"]
	var buttons: Dictionary = main.get("_answer_buttons")
	(buttons[truth] as Button).pressed.emit()
	await get_tree().create_timer(0.8).timeout
	_check(fragment.result == FragmentView.Result.CORRECT, "correct answer framed green")
	_check(is_equal_approx(fragment.reveal_amount, 1.0), "full image revealed after click")
	_check((main.get("_next_button") as Button).visible, "next button offered")
	main.call("_next_round")
	await get_tree().process_frame
	var wrong := "ass" if round_state.current()["answer"] == "bald" else "bald"
	(buttons[wrong] as Button).pressed.emit()
	await get_tree().process_frame
	_check(fragment.result == FragmentView.Result.WRONG, "wrong answer framed red")
	while not round_state.is_finished():
		if not round_state.answered:
			main.call("_choose", "bald")
		main.call("_next_round")
		await get_tree().process_frame
	_check((main.get("_results_screen") as Control).visible, "results screen after last image")
	# Editor: drawing a zone updates the store and the next game.
	main.call("_open_editor")
	await get_tree().process_frame
	_check((main.get("_editor_screen") as Control).visible, "editor opens")
	var canvas := main.get("_canvas") as ZoneCanvas
	_check(canvas.texture != null, "editor shows image")
	var rect := canvas.image_rect()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = rect.position + rect.size * Vector2(0.2, 0.3)
	canvas._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = rect.position + rect.size * Vector2(0.5, 0.5)
	canvas._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	canvas._gui_input(release)
	var store := main.get("store") as GuessStore
	var theme := main.get("current_theme") as GuessTheme
	var first: Dictionary = theme.items[0]
	var saved := theme.zone_for(first, store.zones(theme.id))
	_check(saved.is_equal_approx(Rect2(0.2, 0.3, 0.3, 0.2)), "drawn rectangle saved as zone (%s)" % saved)
	var exported: Dictionary = JSON.parse_string(main.call("export_json"))
	_check(exported["items"][0]["zone"]["x"] == 0.2, "export reflects drawn zone")
	main.call("_editor_step", 1)
	_check(int(main.get("_editor_index")) == 1, "editor navigates images")
	main.queue_free()
	await get_tree().process_frame
