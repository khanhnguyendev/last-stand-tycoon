extends SceneTree
## E6 Task 10: the lane-character marker. Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_lane_character.gd -- --out=docs/review/media/e6/interface
## Flag on, tier 3. For seeds 1, 3, 4, 7 (siege east, sw, west, north) the hero stands at the siege lane's attack zone by day
## (marker_<lane>_siege) and at the hare lane's zone (marker_<lane>_hare; a second seed on the same hare lane gets _s<seed>).
## Also marker_night (seed 3, sw zone, night), marker_home (seed 7, from HOME), icons (the two icons, 4x, side by side), and
## grayscale copies (_gray) of the icon sheet and of one marker shot. Every file has a _40 copy (40%).

var _out := "docs/review/media/e6/interface"
const SEEDS := [1, 3, 4, 7]
var _seen := {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var camera_math = load("res://core/camera_math.gd")
	var layout = load("res://core/map_layout.gd")
	var character = load("res://core/lane_character.gd")
	_icon_sheet()
	for s in SEEDS:
		bal.reset()
		bal.ui.shake_enabled = false
		bal.data.tiers.retune_enabled = true
		if bal.data.tiers.tier_costs.size() < 3:
			bal.data.tiers.tier_costs.append(1500)
		var main = load("res://world/main.gd").create()
		root.add_child(main)
		main.focus_pause.free()
		paused = false
		main.phase_controller.start_new_game(s)
		main.hero.input.player_control = false
		var dbg = main.get_node_or_null("DebugOverlay")
		if dbg != null:
			dbg.visible = false
		for i in 30:
			await physics_frame
		main.phase_controller.debug_skip_to_day()
		gs.debug_set_tier(3, 5)
		for i in 60:
			await physics_frame
		main.world.wave_director.stop()
		var cam := Camera3D.new()
		var vp := root.get_visible_rect().size
		camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)
		cam.global_transform = camera_math.camera_transform(camera_math.focus_for(layout.HOME), bal.ui)
		cam.current = true
		root.add_child(cam)
		var ch: Dictionary = character.for_run(s)
		print("seed ", s, " ", ch)
		await _grab(main, cam, camera_math, bal, "marker_%s_siege" % ch.siege, layout.zone_rect(ch.siege).get_center())
		var hare_name := "marker_%s_hare" % ch.hare
		if _seen.has(hare_name):
			hare_name += "_s%d" % s
		_seen[hare_name] = true
		await _grab(main, cam, camera_math, bal, hare_name, layout.zone_rect(ch.hare).get_center())
		if s == 3:
			main.phase_controller.debug_skip_to_night()
			main.world.wave_director.stop()
			await _grab(main, cam, camera_math, bal, "marker_night", layout.zone_rect(ch.siege).get_center())
		if s == 7:
			await _grab(main, cam, camera_math, bal, "marker_home", layout.HOME)
		cam.free()
		main.free()
		await process_frame
	_gray("marker_east_siege")
	quit(0)

func _save(img: Image, name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate() as Image
	small.resize(int(round(img.get_width() * 0.4)), int(round(img.get_height() * 0.4)), Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)

func _grab(main, cam: Camera3D, camera_math, bal, name: String, focus: Vector2) -> void:
	main.hero.teleport(focus)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)
	await create_timer(3.0).timeout  # the diner's fade and the day banner settle
	_save(root.get_texture().get_image(), name)

## The two icons at 4 x their 64 px size on a mid-grey ground, side by side; and the grayscale copy.
func _icon_sheet() -> void:
	var icons = load("res://art/icons/lane_character_icons.gd")
	var sheet := Image.create(2 * 256 + 3 * 32, 256 + 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.5, 0.5, 1))
	var x := 32
	for kind in [&"siege", &"hare"]:
		var img: Image = icons.image(kind, 64)
		img.resize(256, 256, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 256, 256), Vector2i(x, 32))
		x += 256 + 32
	_save(sheet, "icons")
	_save(_to_gray(sheet), "icons_gray")

func _to_gray(img: Image) -> Image:
	var g := img.duplicate() as Image
	g.convert(Image.FORMAT_L8)
	g.convert(Image.FORMAT_RGBA8)
	return g

func _gray(name: String) -> void:
	var path := ProjectSettings.globalize_path("res://").path_join(_out).path_join(name + ".png")
	if FileAccess.file_exists(path):
		_save(_to_gray(Image.load_from_file(path)), name + "_gray")
