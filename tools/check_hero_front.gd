extends SceneTree
## E6 Task 14 round 5 (D-294.8): the RENDER check that the hero is drawn in front of everything a pad draws, and that nothing drawn around him paints over him.
## Run WITH rendering (not --headless), desktop or the web build (see export/README.md and the report):
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/check_hero_front.gd [-- --mutate=over_hero|prepass|tether_over] [--dump=<path prefix>]
## Tier 3, every building at level 3, the hero off every pad (or on one) in views where a pad's glyph, cost or tether meets his body, or where his ring, his
## blob shadow, an FX burst or a pad's ring and disc are on him. Per view, pictures of the same frozen scene:
##   N  none of the extras (pad glyphs and texts, pad rings and discs, the hero's ring, the blob shadows, the FX) shown,
##   D  N with the hero hidden: the hero's silhouette is where N and D differ by more than 60/255, eroded by 2 px (the antialiased edge blends with what is behind it),
##   and one picture per extra shown alone (labels / rings / shadows / FX) and one with all of them shown.
## PASS (per view) = for every one of those pictures, no silhouette pixel differs from N (nothing is drawn over him), and the extras ARE drawn elsewhere (the labels:
## more than 100 pixels, and, except where he stands ON the pad (views 5 and 7), the label box meets the silhouette: a real overlap). Prints PASS or FAIL per view; exit 1 on any FAIL.
## `--mutate=over_hero`: pad labels (fills and outlines), glyphs and the tether at render priority +5 (over the hero): must FAIL. `--mutate=tether_over`: ONLY the tether (light line and ink edge)
## at +5, everything else as built: must FAIL the tethered view (6). `--mutate=prepass`: the hero back in a depth pre-pass material (round 4): on a
## GPU that skips the pre-pass it must FAIL, on one that honours it it passes (that is why the structure is also asserted in tests/unit/test_branch_pads.gd).

## [spot, pad index, hero offset from the pad (m, x / z), or ["cost", extra ground offset (m, x / z)]: his body stands on the pad's real NEAR cost (round 7: the costs moved off the glyph's foot), shifted by the extra offset,
## or "tether" (the middle of the pad's tether line crosses his body) or "walk" (walked onto the pad, so it is armed: the ON stage), steaks carried, what the view shows]
const VIEWS := [
	["tower_e", 0, ["cost", Vector2(0.0, 0.0)], 0, "cost block under the hero"],
	["tower_ne", 1, ["cost", Vector2(0.0, 0.0)], 0, "cost block under the hero"],
	["fence_n", 0, ["cost", Vector2(0.0, 0.0)], 0, "cost block under the hero"],
	["tower_e", 0, ["cost", Vector2(0.0, 0.8)], 8, "the carried pile in front of the cost"],
	["tower_e", 0, Vector2(0.0, 0.0), 0, "the hero on the pad: its ring and disc, his ring, his shadow, FX"],
	["tower_e", 0, "tether", 0, "the one tethered pad: the cost beside the ring with its tether, the hero standing ON the tether line"],
	["tower_e", 0, "walk", 0, "the hero walked onto the pad (armed): its ring and disc, the payment ring (part paid), the preview ring, his ring, his shadow, FX"],
]
const TOLERANCE := 4.0 / 255.0
const SILHOUETTE_TOLERANCE := 60.0 / 255.0

