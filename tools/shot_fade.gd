extends SceneTree
## E6 A2 (D-294): the diner's occluder fade, shot at tier 1, 2 and 3. Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_fade.gd -- --out=docs/review/media/e6/perf/fade/after
## Per tier: <name>_day_t<N> (the hero in the north zone behind the diner, by day) and <name>_night_t<N> (three boars in the north zone
## behind it at night, the hero at HOME). Each at the window size plus a _40 copy (40%). Prints "FADE <shot> alpha=... faded=...".
var _main
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e6/perf/fade/after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	bal.reset()
	bal.ui.shake_enabled = false
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)
	var camera_math = load("res://core/camera_math.gd")
	var map_layout = load("res://core/map_layout.gd")
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	_main = main
	main.focus_pause.free()
	paused = false
	main.phase_controller.start_new_game(20260930)
	main.hero.input.player_control = false
	for i in 90:
		await physics_frame
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)
	cam.current = true
	root.add_child(cam)
	var gs = root.get_node("GameState")
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	var north: Vector2 = (map_layout.ZONE_RECTS["north"] as Rect2).get_center()
	for tier in [1, 2, 3]:
		if tier > 1:
			gs.debug_set_tier(tier, 3)
			for i in 20:
				await physics_frame
			_swap(main.world.diner_scene_for(tier).resource_path)
		# day: the hero behind the diner
		main.hero.teleport(north)
		for i in 90:
			await physics_frame
		cam.global_transform = camera_math.camera_transform(camera_math.focus_for(north), bal.ui)
		await _grab(out, "day_t%d" % tier)
		# night: boars behind it, the hero at home
		main.hero.teleport(map_layout.HOME)
		main.phase_controller.debug_skip_to_night()
		for i in 10:
			await physics_frame
		for k in 3:
			var b = main.world.wave_director._spawn("north", float(k - 1) * 0.6)
			b.dist = b.path_length() - 2.4 - float(k) * 1.4  # just north of the diner, still on the lane
			b._update_position(false)
			b.set_physics_process(false)  # held there for the shot
		cam.global_transform = camera_math.camera_transform(camera_math.focus_for(map_layout.HOME), bal.ui)
		for i in 80:
			await physics_frame
		await _grab(out, "night_t%d" % tier)
		main.world.wave_director.stop()
		main.phase_controller.debug_skip_to_day()
		for i in 40:
			await physics_frame
		main.world.wave_director.stop()
	quit(_failed)

func _swap(path: String) -> void:
	var vis = _main.world.diner_body.get_node("Visual")
	var art = vis.get_node_or_null("DinerArt")
	if art != null:
		vis.remove_child(art)
		art.queue_free()
	var fresh = load(path).instantiate()
	vis.add_child(fresh)
	vis.move_child(fresh, 0)
	_main.world.occluder_fade.refresh_bounds()

func _grab(out: String, name: String) -> void:
	var fade = _main.world.occluder_fade
	var waited := 0
	while fade.current_alpha() > root.get_node("Balance").ui.occluder_alpha + 1e-3 and waited < 400:
		await physics_frame
		waited += 1
	for i in 20:
		await process_frame
	print("FADE %s alpha=%.3f faded=%s (waited %d)" % [name, fade.current_alpha(), fade.is_faded(), waited])
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	if img.save_png(dir.path_join(name + ".png")) != OK:
		_failed = 1
	var small := img.duplicate()
	small.resize(int(round(img.get_width() * 0.4)), int(round(img.get_height() * 0.4)), Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
