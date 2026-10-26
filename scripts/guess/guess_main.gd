extends Control
## Fragment-guess game controller: title, play, results and zone editor.
## Content comes from GuessTheme, rules from GuessRound, strings from GuessText.

const UI := preload("res://scripts/guess/guess_ui.gd")
const T := preload("res://scripts/guess/guess_text.gd")

var themes: Array[GuessTheme] = []
var current_theme: GuessTheme
var store: GuessStore
var round_state := GuessRound.new()
var rng := RandomNumberGenerator.new()
## Images of the previous game, shown again only once the others run out.
var _previous_deck_ids: Array = []

var _title_screen: Control
var _play_screen: Control
var _results_screen: Control
var _editor_screen: Control
var _leaderboard_screen: Control

# On-chain account (Hemi)
var chain: HemiChain
var _wallet_button: Button
var _chain_status: Label
var _result_chain: Label
var _lb_list: VBoxContainer
var _lb_totals: Label
var _lb_status: Label
var _deploy_box: Control
var _awaiting_tx := false

# Title
var _title_tagline: Label
var _title_rules: Label
var _title_notice: Label
var _title_best: Label
var _theme_picker: OptionButton
var _teaser: FragmentView
var _play_button: Button

# Play
var _fragment: FragmentView
var _round_label: Label
var _score_label: Label
var _question_label: Label
var _answer_buttons: Dictionary = {}
var _feedback_label: Label
var _next_button: Button
var _keys_hint: Label

# Results
var _result_score: Label
var _result_comment: Label
var _result_best: Label

# Editor
var _canvas: ZoneCanvas
var _editor_index := 0
var _editor_counter: Label
var _editor_item: Label
var _editor_state: Label
var _editor_status: Label
var _preview_toggle: CheckButton

var _textures: Dictionary = {}
var _store_path := GuessStore.DEFAULT_PATH


func _ready() -> void:
	rng.randomize()
	store = GuessStore.new(_store_path)
	# English is the base language; the player's EN/FR choice is remembered.
	T.set_locale(store.locale() if not store.locale().is_empty() else T.DEFAULT_LOCALE)
	themes = GuessTheme.load_all()
	chain = HemiChain.new()
	chain.name = "HemiChain"
	add_child(chain)
	chain.status_changed.connect(_on_chain_status)
	chain.game_tx_sent.connect(_on_game_tx_sent)
	chain.game_tx_failed.connect(_on_game_tx_failed)
	chain.game_tx_confirmed.connect(_on_game_tx_confirmed)
	chain.leaderboard_loaded.connect(_on_leaderboard_loaded)
	chain.leaderboard_failed.connect(_on_leaderboard_failed)
	chain.deploy_finished.connect(_on_deploy_finished)
	var background := ColorRect.new()
	background.color = UI.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_build_ui(0)


## Builds every screen in the current language (rebuilt when it changes).
func _build_ui(theme_index: int) -> void:
	for screen: Control in [_title_screen, _play_screen, _results_screen, _editor_screen, _leaderboard_screen]:
		if screen != null:
			remove_child(screen)
			screen.queue_free()
	_title_screen = _build_title()
	_play_screen = _build_play()
	_results_screen = _build_results()
	_editor_screen = _build_editor()
	_leaderboard_screen = _build_leaderboard()
	for screen: Control in [_title_screen, _play_screen, _results_screen, _editor_screen, _leaderboard_screen]:
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
	if themes.is_empty():
		push_error("[guess] No theme available")
	else:
		_select_theme(theme_index)
	_show(_title_screen)


func set_language(value: String) -> void:
	if value == T.locale:
		return
	T.set_locale(value)
	store.set_locale(T.locale)
	if OS.has_feature("web"):
		# Lets the HTML loading screen use the same language next time.
		JavaScriptBridge.eval("try { localStorage.setItem('baldorass.locale', '%s'); } catch (e) {}" % T.locale)
	_build_ui(maxi(0, themes.find(current_theme)))
	var focus := _title_screen.find_child("Lang_" + T.locale, true, false) as Control
	if focus != null:
		focus.grab_focus.call_deferred()


