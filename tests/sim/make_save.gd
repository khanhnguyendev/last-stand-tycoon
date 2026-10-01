extends SceneTree
## Writes export/fixtures/night3_start.save.json (resume_phase NIGHT: resume_from enters night 3 at once) and
## night3_closeup.save.json (resume_phase DAY, day-peak reading) from a PlannerBot run (seed 20260930), using the
## close-up snapshot that precedes night 3. Run: "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/make_save.gd

var _done := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/planner_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	root.get_node("EventBus").snapshot_taken.connect(_on_snapshot)
	main.phase_controller.start_new_game(20260930)
	for i in 60 * 60 * 30:
		if _done:
			return
		await physics_frame
	push_error("no night-3 close-up within 30 min of game time")
	quit(1)

func _on_snapshot(state: Dictionary) -> void:
	# Night N runs with GameState.day == N (new_game sets 1; advance_day at dawn), so the close-up before
	# night 3 carries day == 3.
	if _done or String(state.resume_phase) != "DAY" or int(state.day) != 3:
		return
	_done = true
	var codec = load("res://core/save_codec.gd")
	for pair in [["night3_start", "NIGHT"], ["night3_closeup", "DAY"]]:
		var s: Dictionary = state.duplicate(true)
		s.resume_phase = pair[1]
		var path := ProjectSettings.globalize_path("res://export/fixtures/%s.save.json" % pair[0])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(codec.encode(s, "fixture", 0))
		f.close()
		print("wrote ", path)
	quit(0)
