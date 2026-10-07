extends GutTest
## E5 tier 3 Task 16 (spec 4.1, 4.2, 5; D-261 constraints 3 and 4, D-266.3, D-271): the front lot, the tier sign per tier, and the
## service layout (queue, exit) that moves east at tier 3, switched only when no traveler exists.

const BAR_HALF_DEPTH := 0.5  ## the fence bar's half depth (test_yards.FENCE_BAR_HALF_WIDTH)
const TRAVELER_RADIUS := 0.3  ## a traveler's body (test_branch_pad_layout.TRAVELER_RADIUS)
## The tier-2 kerb (west and east yards) and the default pad list, captured BEFORE Task 16 (27 pieces, 11 points).
const TIER2_KERB_HASH := 1885942610
const TIER2_PADS_HASH := 620547222
## The tier-2 terrain mesh (vertices, colours, indices), captured with the plot code in place but unused below tier 3.
const TIER2_TERRAIN_HASHES := [156478229, 1564565559, 664459956]

var main: Main
var _sold := 0
var _tier_changes: Array = []
var _grew := 0

## `with_cost`: the build knows tier 3 (the shipped build does; false makes a two-tier build). It must be set before Main.create (pools, top tier).
func _make(with_cost := true) -> void:
	Balance.reset()
	if with_cost and Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	elif not with_cost:
		Balance.data.tiers.tier_costs = [0, 500]  # setup: a two-tier build (the shipped build has three)
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(20260930)
	await get_tree().physics_frame
	main.hero.teleport(Vector2(15, 8))  # away from every zone

func after_each() -> void:
	if EventBus.steak_sold.is_connected(_on_sold):
		EventBus.steak_sold.disconnect(_on_sold)
	if EventBus.tier_changed.is_connected(_on_tier_changed):
		EventBus.tier_changed.disconnect(_on_tier_changed)
	Balance.reset()
	GameState.new_game(1)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _day_at(tier: int) -> void:
	if tier > 1:
		GameState.debug_set_tier(tier, GameState.day)
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame

func _on_pool_grew(_size: int) -> void:
	_grew += 1

func _on_sold(_count: int, _gold: int) -> void:
	_sold += 1

func _on_tier_changed(tier: int, _paid: int, _boss: bool) -> void:
	var sp := main.world.traveler_spawner
	_tier_changes.append({"tier": tier, "live": sp.live_count(), "active": sp.pool.active().size(), "phase": main.phase_controller.phase})

# --- the tier sign ---------------------------------------------------------

func test_the_sign_stands_where_the_next_tier_is_sold() -> void:
	await _make()
	var sign := main.world.tier_sign
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.tier_sign(2))), "tier 1 sells tier 2 in the west yard")
	GameState.debug_set_tier(2, 3)
	assert_eq(sign.state(), &"selling")
	assert_true(sign.visible)
	assert_true(sign.position.is_equal_approx(MapLayout.to3(Vector2(-4.7, 8.5))), "tier 2 sells tier 3 on the front lot")
	GameState.debug_set_tier(3, 4)
	assert_eq(sign.state(), &"hidden", "tier 3 is the top")
	GameState.new_game(7)
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.tier_sign(2))), "a new game puts it back in the west yard")
	assert_eq(sign.state(), &"selling")

func test_without_the_cost_entry_no_sign_sells_tier_3() -> void:
	await _make(false)
	GameState.debug_set_tier(2, 3)
	var sign := main.world.tier_sign
	assert_eq(GameState.tier_next_cost(), -1)
	assert_eq(sign.state(), &"hidden")
	assert_false(sign.visible)
	assert_eq(sign.label.text, "")
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.tier_sign(2))), "a hidden sign waits at the tier-2 sign's place, not on the unsold lot")

func test_the_tier_3_sign_takes_payment_at_its_own_position() -> void:
	await _make()
	GameState.debug_set_tier(2, 3)
	await _day_at(2)
	GameState.add_gold(1500)
	await TestHelpers.walk_in(main.hero, MapLayout.tier_sign(3))
	var ticks := 0
	while not GameState.boss_pending and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	assert_true(GameState.boss_pending, "paid in full standing on the front lot")
	assert_eq(GameState.gold, 0)

func test_the_paid_up_sparkle_is_at_the_sign_that_sold() -> void:
	await _make()
	GameState.debug_set_tier(2, 3)
	watch_signals(EventBus)
	GameState.add_gold(1500)
	GameState.pay_into_tier(1500)
	var found := false
	for i in get_signal_emit_count(EventBus, "fx_requested"):
		var args: Array = get_signal_parameters(EventBus, "fx_requested", i)
		if args[0] == &"sparkle" and (args[1] as Vector3).is_equal_approx(MapLayout.to3(MapLayout.tier_sign(3), 1.0)):
			found = true
	assert_true(found, "a sparkle at the tier-3 sign")

