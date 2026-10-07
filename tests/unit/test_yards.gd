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

## The border: a low kerb (<= 0.25 m), gaps where a build-spot pad touches the edge, closed everywhere else.
func test_the_border_is_a_low_kerb_with_gaps_at_pads() -> void:
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
			var seg := _centre_line(xf)
			for q in YardStones.pad_points():
				var d := Geometry2D.get_closest_point_to_segment(q, seg[0], seg[1]).distance_to(q)
				assert_gt(d, MapLayout.BUILD_RADIUS + YardStones.WIDTH * 0.5, "no kerb piece touches the pad at %s" % q)
		# each piece is as long as its spacing ALONG its edge and WIDTH across it (a global-axis scale gets this wrong)
		for xf in YardStones.transforms(MapLayout.YARDS[id]):
			var along := (xf.basis.x as Vector3).length()
			assert_between(along, YardStones.SPACING - 0.01, YardStones.SPACING * 1.5, "%s piece length" % id)
			assert_almost_eq((xf.basis.z as Vector3).length(), 1.0, 1e-4)
			var d := (xf.basis.x as Vector3).normalized()
			assert_true(is_equal_approx(absf(d.x), 1.0) or is_equal_approx(absf(d.z), 1.0), "%s: axis aligned along an edge" % id)
	# the gap is a gap, not a missing kerb: the outline point nearest each tower pad is uncovered, the edge beside it is not
	var gaps := {Vector2(-9.0, MapLayout.spot_position("tower_w").y): Vector2(-9.0, 3.6), Vector2(8.0, tower_e.y): Vector2(9.875, 3.0)}
	for gap in gaps:
		assert_gt(_distance_to_kerb(gap), 0.3, "the kerb leaves the pad at %s free" % gap)
		assert_lt(_distance_to_kerb(gaps[gap]), 0.01, "and continues at %s" % gaps[gap])

## A piece's centre line (xz) from its transform: the origin +- half its length along its x axis.
func _centre_line(xf: Transform3D) -> Array:
	var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
	var c := Vector2(xf.origin.x, xf.origin.z)
	return [c - half, c + half]

func _distance_to_kerb(p: Vector2) -> float:
	var best := INF
	for id in MapLayout.YARDS:
		for xf in YardStones.transforms(MapLayout.YARDS[id]):
			var seg := _centre_line(xf)
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1]).distance_to(p))
	return best

## The "things to stay clear of" for a tier, from MapLayout. Task 8 extends this for tier 3 (the plot, SW lane, the
## new spots): add them HERE and add 3 to _owned_tiers(). Each entry is {pos: Vector2, r: float} (a point and its radius),
## {rect: Rect2, r: float = 0}, or {seg: [a, b], lateral: float} (a lane or path line and its half spread). A prop of
## radius R and height H keeps r + R + H / tan(camera pitch) from points and rects (the top leans over its base) and
## lateral + R from lines.
func _keep_clear(tier: int) -> Array:
	var out := []
	for id in MapLayout.spots_for_tier(tier):
		out.append({"pos": MapLayout.spot_position(id), "r": MapLayout.BUILD_RADIUS, "what": id})
	for id in MapLayout.STATION_PADS:
		out.append({"pos": MapLayout.STATION_PADS[id], "r": MapLayout.BUILD_RADIUS, "what": "pad %s" % id})
	out.append({"pos": MapLayout.COUNTER, "r": MapLayout.COUNTER_SIZE.length() * 0.5, "what": "COUNTER"})
	out.append({"pos": MapLayout.FREEZER, "r": MapLayout.FREEZER_SIZE.length() * 0.5, "what": "FREEZER"})
	var stations := {"GOLD_PILE": MapLayout.GOLD_PILE, "SIGN": MapLayout.SIGN, "SERVICE_POINT": MapLayout.SERVICE_POINT,
		"FREEZER_ZONE": MapLayout.FREEZER_ZONE, "COUNTER_DROP": MapLayout.COUNTER_DROP}
	for name in stations:
		out.append({"pos": stations[name], "r": MapLayout.STATION_RADIUS, "what": name})
	out.append({"pos": MapLayout.HOME, "r": MapLayout.HERO_RADIUS, "what": "HOME"})
	out.append({"pos": MapLayout.DINER_DOOR, "r": MapLayout.STATION_RADIUS, "what": "DINER_DOOR"})
	out.append({"pos": MapLayout.TIER_SIGN, "r": MapLayout.STATION_RADIUS, "what": "tier sign"})
	for q in MapLayout.QUEUE_SLOTS:
		out.append({"pos": q, "r": MapLayout.HERO_RADIUS, "what": "queue slot"})
	for id in MapLayout.LANE_PATHS:
		var pts: Array = MapLayout.LANE_PATHS[id]
		for i in range(1, pts.size()):
			out.append({"seg": [pts[i - 1], pts[i]], "lateral": LaneStrip.WIDTH * 0.5, "what": "lane %s" % id})
	for id in MapLayout.ZONE_RECTS:
		out.append({"rect": MapLayout.ZONE_RECTS[id], "r": 0.0, "what": "zone %s" % id})
	out.append({"seg": [MapLayout.TRAVELER_ENTER, MapLayout.TRAVELER_EXIT], "lateral": MapLayout.HERO_RADIUS, "what": "traveler path"})
	return out

