extends SceneTree
## The three monster kinds side by side, by day and by night (E5 Task 7, ART_BIBLE R1 to R8). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_monsters.gd -- --out=docs/review/media/e5/task07
## Writes monsters_day.png and monsters_night.png (720x1280) and a _40 copy of each (288x512). Spawns the monsters by hand
## on the north lane, freezes them in a row near the hero and runs no waves.
const KINDS := [&"hare", &"boar", &"boss"]
var _focus := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5/task07"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	bal.reset()
	bal.ui.shake_enabled = false
	var camera_math = load("res://core/camera_math.gd")
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
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	var wd = main.world.wave_director
	wd.stop()
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED  # nothing may hit the monsters: a hit flashes the mesh pale
	# A row on open grass left of the north lane: the hero for scale, then the three kinds, all facing the camera.
	var base: Vector3 = main.hero.global_position + Vector3(-4.2, 0.0, -1.0)
	main.hero.teleport(Vector2(base.x - 3.4, base.z))
	var xs := [-1.6, 0.0, 2.4]
	var mons := []
	for k in KINDS.size():
		var b = wd.debug_spawn("north", 0.0, 1.0, KINDS[k])
		b.set_physics_process(false)
		b.position = base + Vector3(xs[k], 0.0, 0.0)
		b.visual.face(Vector3(0.0, 0.0, 1.0))
		mons.append(b)
	_focus = Vector2(base.x - 0.4, base.z)
	await _grab(main, cam, camera_math, bal, mons, out, "monsters_day")
	main.phase_controller.debug_skip_to_night()
	wd.stop()
	main.hero.set_physics_process(false)
	for b in mons:
		b.set_physics_process(false)
	for i in 120:
		await physics_frame
	await _grab(main, cam, camera_math, bal, mons, out, "monsters_night")
	quit(0)

func _grab(main, cam: Camera3D, camera_math, bal, mons: Array, out: String, name: String) -> void:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(_focus), bal.ui)
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
