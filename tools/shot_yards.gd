extends SceneTree
## The tier-2 world by day: the yards, the stones and the two tower spots (E5 Task 10). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_yards.gd -- --out=docs/review/media/e5/task10
## Writes yards_home.png, yards_west.png and yards_east.png (720x1280) and a _40 copy of each (288x512). The hero stands
## at HOME, then at the tower_w stand point, then at tower_e's; the camera follows the hero's xz.
## E5 tier 3 Task 2: the shots are named by --prefix= (default "yards"); the growth evidence uses
##   --out=docs/review/media/e5t3/growth --prefix=yards_after   (writes yards_after_west.png, ...).
## Its yards_after.png is a copy of the west view.
var _focus := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5/task10"
	var prefix := "yards"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--prefix="):
			prefix = a.trim_prefix("--prefix=")
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
	var gs = root.get_node("GameState")
	gs.debug_set_tier(2, 3)
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	var graph = load("res://core/waypoint_graph.gd").create_for_tier(2)
	var map_layout = load("res://core/map_layout.gd")
	var spots := {prefix + "_home": map_layout.HOME, prefix + "_west": graph.position_of("tower_w"), prefix + "_east": graph.position_of("tower_e")}
	for name in spots:
		main.hero.teleport(spots[name])
		for i in 20:
			await physics_frame
		_focus = spots[name]
		await _grab(cam, camera_math, bal, out, name)
	quit(0)

func _grab(cam: Camera3D, camera_math, bal, out: String, name: String) -> void:
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
