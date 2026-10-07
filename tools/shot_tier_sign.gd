extends SceneTree
## The tier sign at phone size (E5 tier 3 Task 3; first written for E5 Task 9). Run WITH rendering (not --headless):
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_tier_sign.gd -- --out=docs/review/media/e5t3/growth --name=sign_after
## Tier 1 on day 2 (the sign sells the yards), the hero standing beside the sign, the camera on the sign. Writes
## <name>.png (hero beside the sign) and <name>_on.png (hero standing on its pad), <name>_north.png (hero 4 m north), each 720x1280 plus a _40 copy (288x512), and prints whether the sign is on screen from HOME.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5t3/growth"
	var shot := "sign_after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--name="):
			shot = a.trim_prefix("--name=")
	var bal = root.get_node("Balance")
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
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)
	cam.current = true
	root.add_child(cam)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(layout.HOME), bal.ui)  # never at the origin (inside the diner's occluder box)
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	main.hero.teleport(layout.HOME)
	for i in 30:
		await physics_frame
	var sp: Vector3 = main.world.tier_sign.global_position
	var scr := cam.unproject_position(sp + Vector3(0, 1.4, 0))
	print("sign from HOME: screen ", scr, " on screen ", Rect2(Vector2.ZERO, vp).has_point(scr) and not cam.is_position_behind(sp))
	main.hero.teleport(layout.TIER_SIGN + Vector2(3.5, 0.0))  # beside it: the sign unobstructed
	for i in 30:
		await physics_frame
	if not await _grab(main, cam, camera_math, bal, layout.TIER_SIGN, out, shot):
		return
	main.hero.teleport(layout.TIER_SIGN)
	for i in 30:
		await physics_frame
	if not await _grab(main, cam, camera_math, bal, layout.TIER_SIGN, out, shot + "_on"):
		return
	main.hero.teleport(layout.TIER_SIGN + Vector2(0.0, -4.0))  # walking north toward the tower_w pad: the label over the ground
	for i in 30:
		await physics_frame
	if not await _grab(main, cam, camera_math, bal, layout.TIER_SIGN + Vector2(0.0, -4.0), out, shot + "_north"):
		return
	quit(0)

func _grab(main, cam: Camera3D, camera_math, bal, focus: Vector2, out: String, name: String) -> bool:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)
	var settled := false
	for i in 600:  # the diner's occluder fade must be fully opaque before the shot
		await physics_frame
		if main.world.occluder_fade.current_alpha() == 1.0 and i >= 20:
			settled = true
			break
	if not settled:
		push_error("occluder fade never settled")
		quit(1)
		return false
	for i in 5:
		await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
	return true
