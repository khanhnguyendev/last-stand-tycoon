extends SceneTree
## E6 Task 10: the lane-character marker. Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_lane_character.gd -- --out=docs/review/media/e6/interface
## Flag on, tier 3. E6 Task 15: the 8 shots marker_<lane>_<siege|hare> for the four entrances (west, north, east, sw) and both characters, each with a
## grayscale copy marker_<lane>_<kind>_gray (the icons must differ by shape, not only colour). The seeds are the first ones (counting up from 1) whose draw
## gives a (character, lane) pair not yet shot; the hero stands at that lane's attack zone by day. Fails unless the lane's badge is shown with the right icon
## and is not hidden by the cover rule. `--extras` adds marker_pair_s4 / marker_pair_s14 (two badges in the north zone), marker_night, marker_home.
## Also icons (the two icons, 4x, side by side) and icons_gray. Every file has a _40 copy (40%).

var _out := "docs/review/media/e6/interface"
const LANES := ["west", "north", "east", "sw"]
var _seen := {}
var _failed := false

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
	var extras := OS.get_cmdline_user_args().has("--extras")
	for s in range(1, 200):
		if _seen.size() == 2 * LANES.size() and not (extras and s <= 14):
			break
		var ch: Dictionary = character.for_run(s)
		var want := []
		for kind in ["siege", "hare"]:
			if not _seen.has("marker_%s_%s" % [ch[kind], kind]):
				want.append(kind)
		if want.is_empty() and not (extras and (s == 3 or s == 4 or s == 7 or s == 14)):
			continue
		bal.reset()
		bal.ui.shake_enabled = false
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
		print("seed ", s, " ", ch)
		for kind in want:
			var name := "marker_%s_%s" % [ch[kind], kind]
			_seen[name] = true
			await _grab(main, cam, camera_math, bal, name, layout.zone_rect(ch[kind]).get_center(), String(ch[kind]), kind)
			if _failed:
				break
			_gray(name)
		if extras and (s == 4 or s == 14):
			await _grab(main, cam, camera_math, bal, "marker_pair_s%d" % s, layout.zone_rect("north").get_center())
		if extras and s == 3:
			main.phase_controller.debug_skip_to_night()
			main.world.wave_director.stop()
			await _grab(main, cam, camera_math, bal, "marker_night", layout.zone_rect(ch.siege).get_center())
		if extras and s == 7:
			await _grab(main, cam, camera_math, bal, "marker_home", layout.HOME)
		cam.free()
		main.free()
		await process_frame
		if _failed:
			quit(1)
			return
	if _seen.size() != 2 * LANES.size():
		printerr("SHOT FAILED: seeds 1 to 199 did not give all 8 (lane, character) pairs; got %s" % str(_seen.keys()))
		quit(1)
		return
	quit(0)

func _save(img: Image, name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate() as Image
	small.resize(int(round(img.get_width() * 0.4)), int(round(img.get_height() * 0.4)), Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)

## `lane` / `kind` ("" = no check): the badge of that lane must show that icon and not be covered when the picture is taken.
func _grab(main, cam: Camera3D, camera_math, bal, name: String, focus: Vector2, lane := "", kind := "") -> void:
	main.hero.teleport(focus)
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(focus), bal.ui)
	await create_timer(3.0).timeout  # the diner's fade and the day banner settle
	if lane != "":
		var badge = main.world.telegraph_markers[lane].badge
		if badge == null or badge.shown_kind() != StringName(kind) or not badge.visible:
			printerr("SHOT FAILED: %s must show the %s badge of the %s lane, but its badge is %s (kind '%s', covered %s)" % [name, kind, lane, "missing" if badge == null else "there", "" if badge == null else String(badge.shown_kind()), "" if badge == null else str(badge.is_covered())])
			_failed = true
			return
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
