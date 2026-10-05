extends SceneTree
## Renders the real game and saves a 720x1280 PNG. Run WITH rendering (no --headless):
## "$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s1/x.png --seconds=12
## --lane=<west|north|east>: hero parked at that lane's zone, one Boar 2 s before it reaches hero range.
## --hero-at=zone_center (with --lane): hero at the centre of that lane's attack zone instead of the lane end.
## --phase=day|night|fail|build|retry (default night; unknown values fail): day = skip to day + 12 s of travelers queueing; build = hero walking into the NW tower spot with the ring filling; fail = diner destroyed (banner); retry = fail, then banner_time + 1 s so the restore runs and the "monsters look tired" banner shows.
## --crop-top=N: save only the top N pixels. --debug: keep the DebugOverlay visible (hidden by default).
## --save=<fixture path>: decode it with SaveCodec.decode and resume_from it instead of start_new_game (no phase staging; waits --seconds, default 12). --drawcalls: print "DRAWCALLS n" once a second while waiting and "DRAWCALLS_MAX n" at the end.
## --steaks=N: bot freed, N steaks lie on the ground 2.5-5 m around the night-1 start (grass and dirt), for the R5 shot.
## --cards=id:level,...: grant cards after start_new_game (Tank placed at its post). --scene=cardpick: no bot, emit wave_cleared so the pick opens (with --wait=<s>: open it after the camera guards and grab <s> s later).
## --fx-offset=x,y,z: offset of the --fx burst from the hero (default 0,0.5,0).
## --fx=<kind>: emit EventBus.fx_requested(kind, hero position + 0.5 up) right before the grab and show it aged --fx-age seconds (default 0.1, stepped by hand) (S5 Task 4).
## --settings=1: open the settings panel right before the grab (S5 Task 8b); the tree is then paused by its pause reason, which is fine for a still.
## --insets=t,r,b,l: safe-area insets for the shot, set through SafeArea.override_for_tests (S5 Task 9). With a landscape --resolution the shot is not 720x1280 (a size warning is printed).
## --arrows=main[,side]: emit wave_incoming with those lanes right before the grab and let the arrow punch settle, so the red lane arrows show (S5 Task 9).
## --guide=<rule id>: the hero parked at the night-1 start, the Guide (Main's own when it built one, else built by hand) and forced to that rule (move|fight|grab|build|collect|take|stock|close) at a fixed target (S5 Task 10).
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
	if _args.has("wait") and _args.get("scene", "") != "cardpick":
		push_error("--wait needs --scene=cardpick")
		quit(2)
		return
	var camera_math = load("res://core/camera_math.gd")
	var map_layout = load("res://core/map_layout.gd")
	var enemy_path = load("res://core/enemy_path.gd")
	_bal = root.get_node("Balance")
	_bal.reset()
	_bal.ui.shake_enabled = false  # a shot must not catch the camera mid-shake (S5 Task 5)
	if _args.has("insets"):
		var iv := String(_args.insets).split(",")
		if iv.size() != 4:
			push_error("bad --insets (want t,r,b,l)")
			quit(2)
			return
		load("res://ui/hud/safe_area.gd").override_for_tests = {"top": float(iv[0]), "right": float(iv[1]), "bottom": float(iv[2]), "left": float(iv[3])}
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	# Main's pause reasons (D-218) pause the tree when this window loses focus (D-147). A capture window is rarely focused, and a paused
	# game still renders and still fires physics_frame, so the shot would show a frozen state. Remove it.
	main.focus_pause.free()
	paused = false
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
	if _args.has("stations"):  # --stations=counter:5,freezer:5 (E1)
		var gs_st = root.get_node("GameState")
		for pair in String(_args.stations).split(",", false):
			var sp := pair.split(":")
			gs_st.debug_set_station_level(StringName(sp[0]), int(sp[1]))
	if _args.get("scene", "") == "cardpick":
		bot.queue_free()
		if not _args.has("wait"):
			_open_cardpick()
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
			await _wait(float(_args.get("day-wait", "12")))
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
	if _args.has("guide"):
		bot.queue_free()
		await physics_frame
		main.hero.input.set_move(Vector2.ZERO)
		main.hero.teleport(map_layout.NIGHT1_START)
		for i in 60:  # the follow camera settles on the hero
			await physics_frame
		var guide = main.guide  # a Main that built its own Guide (boot path) keeps it: never a second one
		if guide == null:
			guide = load("res://ui/guide/guide.gd").new()
			main.add_child(guide)
			guide.setup(main)
		guide.debug_force(StringName(_args.guide))
	if _args.has("stock"):  # --stock=<counter>,<carried>: set right before the grab (E1)
		var sv := String(_args.stock).split(",")
		var gs_sk = root.get_node("GameState")
		gs_sk.counter_steaks = int(sv[0])
		gs_sk.carried_steaks = int(sv[1])
		root.get_node("EventBus").stocks_changed.emit()
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
	var frames_at_cam := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()  # let the diner's occlusion fade (D-151) settle: 3x its fade time
	while Time.get_ticks_msec() - t0 < int(_bal.ui.occluder_fade_s * 1000.0) * 3:
		await process_frame
	# Guard: a grab with the camera not in place gives a ground-level shot from the origin (seen in S4 Task 15).
	var want: Transform3D = camera_math.camera_transform(camera_math.focus_for(main.hero.xz()), _bal.ui)
	if not cam.current or cam.global_position.distance_to(want.origin) > 0.05:
		push_error("capture: camera not in place (current=%s pos=%s want=%s)" % [cam.current, cam.global_position, want.origin])
		quit(1)
		return
	# Guard 2: require 5 frames drawn since the camera was set (10 s wall clock), so the grab is a frame with the camera
	# in place.
	var t1 := Time.get_ticks_msec()
	while Engine.get_frames_drawn() - frames_at_cam < 5 and Time.get_ticks_msec() - t1 < 10000:
		await process_frame
	if Engine.get_frames_drawn() - frames_at_cam < 5:
		push_error("capture: only %d frames drawn since the camera was set (stalled renderer)" % (Engine.get_frames_drawn() - frames_at_cam))
		quit(1)
		return
	# Guard 3: a paused tree means every wait above counted ticks of a frozen game (seen in S4 Task 16b, D-209).
	if paused:
		push_error("capture: the tree is paused; the shot would show a frozen game")
		quit(1)
		return
	if _args.has("wait"):
		# --wait=<s> (cardpick): open the pick only now, then let <s> seconds of game time pass, so the shot catches the
		# entrance motion at a known point (S5 Task 6). Scene timers run on the same clock as tweens.
		_open_cardpick()
		await create_timer(float(_args.wait)).timeout
	if _args.has("settings"):
		main.settings_layer.open()
		for i in 3:
			await process_frame
	if _args.has("arrows"):
		var al := String(_args.arrows).split(",")
		root.get_node("EventBus").wave_incoming.emit(0, StringName(al[0]), StringName(al[1]) if al.size() > 1 else &"")
		await _wait(0.5)
	if _args.has("fx"):
		# The field is stepped by hand so the shot shows exactly 0.1 s of burst whatever the frame rate is.
		var field = main.world.fx_field
		field.set_process(false)
		root.get_node("EventBus").fx_requested.emit(StringName(_args.fx), main.hero.global_position + _fx_offset())
		field.step(float(_args.get("fx-age", "0.1")))
		if field.active_count() == 0:
			push_error("capture: --fx produced no particles")
			quit(1)
			return
		for i in 3:
			await process_frame
	var f0 := Engine.get_frames_drawn()
	var t2 := Time.get_ticks_msec()
	while Engine.get_frames_drawn() == f0 and Time.get_ticks_msec() - t2 < 5000:
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

## --fx-offset=x,y,z: where the --fx burst sits relative to the hero (default 0,0.5,0).
func _fx_offset() -> Vector3:
	var p := String(_args.get("fx-offset", "0,0.5,0")).split(",")
	if p.size() != 3:
		push_error("bad --fx-offset")
		return Vector3(0, 0.5, 0)
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _open_cardpick() -> void:
	var gs2 = root.get_node("GameState")
	root.get_node("EventBus").wave_cleared.emit(gs2.lane_plan.size() - 1)

## Waits `seconds` of physics frames; with --drawcalls, samples the render draw calls once a second.
func _wait(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for i in frames:
		await physics_frame
		if _args.has("drawcalls") and i % 60 == 59:
			var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_dc_max = maxi(_dc_max, dc)
			print("DRAWCALLS %d" % dc)