func _screen_rect(label: Label3D, xf: Transform3D, proj: Projection, half_h := 640.0, half_w := 360.0) -> Rect2:
	var box := label.get_aabb()
	var c := label.global_position
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			var w: Vector3 = c + xf.basis.x * box.size.x * sx + xf.basis.y * box.size.y * sy
			var n := CameraMath.to_ndc(w, xf, proj)
			var px := Vector2(n.x * half_w, -n.y * half_h)
			lo = lo.min(px)
			hi = hi.max(px)
	return Rect2(lo, hi - lo)

## The sign board's mesh AABB corners (world space, all eight), projected: the smallest distance in px to a screen edge (negative = off screen).
func _board_margin(sign: TierSign, xf: Transform3D, proj: Projection, half_w: float, half_h: float) -> float:
	var margin := INF
	for mi in sign.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
		for ix in 2:
			for iy in 2:
				for iz in 2:
					var n := CameraMath.to_ndc(box.position + box.size * Vector3(ix, iy, iz), xf, proj)
					margin = minf(margin, minf(half_w - absf(n.x) * half_w, half_h - absf(n.y) * half_h))
	return margin

func _tier_3_sign_in_the_day() -> void:
	await _make()
	GameState.debug_set_tier(2, 3)
	await _day_at(2)

func test_the_whole_tier_3_sign_board_is_on_screen_from_home_at_9_16_and_9_21() -> void:
	await _tier_3_sign_in_the_day()
	var xf := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), Balance.ui)
	var sign := main.world.tier_sign
	var m916 := _board_margin(sign, xf, CameraMath.projection(Balance.ui, 9.0 / 16.0), 360.0, 640.0)
	var m921 := _board_margin(sign, xf, CameraMath.projection(Balance.ui, 9.0 / 21.0), 360.0, 640.0 * 21.0 / 16.0)
	gut.p("tier-3 sign board AABB corners, margin to the nearest screen edge: 9:16 %.1f px of 720 wide, 9:21 %.1f px" % [m916, m921])
	assert_gt(m916, 8.0, "every corner of the board's AABB is on screen at 9:16")
	assert_gt(m921, 8.0, "and at 9:21")

## The text the sign carries (Task 21: "Buy the lot" at tier 2) and the one it had: the whole label rect is inside the screen from HOME at
## 9:16, 9:21 and 16:9 (base height 1280, so 2275 wide), clears every other world label (the DINER, the close-up sign, the stations) and the HUD bar.
## HUD_BOTTOM: the top column (day, moons, bar) ends 140 base px below the safe-area top; 88 px is the notch inset: a conservative 228 px.
func _label_fits_and_clears(text: String) -> void:  # a coroutine: callers await it
	var xf := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), Balance.ui)
	var sign := main.world.tier_sign
	var old_text: String = sign.label.text
	var old_width := sign.label.get_aabb().size.x
	sign.label.text = text
	await get_tree().process_frame  # a Label3D is shaped on the next frame: before that its AABB is a placeholder cube
	if text != old_text:  # mutation: measuring before the frame (a stale AABB) leaves the width unchanged and fails
		assert_ne(sign.label.get_aabb().size.x, old_width, "the label was re-shaped for '%s': its width changed" % text.replace("\n", " "))
	assert_true(CameraMath.on_screen(MapLayout.to3(MapLayout.tier_sign(3)), xf, CameraMath.projection(Balance.ui)), "the sign's base")
	var hud_bottom: float = 88.0 + Balance.ui.hud_top_bar_px + 50.0  # the notch inset, the bar's tuned depth, and 50 px of air (228 at 90)
	for aspect in [9.0 / 16.0, 9.0 / 21.0, 16.0 / 9.0]:
		var proj := CameraMath.projection(Balance.ui, aspect)
		var half_h: float = 640.0 if aspect > 0.5625 - 1e-6 else 360.0 / aspect  # 9:16 and 16:9 are 1280 tall, 9:21 is 1680
		var half_w: float = 360.0 if aspect < 1.0 else half_h * aspect
		var mine := _screen_rect(sign.label, xf, proj, half_h, half_w)
		assert_gt(mine.size.x, 20.0, "the label has a real extent")
		assert_gt(mine.position.y, -half_h + hud_bottom, "'%s' stays below the HUD bar at %.3f: %s" % [text.replace("\n", " "), aspect, mine])
		assert_true(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0).grow(-8.0).encloses(mine), "'%s': the whole label is on screen from HOME at %.3f, not cut by an edge: %s" % [text.replace("\n", " "), aspect, mine])
		var others := 0
		for l in get_tree().get_nodes_in_group(&"world_labels"):
			var other := l as Label3D
			if other == sign.label or not other.is_visible_in_tree() or other.text == "":
				continue
			others += 1
			assert_false(mine.grow(4.0).intersects(_screen_rect(other, xf, proj, half_h, half_w)), "'%s' clears '%s' at %s" % [text.replace("\n", " "), other.text.replace("\n", " "), other.global_position])
		assert_gt(others, 2, "the close-up sign's and the stations' labels were compared")