# ---------------------------------------------------------------- helpers

func _show(screen: Control) -> void:
	for candidate: Control in [_title_screen, _play_screen, _results_screen, _editor_screen, _leaderboard_screen]:
		candidate.visible = candidate == screen
	var focus_target: Control = null
	if screen == _title_screen:
		focus_target = _play_button
	elif screen == _results_screen:
		focus_target = _results_screen.find_child("Replay", true, false) as Control
	if focus_target != null:
		focus_target.grab_focus.call_deferred()


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if _textures[path] == null:
			push_warning("[guess] Missing image: " + path)
	return _textures[path]


func _zone(item: Dictionary) -> Rect2:
	return current_theme.zone_for(item, store.zones(current_theme.id))


func _select_theme(index: int) -> void:
	current_theme = themes[clampi(index, 0, themes.size() - 1)]
	_refresh_title()
	_rebuild_answer_buttons()


func _brand(size: int) -> HBoxContainer:
	# Wordmark: "Bald" cream, small coral "or", "Ass" coral. Other themes
	# fall back to their title in the same display face.
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var words := current_theme.title.split(" or ") if current_theme != null else PackedStringArray(["Bald", "Ass"])
	if words.size() == 2:
		row.add_child(UI.label(words[0], size, UI.CREAM, UI.FONT_TITLE))
		var joiner := UI.label("or", int(size * 0.5), UI.CORAL, UI.FONT_HEADING)
		joiner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(joiner)
		row.add_child(UI.label(words[1], size, UI.CORAL, UI.FONT_TITLE))
	else:
		row.add_child(UI.label(current_theme.title if current_theme != null else "", size, UI.CREAM, UI.FONT_TITLE))
	return row


# ---------------------------------------------------------------- title

