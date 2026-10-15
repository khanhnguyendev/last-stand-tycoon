extends SceneTree
## The Wrecker (E8 phase 2 Task 5). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_wrecker.gd -- --out=docs/review/media/e8/boss
## Writes wrecker_fence.png (the Wrecker at a built north fence, mid-hit) and wrecker_vs_king.png (hero, Boar, brute, Boar King,
## Wrecker in a row), each with a _40 copy (288x512). Monsters are spawned by hand and frozen; no waves run.
var _focus := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e8/boss"
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
	var base: Vector3 = main.hero.global_position + Vector3(-4.2, 0.0, -1.0)
	var mons := []
	# A brute at the north fence: a built fence, the brute at its stop point, a thump frame.
	var gs = root.get_node("GameState")
	gs.add_gold(gs.next_level_cost("fence_n"))
	gs.pay_into_spot("fence_n", gs.next_level_cost("fence_n"))
	for i in 30:
		await physics_frame
	for b in mons:
		b.visible = false
	var br = wd.debug_spawn("north", 0.0, 1.0, &"wrecker")
	br.set_physics_process(false)
	br.dist = br._director.providers.fence_stop_dist(br)  # the game's own stop point (a static, reached through the instance: a -s script cannot name the class)
	br._update_position()
	_focus = Vector2(br.position.x, br.position.z - 0.6)
	main.hero.teleport(Vector2(br.position.x + 3.2, br.position.z + 1.0))
	# one real attack: 60 steps of 1/60 s reach the 1.0 s interval, so the fence is hit and the thump fires on the last one
	for i in 60:
		br._physics_process(1.0 / 60.0)
	mons = [br]
	await _grab(main, cam, camera_math, bal, mons, out, "wrecker_fence", 4)  # a few frames after the thump so the dust is up
	# the Wrecker beside the Boar King, a brute and a Boar (spec: distinct from the King)
	br.visible = false
	br.alive = false
	var kinds := [&"boar", &"brute", &"boss", &"wrecker"]
	var xs2 := [-5.0, -2.9, 0.0, 3.6]
	var cmp := []
	for k in kinds.size():
		var m = wd.debug_spawn("north", 0.0, 1.0, kinds[k])
		m.set_physics_process(false)
		m.position = base + Vector3(xs2[k], 0.0, 0.0)
		m.visual.face(Vector3(0.0, 0.0, 1.0))
		cmp.append(m)
	main.hero.teleport(Vector2(base.x - 7.4, base.z))
	_focus = Vector2(base.x - 0.5, base.z)
	await _grab(main, cam, camera_math, bal, cmp, out, "wrecker_vs_king")
	quit(0)

func _grab(main, cam: Camera3D, camera_math, bal, mons: Array, out: String, name: String, frames := 20) -> void:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(_focus), bal.ui)
	for i in frames:
		await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
