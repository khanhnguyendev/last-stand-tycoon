extends SceneTree
## E6 Task 11 fix: the tier-3 reveal with both lane badges (retune flag on), and each lane-character banner line showing after the card pick. Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_lane_lines.gd -- --out=docs/review/media/e6/reveal
## Writes reveal_badges (after step 3, both badges popped), lane_line_pick (the pick banner), lane_line_siege, lane_line_hare, each with a _40 copy.

var _out := ""
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e6/reveal"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_out = out
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var bus = root.get_node("EventBus")
	bal.reset()
	bal.ui.shake_enabled = false
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)
	var layout = load("res://core/map_layout.gd")
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
	var pc = main.phase_controller
	pc.debug_skip_to_day()
	gs.add_gold(2000)
	gs.pay_into_tier(gs.tier_next_cost())
	pc.debug_skip_to_night()
	pc.debug_skip_to_day()
	pc.finish_reveal_now()
	pc.debug_skip_to_day()
	main.world.wave_director.stop()
	main.hero.teleport(layout.HOME)
	main.camera_rig.snap()
	for i in 90:
		await process_frame
	gs.add_gold(3000)
	gs.pay_into_tier(gs.tier_next_cost())
	pc.debug_skip_to_night()
	main.world.wave_director.stop()
	pc.debug_skip_to_day()  # the tier-3 dawn: the reveal starts
	var t := 0
	while t < int(1.7 * 60.0):  # step 3 (the badges) ran at 1.30 s
		await physics_frame
		t += 1
	_drain_banners(main)  # the setup's own banner would cover the frame
	await process_frame
	var ch: Dictionary = gs.lane_character()
	for k in ["siege", "hare"]:
		var badge = main.world.telegraph_markers[String(ch[k])].badge
		if badge == null or not badge.visible or badge.held or badge.shown_kind() != StringName(k):
			printerr("SHOT FAILED: reveal_badges must show both badges popped, but the %s badge on the %s lane is %s" % [k, ch[k], "missing" if badge == null else "visible %s, held %s, kind '%s'" % [badge.visible, badge.held, badge.shown_kind()]])
			quit(1)
			return
	await _grab(main, "reveal_badges")
	while t < int(3.05 * 60.0):
		await physics_frame
		t += 1
	_drain_banners(main)
	for i in 200:  # the setup's own banners and the reveal's end
		await physics_frame
	_drain_banners(main)
	await physics_frame
	pc.finish_reveal_now()
	bus.card_chosen.emit(gs.card_offer[0])
	await _grab_when(main, "", "lane_line_pick")
	await _grab_when(main, "Heavy", "lane_line_siege")
	await _grab_when(main, "Quick", "lane_line_hare")
	quit(1 if _failed else 0)

func _drain_banners(main) -> void:
	main.hud._banner_queue.clear()
	main.hud._banner_left = 0.0
	main.hud._show_next_banner()

## Grabs the first frame whose banner text starts with `prefix` ("" = any banner showing), after 20 more frames so the slide-in is done.
func _grab_when(main, prefix: String, name: String) -> void:
	if _failed:
		return
	var guard := 0
	while guard < 1200 and not (main.hud.banner.visible and main.hud.banner.text.begins_with(prefix) and (prefix != "" or not main.hud.banner.text.begins_with("Heavy"))):
		await physics_frame
		guard += 1
	if guard >= 1200:
		printerr("SHOT FAILED: %s: no banner starting with '%s' showed within 1200 frames (banner visible %s, text '%s')" % [name, prefix, main.hud.banner.visible, main.hud.banner.text])
		quit(1)
		_failed = true
		return
	for i in 20:
		await process_frame
	print(name, " banner: ", main.hud.banner.text)
	await _grab(main, name)

func _grab(main, name: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
	print("saved ", name)