func _build_title() -> Control:
	var root := Control.new()
	var layout := UI.hbox(48)
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	var wrapper := UI.margin(layout, 56)
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrapper)

	var left := UI.vbox(18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(left)
	var brand_holder := Control.new()
	brand_holder.name = "BrandHolder"
	brand_holder.custom_minimum_size.y = 96
	left.add_child(brand_holder)
	_title_tagline = UI.label("", 26, UI.CREAM, UI.FONT_HEADING)
	_title_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_title_tagline)
	_title_rules = UI.paragraph("", 18)
	left.add_child(_title_rules)
	_title_notice = UI.paragraph("", 15, UI.CORAL)
	left.add_child(_title_notice)

	_theme_picker = OptionButton.new()
	_theme_picker.custom_minimum_size = Vector2(320, 44)
	_theme_picker.item_selected.connect(_select_theme)
	left.add_child(_theme_picker)

	var buttons := UI.hbox(14)
	_play_button = UI.big_button(T.t("play"), UI.CORAL, UI.BG, Vector2(220, 68))
	_play_button.pressed.connect(_request_start)
	buttons.add_child(_play_button)
	var editor_button := UI.ghost_button(T.t("editor"), 200)
	editor_button.custom_minimum_size.y = 68
	editor_button.pressed.connect(_open_editor)
	buttons.add_child(editor_button)
	left.add_child(buttons)
	var chain_row := UI.hbox(14)
	_wallet_button = UI.ghost_button(T.t("connect_wallet"), 220)
	_wallet_button.custom_minimum_size.y = 48
	_wallet_button.pressed.connect(_on_wallet_pressed)
	chain_row.add_child(_wallet_button)
	var board_button := UI.ghost_button(T.t("leaderboard"), 200)
	board_button.custom_minimum_size.y = 48
	board_button.pressed.connect(_open_leaderboard)
	chain_row.add_child(board_button)
	left.add_child(chain_row)
	_title_best = UI.label("", 15, UI.MUTED)
	left.add_child(_title_best)
	_chain_status = UI.paragraph("", 15, UI.MUTED)
	left.add_child(_chain_status)

	var right := UI.panel(18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(right)
	_teaser = FragmentView.new()
	_teaser.custom_minimum_size = Vector2(360, 360)
	_teaser.mask_color = UI.PANEL.darkened(0.35)
	right.add_child(_teaser)
	root.add_child(_build_language_switch())
	return root


## EN/FR segmented switch, top-left of the home screen.
func _build_language_switch() -> Control:
	var row := UI.hbox(0)
	row.name = "LanguageSwitch"
	row.position = Vector2(56, 24)
	row.tooltip_text = T.t("language")
	for code: String in T.LOCALES:
		var active := code == T.locale
		var first := code == T.LOCALES[0]
		var button := Button.new()
		button.name = "Lang_" + code
		button.text = code.to_upper()
		button.custom_minimum_size = Vector2(58, 36)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_override("font", load(UI.FONT_BOLD))
		button.add_theme_font_size_override("font_size", 15)
		var style := UI.box(UI.CORAL if active else UI.PANEL, UI.CORAL if active else UI.PANEL_EDGE, 0, 1)
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.corner_radius_top_left = 12 if first else 0
		style.corner_radius_bottom_left = 12 if first else 0
		style.corner_radius_top_right = 0 if first else 12
		style.corner_radius_bottom_right = 0 if first else 12
		var hover := style.duplicate() as StyleBoxFlat
		hover.border_color = UI.CREAM if active else UI.CORAL
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		var focus := style.duplicate() as StyleBoxFlat
		focus.draw_center = false
		focus.border_color = UI.CREAM
		focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus", focus)
		var text_color := UI.BG if active else UI.MUTED
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_focus_color", text_color)
		button.add_theme_color_override("font_pressed_color", text_color)
		button.add_theme_color_override("font_hover_color", UI.BG if active else UI.CREAM)
		button.pressed.connect(func() -> void: set_language(code))
		row.add_child(button)
	return row


func _refresh_title() -> void:
	if current_theme == null:
		return
	var holder := _title_screen.find_child("BrandHolder", true, false) as Control
	for child: Node in holder.get_children():
		child.queue_free()
	holder.add_child(_brand(84))
	_title_tagline.text = current_theme.text("tagline")
	_title_rules.text = current_theme.text("rules")
	var missing: PackedStringArray = []
	for entry: Dictionary in current_theme.empty_categories():
		missing.append(entry["label"])
	_title_notice.text = "" if missing.is_empty() else T.t("missing", ", ".join(missing))
	_title_notice.visible = not missing.is_empty()
	_theme_picker.clear()
	for entry: GuessTheme in themes:
		_theme_picker.add_item(entry.title)
	_theme_picker.select(themes.find(current_theme))
	_theme_picker.visible = themes.size() > 1
	var best := store.best_score(current_theme.id)
	_title_best.text = T.t("best", best) if best > 0 else T.t("image_count", current_theme.items.size())
	_play_button.disabled = current_theme.items.is_empty()
	_refresh_chain_ui()
	if not current_theme.items.is_empty():
		var item: Dictionary = current_theme.items[rng.randi_range(0, current_theme.items.size() - 1)]
		_teaser.show_fragment(_texture(item["image"]), _zone(item))


# ---------------------------------------------------------------- play

func _build_play() -> Control:
	var root := Control.new()
	var layout := UI.hbox(32)
	var wrapper := UI.margin(layout, 32)
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrapper)

	_fragment = FragmentView.new()
	_fragment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fragment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fragment.mask_color = Color("150c11")
	layout.add_child(_fragment)

	var side := UI.panel(28)
	side.custom_minimum_size.x = 400
	layout.add_child(side)
	var column := UI.vbox(16)
	side.add_child(column)
	var header := UI.hbox(12)
	_round_label = UI.label("", 16, UI.MUTED, UI.FONT_MEDIUM)
	_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_round_label)
	_score_label = UI.label("", 16, UI.CREAM, UI.FONT_BOLD)
	header.add_child(_score_label)
	column.add_child(header)
	_question_label = UI.label("", 30, UI.CREAM, UI.FONT_HEADING)
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_question_label)
	var answers := UI.vbox(12)
	answers.name = "Answers"
	column.add_child(answers)
	_keys_hint = UI.label("", 14, UI.MUTED)
	column.add_child(_keys_hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_feedback_label = UI.label("", 26, UI.CREAM, UI.FONT_HEADING)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_feedback_label)
	_next_button = UI.big_button(T.t("next"), UI.CREAM, UI.BG, Vector2(300, 60))
	_next_button.add_theme_font_size_override("font_size", 22)
	_next_button.pressed.connect(_next_round)
	column.add_child(_next_button)
	var quit := UI.ghost_button(T.t("quit"))
	quit.pressed.connect(func() -> void: _go_title())
	column.add_child(quit)
	return root


