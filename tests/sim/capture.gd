extends SceneTree
## Renders the real game and saves a 720x1280 PNG. Run WITH rendering (no --headless):
## "$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s1/x.png --seconds=12
## --lane=<west|north|east>: hero parked at that lane's zone, one Boar 2 s before it reaches hero range.
## A -s script compiles before the autoloads exist, so nothing here may name an autoload or any
## script that does (Main, bots, Phase...). They are all load()ed at run time and used untyped.

var _args := {}
var _bal: Node

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_run.call_deferred()

func _run() -> void:
	var camera_math = load("res://core/camera_math.gd")
	var map_layout = load("res://core/map_layout.gd")
	var enemy_path = load("res://core/enemy_path.gd")
	_bal = root.get_node("Balance")
	_bal.reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/parked_bot.gd" if _args.has("lane") else "res://actors/bots/naive_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(int(_args.get("seed", "20260930")))
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, _bal.ui, vp.x / vp.y)  # D-145
	cam.current = true
	root.add_child(cam)
	if _args.has("lane"):
		var lane: String = _args.lane
		if not map_layout.LANE_PATHS.has(lane):
			push_error("bad --lane %s" % lane)
			quit(2)
			return
		main.phase_controller.phase = load("res://core/phase.gd").DAY  # freeze waves for a staged shot
		main.world.wave_director.stop()
		main.hero.teleport(map_layout.lane_end(lane))
		bot.queue_free()
		var eb = _bal.data.enemy
		var b = main.world.wave_director.debug_spawn(lane)
		var length: float = map_layout.path_length(lane)
		var d: float = length
		while d > 0.0 and enemy_path.position_at(lane, d, 0.0, eb.offset_fade_distance).distance_to(map_layout.lane_end(lane)) <= _bal.data.hero.attack_range:
			d -= 0.05
		b.dist = maxf(d - eb.speed * 2.0, 0.0)
		b.set_physics_process(false)
		b._update_position()
	else:
		for i in int(float(_args.get("seconds", "12")) * 60.0):
			await physics_frame
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(main.hero.xz()), _bal.ui)
	for i in 3:
		await process_frame
	var img := root.get_texture().get_image()
	if img.get_size() != Vector2i(720, 1280):
		push_warning("capture size %s" % img.get_size())
	var out: String = _args.get("out", "docs/screenshots/s1/capture.png")
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		push_error("save failed %d" % err)
		quit(1)
		return
	print("saved ", out, " ", img.get_size())
	quit(0)
