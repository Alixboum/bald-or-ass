class_name GuessTheme
extends RefCounted
## Theme data for the fragment-guessing mechanic. A theme only describes
## content: categories (answers), images and their visible zone. Rules live in
## GuessRound, presentation in the UI scripts.

const INDEX_PATH := "res://themes/index.json"
const DEFAULT_ZONE := Rect2(0.42, 0.42, 0.16, 0.16)
const MIN_ZONE_SIZE := 0.02

var source_path := ""
var id := ""
var title := ""
## Texts can be a plain string or {"en": "...", "fr": "..."}; read them with text().
var tagline: Variant = ""
var rules: Variant = ""
var question: Variant = {"en": "Where does this fragment come from?", "fr": "D'où vient ce fragment ?"}
var rounds := 10
var image_dir := ""
var categories: Array[Dictionary] = []
var items: Array[Dictionary] = []
var errors := PackedStringArray()


static func load_all(index_path: String = INDEX_PATH) -> Array[GuessTheme]:
	var result: Array[GuessTheme] = []
	var index: Variant = _read_json(index_path)
	if not (index is Dictionary) or not (index.get("themes") is Array):
		push_error("[guess] Invalid theme index: " + index_path)
		return result
	for path: Variant in index["themes"]:
		var theme := GuessTheme.from_file(str(path))
		if theme != null:
			result.append(theme)
	return result


static func from_file(path: String) -> GuessTheme:
	var data: Variant = _read_json(path)
	if not (data is Dictionary):
		push_error("[guess] Theme file is not a JSON object: " + path)
		return null
	var theme := GuessTheme.from_dict(data)
	theme.source_path = path
	return theme


static func from_dict(data: Dictionary) -> GuessTheme:
	var theme := GuessTheme.new()
	theme.id = str(data.get("id", ""))
	theme.title = str(data.get("title", theme.id))
	theme.tagline = data.get("tagline", "")
	theme.rules = data.get("rules", "")
	theme.question = data.get("question", theme.question)
	theme.rounds = int(data.get("rounds", 10))
	theme.image_dir = str(data.get("image_dir", ""))
	if theme.id.is_empty():
		theme.errors.append("Thème sans identifiant")
	var seen_categories := {}
	for raw: Variant in data.get("categories", []):
		if not (raw is Dictionary) or str(raw.get("id", "")).is_empty():
			theme.errors.append("Catégorie invalide")
			continue
		var category := {
			"id": str(raw["id"]),
			"label": str(raw.get("label", raw["id"])),
			"key": str(raw.get("key", "")).to_upper(),
			"color": Color.from_string(str(raw.get("color", "#ff8a5c")), Color("ff8a5c")),
		}
		seen_categories[category["id"]] = true
		theme.categories.append(category)
	if theme.categories.size() < 2:
		theme.errors.append("Il faut au moins deux catégories de réponse")
	var seen_items := {}
	for raw: Variant in data.get("items", []):
		if not (raw is Dictionary):
			theme.errors.append("Image invalide")
			continue
		var item_id := str(raw.get("id", ""))
		var answer := str(raw.get("answer", ""))
		if item_id.is_empty() or seen_items.has(item_id):
			theme.errors.append("Identifiant d'image manquant ou en double : " + item_id)
			continue
		if not seen_categories.has(answer):
			theme.errors.append("Réponse inconnue pour %s : %s" % [item_id, answer])
			continue
		seen_items[item_id] = true
		var image := str(raw.get("image", ""))
		if not image.begins_with("res://"):
			image = theme.image_dir.path_join(image)
		theme.items.append({
			"id": item_id,
			"image": image,
			"answer": answer,
			"zone": zone_from_dict(raw.get("zone", {}), DEFAULT_ZONE),
		})
	return theme


static func zone_from_dict(raw: Variant, fallback: Rect2) -> Rect2:
	if not (raw is Dictionary):
		return fallback
	var keys := ["x", "y", "w", "h"]
	for key: String in keys:
		if not raw.has(key):
			return fallback
	return normalize_zone(Rect2(float(raw["x"]), float(raw["y"]), float(raw["w"]), float(raw["h"])))


static func zone_to_dict(zone: Rect2) -> Dictionary:
	return {
		"x": snappedf(zone.position.x, 0.0001),
		"y": snappedf(zone.position.y, 0.0001),
		"w": snappedf(zone.size.x, 0.0001),
		"h": snappedf(zone.size.y, 0.0001),
	}


## Clamp a normalized rectangle inside the image, with a minimum size.
static func normalize_zone(zone: Rect2) -> Rect2:
	var rect := zone.abs()
	var size := Vector2(clampf(rect.size.x, MIN_ZONE_SIZE, 1.0), clampf(rect.size.y, MIN_ZONE_SIZE, 1.0))
	var position := Vector2(clampf(rect.position.x, 0.0, 1.0 - size.x), clampf(rect.position.y, 0.0, 1.0 - size.y))
	return Rect2(position, size)


## Theme text in the current interface language (GuessText.locale).
func text(field: String) -> String:
	return GuessText.pick(get(field))


func category(category_id: String) -> Dictionary:
	for entry: Dictionary in categories:
		if entry["id"] == category_id:
			return entry
	return {}


func items_for(category_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		if item["answer"] == category_id:
			result.append(item)
	return result


## Categories without any image yet (useful while a theme is being built).
func empty_categories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in categories:
		if items_for(entry["id"]).is_empty():
			result.append(entry)
	return result


## Theme zones, overridden by zones drawn in the editor (per browser).
func zone_for(item: Dictionary, overrides: Dictionary = {}) -> Rect2:
	if overrides.has(item["id"]):
		return zone_from_dict(overrides[item["id"]], item["zone"])
	return item["zone"]


## Full theme JSON with the given overrides merged in, ready to replace theme.json.
func to_json(overrides: Dictionary = {}) -> String:
	var category_rows: Array = []
	for entry: Dictionary in categories:
		category_rows.append({
			"id": entry["id"], "label": entry["label"], "key": entry["key"],
			"color": "#" + (entry["color"] as Color).to_html(false),
		})
	var item_rows: Array = []
	for item: Dictionary in items:
		var image := str(item["image"])
		if not image_dir.is_empty() and image.begins_with(image_dir):
			image = image.substr(image_dir.length())
		item_rows.append({
			"id": item["id"], "image": image, "answer": item["answer"],
			"zone": zone_to_dict(zone_for(item, overrides)),
		})
	var data := {
		"id": id, "title": title, "tagline": tagline, "rules": rules, "question": question,
		"rounds": rounds, "image_dir": image_dir, "categories": category_rows, "items": item_rows,
	}
	return JSON.stringify(data, "  ", false)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[guess] Missing JSON file: " + path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
