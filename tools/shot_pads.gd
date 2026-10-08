extends SceneTree
## The branch pads at phone size (E5 tier 3 Task 17 fix round 1; E6 Task 14, spec 5.3). Run WITH rendering (not --headless):
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_pads.gd -- --out=docs/review/media/e6/interface [--flag=off]
## Seed 1, a real tier-3 world with the retune flag ON (`--flag=off` shows today's world labels instead), every building at level 3. Writes,
## each 720x1280 plus a _40 copy (288x512):
##   pad_<spot_id>_a.png and pad_<spot_id>_b.png (the 18 pads: the hero WALKS onto the pad, so it is armed and the branch card shows; the world
##     keeps the ring, the glyph and the preview shape),
##   near_stage.png (the hero at (6.0, -9.5), not on a pad: ring, glyph and cost on the pads of tower_ne that are in reach, ring and glyph on the other),
##   sw_corner.png (the hero on fence_sw's first pad: tower_sw's and fence_sw's four pads, the close-up sign and the south-west count row),
##   near_fence_sw_a.png / near_fence_sw_b.png (the hero 3 m west of fence_sw's pad a / 3 m east of its pad b, on no pad: the pad in reach shows ring, glyph
##     and cost, the other pad of the spot, out of reach, ring and glyph only),
##   near_tower_nw.png / near_tower_sw.png (the hero off every pad with both pads of the spot in reach: two blocks, shifted off the tower's pips),
##   unarmed.png (the hero PLACED on tower_e's first pad, not walked in: the card stays hidden; ring and glyph only, no cost, no preview),
##   edge_tower_e_a.png (the hero walked onto tower_e's first pad and standing at its north edge, 0.72 m from the centre: the glyph follows him),
##   far_stage.png (the hero at HOME: every pad shows its ring and glyph only), refund.png (the E5 refund flight, unchanged).
## The hero shuffles in place after arriving (a hero standing still would pay into the pad), with a purse that cannot move the bar.

var _out := "docs/review/media/e6/interface"

func _initialize() -> void:
	_run.call_deferred()

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

func _run() -> void:
	var flag_on := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a == "--flag=off":
			flag_on = false
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var camera_math = load("res://core/camera_math.gd")
	var layout = load("res://core/map_layout.gd")
	bal.reset()
	bal.ui.shake_enabled = false
	bal.data.tiers.retune_enabled = flag_on
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)  # the shot forces tier 3
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.focus_pause.free()
	paused = false
	main.phase_controller.start_new_game(1)
	main.hero.input.player_control = false
	for i in 90:
		await physics_frame
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	gs.debug_set_tier(3, 6)
	for i in 30:
		await physics_frame
	# the tier-3 telegraph: a plan with a brute lane, so the count rows are where a player sees them
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
	print("lane character: ", gs.lane_character(), " flag on: ", flag_on)
	var table: Dictionary = layout.branch_pads(flag_on)
	for id in layout.spots_for_tier(3):
		for i in 2:
			await _walk_and_grab(main, camera_math, bal, "pad_%s_%s" % [id, "ab"[i]], table[id][i])
	await _place_and_grab(main, camera_math, bal, "near_stage", Vector2(6.0, -9.5))
	await _walk_and_grab(main, camera_math, bal, "sw_corner", table["fence_sw"][0])
	await _place_and_grab(main, camera_math, bal, "near_fence_sw_a", Vector2(table["fence_sw"][0].x - 3.0, table["fence_sw"][0].y))
	await _place_and_grab(main, camera_math, bal, "near_fence_sw_b", Vector2(table["fence_sw"][1].x + 3.0, table["fence_sw"][1].y))
	await _place_and_grab(main, camera_math, bal, "near_tower_nw", Vector2(-1.6, -6.9))
	await _place_and_grab(main, camera_math, bal, "near_tower_sw", Vector2(-6.5, 1.4))
	await _place_and_grab(main, camera_math, bal, "unarmed", table["tower_e"][0])
	await _walk_and_grab(main, camera_math, bal, "edge_tower_e_a", table["tower_e"][0], Vector2(0.0, -0.72))
	await _place_and_grab(main, camera_math, bal, "far_stage", layout.HOME)
	# the refund: half the Volley pad on tower_e, then the Longbow pad paid in full with the hero standing on it
	var cost: int = gs.branch_cost("tower_e")
	gs.gold = cost / 2
	gs.pay_into_branch("tower_e", &"volley", cost / 2)
	gs.gold = cost
	var a: Vector2 = table["tower_e"][0]
	main.hero.teleport(a)
	for i in 20:
		await physics_frame
	gs.pay_into_branch("tower_e", &"longbow", cost)  # completes: the Volley pad's gold flies back to the hero
	for i in 14:
		await physics_frame
	main.camera_rig.snap_to(camera_math.focus_for(a))
	for i in 3:
		await process_frame
	var img: Image = root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	img.save_png(dir.path_join("refund.png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join("refund_40.png"))
	quit(0)

## Walks onto the pad from two metres south (the zone arms, the card shows), shuffles in place and saves the picture.
func _walk_and_grab(main, camera_math, bal, name: String, p: Vector2, edge := Vector2.ZERO) -> void:
	main.hero.teleport(p + Vector2(0, 2.0))
	for i in 5:
		await physics_frame
	var step: float = main.hero.move_speed() / 60.0
	for i in 600:
		var d: Vector2 = p - main.hero.xz()
		if d.length() < 0.02:
			break
		main.hero.input.set_move((d / step).limit_length(1.0))
		await physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	var gs = root.get_node("GameState")
	gs.gold = 0
	gs.add_gold(340)  # a purse that is plausible but never enough to move the bar: the hero shuffles so the pad takes nothing
	main.camera_rig.snap_to(camera_math.focus_for(p))
	for i in 90:
		main.hero.input.set_move(Vector2(0.3, 0.0) if (i / 6) % 2 == 0 else Vector2(-0.3, 0.0))
		await physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	if edge != Vector2.ZERO:  # stand at the pad's edge (a direct move, not a teleport: the pad stays armed)
		main.hero.global_position = Vector3(p.x + edge.x, main.hero.global_position.y, p.y + edge.y)
		main.camera_rig.snap_to(camera_math.focus_for(p + edge))
		for i in 20:
			await physics_frame
	await _save(main, name)

## Places the hero (a teleport: the pad stays unarmed) and saves the picture.
func _place_and_grab(main, camera_math, bal, name: String, p: Vector2) -> void:
	main.hero.teleport(Vector2(15.0, 8.0))
	for i in 10:
		await physics_frame
	main.hero.teleport(p)
	main.camera_rig.snap_to(camera_math.focus_for(p))
	for i in 40:
		await physics_frame
	await _save(main, name)

func _save(main, name: String) -> void:
	for i in 90:  # the diner's fade settles
		await process_frame
	var card = main.hud.branch_card
	print(name, ": card visible ", card.visible, ", hero at ", main.hero.xz())
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
