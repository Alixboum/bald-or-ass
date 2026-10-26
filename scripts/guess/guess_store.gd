class_name GuessStore
extends RefCounted
## Local persistence (browser storage on the Web): best scores and zones drawn
## in the editor, per theme.

const DEFAULT_PATH := "user://fragment_guess.json"

var path := DEFAULT_PATH
var _data := {"best": {}, "zones": {}, "locale": ""}


func _init(store_path: String = DEFAULT_PATH) -> void:
	path = store_path
	load_data()


func load_data() -> void:
	_data = {"best": {}, "zones": {}, "locale": ""}
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		if parsed.get("best") is Dictionary:
			_data["best"] = parsed["best"]
		if parsed.get("zones") is Dictionary:
			_data["zones"] = parsed["zones"]
		if parsed.get("locale") is String:
			_data["locale"] = parsed["locale"]


func save() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_data))
	return true


## Saved interface language, or "" when the player never chose one.
func locale() -> String:
	return str(_data.get("locale", ""))


func set_locale(value: String) -> void:
	_data["locale"] = value
	save()


func best_score(theme_id: String) -> int:
	return int(_data["best"].get(theme_id, 0))


## Returns true when the score is a new record.
func submit_score(theme_id: String, score: int) -> bool:
	if score <= best_score(theme_id) and _data["best"].has(theme_id):
		return false
	_data["best"][theme_id] = score
	save()
	return true


func zones(theme_id: String) -> Dictionary:
	var value: Variant = _data["zones"].get(theme_id, {})
	return value if value is Dictionary else {}


func set_zone(theme_id: String, item_id: String, zone: Rect2) -> void:
	var theme_zones := zones(theme_id)
	theme_zones[item_id] = GuessTheme.zone_to_dict(GuessTheme.normalize_zone(zone))
	_data["zones"][theme_id] = theme_zones
	save()


func clear_zone(theme_id: String, item_id: String) -> void:
	var theme_zones := zones(theme_id)
	theme_zones.erase(item_id)
	_data["zones"][theme_id] = theme_zones
	save()


func override_count(theme_id: String) -> int:
	return zones(theme_id).size()
