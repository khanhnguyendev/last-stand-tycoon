extends SceneTree
## E8 phase 2 Task 7: the tier-4 world shots (tier 4 is opened in memory, Tier4Support; it is unreachable in play until Task 9).
## "$GODOT" --path . --resolution 720x1280 -s res://tools/shots_t4.gd -- --out=<dir>
## Writes <dir>/t4_home.png (the HOME view at tier 4) and <dir>/t4_reveal_last.png (the tier-4 reveal after its last step).
var _out := "docs/review/media/e8/backlot"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
	_run.call_deferred()

func _wait(n: int) -> void:
	for i in n:
		await physics_frame

func _grab(name: String) -> void:
	var f0 := Engine.get_frames_drawn()
	while Engine.get_frames_drawn() - f0 < 6:
		await process_frame
	var img := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	path = path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())

func _run() -> void:
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var bus = root.get_node("EventBus")
	bal.reset()
	load("res://tests/support/tier4.gd").open_tier4()
	bal.ui.shake_enabled = false
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.focus_pause.free()
	paused = false
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(20260930)
	await _wait(5)
	var sfx: Array = []
	bus.sfx_requested.connect(func(id): sfx.append(id))
	# the tier-3 day, the tier-4 sign paid, the boss night skipped: the tier-4 dawn reveal
	gs.debug_set_tier(3, gs.day)
	main.phase_controller.debug_skip_to_day()
	await _wait(5)
	gs.add_gold(5000)
	gs.pay_into_tier(gs.tier_next_cost())
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()
	sfx.clear()  # only the reveal's own steps count
	while sfx.count(&"build_done") < 4:
		await physics_frame
	await _wait(20)  # the last step's pop settles
	main.hud.banner_panel.visible = false  # the banner would cover the north lot; the shot is about the map
	await _grab("t4_reveal_last")
	main.phase_controller.finish_reveal_now()
	main.phase_controller.debug_skip_to_day()  # the card pick
	await _wait(30)
	main.hero.teleport(load("res://core/map_layout.gd").HOME)
	await _wait(60 * 4)
	await _grab("t4_home")
	quit()
