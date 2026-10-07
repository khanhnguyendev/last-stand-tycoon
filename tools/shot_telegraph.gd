extends SceneTree
## The day telegraph rows (E5 tier 3 Task 14). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_telegraph.gd -- --out=docs/review/media/e5t3/telegraph
## Writes day_tier2 (Boars and hares on two lanes), day_tier2_boss (the tier paid: the boss icon on its lane), day_tier3 (tier 3
## forced, the cost entry appended, a brute lane), day_tier3_sw (the south-west lane's row), day_tier3_home (the widest rows from
## HOME) and night_arrows (a plain main arrow beside a heavy side arrow), each with a _40 copy (288x512).
## The capture camera is placed at its framing when it is created, and every grab waits for the diner's fade to settle.

var _out := ""

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
	_out = out
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
	var home: Vector2 = layout.HOME
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(home), bal.ui)  # at its framing from the start
	cam.current = true
	root.add_child(cam)
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	# Tier 1, tier 2 paid in full: tonight is a boss night, and the boss icon is on the last wave's main lane (north).
	_plan(main, [_wave("west", 7, 3, "east", 4, 0), _wave("west", 5, 1, "", 0, 0), _wave("north", 0, 0, "", 0, 0)])
	gs.add_gold(2000)
	gs.pay_into_tier(500)
	_plan(main, gs.lane_plan)
	await _grab(main, cam, camera_math, bal, "day_tier2_boss", Vector2(0.0, -3.0))
	gs.debug_set_tier(2, 5)
	_plan(main, [_wave("west", 7, 3, "north", 4, 0), _wave("west", 5, 1, "", 0, 0)])
	await _grab(main, cam, camera_math, bal, "day_tier2", home)
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)  # the shot forces tier 3
	gs.debug_set_tier(3, 6)
	for i in 30:
		await physics_frame
	_plan(main, [_wave("west", 6, 2, "sw", 4, 0, 1, 0), _wave("north", 4, 0, "east", 3, 0, 0, 1)])
	await _grab(main, cam, camera_math, bal, "day_tier3", Vector2(-5.0, -2.0))
	await _grab(main, cam, camera_math, bal, "day_tier3_sw", Vector2(-3.5, 9.0))
	# the widest rows: three pairs on every lane and the boss on the east lane, from HOME
	var w1 := _wave("west", 6, 2, "east", 5, 1, 1, 1)
	var w2 := _wave("north", 6, 2, "sw", 5, 1, 1, 1)
	var w3 := _wave("east", 6, 2, "north", 5, 1, 1, 1)
	w3.boss = true
	_plan(main, [w1, w2, w3])
	await _grab(main, cam, camera_math, bal, "day_tier3_home", home)
	# the edge arrows by night: the main arrow (north) plain, the side arrow (west) heavy
	main.phase_controller.debug_skip_to_night()
	main.world.wave_director.stop()
	_plan(main, [_wave("north", 6, 2, "west", 4, 0, 0, 1)])
	root.get_node("EventBus").wave_incoming.emit(0, &"north", &"west")
	await _grab(main, cam, camera_math, bal, "night_arrows", Vector2(-3.8, -7.8))
	quit(0)

func _plan(main, plan: Array) -> void:
	root.get_node("GameState").lane_plan = plan
	for m in main.world.telegraph_markers.values():
		m.refresh()

func _grab(main, cam: Camera3D, camera_math, bal, name: String, focus: Vector2) -> void:
	main.hero.teleport(focus)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)
	for i in 90:  # the diner's fade settles
		await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
	if name == "day_tier3_home":  # the vertex colours against the palette: the Boar head's face pixel on the sw row
		var mk = main.world.telegraph_markers["sw"]
		var ic: Node3D = mk.items[&"boar"].icon
		for probe in [[Vector3(0.0, -0.1, 0.0), "snout (enemy_snout c97a6a)"], [Vector3(0.0, 0.3, 0.0), "face (enemy_red c8402f)"]]:
			var p := cam.unproject_position(ic.global_position + probe[0] * ic.scale.x)
			print("boar ", probe[1], ": pixel at ", p, " = ", img.get_pixel(int(p.x), int(p.y)).to_html(false))