func test_the_tier_3_sign_label_fits_with_its_real_tier_2_text() -> void:
	await _tier_3_sign_in_the_day()
	assert_eq(main.world.tier_sign.label.text, tr("Buy the lot") + "\n1500", "the sign's own text at tier 2")
	await _label_fits_and_clears(tr("Buy the lot") + "\n1500")

func test_the_tier_3_sign_label_still_fits_the_old_shorter_text() -> void:
	await _tier_3_sign_in_the_day()
	await _label_fits_and_clears(tr("Open the yards") + "\n1500")

# --- the kerb and the lot ---------------------------------------------------

func _hash_transforms(xfs: Array) -> int:
	var pts := PackedFloat32Array()
	for xf in xfs:
		for v in [xf.basis.x, xf.basis.y, xf.basis.z, xf.origin]:
			pts.append_array(PackedFloat32Array([v.x, v.y, v.z]))
	return hash(pts.to_byte_array().hex_encode())

func test_the_tier_2_kerb_and_pad_list_are_byte_identical() -> void:
	var xfs := []
	for id in ["west", "east"]:
		xfs.append_array(YardStones.transforms(MapLayout.yard_rect(id)))
	assert_eq(xfs.size(), 27)
	assert_eq(_hash_transforms(xfs), TIER2_KERB_HASH, "the tier-2 kerb is the one captured before Task 16")
	var pp := PackedFloat32Array()
	for p in YardStones.pad_points():
		pp.append_array(PackedFloat32Array([p.x, p.y]))
	assert_eq(YardStones.pad_points().size(), 11)
	assert_eq(hash(pp.to_byte_array().hex_encode()), TIER2_PADS_HASH, "pad_points() with no tier is the old list")
	var built := 0
	for id in ["west", "east"]:
		built += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, Balance.data.enemy.lateral_spread).size()
	assert_eq(built, 27, "the world's tier-3 build leaves the west and east kerb alone")

func _centre_line(xf: Transform3D) -> Array:
	var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
	var c := Vector2(xf.origin.x, xf.origin.z)
	return [c - half, c + half]

func _front_pieces() -> Array[Transform3D]:
	return YardStones.transforms(MapLayout.yard_rect("front"), true, Balance.data.enemy.lateral_spread)

func _front_clearance(what: String, dist_of: Callable, need: float) -> void:
	var worst := INF
	for xf in _front_pieces():
		var seg := _centre_line(xf)
		worst = minf(worst, float(dist_of.call(seg[0], seg[1])))
	assert_gte(worst, need - 1e-6, "no front kerb piece within %.2f of %s (closest %.2f)" % [need, what, worst])

func _bar(lane: String) -> Array:
	var path: Array = MapLayout.lane_path(lane)
	var t := Geometry.tangent_at(path, Geometry.path_length(path) - MapLayout.FENCE_OFFSET_FROM_END)
	var n := Vector2(-t.y, t.x)
	var f := MapLayout.fence_spot(lane)
	return [f - n * MapLayout.FENCE_BAR_HALF, f + n * MapLayout.FENCE_BAR_HALF]

func test_the_front_lot_kerb_is_closed_except_where_the_things_of_tier_3_stand() -> void:
	Balance.reset()
	var pieces := _front_pieces()
	assert_gt(pieces.size(), 8, "the lot has a kerb")
	var half_w := YardStones.WIDTH * 0.5
	# the SW lane's whole width: centre line +- the monsters' lateral spread, plus the kerb's half width and a margin
	var lane_need: float = Balance.data.enemy.lateral_spread + half_w + 0.2
	var lane_path: Array = MapLayout.lane_path("sw")
	_front_clearance("the SW lane", func(a, b): return _seg_path_dist(a, b, lane_path), lane_need)
	var tower: Vector2 = MapLayout.spot_position("tower_sw")
	_front_clearance("tower_sw's pad", func(a, b): return Geometry.dist_point_segment(tower, a, b), MapLayout.BUILD_RADIUS + half_w)
	var fence: Vector2 = MapLayout.spot_position("fence_sw")
	_front_clearance("fence_sw's pad", func(a, b): return Geometry.dist_point_segment(fence, a, b), MapLayout.BUILD_RADIUS + half_w)
	var bar := _bar("sw")
	_front_clearance("fence_sw's bar", func(a, b): return _seg_seg(a, b, bar[0], bar[1]), BAR_HALF_DEPTH + half_w)
	var pads := 0
	for id in MapLayout.BRANCH_PADS:
		for p in MapLayout.BRANCH_PADS[id]:
			pads += 1
			_front_clearance("branch pad %s of %s" % [p, id], func(a, b): return Geometry.dist_point_segment(p, a, b), MapLayout.BRANCH_PAD_RADIUS + half_w)
	assert_eq(pads, 18)
	# the lane crosses the lot's south and north edges: the outline points inside its width are uncovered, the lot's far edge is covered
	var r: Rect2 = MapLayout.yard_rect("front")
	for crossing in [Vector2(-3.36, r.end.y), Vector2(-2.93, r.position.y)]:
		assert_lt(Geometry.dist_point_segment(crossing, lane_path[1], lane_path[2]), 1.0, "%s is on the lane" % crossing)
		assert_gt(_distance_to_front_kerb(crossing), 0.5, "no kerb across the lane at %s" % crossing)
	for covered in [Vector2(r.position.x, 8.0), Vector2(r.end.x, 7.4)]:
		assert_lt(_distance_to_front_kerb(covered), 0.01, "the kerb is there at %s" % covered)

