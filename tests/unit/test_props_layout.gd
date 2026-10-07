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

## E5 tier 3 (Task 8): the hand-placed props stay off the south-west lane, the tier-3 service layout and the tier-3 spots, and the
## open front lot hides the ones it would stand on.
func test_off_the_tier_3_lane_and_layout() -> void:
	# the props left once the open yards (including the front lot) have hidden the ones standing on them
	var yards: Array[Rect2] = []
	for id in MapLayout.yards_for_tier(3):
		yards.append(MapLayout.yard_rect(id))
	var pts: Array = MapLayout.lane_path("sw")
	var points: Array = [MapLayout.tier_sign(3), MapLayout.fence_spot("sw"), MapLayout.tower_spot("tower_sw")]
	points.append_array(MapLayout.queue_slots(3))
	for id in MapLayout.BRANCH_PADS:
		points.append_array(MapLayout.BRANCH_PADS[id])
	var items := Props.items_for(yards)
	assert_gt(items.size(), 40)
	for it in items:
		for i in range(1, pts.size()):
			var q := Geometry2D.get_closest_point_to_segment(it.pos, pts[i - 1], pts[i])
			assert_gte(q.distance_to(it.pos), 3.0, "%s is off the sw lane" % it.pos)
		for s in points:
			assert_gt(it.pos.distance_to(s), 3.0, "%s clear of the tier-3 point %s" % [it.pos, s])
		assert_gt(absf(it.pos.y - MapLayout.ROAD_Z), 2.5, "%s clear of the road" % it.pos)

func test_the_open_front_lot_hides_the_props_it_would_hold() -> void:
	var front := MapLayout.yard_rect("front")
	var before := PropsLayout.ITEMS.filter(func(it): return Geometry.dist_point_rect(it.pos, front) <= 1.0)
	var items := Props.items_for([front])
	for it in items:
		assert_gt(Geometry.dist_point_rect(it.pos, front), 1.0, "%s clear of the front lot" % it.pos)
	assert_eq(items.size(), PropsLayout.ITEMS.size() - before.size(), "exactly the props within 1 m of the lot go")

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

## E5 tier 3 Task 2: owned-land props are keyed by yard id, only for the open yards, outside the hand-placed layout.
func test_owned_props_are_keyed_by_yard() -> void:
	for id in PropsLayout.OWNED:
		assert_true(MapLayout.all_yards().has(id), "%s is a yard id" % id)
	var west: Array = PropsLayout.owned_for(["west"])
	assert_eq(west.size(), PropsLayout.OWNED["west"].size())
	assert_eq(PropsLayout.owned_for([]).size(), 0, "no open yard, no owned props")
	for it in PropsLayout.OWNED["east"]:
		assert_true(it.kind in ["crate", "barrel", "bench"])
		assert_true((MapLayout.YARDS["east"] as Rect2).has_point(it.pos))

func test_owned_mesh_is_palette_coloured_wound_outward_and_small() -> void:
	var a := Props.owned_arrays(PropsLayout.OWNED["west"])
	var verts: PackedVector3Array = a.v
	var normals: PackedVector3Array = a.n
	var idx: PackedInt32Array = a.i
	assert_gt(idx.size(), 0)
	var palette := Palette.hex_set()
	for t in idx.size() / 3:
		var p0 := verts[idx[t * 3]]
		var p1 := verts[idx[t * 3 + 1]]
		var p2 := verts[idx[t * 3 + 2]]
		assert_lt((p1 - p0).cross(p2 - p0).dot(normals[idx[t * 3]]), 0.0, "front face is clockwise seen from outside")
	for c in a.c:
		assert_true(palette.has((c as Color).to_html(false)), "palette colour %s" % c)
	for v in verts:
		assert_lt(v.y, 1.0)

## Winding against an oracle that is not the builder's own normal: on a crate or barrel side face the stored normal points
## away from the item centre, and the geometric (clockwise) face normal points toward it.
func test_side_faces_point_away_from_the_item_centre() -> void:
	for kind in ["crate", "barrel"]:
		var centre := Vector2(3.0, -2.0)
		var a := Props.owned_arrays([{"kind": kind, "pos": centre, "rot": 0.7, "scale": 1.0}])
		var verts: PackedVector3Array = a.v
		var normals: PackedVector3Array = a.n
		var idx: PackedInt32Array = a.i
		var sides := 0
		for t in idx.size() / 3:
			var p0 := verts[idx[t * 3]]
			var p1 := verts[idx[t * 3 + 1]]
			var p2 := verts[idx[t * 3 + 2]]
			var n: Vector3 = normals[idx[t * 3]]
			if absf(n.y) > 0.5:
				continue
			sides += 1
			var out := (p0 + p1 + p2) / 3.0 - Vector3(centre.x, 0.0, centre.y)
			out.y = 0.0
			assert_gt(n.dot(out), 0.0, "%s: the stored normal points away from the centre" % kind)
			var geometric := (p1 - p0).cross(p2 - p0)
			assert_lt(geometric.dot(out), 0.0, "%s: clockwise from outside, so the right-hand normal points inward" % kind)
		assert_gt(sides, 8, "%s has side faces" % kind)