func _rebuild_answer_buttons() -> void:
	var answers := _play_screen.find_child("Answers", true, false) as VBoxContainer
	for child: Node in answers.get_children():
		child.queue_free()
	_answer_buttons.clear()
	var hints: PackedStringArray = []
	for entry: Dictionary in current_theme.categories:
		var button := UI.big_button(entry["label"], entry["color"], UI.BG, Vector2(300, 78))
		button.add_theme_font_size_override("font_size", 34)
		var category_id: String = entry["id"]
		button.pressed.connect(func() -> void: _choose(category_id))
		button.set_meta("disabled_style", button.get_theme_stylebox("disabled"))
		answers.add_child(button)
		_answer_buttons[category_id] = button
		if not str(entry["key"]).is_empty():
			hints.append("%s = %s" % [entry["key"], entry["label"]])
	_keys_hint.text = T.t("keys", " · ".join(hints)) if not hints.is_empty() else ""


func _start_game() -> void:
	if current_theme == null or current_theme.items.is_empty():
		return
	round_state.setup(current_theme.items, current_theme.rounds, rng, _previous_deck_ids)
	_previous_deck_ids = round_state.deck_ids()
	_show(_play_screen)
	_present_round()


func _present_round() -> void:
	var item := round_state.current()
	_fragment.show_fragment(_texture(item["image"]), _zone(item))
	_round_label.text = T.t("round", [round_state.index + 1, round_state.total()])
	_score_label.text = T.t("score", round_state.score)
	_question_label.text = current_theme.text("question")
	_feedback_label.text = ""
	_next_button.visible = false
	for category_id: String in _answer_buttons:
		var button := _answer_buttons[category_id] as Button
		button.disabled = false
		button.modulate = Color.WHITE
		button.add_theme_stylebox_override("disabled", button.get_meta("disabled_style"))
		button.add_theme_color_override("font_disabled_color", Color(UI.BG, 0.55))
	var first := _answer_buttons.values()[0] as Button if not _answer_buttons.is_empty() else null
	if first != null:
		first.grab_focus.call_deferred()


func _choose(category_id: String) -> void:
	if not _play_screen.visible or round_state.answered:
		return
	var correct := round_state.answer(category_id)
	var item := round_state.current()
	_fragment.reveal(correct)
	var truth := current_theme.category(item["answer"])
	_feedback_label.text = T.t("correct") if correct else T.t("wrong", truth.get("label", "?"))
	_feedback_label.add_theme_color_override("font_color", UI.CORRECT if correct else UI.WRONG)
	_score_label.text = T.t("score", round_state.score)
	for id: String in _answer_buttons:
		var button := _answer_buttons[id] as Button
		button.disabled = true
		button.modulate = Color.WHITE if id == category_id else Color(1, 1, 1, 0.45)
		if id == category_id:
			var fill: Color = current_theme.category(id)["color"]
			button.add_theme_stylebox_override("disabled", UI.box(fill, UI.CORRECT if correct else UI.WRONG, 20, 5))
			button.add_theme_color_override("font_disabled_color", UI.BG)
	_next_button.text = T.t("see_result") if round_state.index + 1 >= round_state.total() else T.t("next")
	_next_button.visible = true
	_next_button.grab_focus.call_deferred()


func _next_round() -> void:
	if not round_state.answered:
		return
	if round_state.advance():
		_present_round()
	else:
		_finish_game()


# ---------------------------------------------------------------- results

