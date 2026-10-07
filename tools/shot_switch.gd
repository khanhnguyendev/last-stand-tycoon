extends SceneTree
## E5 tier 3 Task 21 (the switch): the tier-2 day from HOME, the front-lot sign "Buy the lot 1500" at its place. Run WITH rendering:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_switch.gd -- --out=docs/review/media/e5t3/switch
## Writes sign_t2.png and sign_t2_40.png (288x512). The shipped build is used as it is: NO cost entry is appended, tier 2 is reached
## through the real path (the tier-1 sign paid, the King's night won by the controller's skips).

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/e5t3/switch"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	bal.reset()
	bal.ui.shake_enabled = false
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
	gs.add_gold(gs.tier_next_cost())
	gs.pay_into_tier(gs.tier_next_cost())
	pc.debug_skip_to_night()
	pc.debug_skip_to_day()
	pc.finish_reveal_now()
	pc.debug_skip_to_day()  # the tier-2 card pick
	main.world.wave_director.stop()
	main.hero.teleport(layout.HOME)
	main.camera_rig.snap()
	main.hud._banner_queue.clear()
	main.hud._banner_left = 0.0
	main.hud._show_next_banner()
	for i in 120:  # the fade settles, the camera rests at HOME
		await process_frame
	print("tier=", gs.tier, " cost=", gs.tier_next_cost(), " sign=", main.world.tier_sign.label.text.replace("\n", " | "))
	await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join("sign_t2.png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join("sign_t2_40.png"))
	print("saved sign_t2")
	quit(0)
