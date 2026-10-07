extends GutTest
## E5 spec 7.3: yards and yard spots appear at tier 2, on tier_reached and on restore; one ground draw, one stone draw.

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)

func _ground_meshes() -> Array:
	return main.world.find_children("Ground", "MeshInstance3D", true, false)

func test_tier1_has_no_yards_no_stones_and_five_spots() -> void:
	assert_eq(main.world.yard_ids(), [])
	assert_null(main.world.get_node_or_null("YardStones"))
	assert_eq(main.world.build_spots.keys(), MapLayout.spots_for_tier(1))
	assert_eq(_ground_meshes().size(), 1)
	assert_eq((_ground_meshes()[0] as MeshInstance3D).mesh, GroundArt.terrain_mesh(World.ground_rect(), []))

func test_tier_reached_opens_the_yards_and_adds_the_spots() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.complete_tier_up()
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), ["west", "east"])
	var stones := main.world.get_node_or_null("YardStones") as MultiMeshInstance3D
	assert_not_null(stones)
	assert_gt(stones.multimesh.instance_count, 10)
	assert_eq(main.world.build_spots.keys(), MapLayout.spots_for_tier(2))
	assert_true(main.world.build_spots["tower_w"] is TowerSpot)
	assert_eq(_ground_meshes().size(), 1, "still one ground draw")
	assert_eq((_ground_meshes()[0] as MeshInstance3D).mesh, GroundArt.terrain_mesh(World.ground_rect(), ["west", "east"]))
	assert_eq(stones.find_children("*", "CollisionObject3D", true, false).size(), 0, "no collision on the stones")
	assert_eq(stones.get_child_count(), 0)

func test_debug_set_tier_updates_the_world_too() -> void:
	GameState.debug_set_tier(2, 3)
	assert_eq(main.world.yard_ids(), ["west", "east"])
	assert_true(main.world.build_spots.has("tower_w"))
	assert_not_null(main.world.get_node_or_null("YardStones"))
	var stones := main.world.yard_stones
	var spot = main.world.build_spots["tower_w"]
	GameState.debug_set_tier(2, 3)
	assert_same(main.world.yard_stones, stones, "a repeat tier_changed rebuilds nothing")
	assert_same(main.world.build_spots["tower_w"], spot)

func test_restore_rebuilds_for_the_saved_tier() -> void:
	GameState.debug_set_tier(2, 9)
	var d := GameState.to_dict()
	GameState.new_game(5)
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), [])
	GameState.from_dict(d)
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), ["west", "east"])
	assert_true(main.world.build_spots.has("tower_e"))
	GameState.new_game(6)
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), [], "a new game closes them again")
	assert_false(main.world.build_spots.has("tower_e"))
	assert_null(main.world.get_node_or_null("Spot_tower_w"), "the freed spot is gone from the tree")
	assert_null(main.world.get_node_or_null("YardStones"))

func test_spot_built_by_day_knows_it_is_day() -> void:
	main.phase_controller.debug_skip_to_day()
	await get_tree().process_frame
	GameState.debug_set_tier(2, GameState.day)
	var s: BuildSpot = main.world.build_spots["tower_w"]
	assert_true(s.zone.is_active(), "the new zone knows the phase")
	assert_true(s.marker.visible, "the unbuilt marker shows by day")
	assert_true(s.label.visible)

func test_yard_spots_take_payment_like_any_tower() -> void:
	GameState.debug_set_tier(2, GameState.day)
	main.phase_controller.debug_skip_to_day()
	await get_tree().process_frame
	GameState.add_gold(40)
	await TestHelpers.walk_in(main.hero, WaypointGraph.create_for_tier(2).position_of("tower_w"))
	var frames := 0
	while GameState.gold > 0 and frames < 600:
		await get_tree().physics_frame
		frames += 1
	assert_eq(GameState.gold, 0)
	assert_eq(int(GameState.buildings["tower_w"].level), 1)

func test_props_items_at_tier1_are_the_whole_layout() -> void:
	assert_eq(Props.items_for([]), PropsLayout.ITEMS)

func test_props_items_at_tier2_clear_the_open_yards() -> void:
	var yards: Array[Rect2] = []
	for id in MapLayout.yards_for_tier(2):
		yards.append(MapLayout.YARDS[id])
	var items := Props.items_for(yards)
	assert_lt(items.size(), PropsLayout.ITEMS.size(), "some props stood in the yards")
	assert_gt(items.size(), PropsLayout.ITEMS.size() - 8, "only the nearby ones go")
	for it in items:
		for r in yards:
			assert_gt(Geometry.dist_point_rect(it.pos, r), 1.0)
	for pos in [Vector2(-9.5, 3.5), Vector2(-10.5, -2.5), Vector2(10, 4), Vector2(10.5, -1.5)]:
		assert_false(items.any(func(it): return it.pos == pos), "hidden: %s" % pos)