func _distance_to_front_kerb(p: Vector2) -> float:
	var best := INF
	for xf in _front_pieces():
		var seg := _centre_line(xf)
		best = minf(best, Geometry.dist_point_segment(p, seg[0], seg[1]))
	return best

func _seg_path_dist(a: Vector2, b: Vector2, path: Array) -> float:
	var best := INF
	for i in range(1, path.size()):
		best = minf(best, _seg_seg(a, b, path[i - 1], path[i]))
	return best

func _seg_seg(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	return minf(minf(Geometry.dist_point_segment(a, c, d), Geometry.dist_point_segment(b, c, d)),
		minf(Geometry.dist_point_segment(c, a, b), Geometry.dist_point_segment(d, a, b)))

func test_the_default_kerb_would_cross_the_lane() -> void:
	# the named wrong implementation: the tier-2 rules on the front lot leave pieces across the SW lane
	var path: Array = MapLayout.lane_path("sw")
	var across := 0
	for xf in YardStones.transforms(MapLayout.yard_rect("front")):
		var seg := _centre_line(xf)
		if _seg_path_dist(seg[0], seg[1], path) < Balance.data.enemy.lateral_spread:
			across += 1
	assert_gt(across, 0, "without the tier-3 rules a kerb piece sits on the lane")

func test_at_tier_3_the_world_paves_the_lot_and_builds_its_kerb() -> void:
	await _make()
	GameState.debug_set_tier(3, 4)
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), ["west", "east", "front"])
	var ground := main.world.ground
	assert_eq(ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), ["west", "east", "front"], MapLayout.lanes_for_tier(3)))
	var r: Rect2 = MapLayout.yard_rect("front")
	var paved := 0
	for v in ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if r.has_point(Vector2(v.x, v.z)) and absf(v.y - GroundArt.YARD_Y) < 1e-6:
			paved += 1
	assert_gt(paved, 20, "the lot's cells are paved")
	var kerb := main.world.yard_stones
	var want := 0
	for id in main.world.yard_ids():
		want += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, Balance.data.enemy.lateral_spread).size()
	assert_eq(kerb.multimesh.instance_count, want, "the kerb is the three yards' pieces")
	assert_eq(kerb.multimesh.instance_count, 27 + _front_pieces().size())

func test_the_front_lot_props_are_few_small_and_clear_and_the_old_props_leave_the_lot() -> void:
	var items: Array = PropsLayout.OWNED.get("front", [])
	assert_between(items.size(), 2, 3, "two or three small props")
	var r: Rect2 = MapLayout.yard_rect("front")
	for it in items:
		assert_true(r.has_point(it.pos), "%s on the lot" % [it.pos])
	var xf := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), Balance.ui)
	var proj := CameraMath.projection(Balance.ui)  # 9:16
	var normal_sized := 0
	for it in items:
		if float(it.scale) >= 0.8 and CameraMath.on_screen(MapLayout.to3(it.pos, 0.5), xf, proj):
			normal_sized += 1
	assert_gte(normal_sized, 1, "a prop of normal size (scale >= 0.8) is on screen from HOME at 9:16")
	var rects: Array[Rect2] = []
	for id in MapLayout.yards_for_tier(3):
		rects.append(MapLayout.yard_rect(id))
	for it in Props.items_for(rects):
		assert_gt(Geometry.dist_point_rect(it.pos, r), Props.CLEAR_DIST, "no layout prop stands on the lot at %s" % [it.pos])
	var tier2 := GroundArt.terrain_mesh(World.ground_rect(), ["west", "east"])
	var tier3 := GroundArt.terrain_mesh(World.ground_rect(), ["west", "east", "front"], MapLayout.lanes_for_tier(3))
	assert_eq(_raised_vertices(tier2, r), 0, "tier 2: nothing on the unowned lot")
	assert_gt(_raised_vertices(tier3, r), 20, "tier 3: the lot's props ride the ground mesh")

