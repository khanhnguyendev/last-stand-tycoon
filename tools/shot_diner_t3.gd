extends SceneTree
## The tier-3 diner shots (E5 tier-3 Task 19). Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_diner_t3.gd -- [--out=docs/review/media/e5t3/growth] [--only=main|west]
## --only=main (default) writes diner_t3.png (the hero at HOME, nobody behind the diner: opaque), diner_t3_north.png (the hero
## on the north lane behind the diner: the fade is active) and the strip diner_t1_t2_t3.png (the three diners from HOME side by
## side). --only=west writes diner_t3_west.png (the hero in the west yard); run it with --resolution 1280x720 for a 16:9 shot.
## Each shot is written at the window size plus a _40 copy (40% of it). The world is not wired to the tier-3 scene yet (the
## tier table of world/world.gd ends at tier 2), so the tool sets tier 3 through GameState.debug_set_tier and then replaces the
## diner's DinerArt child with art/env/diner_t3.tscn the way World._swap_diner_art does (child 0, OccluderFade.refresh_bounds()).
## Before each shot it waits until the diner's OccluderFade has settled and prints "FADE name alpha=... faded=...";
## a shot whose fade state is not the expected one (opaque, except _north) fails the run. Exits non-zero when a PNG cannot be saved.
const T1 := "res://art/env/diner.tscn"
const T2 := "res://art/env/diner_t2.tscn"
const T3 := "res://art/env/diner_t3.tscn"
var _main
var _focus := Vector2.ZERO
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5t3/growth"
	var only := "main"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
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
	var strip := []
	if only == "main":
		strip.append(await _grab(cam, camera_math, bal, out, "strip_t1"))
		gs.debug_set_tier(2, 3)
		for i in 20:
			await physics_frame
		strip.append(await _grab(cam, camera_math, bal, out, "strip_t2"))
	gs.debug_set_tier(3, 3)
	for i in 20:
		await physics_frame
	_swap(T3)
	for i in 20:
		await physics_frame
	if only == "west":
		_focus = Vector2(-7.0, 3.0)
		main.hero.teleport(_focus)
		for i in 30:
			await physics_frame
		await _grab(cam, camera_math, bal, out, "diner_t3_west")
		quit(_failed)
		return
	strip.append(await _grab(cam, camera_math, bal, out, "diner_t3"))
	_compose(strip, out)
	_focus = (map_layout.ZONE_RECTS["north"] as Rect2).get_center()
	main.hero.teleport(_focus)
	for i in 90:
		await physics_frame
	await _grab(cam, camera_math, bal, out, "diner_t3_north", true)
	quit(_failed)

## Replaces the DinerArt child of the diner's Visual as World._swap_diner_art does.
func _swap(path: String) -> void:
	var vis = _main.world.diner_body.get_node("Visual")
	var art = vis.get_node_or_null("DinerArt")
	if art != null:
		vis.remove_child(art)
		art.queue_free()
	var fresh = load(path).instantiate()
	vis.add_child(fresh)
	vis.move_child(fresh, 0)
	_main.world.occluder_fade.refresh_bounds()

func _grab(cam: Camera3D, camera_math, bal, out: String, name: String, expect_faded := false) -> Image:
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(_focus), bal.ui)
	var fade = _main.world.occluder_fade
	var want: float = bal.ui.occluder_alpha if expect_faded else 1.0
	var waited := 0
	while (absf(fade.current_alpha() - want) > 1e-3 or fade.is_faded() != expect_faded) and waited < 600:
		await physics_frame
		waited += 1
	for i in 20:
		await process_frame
	print("FADE %s alpha=%.3f faded=%s (waited %d frames)" % [name, fade.current_alpha(), fade.is_faded(), waited])
	if absf(fade.current_alpha() - want) > 1e-3 or fade.is_faded() != expect_faded:
		push_error("%s: the diner fade is %.3f, expected %.3f" % [name, fade.current_alpha(), want])
		_failed = 1
	var img := root.get_texture().get_image()
	if img == null:
		push_error("no frame to grab for " + name)
		_failed = 1
		return null
	if not name.begins_with("strip_"):
		_write(img, out, name)
	return img

func _write(img: Image, out: String, name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	_save(img, dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(int(round(img.get_width() * 0.4)), int(round(img.get_height() * 0.4)), Image.INTERPOLATE_LANCZOS)
	_save(small, dir.path_join(name + "_40.png"))
	print("saved ", name)

## The three diners side by side: tier 1, tier 2, tier 3 (each from HOME, opaque).
func _compose(shots: Array, out: String) -> void:
	for s in shots:
		if s == null:
			_failed = 1
			return
	var w: int = shots[0].get_width()
	var h: int = shots[0].get_height()
	var strip := Image.create(w * shots.size(), h, false, shots[0].get_format())
	for i in shots.size():
		strip.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	_write(strip, out, "diner_t1_t2_t3")

func _save(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("cannot save %s: %d" % [path, err])
		_failed = 1