func _build_results() -> Control:
	var root := Control.new()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := UI.panel(44)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var column := UI.vbox(16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	column.add_child(UI.label(T.t("verdict"), 18, UI.CORAL, UI.FONT_MEDIUM))
	_result_score = UI.label("", 88, UI.CREAM, UI.FONT_TITLE)
	column.add_child(_result_score)
	_result_comment = UI.paragraph("", 22, UI.CREAM)
	column.add_child(_result_comment)
	_result_best = UI.label("", 16, UI.MUTED)
	column.add_child(_result_best)
	var row := UI.hbox(14)
	var replay := UI.big_button(T.t("replay"), UI.CORAL, UI.BG, Vector2(220, 64))
	replay.name = "Replay"
	replay.pressed.connect(_request_start)
	row.add_child(replay)
	var home := UI.ghost_button(T.t("home"), 160)
	home.custom_minimum_size.y = 64
	home.pressed.connect(func() -> void: _go_title())
	row.add_child(home)
	column.add_child(row)
	_result_chain = UI.paragraph("", 15, UI.MUTED)
	column.add_child(_result_chain)
	return root


func _finish_game() -> void:
	var score := round_state.score
	var total := round_state.total()
	var record := store.submit_score(current_theme.id, score)
	_result_score.text = "%d / %d" % [score, total]
	var ratio := float(score) / maxf(1.0, float(total))
	if ratio >= 1.0:
		_result_comment.text = T.t("perfect_theme") if current_theme.id == "bald_or_ass" else T.t("perfect")
	elif ratio >= 0.7:
		_result_comment.text = T.t("great")
	elif ratio >= 0.4:
		_result_comment.text = T.t("ok")
	else:
		_result_comment.text = T.t("bad")
	_result_best.text = T.t("record") if record and score > 0 else T.t("best", store.best_score(current_theme.id))
	_result_chain.text = ""
	if chain.requires_tx():
		chain.load_leaderboard()
	_show(_results_screen)


func _go_title() -> void:
	_refresh_title()
	_show(_title_screen)


# ---------------------------------------------------------------- editor

func _build_editor() -> Control:
	var root := Control.new()
	var layout := UI.hbox(28)
	var wrapper := UI.margin(layout, 28)
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrapper)

	_canvas = ZoneCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.zone_drawn.connect(_on_zone_drawn)
	layout.add_child(_canvas)

	var side := UI.panel(24)
	side.custom_minimum_size.x = 400
	layout.add_child(side)
	var column := UI.vbox(12)
	side.add_child(column)
	column.add_child(UI.label(T.t("editor_title"), 30, UI.CREAM, UI.FONT_HEADING))
	column.add_child(UI.paragraph(T.t("editor_help"), 15))
	_editor_counter = UI.label("", 15, UI.MUTED, UI.FONT_MEDIUM)
	column.add_child(_editor_counter)
	_editor_item = UI.label("", 22, UI.CREAM, UI.FONT_BOLD)
	column.add_child(_editor_item)
	_editor_state = UI.label("", 14, UI.MUTED)
	column.add_child(_editor_state)

	var nav := UI.hbox(10)
	var previous := UI.ghost_button(T.t("previous"))
	previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous.pressed.connect(func() -> void: _editor_step(-1))
	nav.add_child(previous)
	var following := UI.ghost_button(T.t("following"))
	following.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	following.pressed.connect(func() -> void: _editor_step(1))
	nav.add_child(following)
	column.add_child(nav)

	_preview_toggle = CheckButton.new()
	_preview_toggle.text = T.t("preview")
	_preview_toggle.add_theme_color_override("font_color", UI.CREAM)
	_preview_toggle.toggled.connect(func(on: bool) -> void: _canvas.preview_mask = on)
	column.add_child(_preview_toggle)

	var reset := UI.ghost_button(T.t("reset_zone"))
	reset.pressed.connect(_reset_zone)
	column.add_child(reset)

	# Shown only when no contract is configured yet (web wallet required).
	var deploy_box := UI.vbox(8)
	deploy_box.add_child(UI.paragraph(T.t("deploy_help"), 14))
	var deploy := UI.ghost_button(T.t("deploy"))
	deploy.pressed.connect(_deploy_contract)
	deploy_box.add_child(deploy)
	column.add_child(deploy_box)
	_deploy_box = deploy_box

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(UI.paragraph(T.t("export_help"), 14))
	var export_row := UI.hbox(10)
	var copy := UI.ghost_button(T.t("copy"))
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(_copy_json)
	export_row.add_child(copy)
	var download := UI.ghost_button(T.t("download"))
	download.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	download.visible = OS.has_feature("web")
	download.pressed.connect(_download_json)
	export_row.add_child(download)
	column.add_child(export_row)
	_editor_status = UI.label("", 14, UI.CORAL)
	_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_editor_status)
	var back := UI.big_button(T.t("back"), UI.CREAM, UI.BG, Vector2(300, 56))
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func() -> void: _go_title())
	column.add_child(back)
	return root