## The colour of the topmost ground triangle at xz (vertex colours interpolated), or a transparent colour when none covers it.
func _surface_colour_at(mesh: ArrayMesh, p: Vector2) -> Color:
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var best_y := -INF
	var out := Color(0, 0, 0, 0)
	for t in idx.size() / 3:
		var i0 := idx[t * 3]
		var i1 := idx[t * 3 + 1]
		var i2 := idx[t * 3 + 2]
		var a2 := Vector2(v[i0].x, v[i0].z)
		var b2 := Vector2(v[i1].x, v[i1].z)
		var c2 := Vector2(v[i2].x, v[i2].z)
		if p.x < minf(a2.x, minf(b2.x, c2.x)) - 1e-4 or p.x > maxf(a2.x, maxf(b2.x, c2.x)) + 1e-4 or p.y < minf(a2.y, minf(b2.y, c2.y)) - 1e-4 or p.y > maxf(a2.y, maxf(b2.y, c2.y)) + 1e-4:
			continue
		var den := (b2.y - c2.y) * (a2.x - c2.x) + (c2.x - b2.x) * (a2.y - c2.y)
		if absf(den) < 1e-9:
			continue
		var w0 := ((b2.y - c2.y) * (p.x - c2.x) + (c2.x - b2.x) * (p.y - c2.y)) / den
		var w1 := ((c2.y - a2.y) * (p.x - c2.x) + (a2.x - c2.x) * (p.y - c2.y)) / den
		var w2 := 1.0 - w0 - w1
		if w0 < -1e-4 or w1 < -1e-4 or w2 < -1e-4:
			continue
		var y := (v[i0].y * w0 + v[i1].y * w1 + v[i2].y * w2)
		if y > best_y:
			best_y = y
			out = c[i0] * w0 + c[i1] * w1 + c[i2] * w2
	return out

func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _is_paved(col: Color) -> bool:
	var cream := Palette.color(&"diner_cream")
	var stone := Palette.color(&"stone")
	var best := INF
	for k in 11:
		best = minf(best, _cdist(col, cream.lerp(stone, 0.04 * k)))
	return best < 0.03

func test_the_lot_is_paved_on_both_sides_of_the_lane_and_the_lane_keeps_a_narrow_track() -> void:
	Balance.reset()
	var spread: float = Balance.data.enemy.lateral_spread
	var mesh := GroundArt.terrain_mesh(World.ground_rect(), ["west", "east", "front"], MapLayout.lanes_for_tier(3), spread)
	var path: Array = MapLayout.lane_path("sw")
	var tangent: Vector2 = (path[2] - path[1]).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var centre: Vector2 = (path[1] as Vector2).lerp(path[2], 0.4)  # inside the lot (z 7.5)
	assert_true(MapLayout.yard_rect("front").has_point(centre))
	var dirt := Palette.color(&"dirt")
	assert_lt(_cdist(_surface_colour_at(mesh, centre), dirt), 0.02, "on the centre line: lane dirt")
	assert_lt(_cdist(_surface_colour_at(mesh, centre + normal * 0.98), Palette.color(&"dirt_dark")), 0.05, "the track's 2 m width ends in its dark border")
	for side in [-1.0, 1.0]:
		var p: Vector2 = centre + normal * side * 1.3
		assert_true(MapLayout.yard_rect("front").has_point(p))
		assert_true(_is_paved(_surface_colour_at(mesh, p)), "1.3 m to the side of the lane centre line, inside the lot: paving (%s)" % _surface_colour_at(mesh, p))
	# outside the lot the lane keeps its normal 3 m strip: the E-W part at z = 11, 1.1 m off its centre line, is dirt
	assert_lt(_cdist(_surface_colour_at(mesh, Vector2(-9.0, 12.1)), dirt), 0.02, "outside the lot: the full strip")
	# without the plot's paving over the lane (tier 2 mesh, no front yard) the same point is the strip's border
	var tier2 := GroundArt.terrain_mesh(World.ground_rect(), ["west", "east"], MapLayout.lanes_for_tier(3), spread)
	assert_false(_is_paved(_surface_colour_at(tier2, centre + normal * 1.3)), "without the front yard that point is lane or grass, not paving")

func test_the_tier_2_terrain_mesh_is_byte_identical() -> void:
	var a := GroundArt.terrain_mesh(World.ground_rect(), ["west", "east"]).surface_get_arrays(0)
	var got := []
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
		got.append(hash(a[k].to_byte_array().hex_encode()))
	gut.p("TIER2TERRAIN %s" % [got])
	assert_eq(got, TIER2_TERRAIN_HASHES, "tiers 1 and 2 ground meshes did not move")

func _raised_vertices(mesh: ArrayMesh, rect: Rect2) -> int:
	var n := 0
	for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y > 0.1 and rect.has_point(Vector2(v.x, v.z)):
			n += 1
	return n

# --- the queue and the exit -------------------------------------------------

func _fill_queue(count: int) -> void:
	GameState.counter_steaks = 0
	var guard := 0
	while main.world.traveler_spawner.queue.size() < count and guard < 60 * 40:
		await get_tree().physics_frame
		guard += 1

