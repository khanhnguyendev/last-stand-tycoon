extends SceneTree
## E5 tier 3 Task 16: the front lot, the tier-3 sign and the east queue. Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_tier3_layout.gd -- --out=docs/review/media/e5t3/layout
## Writes tier2_sign_front_lot.png (tier 2 with the tier-3 cost entry: the sign on the unowned lot, hero at HOME), tier3_day_front.png
## (tier 3 by day from HOME, a few travelers in the east queue) and tier3_day_east_queue.png (hero at the counter), each 720x1280 with a
## _40 copy (288x512), plus tier3_day_front_lot_close.png (hero on the lot beside the SW fence spot). Prints whether the sign and its label are on screen from HOME.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5t3/layout"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	bal.reset()
	bal.ui.shake_enabled = false
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)  # test-only until the switch (Task 21)
	var camera_math = load("res://core/camera_math.gd")
	var layout = load("res://core/map_layout.gd")
	var gs = root.get_node("GameState")
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
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)
	cam.current = true
	root.add_child(cam)
	gs.debug_set_tier(2, 3)
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	main.hero.teleport(layout.HOME)
	for i in 30:
		await physics_frame
	var sp: Vector3 = main.world.tier_sign.global_position
	var top: Vector3 = main.world.tier_sign.label.global_position + Vector3(0, 0.4, 0)
	var xf: Transform3D = camera_math.camera_transform(camera_math.focus_for(layout.HOME), bal.ui)
	var proj: Projection = camera_math.projection(bal.ui)
	print("tier-3 sign at ", sp, " on screen from HOME: ", camera_math.on_screen(sp, xf, proj), ", label top: ", camera_math.on_screen(top, xf, proj))
	await _grab(cam, camera_math, bal, layout.HOME, out, "tier2_sign_front_lot")
	gs.debug_set_tier(3, 4)
	gs.counter_steaks = 0  # nothing is served: the queue fills along the east side
	for i in 60 * 24:
		await physics_frame
	main.hero.teleport(layout.HOME)
	for i in 30:
		await physics_frame
	print("queue: ", main.world.traveler_spawner.queue.size(), " travelers")
	await _grab(cam, camera_math, bal, layout.HOME, out, "tier3_day_front")
	main.hero.teleport(layout.COUNTER_DROP)
	for i in 30:
		await physics_frame
	await _grab(cam, camera_math, bal, layout.COUNTER_DROP, out, "tier3_day_east_queue")
	main.hero.teleport(Vector2(-4.6, 7.9))  # on the lot, beside the SW fence spot: paving, kerb, props and the lane track in frame
	for i in 30:
		await physics_frame
	await _grab(cam, camera_math, bal, Vector2(-4.6, 7.9), out, "tier3_day_front_lot_close")
	quit(0)

func _grab(cam: Camera3D, camera_math, bal, focus: Vector2, out: String, name: String) -> void:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)
	for i in 20:
		await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