func _open_editor() -> void:
	if current_theme == null:
		return
	_editor_index = clampi(_editor_index, 0, maxi(0, current_theme.items.size() - 1))
	_editor_status.text = ""
	_deploy_box.visible = chain.available() and chain.contract.is_empty()
	_show(_editor_screen)
	_editor_present()


func _editor_present() -> void:
	if current_theme.items.is_empty():
		_canvas.texture = null
		_editor_counter.text = T.t("no_images")
		_editor_item.text = ""
		_editor_state.text = ""
		return
	var item: Dictionary = current_theme.items[_editor_index]
	_canvas.texture = _texture(item["image"])
	_canvas.zone = _zone(item)
	_editor_counter.text = T.t("round", [_editor_index + 1, current_theme.items.size()])
	_editor_item.text = "%s  ·  %s" % [item["id"], current_theme.category(item["answer"]).get("label", "?")]
	_editor_refresh_state()


func _editor_refresh_state() -> void:
	var item: Dictionary = current_theme.items[_editor_index]
	var custom := store.zones(current_theme.id).has(item["id"])
	var zone := _zone(item)
	_editor_state.text = "%s · x %.0f %% · y %.0f %% · %.0f × %.0f %%" % [
		T.t("zone_custom") if custom else T.t("zone_theme"),
		zone.position.x * 100.0, zone.position.y * 100.0, zone.size.x * 100.0, zone.size.y * 100.0,
	]


func _editor_step(direction: int) -> void:
	if current_theme.items.is_empty():
		return
	_editor_index = posmod(_editor_index + direction, current_theme.items.size())
	_editor_status.text = ""
	_editor_present()


func _on_zone_drawn(zone: Rect2) -> void:
	var item: Dictionary = current_theme.items[_editor_index]
	store.set_zone(current_theme.id, item["id"], zone)
	_editor_status.text = T.t("zone_saved")
	_editor_refresh_state()


func _reset_zone() -> void:
	if current_theme.items.is_empty():
		return
	store.clear_zone(current_theme.id, current_theme.items[_editor_index]["id"])
	_editor_status.text = T.t("zone_reset")
	_editor_present()


func export_json() -> String:
	return current_theme.to_json(store.zones(current_theme.id))


func _copy_json() -> void:
	DisplayServer.clipboard_set(export_json())
	_editor_status.text = T.t("copied", store.override_count(current_theme.id))


func _download_json() -> void:
	if not OS.has_feature("web"):
		return
	var file_name := "%s.theme.json" % current_theme.id
	JavaScriptBridge.download_buffer(export_json().to_utf8_buffer(), file_name, "application/json")
	_editor_status.text = T.t("downloaded", file_name)


# ---------------------------------------------------------------- on-chain (Hemi)

## Play / Replay: when a contract is configured, the game only starts after
## the player validates the start-of-game transaction in their wallet.
func _request_start() -> void:
	if current_theme == null or current_theme.items.is_empty():
		return
	if not chain.requires_tx():
		_start_game()
		return
	if _awaiting_tx or chain.busy:
		return
	_awaiting_tx = true
	_set_chain_message(T.t("tx_confirm"), UI.CREAM)
	_set_start_buttons_disabled(true)
	chain.start_game_tx()