func _settled() -> bool:
	for t in main.world.traveler_spawner.queue:
		if not (t as Traveler).at_target():
			return false
	return true

func _queue_uses(tier: int) -> void:
	await _day_at(tier)
	var sp := main.world.traveler_spawner
	await _fill_queue(3)
	var guard := 0
	while not _settled() and guard < 60 * 20:
		await get_tree().physics_frame
		guard += 1
	assert_true(_settled(), "tier %d: the queue settled" % tier)
	var slots := MapLayout.queue_slots(tier)
	for i in sp.queue.size():
		assert_lt((sp.queue[i] as Traveler).xz().distance_to(slots[i]), 0.06, "tier %d: traveler %d stands at slot %d %s" % [tier, i, i, slots[i]])

func test_tier_1_queues_at_the_old_slots() -> void:
	await _make()
	await _queue_uses(1)
	assert_eq(MapLayout.queue_slots(1)[1], MapLayout.QUEUE_SLOTS[1])

func test_tier_2_queues_at_the_old_slots() -> void:
	await _make()
	await _queue_uses(2)
	assert_eq(MapLayout.queue_slots(2)[1], MapLayout.QUEUE_SLOTS[1])

func test_tier_3_queues_on_the_east_side() -> void:
	await _make()
	await _queue_uses(3)
	assert_eq(MapLayout.queue_slots(3)[1], Vector2(1.1, 6.9))

## Serves the front traveler and returns the leaving traveler's [target, final position].
func _serve_and_watch_exit(tier: int) -> Array:
	var sp := main.world.traveler_spawner
	var front: Traveler = sp.queue[0]
	GameState.counter_steaks = 20
	var guard := 0
	while not front.leaving and guard < 60 * 10:
		await get_tree().physics_frame
		guard += 1
	assert_true(front.leaving, "tier %d: the front traveler was served" % tier)
	var target: Vector2 = front._target
	var last := front.xz()
	guard = 0
	while sp.leaving.has(front) and guard < 60 * 30:
		last = front.xz()
		await get_tree().physics_frame
		guard += 1
	assert_false(sp.leaving.has(front), "tier %d: it walked off" % tier)
	return [target, last]

func _leaves_by_the_exit_of(tier: int) -> void:
	await _make()
	await _queue_uses(tier)
	var out := await _serve_and_watch_exit(tier)
	assert_eq(out[0], MapLayout.traveler_exit(tier), "tier %d: it targets the tier's exit" % tier)
	assert_lt(out[1].distance_to(MapLayout.traveler_exit(tier)), 0.5 + 2.5 / 60.0, "tier %d: and arrived there" % tier)

func test_tier_1_travelers_leave_west() -> void:
	await _leaves_by_the_exit_of(1)
	assert_lt(MapLayout.traveler_exit(1).x, 0.0)

func test_tier_2_travelers_leave_west() -> void:
	await _leaves_by_the_exit_of(2)
	assert_lt(MapLayout.traveler_exit(2).x, 0.0)

func test_tier_3_travelers_leave_east() -> void:
	await _leaves_by_the_exit_of(3)
	assert_gt(MapLayout.traveler_exit(3).x, 0.0)

func test_the_traveler_pool_size_is_the_literal_it_always_was() -> void:
	# queue_max 9 + ceil(24.5 m / 2.5 m/s / 0.5 s) = 20 + 2: the exits of tiers 1 and 3 are both 24.5 m from the service point
	assert_almost_eq(MapLayout.SERVICE_POINT.distance_to(MapLayout.traveler_exit(3)), MapLayout.SERVICE_POINT.distance_to(MapLayout.traveler_exit(1)), 1e-6)
	assert_eq(StationEffects.traveler_pool_size(Balance.data.stations, Balance.data.economy), 31)

# --- when the layout switches -------------------------------------------------

func test_the_switch_at_the_tier_up_dawn_finds_no_traveler() -> void:
	await _make()
	await _day_at(2)
	await _fill_queue(2)
	GameState.add_gold(1500)
	GameState.pay_into_tier(1500)
	assert_true(GameState.boss_pending)
	main.phase_controller.debug_skip_to_night()  # the real close-up
	var sp := main.world.traveler_spawner
	assert_gt(sp.live_count(), 0, "the close-up sent the queue away: travelers are still on the road when the night starts")
	assert_eq(sp.queue.size(), 0)
	await _ticks(30)
	EventBus.tier_changed.connect(_on_tier_changed)
	_tier_changes.clear()
	main.phase_controller.debug_skip_to_day()  # the dawn: heal, advance_day, complete_tier_up
	assert_eq(GameState.tier, 3)
	var at_switch: Array = _tier_changes.filter(func(c): return c.tier == 3)
	assert_gt(at_switch.size(), 0, "tier_changed announced tier 3")
	for c in at_switch:
		assert_eq(c.live, 0, "no live traveler when the tier changes")
		assert_eq(c.active, 0, "and none out of the pool")
		assert_eq(c.phase, Phase.DAWN, "at the dawn")
	assert_eq(main.world.traveler_spawner.live_count(), 0)
	assert_eq(main.world.traveler_spawner.dropped_at_switch, 0, "the spawner's own switch dropped nobody: the dawn had already recalled them")

