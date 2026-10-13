extends SceneTree
## E6 Task 12: the third edge arrow. Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_arrows_three.gd -- --out=docs/review/media/e6/interface
## Tier 3 with the retune flag on (E6 Task 15), a night wave with main west, side east (carrying the brutes: the heavy mark) and an extra hare group on sw.
## arrows_three (hero at HOME) and arrows_three_zone (hero in the north zone); each with a _40 copy (40%).

var _out := "docs/review/media/e6/interface"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var bus = root.get_node("EventBus")
	var layout = load("res://core/map_layout.gd")
	bal.reset()
	bal.ui.shake_enabled = false
	bal.data.tiers.retune_enabled = true
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.focus_pause.free()
	paused = false
	main.phase_controller.start_new_game(3)
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
	main.phase_controller.debug_skip_to_night()
	main.world.wave_director.stop()
	var wave := {"main": "west", "side": "east", "main_count": 5, "side_count": 3, "hp_mult": 1.0, "fast_main": 0, "fast_side": 0,
		"boss": false, "brute_main": 0, "brute_side": 2, "extra": [{"lane": "sw", "count": 2, "fast": 2}]}
	gs.lane_plan = [wave, wave.duplicate(true), wave.duplicate(true)]
	for where in [["arrows_three", layout.HOME], ["arrows_three_zone", layout.zone_rect("north").get_center()]]:
		main.hero.teleport(where[1])
		main.camera_rig.snap()
		for i in 20:
			await physics_frame
		bus.wave_incoming.emit(0, &"west", &"east")
		await create_timer(1.0).timeout  # the punch settles
		var h = main.hud
		if not (h.arrows.main.visible and h.arrows.side.visible and h.arrows.extra.visible) or h._arrow_lane.main != "west" or h._arrow_lane.side != "east" or h._arrow_lane.extra != "sw":
			printerr("SHOT FAILED: %s must show three lane arrows (west, east, sw), but the HUD has %s with visible main %s side %s extra %s" % [where[0], str(h._arrow_lane), h.arrows.main.visible, h.arrows.side.visible, h.arrows.extra.visible])
			quit(1)
			return
		_save(root.get_texture().get_image(), where[0])
	quit(0)

func _save(img: Image, name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate() as Image
	small.resize(int(round(img.get_width() * 0.4)), int(round(img.get_height() * 0.4)), Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
