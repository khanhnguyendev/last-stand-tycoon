extends SceneTree
## E6 Task 14 round 4 (D-294.8): the RENDER check that no pad label is drawn over the hero. Run WITH rendering (not --headless):
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/check_hero_front.gd [-- --mutate=over_hero]
## Flag on, tier 3, every building at level 3. For each of three views where the hero's body and a pad's cost block overlap on the screen (the hero stands about 1.2 m
## south of the pad, off every pad: the pad shows its NEAR block), three pictures of the same frozen scene are taken: A as it is, B with every pad glyph and cost hidden,
## D with B and the hero hidden. The hero's silhouette is the set of pixels where B and D differ (eroded by two pixels: the antialiased edge blends with what is behind it); the check passes when A and B are the same on every
## silhouette pixel (no pixel of his body changes when the labels show) while A and B differ elsewhere (the labels are drawn) and the label's box meets the silhouette
## (the view is a real overlap). Exit 0 on pass, 1 on fail. `--mutate=over_hero` draws the cost over the hero (render priority above his): the check must FAIL.

const VIEWS := [["tower_e", 0], ["fence_w", 1], ["fence_n", 0]]
const TOLERANCE := 4.0 / 255.0
## The silhouette is where his body changes the picture by more than his soft blob shadow does (hiding him hides the shadow too).
const SILHOUETTE_TOLERANCE := 60.0 / 255.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mutate := ""
	var dump := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dump="):
			dump = a.trim_prefix("--dump=")
		if a.begins_with("--mutate="):
			mutate = a.trim_prefix("--mutate=")
	var layout = load("res://core/map_layout.gd")
	var camera_math = load("res://core/camera_math.gd")
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	bal.reset()
	bal.ui.shake_enabled = false
	bal.data.tiers.retune_enabled = true
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
	var fails := 0
	for v in VIEWS:
		var pad = main.world.branch_pads[v[0]][v[1]]
		var at: Vector2 = layout.branch_pad(v[0], v[1], true) + Vector2(0.0, 1.2)
		main.hero.teleport(Vector2(15.0, 8.0))
		for i in 10:
			await physics_frame
		main.hero.teleport(at)
		main.camera_rig.snap_to(camera_math.focus_for(at))
		for i in 40:
			await physics_frame
		main.hero.visual.process_mode = Node.PROCESS_MODE_DISABLED  # a frozen pose: the three pictures must agree
		if mutate == "over_hero":
			pad.cost_label.render_priority = 5
			pad.icon.material_override = pad.icon.material_override.duplicate()
			pad.icon.material_override.render_priority = 5
		var a := await _grab()
		_set_labels(main, false)
		var b := await _grab()
		main.hero.visual.visible = false
		var d := await _grab()
		main.hero.visual.visible = true
		_set_labels(main, true)
		main.hero.visual.process_mode = Node.PROCESS_MODE_INHERIT
		if dump != "":
			a.save_png("%s_%s_A.png" % [dump, v[0]])
			b.save_png("%s_%s_B.png" % [dump, v[0]])
			d.save_png("%s_%s_D.png" % [dump, v[0]])
		var r := _compare(a, b, d)
		print("%s pad %d, hero at %s: silhouette %d px, label pixels %d, label pixels on the hero's bounding box %d, label box meets the silhouette: %s, silhouette pixels changed by the label: %d -> %s" % [
			v[0], v[1], at, r.sil, r.label, r.label_on_box, r.meets, r.changed, "PASS" if r.ok else "FAIL"])
		if not r.ok:
			fails += 1
	print("hero in front: %s" % ("PASS" if fails == 0 else "FAIL (%d views)" % fails))
	quit(0 if fails == 0 else 1)

var _saved := {}

## Hides (or restores) every pad glyph and text: the ring stays (it is on the ground, under the hero).
func _set_labels(main, on: bool) -> void:
	for id in main.world.branch_pads:
		for p in main.world.branch_pads[id]:
			for n in [p.icon, p.cost_label, p.name_label, p.effect_label, p.warn_label, p.warn_icon]:
				if n == null:
					continue
				if not on:
					_saved[n] = n.visible
					n.visible = false
				elif _saved.has(n):
					n.visible = _saved[n]

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

func _differs(a: Image, b: Image, x: int, y: int, tol := TOLERANCE) -> bool:
	var ca := a.get_pixel(x, y)
	var cb := b.get_pixel(x, y)
	return absf(ca.r - cb.r) > tol or absf(ca.g - cb.g) > tol or absf(ca.b - cb.b) > tol

func _compare(a: Image, b: Image, d: Image) -> Dictionary:
	var w := a.get_width()
	var h := a.get_height()
	var sil := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if _differs(b, d, x, y, SILHOUETTE_TOLERANCE):
				sil[Vector2i(x, y)] = true
	var eroded := _erode(_erode(sil))  # two pixels in: the antialiased edge of his body blends with whatever lies behind it, by any renderer
	var box := Rect2i()
	var first := true
	for k in eroded:
		box = Rect2i(k, Vector2i.ONE) if first else box.expand(k)
		first = false
	var changed := 0
	var label := 0
	var label_on_box := 0
	var lbox := Rect2i()
	var lfirst := true
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if _differs(a, b, x, y):
				label += 1
				lbox = Rect2i(Vector2i(x, y), Vector2i.ONE) if lfirst else lbox.expand(Vector2i(x, y))
				lfirst = false
				if box.has_point(Vector2i(x, y)):
					label_on_box += 1
				if eroded.has(Vector2i(x, y)):
					changed += 1
	var meets := false
	if not first and not lfirst:
		meets = box.intersects(lbox)
	var ok := eroded.size() > 200 and label > 100 and meets and label_on_box > 20 and changed == 0
	return {"sil": eroded.size(), "label": label, "label_on_box": label_on_box, "meets": meets, "changed": changed, "ok": ok}