func test_the_first_day_after_the_tier_up_queues_east() -> void:
	await _make()
	await _day_at(2)
	GameState.add_gold(1500)
	GameState.pay_into_tier(1500)
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()
	await _ticks(int(Balance.data.tiers.tier_reveal_time * 60.0) + 120)
	assert_false(main.phase_controller.reveal_pending)
	main.phase_controller.debug_skip_to_day()  # the card pick
	await _ticks(2)
	assert_eq(main.phase_controller.phase, Phase.DAY)
	await _queue_uses(3)
	var out := await _serve_and_watch_exit(3)
	assert_eq(out[0], MapLayout.traveler_exit(3))
	assert_gt(MapLayout.traveler_exit(3).x, 20.0)

func test_debug_set_tier_in_the_day_clears_the_travelers_when_the_layout_moves() -> void:
	await _make()
	await _day_at(2)
	await _fill_queue(3)
	var sp := main.world.traveler_spawner
	assert_gt(sp.live_count(), 0)
	var alive := sp.live_count()
	GameState.debug_set_tier(3, GameState.day)
	assert_eq(sp.live_count(), 0, "every traveler was dropped: none keeps the old exit")
	assert_eq(sp.dropped_at_switch, alive, "the spawner dropped exactly those that were alive")
	assert_eq(sp.pool.active().size(), 0)
	assert_true(sp.active, "the day goes on")
	await _fill_queue(2)
	for i in 60 * 15:
		await get_tree().physics_frame
		for t in sp.pool.active():
			assert_gte((t as Traveler)._target.x, 0.0, "nothing targets the west at tier 3")
	assert_lt((sp.queue[1] as Traveler).xz().distance_to(MapLayout.queue_slots(3)[1]), 0.06, "the next travelers use the east slots")

func test_debug_set_tier_between_tiers_1_and_2_touches_no_traveler() -> void:
	await _make()
	await _day_at(1)
	await _fill_queue(3)
	var sp := main.world.traveler_spawner
	var before := sp.live_count()
	var queued: Array = sp.queue.duplicate()
	GameState.debug_set_tier(2, GameState.day)
	assert_eq(sp.live_count(), before, "same slots, same exit: nothing changes shape")
	assert_eq(sp.queue, queued, "the very same travelers stand in the same order")
	assert_eq(sp.dropped_at_switch, 0, "the spawner's layout switch did nothing at the 1 -> 2 tier-up")

func test_a_save_made_mid_day_at_tier_3_reloads_with_the_east_layout() -> void:
	await _make()
	await _day_at(3)
	await _fill_queue(2)
	var saved := GameState.to_dict()
	saved.resume_phase = "DAY"
	for k in saved.keys():
		assert_false(String(k).contains("travel"), "no traveler is saved (%s)" % k)
	GameState.new_game(9)  # back to tier 1: the world follows
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), [])
	main.phase_controller.resume_from(saved)  # the boot resume: restore, back into the day
	await get_tree().process_frame
	assert_eq(GameState.tier, 3)
	assert_eq(main.world.yard_ids(), ["west", "east", "front"], "the world rebuilt with the front lot")
	var sp := main.world.traveler_spawner
	assert_eq(sp.live_count(), 0, "a load starts with an empty queue")
	await _fill_queue(2)
	var guard := 0
	while not _settled() and guard < 60 * 20:
		await get_tree().physics_frame
		guard += 1
	assert_lt((sp.queue[1] as Traveler).xz().distance_to(MapLayout.queue_slots(3)[1]), 0.06, "the next traveler queues at an east slot")
	var out := await _serve_and_watch_exit(3)
	assert_eq(out[0], MapLayout.traveler_exit(3), "and leaves east")

# --- day traffic (D-261 constraint 3) -------------------------------------

func _seg_clearances(tier: int, p0: Vector2, p1: Vector2, stats: Dictionary) -> void:
	for lane in MapLayout.lanes_for_tier(tier):
		var bar := _bar(lane)
		stats.bar = minf(stats.bar, _seg_seg(p0, p1, bar[0], bar[1]) - BAR_HALF_DEPTH - TRAVELER_RADIUS)
		stats.zone = minf(stats.zone, Geometry.dist_point_rect(p1, MapLayout.zone_rect(lane)) - TRAVELER_RADIUS)
	if tier < 3:  # branch pads exist from tier 3
		return
	for id in MapLayout.BRANCH_PADS:
		for pad in MapLayout.BRANCH_PADS[id]:
			stats.pad = minf(stats.pad, Geometry.dist_point_segment(pad, p0, p1) - MapLayout.BRANCH_PAD_RADIUS)

