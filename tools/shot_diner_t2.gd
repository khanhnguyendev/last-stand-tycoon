extends SceneTree
## The tier-2 diner (E5 Task 11). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_diner_t2.gd -- --out=docs/review/media/e5/task11
## Also diner_t2_west_zone_kill_night (one of the three killed at the wall: steaks and shadows on the terrace).
## Exits non-zero when a PNG cannot be saved. Writes diner_t1_home, diner_t2_home_day, diner_t2_west_day, diner_t2_home_night and diner_t2_west_zone_night (three
## monsters standing in the west attack zone), 720x1280 plus a _40 copy of each. The camera follows a focus point.
var _focus := Vector2.ZERO
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5/task11"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	bal.reset()
	bal.ui.shake_enabled = false
	var camera_math = load("res://core/camera_math.gd")
	var map_layout = load("res://core/map_layout.gd")
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
	var gs = root.get_node("GameState")
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	_focus = map_layout.HOME
	main.hero.teleport(map_layout.HOME)
	for i in 20:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t1_home")
	gs.debug_set_tier(2, 3)
	for i in 20:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t2_home_day")
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

func _grab(cam: Camera3D, camera_math, bal, out: String, name: String) -> void:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(_focus), bal.ui)
	for i in 20:
		await process_frame
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
