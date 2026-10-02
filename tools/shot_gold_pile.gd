extends SceneTree
## A close-up of the gold pile (S4 Task 15 follow-up). Run WITH rendering at 720x1280:
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_gold_pile.gd -- --out=docs/review/media/s4/task15/gold_pile.png
## Fills the pile's multimesh to its cap (visual only, GameState untouched) and frames it low and close.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "docs/review/media/s4/task15/gold_pile.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.phase_controller.start_new_game(20260930)
	for i in 60:
		await physics_frame
	main.phase_controller.debug_skip_to_day()
	for i in 5:
		await physics_frame
	main.camera_rig.set_process(false)
	main.camera_rig.set_physics_process(false)
	main.hud.visible = false
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	var pile = main.world.gold_pile
	# runtime loads: these scripts use the EventBus autoload, which a `-s` script cannot reference at parse time
	load("res://art/pickups/pile.gd").set_count(pile._pile, 30)
	var cam: Camera3D = main.camera_rig.camera
	var target: Vector3 = pile.global_position + Vector3(0, 0.25, 0)
	cam.global_transform = Transform3D(Basis.IDENTITY, target + Vector3(0.6, 1.1, 2.4)).looking_at(target, Vector3.UP)
	cam.fov = 40.0
	for i in 20:
		await process_frame
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("saved ", out, " ", img.get_size())
	quit(0)
