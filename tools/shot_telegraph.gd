extends SceneTree
## The day telegraph rows (E5 tier 3 Task 14). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_telegraph.gd -- --out=docs/review/media/e5t3/telegraph
## Writes day_tier2.png (Boars and hares on two lanes), day_tier2_boss.png (the tier paid: the boss icon on its lane) and
## day_tier3.png (tier 3 forced, the cost entry appended, a brute lane and the sw lane), each with a _40 copy (288x512).
## The capture camera is placed at its framing when it is created, and every grab waits for the diner's fade to settle.

func _initialize() -> void:
	_run.call_deferred()

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

func _run() -> void:
	var out := "docs/review/media/e5t3/telegraph"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	bal.reset()
	bal.ui.shake_enabled = false
	var camera_math = load("res://core/camera_math.gd")
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
	var focus := Vector2(-5.2, -7.8)  # between the west and north markers
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)  # at its framing from the start
	cam.current = true
	root.add_child(cam)
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	# Tier 1, tier 2 paid in full: tonight is a boss night, and the boss icon is on the last wave's main lane (north).
	main.hero.teleport(focus)
	_plan(main, [_wave("west", 7, 3, "north", 4, 0), _wave("west", 5, 1, "", 0, 0), _wave("north", 0, 0, "", 0, 0)])
	gs.add_gold(2000)
	gs.pay_into_tier(500)
	_plan(main, gs.lane_plan)
	main.hero.teleport(Vector2(-3.8, -7.8))
	await _grab(cam, out, "day_tier2_boss", Vector2(-3.8, -7.8), camera_math, bal)
	gs.debug_set_tier(2, 5)
	main.hero.teleport(focus)
	_plan(main, [_wave("west", 7, 3, "north", 4, 0), _wave("west", 5, 1, "", 0, 0)])
	await _grab(cam, out, "day_tier2", focus, camera_math, bal)
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)  # the shot forces tier 3
	gs.debug_set_tier(3, 6)
	for i in 30:
		await physics_frame
	main.hero.teleport(focus)
	_plan(main, [_wave("west", 6, 2, "sw", 4, 0, 1, 0), _wave("north", 4, 0, "sw", 3, 0, 0, 1)])
	main.hero.teleport(Vector2(-6.6, -7.8))
	await _grab(cam, out, "day_tier3", Vector2(-6.6, -7.8), camera_math, bal)
	focus = Vector2(-3.5, 8.0)  # the south-west lane's marker
	main.hero.teleport(focus)
	await _grab(cam, out, "day_tier3_sw", focus, camera_math, bal)
	# The edge arrows by night: west carries a brute (heavy mark), north none.
	focus = Vector2(-3.8, -7.8)
	main.hero.teleport(focus)
	main.phase_controller.debug_skip_to_night()
	main.world.wave_director.stop()
	_plan(main, [_wave("west", 6, 2, "north", 4, 0, 1, 0)])
	root.get_node("EventBus").wave_incoming.emit(0, &"west", &"north")
	await _grab(cam, out, "night_arrows", focus, camera_math, bal)
	quit(0)

func _plan(main, plan: Array) -> void:
	root.get_node("GameState").lane_plan = plan
	for m in main.world.telegraph_markers.values():
		m.refresh()

func _grab(cam: Camera3D, out: String, name: String, focus := Vector2.INF, camera_math = null, bal = null) -> void:
	if focus != Vector2.INF:  # the one shot with its own framing: the camera moves, then settles
		cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)
	for i in 90:  # the diner's fade settles
		await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