var _saved := {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mutate := ""
	var dump := ""
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dump="):
			dump = a.trim_prefix("--dump=")
		if a.begins_with("--mutate="):
			mutate = a.trim_prefix("--mutate=")
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var layout = load("res://core/map_layout.gd")
	var camera_math = load("res://core/camera_math.gd")
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	bal.reset()
	bal.ui.shake_enabled = false
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.focus_pause.free()
	paused = false
	main.phase_controller.start_new_game(1)
	main.hero.input.player_control = false
	for i in 90:
		await physics_frame
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	gs.debug_set_tier(3, 6)
	for i in 30:
		await physics_frame
	gs.gold = 100000
	for id in layout.spots_for_tier(3):
		while gs.next_level_cost(id) >= 0:
			gs.pay_into_spot(id, 100000)
	gs.gold = 0
	for i in 30:
		await physics_frame
	if mutate == "prepass":
		for mi in main.hero.visual.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var d = mi.get_active_material(s).duplicate()
				d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				d.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
				d.render_priority = -2
				mi.set_surface_override_material(s, d)
	var fails := 0
	var n := 0
	for v in VIEWS:
		n += 1
		if only != "" and str(n) != only:
			continue
		var pad = main.world.branch_pads[v[0]][v[1]]
		var pad_at: Vector2 = layout.branch_pad(v[0], v[1])
		var at: Vector2 = pad_at
		if v[2] is Vector2:
			at = pad_at + v[2]
		elif v[2] is Array:  # his feet on the screen point 0.4 m below the NEAR cost's centre (his body covers it), plus the extra ground offset
			var xf = camera_math.camera_transform(Vector2.ZERO, bal.ui)
			var cl: Vector3 = pad._pos[pad.NEAR][pad.cost_label]
			at = pad_at + Vector2(cl.dot(xf.basis.x), -(cl.dot(xf.basis.y) - 0.4) / sin(deg_to_rad(absf(bal.ui.camera_pitch)))) + v[2][1]
		elif v[2] is String and v[2] == "tether":  # his feet on the screen point of the middle of the tether line: ground north of the pad by (line height on the screen) / sin(pitch)
			if pad.tether_ends.size() != 2:
				printerr("view %d: %s pad %d has no tether" % [n, v[0], v[1]])
				fails += 1
				continue
			var xf = camera_math.camera_transform(Vector2.ZERO, bal.ui)
			var mid: Vector3 = (pad.tether_ends[0] + pad.tether_ends[1]) * 0.5
			# his legs and trunk are above his feet: the line crosses his body 0.4 m (on the screen) above them
			at = pad_at + Vector2(mid.dot(xf.basis.x), -(mid.dot(xf.basis.y) - 0.4) / sin(deg_to_rad(absf(bal.ui.camera_pitch))))
		main.hero.teleport(Vector2(15.0, 8.0))
		for i in 10:
			await physics_frame
		gs.carried_steaks = v[3]
		root.get_node("EventBus").stocks_changed.emit()
		if v[2] is String and v[2] == "walk":  # part paid (the payment ring shows), then walked on with an empty purse so nothing more moves
			gs.gold = 40
			gs.pay_into_branch(v[0], pad.branch_id, 40)
			gs.gold = 0
			main.hero.teleport(pad_at + Vector2(0.0, 2.0))
			for i in 5:
				await physics_frame
			var step: float = main.hero.move_speed() / 60.0
			for i in 600:
				var dd: Vector2 = pad_at - main.hero.xz()
				if dd.length() < 0.02:
					break
				main.hero.input.set_move((dd / step).limit_length(1.0))
				await physics_frame
			main.hero.input.set_move(Vector2.ZERO)
		else:
			main.hero.teleport(at)
		main.camera_rig.snap_to(camera_math.focus_for(at))
		for i in 40:
			await physics_frame
		if v[2] is Array and (pad.stage != 2 or not pad.cost_label.is_visible_in_tree()):  # the view exists for a cost that shows (NEAR) under him
			printerr("view %d: %s pad %d is in stage %d (cost shown %s), not NEAR with its cost" % [n, v[0], v[1], pad.stage, pad.cost_label.is_visible_in_tree()])
			fails += 1
		if v[2] is String and v[2] == "tether" and (pad.stage != 2 or not pad.tether.is_visible_in_tree()):
			printerr("view %d: %s pad %d does not show its tether (stage %d)" % [n, v[0], v[1], pad.stage])
			fails += 1
		if v[2] is String and v[2] == "walk" and pad.stage != 3:
			printerr("view %d: the pad is in stage %d, not ON" % [n, pad.stage])
			fails += 1
		if v[2] is String and v[2] == "walk":  # the extras this view exists for must really be on screen
			var shown: bool = pad.zone.ring.is_visible_in_tree() and pad.preview_rings.size() > 0 and pad.preview_rings[0].is_visible_in_tree()
			print("view %d: payment ring shown %s, preview rings shown %s" % [n, pad.zone.ring.is_visible_in_tree(), pad.preview_rings.size() > 0 and pad.preview_rings[0].is_visible_in_tree()])
			if not shown:
				printerr("view %d: the payment ring or the preview ring is not shown" % n)
				fails += 1
		if mutate == "tether_over":
			for id in main.world.branch_pads:
				for p in main.world.branch_pads[id]:
					if p.tether != null:
						p.tether.material_override.render_priority = 5
						p.tether_ink.material_override.render_priority = 5
		if mutate == "over_hero":
			for id in main.world.branch_pads:
				for p in main.world.branch_pads[id]:
					for l in [p.cost_label, p.name_label, p.effect_label]:
						l.render_priority = 5
						l.outline_render_priority = 5
					p.icon.material_override = p.icon.material_override.duplicate()
					p.icon.material_override.render_priority = 5
					if p.tether != null:
						p.tether.material_override.render_priority = 5
						p.tether_ink.material_override.render_priority = 5
		# FX: a few bursts on his body, then frozen (the field stops processing: the pictures must agree)
		for k in [&"poof", &"sparkle", &"hit"]:
			main.world.fx_field.burst(k, main.hero.global_position + Vector3(0, 0.9, -0.6))  # BEHIND him (north of him, the camera looks north): his body must hide them
		main.world.fx_field.step(0.05)
		main.world.fx_field.set_process(false)
		main.hero.visual.process_mode = Node.PROCESS_MODE_DISABLED  # a frozen pose
		var pics := {}
		_saved.clear()  # the visibility to restore is this view's (a pad's cost and tether show or hide with the stage)
		_extras(main, "none")
		pics["N"] = await _grab()
		main.hero.visible = false
		pics["D"] = await _grab()
		main.hero.visible = true
		for what in ["labels", "rings", "shadows", "fx", "all"]:
			_extras(main, "none")
			_extras(main, what)
			pics[what] = await _grab()
		_extras(main, "all")
		main.world.fx_field.set_process(true)
		main.hero.visual.process_mode = Node.PROCESS_MODE_INHERIT
		if dump != "":
			for k in pics:
				pics[k].save_png("%s_%d_%s.png" % [dump, n, k])
		var cam: Camera3D = main.camera_rig.camera
		var on_pad: bool = v[2] is String and v[2] == "walk" or (v[2] is Vector2 and v[2] == Vector2.ZERO)  # he stands on the pad: only the glyph above his head is a label; no overlap with it is required
		var r := _compare(pics, Vector2i(cam.unproject_position(main.hero.global_position + Vector3(0, 0.9, 0))), not on_pad)
		var line := "view %d %s pad %d, hero asked at %s, stands at %s, %d steaks (%s): silhouette %d px" % [n, v[0], v[1], at, main.hero.xz(), v[3], v[4], r.sil]
		for k in ["labels", "rings", "shadows", "fx", "all"]:
			line += ", %s drawn %d / on him %d" % [k, r.drawn[k], r.changed[k]]
		var ok: bool = r.ok
		line += ", label box meets the silhouette: %s -> %s" % [r.meets, "PASS" if ok else "FAIL"]
		print(line)
		if not ok:
			fails += 1
	print("hero in front: %s" % ("PASS" if fails == 0 else "FAIL (%d views)" % fails))
	quit(0 if fails == 0 else 1)

## Shows ("on") or hides ("off") the extras of `what` ("none" hides all; "all" shows all). Pad rings include the payment ring, the preview rings and the hero's own ring.
func _extras(main, what: String) -> void:
	var set_group := func(group: String, on: bool) -> void:
		for n in _group_nodes(main, group):
			if not on:
				if not _saved.has(n):
					_saved[n] = n.visible
				n.visible = false
			elif _saved.has(n):
				n.visible = _saved[n]
	if what == "none":
		for g in ["labels", "rings", "shadows", "fx"]:
			set_group.call(g, false)
	elif what == "all":
		for g in ["labels", "rings", "shadows", "fx"]:
			set_group.call(g, true)
	else:
		set_group.call(what, true)

func _group_nodes(main, group: String) -> Array:
	var out: Array = []
	match group:
		"labels":
			for id in main.world.branch_pads:
				for p in main.world.branch_pads[id]:
					for n in [p.icon, p.cost_label, p.name_label, p.effect_label, p.warn_label, p.warn_icon, p.tether, p.tether_ink]:
						if n != null:
							out.append(n)
		"rings":
			for id in main.world.branch_pads:
				for p in main.world.branch_pads[id]:
					out.append(p.marker)
					out.append(p.zone.ring)
					out.append_array(p.preview_rings)
			out.append_array(main.hero.find_children("*", "MeshInstance3D", false, false).filter(func(m): return m.get_script() != null and "hero_ring" in String(m.get_script().resource_path)))
		"shadows":
			out.append(main.world.shadow_field)
		"fx":
			out.append(main.world.fx_field)
	return out

func _grab() -> Image:
	for i in 6:
		await process_frame
	return root.get_texture().get_image()

func _erode(set: Dictionary) -> Dictionary:
	var out := {}
	for k in set:
		if set.has(k + Vector2i(1, 0)) and set.has(k - Vector2i(1, 0)) and set.has(k + Vector2i(0, 1)) and set.has(k - Vector2i(0, 1)):
			out[k] = true
	return out

## The 4-connected piece of `set` that contains the pixel nearest `seed_px`.
func _component(set: Dictionary, seed_px: Vector2i) -> Dictionary:
	var start := Vector2i(-1, -1)
	var best := 1000000000
	for k in set:
		var d: int = (k - seed_px).length_squared()
		if d < best:
			best = d
			start = k
	var out := {}
	if start.x < 0:
		return out
	var stack: Array[Vector2i] = [start]
	out[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for n in [c + Vector2i(1, 0), c - Vector2i(1, 0), c + Vector2i(0, 1), c - Vector2i(0, 1)]:
			if set.has(n) and not out.has(n):
				out[n] = true
				stack.append(n)
	return out

func _differs(a: Image, b: Image, x: int, y: int, tol := TOLERANCE) -> bool:
	var ca := a.get_pixel(x, y)
	var cb := b.get_pixel(x, y)
	return absf(ca.r - cb.r) > tol or absf(ca.g - cb.g) > tol or absf(ca.b - cb.b) > tol

func _compare(pics: Dictionary, seed_px: Vector2i, require_meets := true) -> Dictionary:
	var n: Image = pics["N"]
	var w := n.get_width()
	var h := n.get_height()
	var sil := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if _differs(n, pics["D"], x, y, SILHOUETTE_TOLERANCE):
				sil[Vector2i(x, y)] = true
	var eroded := _component(_erode(_erode(sil)), seed_px)  # two pixels in, and only the piece that holds his body (hiding him also changes station labels that react to him)
	var box := Rect2i()
	var first := true
	for k in eroded:
		box = Rect2i(k, Vector2i.ONE) if first else box.expand(k)
		first = false
	var drawn := {}
	var changed := {}
	var lbox := Rect2i()
	var lfirst := true
	var ok := eroded.size() > 200
	for what in ["labels", "rings", "shadows", "fx", "all"]:
		var img: Image = pics[what]
		var d := 0
		var c := 0
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if _differs(img, n, x, y):
					d += 1
					if what == "labels":
						lbox = Rect2i(Vector2i(x, y), Vector2i.ONE) if lfirst else lbox.expand(Vector2i(x, y))
						lfirst = false
					if eroded.has(Vector2i(x, y)):
						c += 1
		drawn[what] = d
		changed[what] = c
		if c != 0:
			ok = false
	var meets := not first and not lfirst and box.intersects(lbox)
	ok = ok and drawn["labels"] > 100 and (meets or not require_meets)
	return {"sil": eroded.size(), "drawn": drawn, "changed": changed, "meets": meets, "ok": ok}
