extends SceneTree
## Renders the real game and saves a 720x1280 PNG. Run WITH rendering (no --headless):
## "$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s1/x.png --seconds=12
## --lane=<west|north|east>: hero parked at that lane's zone, one Boar 2 s before it reaches hero range.
## --hero-at=zone_center (with --lane): hero at the centre of that lane's attack zone instead of the lane end.
## --phase=day|night|fail|build|retry (default night; unknown values fail): day = skip to day + 12 s of travelers queueing; build = hero walking into the NW tower spot with the ring filling; fail = diner destroyed (banner); retry = fail, then banner_time + 1 s so the restore runs and the "monsters look tired" banner shows.
## --crop-top=N: save only the top N pixels. --debug: keep the DebugOverlay visible (hidden by default).
## --save=<fixture path>: decode it with SaveCodec.decode and resume_from it instead of start_new_game (no phase staging; waits --seconds, default 12). --drawcalls: print "DRAWCALLS n" once a second while waiting and "DRAWCALLS_MAX n" at the end.
## --steaks=N: bot freed, N steaks lie on the ground 2.5-5 m around the night-1 start (grass and dirt), for the R5 shot.
## --cards=id:level,...: grant cards after start_new_game (Tank placed at its post). --scene=cardpick: no bot, emit wave_cleared so the pick opens.
## A -s script compiles before the autoloads exist, so nothing here may name an autoload or any
## script that does (Main, bots, Phase...). They are all load()ed at run time and used untyped.

var _args := {}
var _bal: Node
var _dc_max := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_run.call_deferred()

