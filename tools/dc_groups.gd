extends SceneTree
## E6 A3 (D-294): attributes the night's draw calls to groups of nodes. Run WITH rendering (no --headless):
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/dc_groups.gd -- --save=export/fixtures/tier3_cap_threat.save.json --hero=0,9.5
## --save=<fixture>   resumed with resume_from (a NIGHT fixture enters the night at once; a DAY fixture needs --closeup)
## --closeup          emits closeup_requested (the night is then entered as in play)
## --hero=x,y         teleports the hero there and snaps the camera to its focus (default: where the save puts him)
## --retune          sets Balance.data.tiers.retune_enabled = true before the game is created (the ?retune=1 equivalent; no schema change needed)
## --forcefade       replaces the diner fade's targets by a point just north of the diner, so the camera at HOME sees it hidden and the dithered fade is active for the sample
## --only             prints the whole-scene count only (no group table)
## --wait=<s>         seconds of physics frames before measuring (default 20); use --fixed-fps 60 so a process frame is one physics tick and runs agree
## --list=1           also hides every child of every top-level node, one at a time (a long table)
## Prints "DC <label> <draw calls> (<delta against the whole scene>)" for the whole scene, then one line per group hidden alone, restored after.
## A group is a node (visible = false) or a node type (every Label3D, Sprite3D, MeshInstance3D, particles... under the game and the HUD).
var _args := {}
var _main

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_run.call_deferred()

func _dc() -> int:
	var sum := 0
	for i in 20:
		await process_frame
		sum += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return int(round(sum / 20.0))

func _run() -> void:
	var bal = root.get_node("Balance")
	bal.reset()
	bal.ui.shake_enabled = false
	if _args.has("retune"):
		bal.data.tiers.retune_enabled = true
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	_main = main
	main.focus_pause.free()
	paused = false
	var codec = load("res://core/save_codec.gd")
	var gs = root.get_node("GameState")
	var decoded: Dictionary = codec.decode(FileAccess.get_file_as_string(String(_args.save)), gs.SCHEMA_VERSION, bal.data)
	if not decoded.ok:
		push_error("bad save: %s" % decoded.reason)
		quit(2)
		return
	main.phase_controller.resume_from(decoded.state)
	if _args.has("closeup"):
		for i in 480:
			await physics_frame
		root.get_node("EventBus").closeup_requested.emit()
	for i in int(float(_args.get("wait", "20")) * 60.0):
		await physics_frame
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	if _args.has("hero"):
		var p := String(_args.hero).split(",")
		var v := Vector2(float(p[0]), float(p[1]))
		main.hero.teleport(v)
		main.camera_rig.snap_to(load("res://core/camera_math.gd").focus_for(v))
		for i in 60:
			await physics_frame
	if _args.has("forcefade"):
		main.world.occluder_fade._targets = func(): return [Vector3(0.0, 1.0, -4.0)]
		for i in 90:
			await physics_frame
	var h = main.hero.global_position
	print("HERO %.1f %.1f phase=%s nodes=%d faded=%s" % [h.x, h.z, str(main.phase_controller.phase), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), str(main.world.occluder_fade.is_faded())])
	var base: int = await _dc()
	print("DC whole_scene %d" % base)
	if _args.has("only"):
		quit(0)
		return
	if _args.has("dump"):
		var cam: Camera3D = root.get_viewport().get_camera_3d()
		for n in main.find_children("*", "Label3D", true, false):
			var l := n as Label3D
			if l.is_visible_in_tree():
				print("L3D %s text=%s onscreen=%s alpha=%.2f" % [main.get_path_to(l), l.text.replace("\n", "|"), str(cam.is_position_in_frustum(l.global_position)), l.modulate.a])
		var per := {}
		for n in main.find_children("*", "MeshInstance3D", true, false):
			var m := n as MeshInstance3D
			if m.is_visible_in_tree() and m.layers != 0 and cam.is_position_in_frustum(m.global_position):
				var k := String(main.get_path_to(m)).get_slice("/", 1)
				per[k] = int(per.get(k, 0)) + m.mesh.get_surface_count()
		print("MESH_SURFACES_IN_FRUSTUM_BY_TOPNODE %s" % str(per))
		for top in ["Spot_tower_nw", "Spot_fence_n", "Pad_counter", "Pad_freezer", "GoldPile", "CounterBody", "Props", "Diner", "GuardRoster"]:
			var t = main.world.get_node_or_null(top)
			if t == null:
				continue
			for n in t.find_children("*", "MeshInstance3D", true, false):
				var m := n as MeshInstance3D
				if m.is_visible_in_tree() and cam.is_position_in_frustum(m.global_position):
					var mat := m.get_active_material(0)
					print("MESH %s surf=%d mat=%s" % [main.get_path_to(m), m.mesh.get_surface_count(), mat.resource_name if mat else "none"])
	var groups: Array = []  # [label, Array of nodes]
	for t in ["Label3D", "Sprite3D", "MeshInstance3D", "MultiMeshInstance3D", "GPUParticles3D", "CPUParticles3D", "Sprite2D", "Label", "TextureRect", "ColorRect", "Control"]:
		var nodes: Array = []
		for n in main.find_children("*", t, true, false):
			if n is CanvasItem and not (n as CanvasItem).visible:
				continue
			if n is Node3D and not (n as Node3D).visible:
				continue
			nodes.append(n)
		groups.append(["type:" + t, nodes])
	var pips: Array = []
	for n in main.find_children("LevelPipsBatch", "MultiMeshInstance3D", true, false):
		if (n as Node3D).is_visible_in_tree():
			pips.append(n)
	groups.append(["name:Pip* (level pips)", pips])
	for top in main.get_children():
		groups.append(["node:" + top.name, [top]])
		if _args.has("list") or top.name == "World" or top.name == "Hud":
			for c in top.get_children():
				groups.append(["node:" + top.name + "/" + c.name, [c]])
	for g in groups:
		var arr: Array = g[1]
		var was: Array = []
		for n in arr:
			was.append(n.visible if "visible" in n else null)
			if "visible" in n:
				n.visible = false
		var vis_before := 0
		var dc: int = await _dc()
		for i in arr.size():
			if was[i] != null:
				arr[i].visible = was[i]
		if dc != base:
			print("DC %s n=%d %d (%+d)" % [g[0], arr.size(), dc, dc - base])
	print("DC_DONE")
	quit(0)
