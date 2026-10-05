extends GutTest
## S4 Task 13 (D-194, D-201): the hand-placed props stand outside the play bounds, on the ground, off every lane,
## and every model is a real baked mesh.

func test_there_are_about_sixty_items() -> void:
	assert_between(PropsLayout.ITEMS.size(), 50, 70)

func test_outside_the_play_bounds_and_on_the_ground() -> void:
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN).grow(1.0)
	var ground := World.ground_rect().grow(-10.0)
	for it in PropsLayout.ITEMS:
		var p: Vector2 = it.pos
		if it.get("near_diner", false):
			continue
		assert_false(play.has_point(p), "%s is outside the play bounds" % p)
		assert_true(ground.has_point(p), "%s is on the ground" % p)

func test_near_diner_items_are_off_every_footprint() -> void:
	var near := PropsLayout.ITEMS.filter(func(it): return it.get("near_diner", false))
	assert_between(near.size(), 4, 6)
	var diner := Rect2(Vector2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF), Vector2.ONE * MapLayout.DINER_HALF * 2.0).grow(1.5)
	for it in near:
		assert_false(diner.has_point(it.pos), "%s clear of the diner" % it.pos)
		assert_true(Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN).has_point(it.pos), "stays near the diner")

func test_off_every_lane_path() -> void:
	for it in PropsLayout.ITEMS:
		for id in MapLayout.LANE_PATHS:
			var pts: Array = MapLayout.LANE_PATHS[id]
			for i in range(1, pts.size()):
				var q := Geometry2D.get_closest_point_to_segment(it.pos, pts[i - 1], pts[i])
				assert_gt(q.distance_to(it.pos), 3.0, "%s is off lane %s" % [it.pos, id])

func test_off_stations_roads_and_spots() -> void:
	var points: Array = [MapLayout.COUNTER, MapLayout.FREEZER, MapLayout.GOLD_PILE, MapLayout.SIGN, MapLayout.HOME, MapLayout.DINER_DOOR]
	points.append_array(MapLayout.QUEUE_SLOTS)
	points.append_array(MapLayout.STATION_PADS.values())
	for id in MapLayout.SPOT_IDS:
		points.append(MapLayout.spot_position(id))
	for it in PropsLayout.ITEMS:
		var p: Vector2 = it.pos
		assert_gt(absf(p.y - MapLayout.ROAD_Z), 2.5, "%s clear of the road" % p)
		for s in points:
			assert_gt(p.distance_to(s), 3.0, "%s clear of %s" % [p, s])

func test_every_model_exists_and_is_a_mesh() -> void:
	for it in PropsLayout.ITEMS:
		assert_true(ResourceLoader.exists(it.model), "%s exists" % it.model)
	for m in PropsLayout.models():
		assert_true(load(m) is ArrayMesh, "%s is a baked mesh" % m)

func test_item_fields() -> void:
	for it in PropsLayout.ITEMS:
		assert_gt(float(it.scale), 0.0)
		assert_true(it.rot is float)

func test_props_node_is_two_static_meshes_without_collision() -> void:
	var props := Props.new()
	add_child_autofree(props)
	props.build()
	var meshes := props.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 2, "castle atlas + tower-defense atlas")
	assert_eq(props.find_children("*", "CollisionObject3D", true, false).size(), 0, "no collision")
	assert_eq(props.find_children("*", "MultiMeshInstance3D", true, false).size(), 0)
	var tris := 0
	for m in meshes:
		assert_true((m as MeshInstance3D).mesh is ArrayMesh)
		assert_eq((m as MeshInstance3D).mesh.get_surface_count(), 1)
		tris += ((m as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var expect := 0
	for it in PropsLayout.ITEMS:
		var mesh := load(it.model) as ArrayMesh
		for i in mesh.get_surface_count():
			expect += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_eq(tris, expect, "every item is in the merge")
