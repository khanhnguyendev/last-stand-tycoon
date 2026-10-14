extends SceneTree
## The tier-3 checkpoint stills (E5 tier 3 Task 25). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_checkpoint.gd -- --out=docs/review/media/e5t3/checkpoint
## Writes growth_tier1, growth_tier2, growth_tier3 (the same view, the hero at HOME, by day, every spot of the tier built to level 3;
## the tiers are reached the real way: the sign paid, the boss night skipped, the reveal finished), sw_corner_all_pads (tier 3, all nine
## buildings at level 3, the hero on fence_sw's first pad) and night_brute_lane (a tier-3 night, a siege brute held at the south-west fence,
## the south-west edge arrow raised, the hero at HOME). Each 720x1280 with a _40 copy (288x512). The game's own camera frames every shot.
## The tier-3 cost entry is appended in memory only when the shipped balance lacks it.

var _out := "docs/review/media/e5t3/checkpoint"

func _initialize() -> void:
	_run.call_deferred()

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
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
	pc.debug_skip_to_day()
	main.world.wave_director.stop()
	_max(gs, layout.spots_for_tier(1))
	await _home_grab(main, layout, "growth_tier1")
	for t in [2, 3]:
		gs.add_gold(3000)
		gs.pay_into_tier(gs.tier_next_cost())
		pc.debug_skip_to_night()
		main.world.wave_director.stop()
		pc.debug_skip_to_day()
		pc.finish_reveal_now()
		pc.debug_skip_to_day()  # the card pick
		main.world.wave_director.stop()
		_max(gs, layout.spots_for_tier(t))
		await _home_grab(main, layout, "growth_tier%d" % t)
	# tier 3, the corner: the hero on fence_sw's first pad, tower_sw's and fence_sw's four pads in view
	main.hero.teleport((layout.BRANCH_PADS["fence_sw"] as Array)[0])
	main.camera_rig.snap()
	_drain_banners(main)
	for i in 120:
		await process_frame
	await _grab("sw_corner_all_pads")
	# a tier-3 night: a brute held at the south-west fence, the arrow of that lane
	pc.debug_skip_to_night()
	var wd = main.world.wave_director
	wd.stop()
	_plan(main, [_wave("sw", 6, 2, "west", 4, 0, 2, 0), _wave("north", 4, 0, "east", 3, 0, 0, 0)])
	main.hero.teleport(layout.HOME)
	main.camera_rig.snap()
	var br = wd.debug_spawn("sw", 0.0, 1.0, &"brute")
	br.set_physics_process(false)
	br.dist = br._director.providers.fence_stop_dist(br)
	br._update_position()
	bus.wave_incoming.emit(0, &"sw", &"west")
	_drain_banners(main)
	for i in 240:  # the night's light settles
		await process_frame
	for i in 60:  # one real attack: the thump fires on the last step
		br._physics_process(1.0 / 60.0)
	for i in 4:
		await process_frame
	await _grab("night_brute_lane")
	quit(0)

func _max(gs, ids: Array) -> void:
	gs.gold = 100000
	for id in ids:
		while gs.next_level_cost(id) >= 0:
			gs.pay_into_spot(id, 100000)
	gs.gold = 0
	root.get_node("EventBus").gold_changed.emit(0, 0)  # the HUD purse follows the signal

func _home_grab(main, layout, name: String) -> void:
	_plan(main, [_wave("west", 7, 3, "east", 4, 0), _wave("north", 5, 1, "west", 3, 0)])
	main.hero.teleport(layout.HOME)
	main.camera_rig.snap()
	_drain_banners(main)
	for i in 240:
		await process_frame
	await _grab(name)

func _drain_banners(main) -> void:
	main.hud._banner_queue.clear()
	main.hud._banner_left = 0.0
	main.hud._show_next_banner()

func _plan(main, plan: Array) -> void:
	root.get_node("GameState").lane_plan = plan
	for m in main.world.telegraph_markers.values():
		m.refresh()

func _grab(name: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