func _on_game_tx_sent(_hash: String) -> void:
	if not _awaiting_tx:
		return
	_awaiting_tx = false
	_set_start_buttons_disabled(false)
	_set_chain_message("", UI.MUTED)
	_start_game()


func _on_game_tx_failed(code: String, message: String) -> void:
	_awaiting_tx = false
	_set_start_buttons_disabled(false)
	var text := ""
	match code:
		"rejected":
			text = T.t("tx_rejected")
		"no_funds":
			text = T.t("tx_no_funds")
		"wrong_chain":
			text = T.t("tx_wrong_chain")
		"no_wallet", "no_account":
			text = T.t("no_wallet")
		"pending":
			text = T.t("tx_pending")
		_:
			text = T.t("tx_error", message.substr(0, 120) if not message.is_empty() else code)
	_set_chain_message(text, UI.WRONG)


func _on_game_tx_confirmed(_hash: String) -> void:
	if _results_screen.visible:
		chain.load_leaderboard()


func _set_start_buttons_disabled(disabled: bool) -> void:
	_play_button.disabled = disabled or current_theme.items.is_empty()
	var replay := _results_screen.find_child("Replay", true, false) as Button
	if replay != null:
		replay.disabled = disabled


## Same message on the home and results screens (where Play/Replay live).
func _set_chain_message(text: String, color: Color) -> void:
	for label: Label in [_chain_status, _result_chain]:
		label.add_theme_color_override("font_color", color)
	_chain_status.text = text if not text.is_empty() else _chain_hint()
	_result_chain.text = text
	if text.is_empty():
		_chain_status.add_theme_color_override("font_color", UI.MUTED)


func _chain_hint() -> String:
	if not chain.available():
		return ""
	if chain.contract.is_empty():
		return T.t("onchain_off")
	if not chain.has_wallet and not chain.mock:
		return T.t("no_wallet")
	return T.t("onchain_on")


func _refresh_chain_ui() -> void:
	if _wallet_button == null:
		return
	var connected := not chain.account.is_empty()
	_wallet_button.text = T.t("wallet", chain.short_address(chain.account)) if connected else T.t("connect_wallet")
	_wallet_button.visible = chain.available()
	if not _awaiting_tx:
		_chain_status.text = _chain_hint()
		_chain_status.add_theme_color_override("font_color", UI.MUTED)


func _on_chain_status() -> void:
	_refresh_chain_ui()


func _on_wallet_pressed() -> void:
	if chain.account.is_empty():
		chain.connect_wallet()
	elif not chain.account.is_empty():
		OS.shell_open(chain.explorer_link("address", chain.account))


func _build_leaderboard() -> Control:
	var root := Control.new()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := UI.panel(36)
	card.custom_minimum_size = Vector2(680, 600)
	center.add_child(card)
	var column := UI.vbox(12)
	card.add_child(column)
	column.add_child(UI.label(T.t("leaderboard"), 40, UI.CREAM, UI.FONT_TITLE))
	column.add_child(UI.label(T.t("lb_subtitle"), 16, UI.CORAL, UI.FONT_MEDIUM))
	_lb_totals = UI.label("", 16, UI.MUTED)
	column.add_child(_lb_totals)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_lb_list = UI.vbox(6)
	_lb_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lb_list)
	_lb_status = UI.paragraph("", 16, UI.MUTED)
	column.add_child(_lb_status)
	var row := UI.hbox(12)
	var refresh := UI.ghost_button(T.t("refresh"), 150)
	refresh.pressed.connect(func() -> void: _load_leaderboard())
	row.add_child(refresh)
	var explorer := UI.ghost_button(T.t("view_contract"), 180)
	explorer.name = "ViewContract"
	explorer.pressed.connect(func() -> void:
		if not chain.contract.is_empty():
			OS.shell_open(chain.explorer_link("address", chain.contract)))
	row.add_child(explorer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var back := UI.big_button(T.t("back"), UI.CREAM, UI.BG, Vector2(160, 52))
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void: _go_title())
	row.add_child(back)
	column.add_child(row)
	return root


