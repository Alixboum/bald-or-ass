class_name HemiChain
extends Node
## Godot side of the Hemi on-chain account: wallet connection, one transaction
## per game and the games-played leaderboard. Talks to window.HemiChain
## (web/hemi_bridge.js) on the web; elsewhere it is inactive unless `mock` is
## set (tests), which simulates a wallet.

signal status_changed
signal game_tx_sent(hash: String)
signal game_tx_failed(code: String, message: String)
signal game_tx_confirmed(hash: String)
signal leaderboard_loaded(data: Dictionary)
signal leaderboard_failed(code: String, message: String)
signal deploy_finished(ok: bool, address: String, code: String)

const CONFIG_PATH := "res://config/hemi.json"

var config := {}
var account := ""
var contract := ""
var has_wallet := false
var busy := false
var last_leaderboard := {}
## Test double: simulated wallet that always accepts (unless mock_reject).
var mock := false
var mock_reject := false
var mock_games := {}

var _bridge: JavaScriptObject
var _callbacks: Array = []
var _listener: JavaScriptObject


func _ready() -> void:
	config = load_config()
	contract = str(config.get("contract", "")).to_lower()
	if OS.has_feature("web"):
		_bridge = JavaScriptBridge.get_interface("HemiChain")
		if _bridge != null:
			_listener = JavaScriptBridge.create_callback(_on_bridge_event)
			_bridge.call("listen", _listener)
			_call("configure", config, _on_status)


static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return parsed if parsed is Dictionary else {}


## True when on-chain features can run (web wallet bridge or test mock).
func available() -> bool:
	return mock or _bridge != null


## True when every game must start with a validated transaction.
func requires_tx() -> bool:
	return available() and not contract.is_empty()


func short_address(address: String) -> String:
	return address if address.length() < 12 else "%s…%s" % [address.substr(0, 6), address.substr(address.length() - 4)]


func explorer_link(kind: String, value: String) -> String:
	return "%s/%s/%s" % [str(config.get("explorer_url", "https://explorer.hemi.xyz")).trim_suffix("/"), kind, value]


func refresh_status() -> void:
	if mock:
		status_changed.emit()
	elif _bridge != null:
		_call("status", {}, _on_status)


func connect_wallet() -> void:
	if mock:
		account = "0x" + "ab".repeat(20)
		has_wallet = true
		status_changed.emit()
		return
	if _bridge == null:
		return
	busy = true
	_call("connect", {}, func(result: Dictionary) -> void:
		busy = false
		if result.get("ok", false):
			account = str(result["data"].get("account", ""))
		status_changed.emit()
		if not result.get("ok", false):
			game_tx_failed.emit(str(result.get("code", "error")), str(result.get("message", ""))))


## Asks the wallet to sign the start-of-game transaction.
func start_game_tx() -> void:
	if busy:
		return
	busy = true
	if mock:
		_finish_mock_tx.call_deferred()
		return
	_call("startGame", {}, func(result: Dictionary) -> void:
		busy = false
		if result.get("ok", false):
			account = str(result["data"].get("account", account))
			status_changed.emit()
			game_tx_sent.emit(str(result["data"].get("hash", "")))
		else:
			game_tx_failed.emit(str(result.get("code", "error")), str(result.get("message", ""))))


func load_leaderboard() -> void:
	if mock:
		var rows: Array = []
		var total := 0
		for address: String in mock_games:
			rows.append({"address": address, "games": mock_games[address]})
			total += int(mock_games[address])
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["games"] > b["games"])
		last_leaderboard = {"rows": rows, "total": total, "players": rows.size(), "account": account}
		leaderboard_loaded.emit.call_deferred(last_leaderboard)
		return
	if _bridge == null or contract.is_empty():
		leaderboard_failed.emit("no_contract", "")
		return
	_call("leaderboard", {}, func(result: Dictionary) -> void:
		if result.get("ok", false):
			last_leaderboard = result["data"]
			leaderboard_loaded.emit(last_leaderboard)
		else:
			leaderboard_failed.emit(str(result.get("code", "error")), str(result.get("message", ""))))


## Games played by the connected wallet, from the last leaderboard read.
func my_games() -> int:
	if account.is_empty():
		return 0
	for row: Dictionary in last_leaderboard.get("rows", []):
		if str(row.get("address", "")) == account:
			return int(row.get("games", 0))
	return 0


## Deploys GameCounter from the connected wallet (web only).
func deploy_contract() -> void:
	if _bridge == null or busy:
		deploy_finished.emit(false, "", "unavailable")
		return
	busy = true
	_call("deploy", {}, func(result: Dictionary) -> void:
		busy = false
		if result.get("ok", false):
			contract = str(result["data"].get("address", ""))
			status_changed.emit()
			deploy_finished.emit(true, contract, "")
		else:
			deploy_finished.emit(false, "", str(result.get("code", "error"))))


# ---------------------------------------------------------------- internals

func _finish_mock_tx() -> void:
	busy = false
	if mock_reject:
		game_tx_failed.emit("rejected", "User rejected the request.")
		return
	if account.is_empty():
		account = "0x" + "ab".repeat(20)
	mock_games[account] = int(mock_games.get(account, 0)) + 1
	var hash := "0x" + "%064x" % int(mock_games[account])
	game_tx_sent.emit(hash)
	game_tx_confirmed.emit(hash)


func _call(op: String, args: Dictionary, done: Callable) -> void:
	# The JavaScript callback must stay referenced until it fires.
	var holder := {}
	var callback := JavaScriptBridge.create_callback(func(js_args: Array) -> void:
		_callbacks.erase(holder.get("cb"))
		var parsed: Variant = JSON.parse_string(str(js_args[0]) if not js_args.is_empty() else "")
		done.call(parsed if parsed is Dictionary else {"ok": false, "code": "bad_reply"}))
	holder["cb"] = callback
	_callbacks.append(callback)
	_bridge.call("invoke", op, JSON.stringify(args), callback)


func _on_status(result: Dictionary) -> void:
	if result.get("ok", false):
		var data: Dictionary = result["data"]
		has_wallet = bool(data.get("hasWallet", false))
		account = str(data.get("account", ""))
		contract = str(data.get("contract", contract)).to_lower()
	status_changed.emit()


func _on_bridge_event(js_args: Array) -> void:
	var parsed: Variant = JSON.parse_string(str(js_args[0]) if not js_args.is_empty() else "")
	if not (parsed is Dictionary):
		return
	match str(parsed.get("event", "")):
		"account":
			account = str(parsed.get("account", ""))
			status_changed.emit()
		"confirmed":
			game_tx_confirmed.emit(str(parsed.get("hash", "")))