func _run() -> void:
	var camera_math = load("res://core/camera_math.gd")
	var map_layout = load("res://core/map_layout.gd")
	var enemy_path = load("res://core/enemy_path.gd")
	_bal = root.get_node("Balance")
	_bal.reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/parked_bot.gd" if _args.has("lane") else "res://actors/bots/naive_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	if _args.has("save"):
		var codec = load("res://core/save_codec.gd")
		var text := FileAccess.get_file_as_string(String(_args.save))
		var decoded: Dictionary = codec.decode(text, root.get_node("GameState").SCHEMA_VERSION, _bal.data)
		if not decoded.ok:
			push_error("bad --save %s: %s" % [_args.save, decoded.reason])
			quit(2)
			return
		main.phase_controller.resume_from(decoded.state)
	else:
		main.phase_controller.start_new_game(int(_args.get("seed", "20260930")))
	if _args.has("cards"):
		var gs = root.get_node("GameState")
		for pair in String(_args.cards).split(",", false):
			var parts := pair.split(":")
			for i in (int(parts[1]) if parts.size() > 1 else 1):
				gs.debug_grant_card(StringName(parts[0]))
		var tank = main.world.guard_roster.guards.get(&"tank")
		if tank != null:
			tank.place_at_post()
	if _args.get("scene", "") == "cardpick":
		bot.queue_free()
		var gs2 = root.get_node("GameState")
		root.get_node("EventBus").wave_cleared.emit(gs2.lane_plan.size() - 1)
	var phase_arg: String = _args.get("phase", "night")
	if not phase_arg in ["day", "night", "fail", "build", "retry"]:
		push_error("bad --phase %s" % phase_arg)
		quit(2)
		return
	if _args.has("save"):
		await _wait(float(_args.get("seconds", "12")))
	elif phase_arg in ["day", "build"]:
		for i in 60:
			await physics_frame
		main.phase_controller.debug_skip_to_day()
		bot.queue_free()
		for i in 2:  # the bot still thinks once before it is freed and leaves its last move vector set
			await physics_frame
		main.hero.input.set_move(Vector2.ZERO)
		if phase_arg == "day":
			main.hero.teleport(map_layout.HOME)  # outside every zone (D-122); the queue slots are in frame
		if phase_arg == "day":  # let travelers queue (spec 9.6.1)
			await _wait(12.0)
		else:
			for i in 30:
				await physics_frame
	if phase_arg == "build":
		var gs3 = root.get_node("GameState")
		gs3.add_gold(500)
		# teleport() disarms station zones until the hero walks in (D-121), so start outside and walk in.
		var spot: Vector2 = map_layout.TOWER_SPOTS.tower_nw
		main.hero.teleport(spot + Vector2(map_layout.BUILD_RADIUS + 0.8, 0.0))
		for i in 600:
			if main.hero.xz().distance_to(spot) < map_layout.BUILD_RADIUS * 0.7:
				break
			main.hero.input.set_move(Vector2(-1, 0))
			await physics_frame
		main.hero.input.set_move(Vector2.ZERO)
		for i in int((_bal.data.economy.stand_still_time + 0.3) * 60.0):  # ring fills
			await physics_frame
	if phase_arg in ["fail", "retry"]:
		for i in 8 * 60:
			await physics_frame
		root.get_node("GameState").damage_diner(1e9)
		if phase_arg == "fail":
			for i in 36:
				await physics_frame
		else:  # the restore runs after the fail banner; then the mercy banner shows
			for i in int((_bal.ui.banner_time + 1.0) * 60.0):
				await physics_frame
	if _args.has("steaks"):
		bot.queue_free()
		await physics_frame
		main.hero.input.set_move(Vector2.ZERO)
		var spots := [Vector2(-5, -8), Vector2(-4.5, -10.5), Vector2(-1.2, -9.5), Vector2(0.4, -11.5), Vector2(1.4, -8.8),
			Vector2(2.8, -10.5), Vector2(-3.2, -12.5), Vector2(4.5, -9.0)]
		for i in mini(int(_args.steaks), spots.size()):
			var st = main.world.steak_pool.acquire()
			st.place(map_layout.to3(spots[i]))
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null and not _args.has("debug"):
		dbg.visible = false
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, _bal.ui, vp.x / vp.y)  # D-145
	cam.current = true
	root.add_child(cam)
	if _args.has("lane"):
		var lane: String = _args.lane
		if not map_layout.LANE_PATHS.has(lane):
			push_error("bad --lane %s" % lane)
			quit(2)
			return
		main.phase_controller.phase = load("res://core/phase.gd").DAY  # freeze waves for a staged shot
		main.world.wave_director.stop()
		var hero_at: Vector2 = map_layout.lane_end(lane)
		if _args.get("hero-at", "") == "zone_center":
			hero_at = (map_layout.ZONE_RECTS[lane] as Rect2).get_center()
		main.hero.teleport(hero_at)
		bot.queue_free()
		var eb = _bal.data.enemy
		var b = main.world.wave_director.debug_spawn(lane)
		var length: float = map_layout.path_length(lane)
		var d: float = length
		while d > 0.0 and enemy_path.position_at(lane, d, 0.0, eb.offset_fade_distance).distance_to(map_layout.lane_end(lane)) <= _bal.data.hero.attack_range:
			d -= 0.05
		b.dist = maxf(d - eb.speed * 2.0, 0.0)
		b.set_physics_process(false)
		b._update_position()
		if _args.has("seconds"):  # optional settle time (lets the "monsters return" banner clear)
			for i in int(float(_args.seconds) * 60.0):
				await physics_frame
	elif phase_arg == "night" and not _args.has("save"):
		await _wait(float(_args.get("seconds", "12")))
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(main.hero.xz()), _bal.ui)
	var t0 := Time.get_ticks_msec()  # let the diner's occlusion fade (D-151) settle: 3x its fade time
	while Time.get_ticks_msec() - t0 < int(_bal.ui.occluder_fade_s * 1000.0) * 3:
		await process_frame
	var img := root.get_texture().get_image()
	if img.get_size() != Vector2i(720, 1280):
		push_warning("capture size %s" % img.get_size())
	if _args.has("crop-top"):
		img = img.get_region(Rect2i(0, 0, img.get_width(), int(_args["crop-top"])))
	var out: String = _args.get("out", "docs/screenshots/s1/capture.png")
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		push_error("save failed %d" % err)
		quit(1)
		return
	print("saved ", out, " ", img.get_size())
	if _args.has("drawcalls"):
		print("DRAWCALLS_MAX %d" % _dc_max)
	quit(0)

## Waits `seconds` of physics frames; with --drawcalls, samples the render draw calls once a second.
func _wait(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for i in frames:
		await physics_frame
		if _args.has("drawcalls") and i % 60 == 59:
			var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_dc_max = maxi(_dc_max, dc)
			print("DRAWCALLS %d" % dc)