func _open_leaderboard() -> void:
	_show(_leaderboard_screen)
	(_leaderboard_screen.find_child("ViewContract", true, false) as Control).visible = not chain.contract.is_empty()
	_load_leaderboard()


func _load_leaderboard() -> void:
	for child: Node in _lb_list.get_children():
		child.queue_free()
	_lb_totals.text = ""
	if not chain.available() or chain.contract.is_empty():
		_lb_status.text = T.t("lb_no_contract")
		return
	_lb_status.text = T.t("lb_loading")
	chain.load_leaderboard()


func _games_text(count: int) -> String:
	return T.t("lb_games_one", count) if count == 1 else T.t("lb_games", count)


func _on_leaderboard_loaded(data: Dictionary) -> void:
	if _results_screen.visible and chain.account != "":
		_result_chain.add_theme_color_override("font_color", UI.CORRECT)
		_result_chain.text = "%s %s" % [T.t("tx_recorded"), T.t("my_games", chain.my_games())]
	if _lb_list == null:
		return
	for child: Node in _lb_list.get_children():
		child.queue_free()
	var rows: Array = data.get("rows", [])
	var player_total := int(data.get("players", rows.size()))
	_lb_totals.text = T.t("lb_totals", [_games_text(int(data.get("total", 0))), T.t("lb_players_one", player_total) if player_total == 1 else T.t("lb_players", player_total)])
	_lb_status.text = T.t("lb_empty") if rows.is_empty() else ""
	var rank := 0
	for row_data: Dictionary in rows.slice(0, 100):
		rank += 1
		var mine := str(row_data.get("address", "")) == chain.account and not chain.account.is_empty()
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", UI.box(UI.CORAL.darkened(0.55) if mine else UI.PANEL.lightened(0.04), UI.CORAL if mine else UI.PANEL_EDGE, 12, 1))
		var cells := UI.hbox(16)
		line.add_child(cells)
		var medal_color := UI.CORAL if rank <= 3 else UI.MUTED
		var rank_label := UI.label("#%d" % rank, 18, medal_color, UI.FONT_BOLD)
		rank_label.custom_minimum_size.x = 56
		cells.add_child(rank_label)
		var who := chain.short_address(str(row_data.get("address", "")))
		var address_label := UI.label(who + ("  (%s)" % T.t("lb_you") if mine else ""), 18, UI.CREAM, UI.FONT_MEDIUM)
		address_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cells.add_child(address_label)
		cells.add_child(UI.label(_games_text(int(row_data.get("games", 0))), 18, UI.CREAM, UI.FONT_BOLD))
		_lb_list.add_child(line)


func _on_leaderboard_failed(code: String, message: String) -> void:
	if _lb_status == null:
		return
	_lb_status.text = T.t("lb_no_contract") if code == "no_contract" else T.t("lb_error", message.substr(0, 100) if not message.is_empty() else code)


func _deploy_contract() -> void:
	_editor_status.text = T.t("deploying")
	chain.deploy_contract()


func _on_deploy_finished(ok: bool, address: String, code: String) -> void:
	if ok:
		_editor_status.text = T.t("deployed", address)
		_deploy_box.visible = false
		print("[hemi] GameCounter deployed at ", address)
	else:
		_editor_status.text = T.t("tx_rejected") if code == "rejected" else T.t("deploy_failed", code)
	_refresh_chain_ui()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := OS.get_keycode_string(event.keycode).to_upper()
	if event.keycode == KEY_ESCAPE:
		if not _title_screen.visible:
			_go_title()
			get_viewport().set_input_as_handled()
		return
	if _play_screen.visible:
		if not round_state.answered:
			for entry: Dictionary in current_theme.categories:
				if not str(entry["key"]).is_empty() and key == entry["key"]:
					_choose(entry["id"])
					get_viewport().set_input_as_handled()
					return
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_next_round()
			get_viewport().set_input_as_handled()
	elif _editor_screen.visible:
		if event.keycode == KEY_LEFT:
			_editor_step(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			_editor_step(1)
			get_viewport().set_input_as_handled()
