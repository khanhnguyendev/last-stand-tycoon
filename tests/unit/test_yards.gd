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
	assert_eq(main.world.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.name.begins_with("Yard")).size(), 0, "no collision on yards or stones")

func test_debug_set_tier_updates_the_world_too() -> void:
	GameState.debug_set_tier(2, 3)
	assert_eq(main.world.yard_ids(), ["west", "east"])
	assert_true(main.world.build_spots.has("tower_w"))
	assert_not_null(main.world.get_node_or_null("YardStones"))
	GameState.debug_set_tier(2, 3)
	assert_eq(main.world.find_children("YardStones", "", true, false).size(), 1, "a repeat tier_changed rebuilds nothing")

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
	while GameState.gold > 0:
		await get_tree().physics_frame
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
