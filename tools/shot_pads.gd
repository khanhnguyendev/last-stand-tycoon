extends SceneTree
## The branch pads at phone size (E5 tier 3 Task 17). Run WITH rendering (not --headless):
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_pads.gd -- --out=docs/review/media/e5t3/pads
## A real tier-3 world (the cost entry appended here, tier 3 forced, all nine buildings at level 3). Writes, each 720x1280 plus a
## _40 copy (288x512): pad_<spot_id>.png for every spot (the hero standing on its first pad, the preview showing) and
## pad_<spot_id>_b.png (on its second pad), sw_corner.png (the hero on fence_sw's first pad: tower_sw's and fence_sw's four pads
## all on screen), and refund.png (the other pad's partial payment flying back to the hero).
## The capture camera is placed at its framing when it is created, label_dim_alpha is 1 (no label dimmed under the HUD), and
## every grab waits for the diner's fade to settle.

var _out := ""

func _initialize() -> void:
	_run.call_deferred()

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

func _run() -> void:
	var out := "docs/review/media/e5t3/pads"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_out = out
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var bus = root.get_node("EventBus")
	bal.reset()
	bal.ui.shake_enabled = false
	bal.ui.label_dim_alpha = 1.0
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
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(layout.HOME), bal.ui)  # at its framing from the start
	cam.current = true
	root.add_child(cam)
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)  # the shot forces tier 3
	gs.debug_set_tier(3, 6)
	for i in 30:
		await physics_frame
	# the tier-3 telegraph: a plan with a brute lane, so the rows are where a player sees them
	gs.lane_plan = [_wave("west", 6, 2, "sw", 4, 0, 1, 0), _wave("north", 4, 0, "east", 3, 0, 0, 1)]
	for m in main.world.telegraph_markers.values():
		m.refresh()
	gs.gold = 100000
	for id in layout.spots_for_tier(3):
		while gs.next_level_cost(id) >= 0:
			gs.pay_into_spot(id, 100000)
	gs.gold = 0
	for i in 30:
		await physics_frame
	for id in layout.spots_for_tier(3):
		for i in 2:
			var p: Vector2 = (layout.BRANCH_PADS[id] as Array)[i]
			await _grab(main, cam, camera_math, bal, "pad_%s%s" % [id, "" if i == 0 else "_b"], p)
	await _grab(main, cam, camera_math, bal, "sw_corner", (layout.BRANCH_PADS["fence_sw"] as Array)[0])
	# the four pads of the corner: each on screen from the framing of the shot
	var vr := Rect2(Vector2.ZERO, vp)
	for id in ["tower_sw", "fence_sw"]:
		for p in layout.BRANCH_PADS[id]:
			var s := cam.unproject_position(layout.to3(p))
			print("sw_corner: ", id, " pad ", p, " at ", s, " on screen ", vr.has_point(s))
	# the refund: half the Volley pad on tower_e, then the Longbow pad paid in full with the hero standing on it
	var cost: int = gs.branch_cost("tower_e")
	gs.gold = cost / 2
	gs.pay_into_branch("tower_e", &"volley", cost / 2)
	gs.gold = cost
	var a: Vector2 = (layout.BRANCH_PADS["tower_e"] as Array)[0]
	main.hero.teleport(a)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(a), bal.ui)
	for i in 20:
		await physics_frame
	gs.pay_into_branch("tower_e", &"longbow", cost)  # completes: the Volley pad's gold flies back to the hero
	for i in 14:
		await physics_frame
	await _save(main, cam, camera_math, bal, "refund", a, false)
	quit(0)

func _grab(main, cam: Camera3D, camera_math, bal, name: String, focus: Vector2) -> void:
	main.hero.teleport(focus)
	for i in 30:  # the hero is inside the pad: the preview shows
		await physics_frame
	await _save(main, cam, camera_math, bal, name, focus, true)

func _save(main, cam: Camera3D, camera_math, bal, name: String, focus: Vector2, settle: bool) -> void:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)
	if settle:
		for i in 90:  # the diner's fade settles
			await process_frame
	else:
		for i in 3:
			await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
