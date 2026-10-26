class_name GuessRound
extends RefCounted
## Theme-agnostic rules: a shuffled deck of items, one answer per round,
## score counting and end of session. No UI here.

var deck: Array[Dictionary] = []
var index := 0
var score := 0
var answered := false
var last_correct := false
var last_choice := ""
var history: Array[Dictionary] = []


## Longest allowed run of the same answer category in a row (when avoidable).
const MAX_STREAK := 2


## Builds a mixed deck: categories balanced, no run longer than MAX_STREAK
## when avoidable, and items whose id is in `avoid_ids` (e.g. the previous
## game) used only once the fresh ones run out.
func setup(items: Array[Dictionary], rounds: int, rng: RandomNumberGenerator = null, avoid_ids: Array = []) -> void:
	var random := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		random.randomize()
	var pool: Array[Dictionary] = items.duplicate()
	_shuffle(pool, random)
	var count := pool.size() if rounds <= 0 else mini(rounds, pool.size())

	# Per-category queues, fresh items first (each part already shuffled).
	var queues := {}
	var categories: Array[String] = []
	for pass_avoided: bool in [false, true]:
		for item: Dictionary in pool:
			if avoid_ids.has(str(item.get("id", ""))) != pass_avoided:
				continue
			var category := str(item.get("answer", ""))
			if not queues.has(category):
				queues[category] = []
				categories.append(category)
			queues[category].append(item)
	_shuffle(categories, random)

	# Balanced pick: round-robin over categories until `count` items.
	var picked: Array[Dictionary] = []
	while picked.size() < count:
		for category: String in categories:
			if picked.size() < count and not queues[category].is_empty():
				picked.append(queues[category].pop_front())

	# Order: random, but avoid runs longer than MAX_STREAK.
	_shuffle(picked, random)
	deck = []
	while not picked.is_empty():
		var options: Array[int] = []
		for i: int in picked.size():
			if _keeps_order_possible(picked, i):
				options.append(i)
		var choice: int = options[random.randi_range(0, options.size() - 1)] if not options.is_empty() else 0
		deck.append(picked[choice])
		picked.remove_at(choice)
	index = 0
	score = 0
	answered = false
	last_correct = false
	last_choice = ""
	history.clear()


## Ids of the items in the current deck (to avoid them next game).
func deck_ids() -> Array:
	return deck.map(func(item: Dictionary) -> String: return str(item.get("id", "")))


## True if placing picked[index] next keeps a run-free order possible for
## everything left (each category must fit between the others).
func _keeps_order_possible(picked: Array[Dictionary], index: int) -> bool:
	var category := str(picked[index].get("answer", ""))
	var streak := 1
	for k: int in range(deck.size() - 1, -1, -1):
		if str(deck[k].get("answer", "")) != category:
			break
		streak += 1
	if streak > MAX_STREAK:
		return false
	var remaining := {}
	for i: int in picked.size():
		if i != index:
			var c := str(picked[i].get("answer", ""))
			remaining[c] = int(remaining.get(c, 0)) + 1
	var total_left := picked.size() - 1
	for c: String in remaining:
		var others: int = total_left - int(remaining[c])
		var head_room := (MAX_STREAK - streak) if c == category else MAX_STREAK
		if int(remaining[c]) > head_room + MAX_STREAK * others:
			return false
	return true


## Fisher-Yates with the provided generator so tests stay deterministic.
func _shuffle(values: Array, random: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var swap = values[i]
		values[i] = values[j]
		values[j] = swap


func total() -> int:
	return deck.size()


func has_rounds() -> bool:
	return not deck.is_empty()


func current() -> Dictionary:
	if index < 0 or index >= deck.size():
		return {}
	return deck[index]


## Records the player's choice once per round and returns whether it is correct.
func answer(category_id: String) -> bool:
	if answered or current().is_empty():
		return last_correct
	answered = true
	last_choice = category_id
	last_correct = category_id == current()["answer"]
	if last_correct:
		score += 1
	history.append({"id": current()["id"], "choice": category_id, "correct": last_correct})
	return last_correct


## Moves to the next round. Returns false when the session is over.
func advance() -> bool:
	if not answered:
		return true
	index += 1
	answered = false
	last_choice = ""
	return index < deck.size()


func is_finished() -> bool:
	return index >= deck.size()
