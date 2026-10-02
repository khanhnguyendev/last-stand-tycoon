extends SceneTree
## The night HUD after one wave clears (S4 Task 15): a lit moon next to unlit ones. Run WITH rendering at 720x1280:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_moons.gd -- --out=docs/review/media/s4/task15/moons.png
## Emits wave_cleared(0) on the EventBus for the HUD only (the sim is not advanced), then saves the top 360 px.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/s4/task15/moons.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.phase_controller.start_new_game(20260930)
	for i in 90:
		await physics_frame
	root.get_node("EventBus").wave_cleared.emit(0)
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	for i in 10:
		await process_frame
	var img := root.get_texture().get_image().get_region(Rect2i(0, 0, 720, 360))
	var path := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("saved ", out)
	quit(0)