func _owned_tiers() -> Array:
	return [2]

## The least allowed distance from a prop's centre to `rule` (see _keep_clear).
func _least_distance(rule: Dictionary, radius: float, height: float) -> float:
	var lean := height / tan(deg_to_rad(absf(Balance.ui.camera_pitch)))
	if rule.has("seg"):
		return float(rule.lateral) + radius
	return float(rule.r) + radius + lean

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
				var radius := Props.owned_radius(it.kind, float(it.scale))
				var height := Props.owned_height(it.kind, float(it.scale))
				var inner := (MapLayout.YARDS[id] as Rect2).grow(-(YardStones.WIDTH * 0.5 + radius))
				assert_true(inner.has_point(p), "%s %s inside the %s yard inset by the kerb and its own radius %.2f" % [it.kind, p, id, radius])
				for rule in rules:
					assert_gte(_distance_to(p, rule), _least_distance(rule, radius, height), "tier %d: %s at %s clear of %s" % [tier, it.kind, p, rule.what])
	assert_gt(seen, 6, "props were checked")

func test_owned_prop_dimensions_come_from_the_mesh_builder() -> void:
	# radius and height are the extents of the geometry the builder emits, so a bigger mesh cannot slip past the rules
	for kind in ["crate", "barrel", "bench"]:
		for scale in [1.0, 0.8]:
			var a := Props.owned_arrays([{"kind": kind, "pos": Vector2.ZERO, "rot": 0.0, "scale": scale}])
			var far := 0.0
			var top := 0.0
			for v in a.v as PackedVector3Array:
				far = maxf(far, Vector2(v.x, v.z).length())
				top = maxf(top, v.y)
			assert_lte(far, Props.owned_radius(kind, scale) + 1e-4, "%s radius covers the mesh" % kind)
			assert_gte(far, Props.owned_radius(kind, scale) * 0.7, "%s radius is not wildly loose" % kind)
			assert_almost_eq(top, Props.owned_height(kind, scale), 1e-4, "%s height" % kind)

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
	# behavioural: the hero walks onto a crate, a barrel and a bench (a collider would stop it short)
	main.hero.input.player_control = false
	var picks := [PropsLayout.OWNED["east"][0], PropsLayout.OWNED["west"][1], PropsLayout.OWNED["west"][0]]
	assert_eq(picks.map(func(it): return it.kind), ["crate", "barrel", "bench"])
	for it in picks:
		await TestHelpers.walk_in(main.hero, it.pos)
		assert_lt(main.hero.xz().distance_to(it.pos), 0.1, "the hero stands on the %s at %s" % [it.kind, it.pos])
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