## Tier 1 keeps today's merged prop meshes (numbers captured before E5 Task 10).
func test_props_tier1_meshes_are_unchanged() -> void:
	var p := Props.new()
	add_child_autofree(p)
	p.build()
	var verts := {}
	for c in p.get_children():
		var a := ((c as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		verts[c.name] = [(a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size()]
	assert_eq(verts, {"Props_kenney-castle__colormap": [8658, 15228], "Props_kenney-tower-defense__colormap": [11364, 17376]})

func test_props_rebuild_for_open_yards_keeps_two_draws_and_shrinks() -> void:
	var p := Props.new()
	add_child_autofree(p)
	p.build()
	var before := 0
	for c in p.get_children():
		before += ((c as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	var yards: Array[Rect2] = [MapLayout.YARDS["west"], MapLayout.YARDS["east"]]
	p.build(yards)
	await get_tree().process_frame
	assert_eq(p.get_children().filter(func(c): return not c.is_queued_for_deletion()).size(), 2)
	var after := 0
	for c in p.get_children():
		if not c.is_queued_for_deletion():
			after += ((c as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert_lt(after, before)
	p.build([])
	await get_tree().process_frame
	var back := 0
	for c in p.get_children():
		if not c.is_queued_for_deletion():
			back += ((c as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert_eq(back, before, "closing the yards brings the props back")

## The border: a low kerb (<= 0.25 m), gaps where a pad or the tier sign touches the edge.
func test_the_border_is_a_low_kerb_with_gaps_at_pads_and_the_sign() -> void:
	GameState.debug_set_tier(2, 3)
	var kerb := main.world.yard_stones
	assert_not_null(kerb)
	var top := 0.0
	var bottom := 1.0
	var count := 0
	for id in main.world.yard_ids():  # the headless dummy renderer keeps no instance transforms: use the builder's own
		for xf in YardStones.transforms(MapLayout.YARDS[id]):
			count += 1
			var box: AABB = xf * kerb.multimesh.mesh.get_aabb()
			top = maxf(top, box.end.y)
			bottom = minf(bottom, box.position.y)
	assert_eq(kerb.multimesh.instance_count, count, "every piece is an instance")
	assert_lte(top - bottom, 0.25, "kerb height")
	assert_gt(top - bottom, 0.05, "and it is a real kerb, not a flat line")
	assert_gte(bottom, -0.001, "on the ground")
	var tower_e := MapLayout.spot_position("tower_e")
	assert_lt(Geometry.dist_point_rect(tower_e, MapLayout.YARDS["east"]), MapLayout.BUILD_RADIUS, "tower_e's pad touches the yard edge")
	for id in MapLayout.YARDS:
		for xf in YardStones.transforms(MapLayout.YARDS[id]):
			var p := Vector2(xf.origin.x, xf.origin.z)
			assert_gt(p.distance_to(MapLayout.TIER_SIGN), MapLayout.STATION_RADIUS, "no kerb piece at the sign")
			for q in YardStones.pad_points():
				assert_gt(p.distance_to(q), MapLayout.BUILD_RADIUS, "no kerb piece inside a pad at %s" % q)
	# each piece is as long as its spacing ALONG its edge and WIDTH across it (a global-axis scale gets this wrong)
	for xf in YardStones.transforms(MapLayout.YARDS["west"]):
		var along := (xf.basis.x as Vector3).length()
		assert_between(along, YardStones.SPACING - 0.01, YardStones.SPACING * 1.5, "piece length")
		assert_almost_eq((xf.basis.z as Vector3).length(), 1.0, 1e-4)
		var d := (xf.basis.x as Vector3).normalized()
		assert_true(is_equal_approx(absf(d.x), 1.0) or is_equal_approx(absf(d.z), 1.0), "axis aligned along an edge")
	# the gap is a gap, not a missing kerb: the same edge elsewhere still has pieces
	var near_tower := YardStones.transforms(MapLayout.YARDS["east"]).filter(func(xf): return Vector2(xf.origin.x, xf.origin.z).distance_to(tower_e) < 3.0)
	assert_gt(near_tower.size(), 0, "kerb continues beside the gap")

## The "things to stay clear of" for a tier, from MapLayout. Task 8 extends this for tier 3 (the plot, SW lane, the
## new spots): add them HERE and add 3 to _owned_tiers(). Each entry is {pos: Vector2, d: float} (a point and the least
## distance from a prop centre) or {rect: Rect2, d: float}, or {seg: [a, b], d: float} (a lane or path line).
func _keep_clear(tier: int) -> Array:
	var out := []
	for id in MapLayout.spots_for_tier(tier):
		out.append({"pos": MapLayout.spot_position(id), "d": MapLayout.BUILD_RADIUS + 0.8, "what": id})
	for id in MapLayout.STATION_PADS:
		out.append({"pos": MapLayout.STATION_PADS[id], "d": MapLayout.BUILD_RADIUS + 0.8, "what": "pad %s" % id})
	var points := {"COUNTER": MapLayout.COUNTER, "FREEZER": MapLayout.FREEZER, "GOLD_PILE": MapLayout.GOLD_PILE, "SIGN": MapLayout.SIGN,
		"HOME": MapLayout.HOME, "DINER_DOOR": MapLayout.DINER_DOOR, "SERVICE_POINT": MapLayout.SERVICE_POINT,
		"FREEZER_ZONE": MapLayout.FREEZER_ZONE, "COUNTER_DROP": MapLayout.COUNTER_DROP}
	for name in points:
		out.append({"pos": points[name], "d": 2.0, "what": name})
	out.append({"pos": MapLayout.TIER_SIGN, "d": 2.5, "what": "tier sign"})
	for q in MapLayout.QUEUE_SLOTS:
		out.append({"pos": q, "d": 1.5, "what": "queue slot"})
	for id in MapLayout.LANE_PATHS:
		var pts: Array = MapLayout.LANE_PATHS[id]
		for i in range(1, pts.size()):
			out.append({"seg": [pts[i - 1], pts[i]], "d": 2.5, "what": "lane %s" % id})
	for id in MapLayout.ZONE_RECTS:
		out.append({"rect": MapLayout.ZONE_RECTS[id], "d": 1.5, "what": "zone %s" % id})
	out.append({"seg": [MapLayout.TRAVELER_ENTER, MapLayout.TRAVELER_EXIT], "d": 3.0, "what": "traveler path"})
	return out

func _owned_tiers() -> Array:
	return [2]

func _distance_to(p: Vector2, rule: Dictionary) -> float:
	if rule.has("pos"):
		return p.distance_to(rule.pos)
	if rule.has("rect"):
		return Geometry.dist_point_rect(p, rule.rect)
	return Geometry2D.get_closest_point_to_segment(p, rule.seg[0], rule.seg[1]).distance_to(p)

func test_owned_props_keep_clear() -> void:
	var seen := 0
	for tier in _owned_tiers():
		var rules := _keep_clear(tier)
		for id in MapLayout.yards_for_tier(tier):
			assert_true(PropsLayout.OWNED.has(id), "%s has owned-land props" % id)
			for it in PropsLayout.OWNED.get(id, []):
				seen += 1
				var p: Vector2 = it.pos
				assert_true((MapLayout.YARDS[id] as Rect2).grow(-0.4).has_point(p), "%s %s inside the %s yard, off the kerb" % [it.kind, p, id])
				for rule in rules:
					assert_gte(_distance_to(p, rule), float(rule.d), "tier %d: %s at %s clear of %s" % [tier, it.kind, p, rule.what])
	assert_gt(seen, 6, "props were checked")

func test_owned_props_ride_the_ground_mesh_and_have_no_collider() -> void:
	var tier1 := GroundArt.terrain_mesh(World.ground_rect(), [])
	assert_eq(_props_height_vertices(tier1, MapLayout.YARDS["west"]) + _props_height_vertices(tier1, MapLayout.YARDS["east"]), 0, "tier 1: nothing above the ground")
	GameState.debug_set_tier(2, 3)
	var ground := _ground_meshes()[0] as MeshInstance3D
	assert_eq(_ground_meshes().size(), 1, "no extra draw")
	assert_eq(ground.mesh.get_surface_count(), 1)
	for id in ["west", "east"]:
		assert_gt(_props_height_vertices(ground.mesh, MapLayout.YARDS[id]), 50, "%s yard carries its props" % id)
	assert_eq(main.world.props.find_children("*", "MeshInstance3D", true, false).size(), 2, "the atlas props are still two meshes")
	assert_eq(main.world.find_children("*", "CollisionObject3D", true, false).filter(func(n): return n.get_parent() == ground or n == ground).size(), 0)
	var top := 0.0
	for v in ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		top = maxf(top, v.y)
	assert_lt(top, 1.0, "small props")

## Vertices of `mesh` inside `rect` that stand clearly above the paved ground (a prop).
func _props_height_vertices(mesh: ArrayMesh, rect: Rect2) -> int:
	var n := 0
	for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y > 0.1 and rect.has_point(Vector2(v.x, v.z)):
			n += 1
	return n
