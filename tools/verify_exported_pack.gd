extends SceneTree
## Checks the exported Web pack: identity, theme data, images, exclusions and
## that the game boots to its title and starts a round.

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	_check(ProjectSettings.get_setting("application/config/name") == "Bald or Ass", "exported identity")
	_check(FileAccess.file_exists("res://themes/index.json"), "theme index exported")
	_check(FileAccess.file_exists("res://themes/bald_or_ass/theme.json"), "theme data exported")
	var themes := GuessTheme.load_all()
	_check(not themes.is_empty() and themes[0].errors.is_empty(), "theme loads from pack")
	if not themes.is_empty():
		for item: Dictionary in themes[0].items:
			_check(ResourceLoader.exists(item["image"]), "pack image: " + item["image"])
	_check(not ResourceLoader.exists("res://test/guess_tests.tscn"), "test scene excluded")
	_check(not ResourceLoader.exists("res://tools/capture_native.gd"), "native capture tool excluded")
	var font := load("res://assets/template/fonts/ui_regular.tres") as Font
	_check(font != null, "exported font")
	if font != null:
		for codepoint: int in "éèàçôœ’«»…".to_utf32_buffer().to_int32_array():
			_check(font.has_char(codepoint), "exported glyph: %d" % codepoint)
	var packed := load("res://scenes/guess_main.tscn") as PackedScene
	_check(packed != null, "exported main scene")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		_check(bool((main.get("_title_screen") as Control).visible), "pack boots to title")
		main.call("_start_game")
		await process_frame
		_check(bool((main.get("_play_screen") as Control).visible), "pack starts a round")
		_check((main.get("_fragment") as Control).get("texture") != null, "pack shows a fragment")
		main.queue_free()
		await process_frame
	if _failures.is_empty():
		print("[exported-pack] PASS: identity, theme, images, fonts, exclusions, boot, round")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("[exported-pack] " + failure)
		quit(1)


func _check(condition: bool, context: String) -> void:
	if not condition and context not in _failures:
		_failures.append(context)