## Walks real travelers through full visits (the queue fills, advances slot to slot, is served, walks out) and returns the tightest
## clearances of every per-tick step against the fence bars, the attack zones and the branch pads (negative = a violation).
func _traffic(tier: int, counter_level := 0) -> Dictionary:
	await _day_at(tier)
	var sp := main.world.traveler_spawner
	if counter_level > 0:
		GameState.stations[&"counter"] = {"level": counter_level, "paid": 0}  # test-only: the queue holds queue_max(level) travelers
	_grew = 0
	sp.pool.grew.connect(_on_pool_grew)
	var max_queue := 0
	EventBus.steak_sold.connect(_on_sold)
	_sold = 0
	var stats := {"bar": INF, "zone": INF, "pad": INF, "steps": 0, "visits": 0}
	var last := {}
	var seen := {}
	GameState.counter_steaks = 0  # the queue fills first
	var tick := 0
	while tick < 60 * 50 and not (_sold >= 6 and sp.live_count() == 0):
		if tick == 60 * 25:
			GameState.counter_steaks = 1000  # then it advances slot to slot as each is served
		await get_tree().physics_frame
		tick += 1
		max_queue = maxi(max_queue, sp.queue.size())
		for t in sp.pool.active():
			var p := (t as Traveler).xz()
			seen[t.get_instance_id()] = true
			if last.has(t):
				_seg_clearances(tier, last[t], p, stats)
				stats.steps += 1
			last[t] = p
		for t in last.keys():
			if not sp.pool.active().has(t):
				last.erase(t)
	stats.visits = _sold
	stats.travelers = seen.size()
	stats.max_queue = max_queue
	stats.grew = _grew
	sp.pool.grew.disconnect(_on_pool_grew)
	EventBus.steak_sold.disconnect(_on_sold)
	return stats

func test_tier_3_day_traffic_keeps_off_the_fence_bars_the_zone_and_the_pads() -> void:
	await _make()
	var s := await _traffic(3, Balance.data.stations.max_level)
	gut.p("tier 3 traffic: %s" % [s])
	assert_eq(s.max_queue, 9, "the queue really reached nine: slots 4 to 8 and the row corner were walked")
	assert_eq(s.grew, 0, "the traveler pool never grew during the walk (no growth warning)")
	assert_gte(s.visits, 6, "full visits were walked")
	assert_gt(s.steps, 1000)
	assert_gt(s.bar, 0.0, "no step within bar half-depth + traveler radius of a fence bar (all four lanes)")
	assert_gt(s.zone, 0.0, "nor into an attack zone (the SW one included)")
	assert_gt(s.pad, 0.0, "nor within a branch pad's radius")

func _report_traffic(tier: int) -> void:
	await _make()
	var s := await _traffic(tier)
	gut.p("tier %d traffic vs the three fence bars and zones (information, not asserted): %s" % [tier, s])
	assert_gte(s.visits, 6, "tier %d: full visits were walked" % tier)
	assert_gt(s.steps, 1000)
	assert_gt(s.bar, 0.0, "tier %d: clear of the three fence bars (a floor, not a rule)" % tier)
	assert_gt(s.zone, 0.0, "tier %d: clear of the three attack zones" % tier)

func test_tier_1_day_traffic_is_reported() -> void:
	await _report_traffic(1)

func test_tier_2_day_traffic_is_reported() -> void:
	await _report_traffic(2)

# --- the gold pile at night -----------------------------------------------

func _pile_empty_from_close_up_to_dawn(tier: int) -> void:
	await _make()
	await _day_at(tier)
	GameState.counter_steaks = 10
	assert_eq(GameState.sell_from_counter(4), 4)
	var pile := GameState.gold_pile
	var gold := GameState.gold
	assert_gt(pile, 0, "tier %d: gold was on the pile when the player closed up" % tier)
	main.phase_controller.debug_skip_to_night()
	assert_eq(GameState.gold_pile, 0, "tier %d: the close-up emptied the pile" % tier)
	assert_eq(GameState.gold, gold + pile, "tier %d: into the purse, nothing lost" % tier)
	for i in 240:
		await get_tree().physics_frame
		assert_eq(GameState.gold_pile, 0, "tier %d: tick %d of the night" % [tier, i])
	main.phase_controller.debug_skip_to_day()  # the dawn
	assert_eq(GameState.gold_pile, 0, "tier %d: through the dawn" % tier)
	assert_eq(GameState.gold, gold + pile)
	await _ticks(5)
	assert_eq(GameState.gold_pile, 0)

func test_the_pile_is_empty_from_close_up_to_dawn_at_tier_1() -> void:
	await _pile_empty_from_close_up_to_dawn(1)

func test_the_pile_is_empty_from_close_up_to_dawn_at_tier_2() -> void:
	await _pile_empty_from_close_up_to_dawn(2)

func test_the_pile_is_empty_from_close_up_to_dawn_at_tier_3() -> void:
	await _pile_empty_from_close_up_to_dawn(3)
