extends SceneTree
## The four branch models in the world (E5 tier 3 Task 18, spec 7, ART_BIBLE R1 to R8). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_branches.gd -- [--out=docs/review/media/e5t3/branches]
## Forces tier 3 (the cost entry is appended in the tool, as the tests do), builds towers and fences to level 3, buys the branches
## and writes, each 720x1280 plus a _40 copy (288x512):
##   fences_l3.png, fences_east_l3.png  the unbranched level-3 reference at the two fence foci (taken first)
##   towers.png        tower_nw (Longbow) in full
##   towers_ne.png     tower_ne (Volley) in full
##   towers_west.png   tower_w (Volley) and tower_sw (Longbow)
##   towers_east.png   tower_e left unbranched (the level-3 reference) beside the Stone east fence
##   fences.png        the west (Stone) and north (Spike) fences, at the game's own zoom
##   fences_east.png   the east (Stone) and south-west (Spike) fences, at the game's own zoom
##   mixed_night.png   night: boars stand at the Stone west fence and the Spike north fence (no towers, hero parked far away)
## Before each shot it waits until the diner's OccluderFade has settled and prints "FADE name alpha=...". The camera follows a focus
## point and is placed at its framing on creation. Exits non-zero when a PNG cannot be saved.
var _main
var _focus := Vector2.ZERO
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5t3/branches"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	bal.reset()
	bal.ui.shake_enabled = false
	bal.ui.label_dim_alpha = 1.0  # the HUD dimmer projects with the game's camera; the tool renders from its own, so labels would be dimmed falsely
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
	_focus = map_layout.HOME
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(_focus), bal.ui)
	var gs = root.get_node("GameState")
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	gs.debug_set_tier(3, 3)
	gs.add_gold(100000)
	# the unbranched level-3 reference first: every spot at level 3, same two fence foci (Stone is closest to the level-3 fence, grey stone too)
	for id in ["tower_nw", "tower_ne", "tower_w", "tower_e", "tower_sw", "fence_w", "fence_n", "fence_e", "fence_sw"]:
		while gs.next_level_cost(id) > 0:
			gs.pay_into_spot(id, gs.next_level_cost(id))
	for i in 30:
		await physics_frame
	main.hero.teleport(Vector2(0.0, 9.5))
	for i in 20:
		await physics_frame
	_focus = Vector2(-4.5, -6.0)
	await _grab(cam, camera_math, bal, out, "fences_l3")
	_focus = Vector2(3.0, 3.0)
	await _grab(cam, camera_math, bal, out, "fences_east_l3")
	var plan := {"tower_nw": &"longbow", "tower_ne": &"volley", "tower_w": &"volley", "tower_e": &"", "tower_sw": &"longbow",
		"fence_w": &"stone", "fence_n": &"spike", "fence_e": &"stone", "fence_sw": &"spike"}
	for id in plan:
		while gs.next_level_cost(id) > 0:
			gs.pay_into_spot(id, gs.next_level_cost(id))
		if plan[id] != &"":
			gs.pay_into_branch(id, plan[id], gs.branch_cost(id))
	for i in 30:
		await physics_frame
	# nobody on the pads, the hero parked behind the camera's reach
	main.hero.teleport(Vector2(0.0, 9.5))
	for i in 20:
		await physics_frame
	_focus = Vector2(-2.5, -5.5)
	await _grab(cam, camera_math, bal, out, "towers")
	_focus = Vector2(2.5, -5.5)
	await _grab(cam, camera_math, bal, out, "towers_ne")
	_focus = Vector2(-8.5, 2.5)
	await _grab(cam, camera_math, bal, out, "towers_west")
	_focus = Vector2(8.0, 1.5)
	await _grab(cam, camera_math, bal, out, "towers_east")
	_focus = Vector2(-4.5, -6.0)
	await _grab(cam, camera_math, bal, out, "fences")
	_focus = Vector2(3.0, 3.0)
	await _grab(cam, camera_math, bal, out, "fences_east")
	# night: two boars stand at each of the west (Stone) and north (Spike) fences, up-lane of the bar, frozen (nothing hits them)
	main.phase_controller.debug_skip_to_night()
	main.world.wave_director.stop()
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	for id in ["tower_nw", "tower_ne", "tower_w", "tower_e", "tower_sw"]:
		main.world.build_spots[id].attacker.enabled = false
		main.world.build_spots[id].set_physics_process(false)
	for lane in ["west", "north"]:
		var path: Array = map_layout.lane_path(lane)
		var geo = load("res://core/geometry.gd")
		var fence: Vector2 = map_layout.fence_spot(lane)
		var t: Vector2 = geo.tangent_at(path, map_layout.path_length(lane) - map_layout.FENCE_OFFSET_FROM_END)
		var side := Vector2(-t.y, t.x)
		for k in 2:
			var b = main.world.wave_director.debug_spawn(lane, 0.0, 1.0, &"boar")
			b.set_physics_process(false)
			var p: Vector2 = fence - t * (0.9 + 0.8 * k) + side * (-0.7 + 1.4 * k)
			b.position = Vector3(p.x, 0.0, p.y)
			b.visual.face(Vector3(t.x, 0.0, t.y))
	for i in 120:
		await physics_frame
	_focus = Vector2(-4.5, -6.0)
	await _grab(cam, camera_math, bal, out, "mixed_night")
	quit(_failed)

func _grab(cam: Camera3D, camera_math, bal, out: String, name: String) -> void:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(_focus), bal.ui)
	var fade = _main.world.occluder_fade
	var waited := 0
	while (absf(fade.current_alpha() - 1.0) > 1e-3 or fade.is_faded()) and waited < 600:
		await physics_frame
		waited += 1
	for i in 20:
		await process_frame
	print("FADE %s alpha=%.3f faded=%s (waited %d frames)" % [name, fade.current_alpha(), fade.is_faded(), waited])
	var img := root.get_texture().get_image()
	if img == null:
		push_error("no frame to grab for " + name)
		_failed = 1
		return
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	_save(img, dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	_save(small, dir.path_join(name + "_40.png"))
	print("saved ", name)

func _save(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("cannot save %s: %d" % [path, err])
		_failed = 1
