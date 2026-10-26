extends SceneTree
## Native capture: GUESS_CAPTURE_PATH=/abs/out.png GUESS_CAPTURE_STATE=title|play|reveal_ok|reveal_ko|results|editor

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var path := OS.get_environment("GUESS_CAPTURE_PATH")
	var state := OS.get_environment("GUESS_CAPTURE_STATE")
	root.size = Vector2i(1280, 720)
	var main: Control = (load("res://scenes/guess_main.tscn") as PackedScene).instantiate()
	main.set("_store_path", "user://fragment_guess_capture.json")
	root.add_child(main)
	await process_frame
	var round_state := main.get("round_state") as GuessRound
	match state:
		"title_fr":
			main.call("set_language", "fr")
		"title_chain", "leaderboard":
			var chain := main.get("chain") as HemiChain
			chain.mock = true
			chain.contract = "0x" + "cd".repeat(20)
			chain.account = "0x3f8a" + "0".repeat(32) + "b21c"
			chain.mock_games = {"0x91c2" + "1".repeat(32) + "77aa": 14, chain.account: 6, "0x0d4e" + "2".repeat(32) + "e903": 3, "0xa7b1" + "3".repeat(32) + "1c5f": 1}
			main.call("_go_title")
			if state == "leaderboard":
				main.call("_open_leaderboard")
			await process_frame
			await process_frame
		"play", "reveal_ok", "reveal_ko":
			main.call("_start_game")
			await process_frame
			if state != "play":
				var truth: String = round_state.current()["answer"]
				var choice := truth if state == "reveal_ok" else ("ass" if truth == "bald" else "bald")
				main.call("_choose", choice)
				await create_timer(0.9).timeout
		"results":
			main.call("_start_game")
			while not round_state.is_finished():
				main.call("_choose", round_state.current()["answer"] if round_state.index % 3 else "ass")
				main.call("_next_round")
		"editor":
			main.call("_open_editor")
	for _i: int in 6:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("[capture] ", path)
	quit(0)
