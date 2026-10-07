extends SceneTree
## The tier-3 reveal, the south-west arrow and the HUD clear of count rows (E5 tier 3 Task 20). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_reveal_t3.gd -- --out=docs/review/media/e5t3/reveal
## Writes reveal_t3_0 (before step 1), reveal_t3_2 (after step 2: the lot and the lane), reveal_t3_5 (after the storey) and
## reveal_t3_end (all steps done, just before the card pick), arrow_sw (a night with the south-west arrow beside a west one, hero at
## HOME) and home_rows_hidden (a tier-1 day from HOME: the HUD clear of count rows), each with a _40 copy (288x512).
## The tier-3 cost entry is appended here (the switch is Task 21). The game's own camera does the framing: it is at the hero
## when the game is created, and every still grab waits for the diner's fade to settle.

var _out := ""

func _initialize() -> void:
	_run.call_deferred()

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

func _run() -> void:
	var out := "docs/review/media/e5t3/reveal"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_out = out
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var bus = root.get_node("EventBus")
	bal.reset()
	bal.ui.shake_enabled = false
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)
	var layout = load("res://core/map_layout.gd")
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.focus_pause.free()
	paused = false
	main.phase_controller.start_new_game(20260930)
	main.hero.input.player_control = false
	for i in 90:
		await physics_frame
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	var pc = main.phase_controller
	# tier 2 (its reveal ended at once), then the tier-3 sign paid and the boss night won
	pc.debug_skip_to_day()
	gs.add_gold(2000)
	gs.pay_into_tier(gs.tier_next_cost())
	pc.debug_skip_to_night()
	pc.debug_skip_to_day()
	pc.finish_reveal_now()
	pc.debug_skip_to_day()  # the tier-2 card pick
	main.world.wave_director.stop()
	main.hero.teleport(layout.HOME)
	main.camera_rig.snap()
	for i in 90:  # the fade settles, the camera rests at HOME
		await process_frame
	gs.add_gold(3000)
	gs.pay_into_tier(gs.tier_next_cost())
	pc.debug_skip_to_night()
	main.world.wave_director.stop()
	_drain_banners(main)
	pc.debug_skip_to_day()  # the tier-3 dawn: the reveal starts
	# the times: step 1 at 0.6 s, step 2 at 0.91 s, step 5 at 1.85 s, the card pick at 3.0 s
	var t := 0
	for target in [[0.55, "reveal_t3_0"], [1.1, "reveal_t3_2"], [2.1, "reveal_t3_5"], [2.9, "reveal_t3_end"]]:
		var want := int(target[0] * 60.0)
		while t < want:
			await physics_frame
			t += 1
		await _grab(main, target[1])
	pc.finish_reveal_now()
	pc.debug_skip_to_day()  # the card pick
	# a night with the south-west arrow (main) beside a west one, heavy, hero at HOME
	pc.debug_skip_to_night()
	main.world.wave_director.stop()
	_plan(main, [_wave("sw", 6, 2, "west", 4, 0, 1, 0), _wave("north", 4, 0, "east", 3, 0, 0, 0)])
	main.hero.teleport(layout.HOME)
	main.camera_rig.snap()
	bus.wave_incoming.emit(0, &"sw", &"west")
	_drain_banners(main)
	for i in 240:  # the night's light settles
		await process_frame
	await _grab(main, "arrow_sw")
	# a tier-1 day from HOME: the HUD clear of count rows
	pc.start_new_game(20260930)
	pc.debug_skip_to_day()
	main.world.wave_director.stop()
	_plan(main, [_wave("west", 7, 3, "east", 4, 0), _wave("north", 5, 1, "west", 3, 0)])
	main.hero.teleport(layout.HOME)
	main.camera_rig.snap()
	_drain_banners(main)
	for i in 240:
		await process_frame
	await _grab(main, "home_rows_hidden")
	quit(0)

## Empties the HUD's banner queue (a banner left over from the script's own skips would cover the picture).
func _drain_banners(main) -> void:
	main.hud._banner_queue.clear()
	main.hud._banner_left = 0.0
	main.hud._show_next_banner()

func _plan(main, plan: Array) -> void:
	root.get_node("GameState").lane_plan = plan
	for m in main.world.telegraph_markers.values():
		m.refresh()

func _grab(main, name: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
