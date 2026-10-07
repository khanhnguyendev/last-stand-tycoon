extends SceneTree
## The tier-2 diner shots (E5 Task 11, E5 slice 2 Task 1). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_diner_t2.gd -- [--out=docs/review/media/e5t3/growth] [--all]
## Writes the growth evidence, each 720x1280 plus a _40 copy (288x512), under --out (default docs/review/media/e5t3/growth):
##   diner_t1.png            the tier-1 diner, the hero at HOME, nobody behind it (opaque)
##   diner_t2_after.png      the tier-2 diner, same framing (opaque)
##   diner_t2_after_north.png  the hero in the north zone behind the diner: the fade is active
## With --all it also writes the slice-1 set: diner_t2_west_day, diner_t2_home_night, diner_t2_west_zone_night (three
## monsters standing in the west attack zone) and diner_t2_west_zone_kill_night (one of the three killed at the wall).
## Before each shot the tool waits until the diner's OccluderFade has settled (alpha 1.0 or the faded alpha) and prints
## "FADE name alpha=... faded=..."; a shot whose fade state is not the expected one (opaque, except _north) fails the run.
## Exits non-zero when a PNG cannot be saved. The camera follows a focus point.
var _main
var _all := false
var _focus := Vector2.ZERO
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5t3/growth"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--all":
			_all = true
	var bal = root.get_node("Balance")
	bal.reset()
	bal.ui.shake_enabled = false
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
	# at the HOME framing at once: a camera left at the origin sits inside the walls box and keeps the diner faded
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(map_layout.HOME), bal.ui)
	var gs = root.get_node("GameState")
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	_focus = map_layout.HOME
	main.hero.teleport(map_layout.HOME)
	for i in 20:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t1")
	gs.debug_set_tier(2, 3)
	for i in 20:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t2_after")
	# E5 slice 2 Task 1: the hero in the north zone, behind the diner: the fade is active (diner_t2_after_north).
	_focus = (map_layout.ZONE_RECTS["north"] as Rect2).get_center()
	main.hero.teleport(_focus)
	for i in 90:
		await physics_frame
	print("fade active: ", main.world.occluder_fade.is_faded())
	await _grab(cam, camera_math, bal, out, "diner_t2_after_north", true)
	if not _all:
		quit(_failed)
		return
	_focus = Vector2(-7.0, 3.0)
	main.hero.teleport(_focus)
	for i in 20:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t2_west_day")
	main.phase_controller.debug_skip_to_night()
	main.world.wave_director.stop()
	_focus = map_layout.HOME
	main.hero.teleport(map_layout.HOME)
	for i in 120:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t2_home_night")
	# Three monsters walk up the west lane and stand at the wall; nothing hits them (the hero is parked far away).
	var mons := []
	for off in [-0.8, 0.0, 0.8]:
		mons.append(main.world.wave_director.debug_spawn("west", off, 1.0, &"boar"))
	main.hero.teleport(Vector2(0.0, 9.0))
	for i in 900:
		await physics_frame
	for b in mons:
		if is_instance_valid(b):
			print("monster at ", b.global_position)
	_focus = Vector2(-5.0, 0.0)
	await _grab(cam, camera_math, bal, out, "diner_t2_west_zone_night")
	# One of them dies at the wall: its steaks and the others' blob shadows must show on the cream terrace.
	main.hero.teleport(Vector2(-7.5, 3.5))
	var dead = mons[1]
	if is_instance_valid(dead):
		dead.take_hit(1e9)
	for i in 30:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t2_west_zone_kill_night")
	quit(_failed)

func _grab(cam: Camera3D, camera_math, bal, out: String, name: String, expect_faded := false) -> void:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(_focus), bal.ui)
	var fade = _main.world.occluder_fade
	var want: float = bal.ui.occluder_alpha if expect_faded else 1.0
	var waited := 0
	# the evidence shots must be exactly settled (is_faded() agrees); the --all slice-1 shots only need the alpha within 1e-3
	# (monsters standing at the west wall graze the fade box and keep alpha a hair under 1.0)
	var strict := name in ["diner_t1", "diner_t2_after", "diner_t2_after_north"]
	while (absf(fade.current_alpha() - want) > 1e-3 or (strict and fade.is_faded() != expect_faded)) and waited < 600:
		await physics_frame
		waited += 1
	for i in 20:
		await process_frame
	print("FADE %s alpha=%.3f faded=%s (waited %d frames)" % [name, fade.current_alpha(), fade.is_faded(), waited])
	if absf(fade.current_alpha() - want) > 1e-3 or (strict and fade.is_faded() != expect_faded):
		push_error("%s: the diner fade is %.3f, expected %.3f" % [name, fade.current_alpha(), want])
		_failed = 1
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
