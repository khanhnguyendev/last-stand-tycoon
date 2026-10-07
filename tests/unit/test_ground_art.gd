extends GutTest
## S4 Task 13 (D-194, D-201): the ground, road and lane strips are single meshes with palette vertex colours; the edge
## stones and props are MultiMeshes; the position hash is deterministic and varies.

func test_hash_is_deterministic_and_varies() -> void:
	assert_eq(GroundArt.hash01(3.0, 4.0), GroundArt.hash01(3.0, 4.0))
	var seen := {}
	for i in 20:
		var h := GroundArt.hash01(i * 2.0, 6.0)
		assert_between(h, 0.0, 1.0)
		seen[snappedf(h, 0.01)] = true
	assert_gt(seen.size(), 10, "the hash varies cell to cell")

func test_ground_colours_stay_between_grass_and_grass_dark() -> void:
	var lo := Palette.color(&"grass_dark")
	var hi := Palette.color(&"grass")
	for i in 30:
		var c := GroundArt.grass_at(i * 2.0, -i * 2.0)
		assert_between(c.g, lo.g - 0.001, hi.g + 0.001)
		assert_between(c.r, lo.r - 0.001, hi.r + 0.001)

func test_ground_mesh_covers_the_rect_in_one_surface() -> void:
	var rect := World.ground_rect()
	var m := GroundArt.ground_mesh(rect)
	assert_eq(m.get_surface_count(), 1)
	var a := m.get_aabb()
	assert_almost_eq(a.position.x, rect.position.x, 0.01)
	assert_almost_eq(a.end.x, rect.end.x, 0.01)
	assert_almost_eq(a.position.z, rect.position.y, 0.01)
	assert_almost_eq(a.end.z, rect.end.y, 0.01)
	assert_true(GroundArt.material().vertex_color_is_srgb)

func test_ground_faces_up_in_godot_winding() -> void:
	var m := GroundArt.ground_mesh(Rect2(0, 0, 4, 4))
	var arrays := m.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in idx.size() / 3:
		var a := v[idx[t * 3]]
		assert_lt((v[idx[t * 3 + 1]] - a).cross(v[idx[t * 3 + 2]] - a).y, 0.0, "clockwise from above is front-facing")

func test_lane_strip_faces_up_for_every_lane() -> void:
	for id in MapLayout.LANE_PATHS:
		var m := LaneStrip.build_mesh(MapLayout.LANE_PATHS[id])
		assert_eq(m.get_surface_count(), 1)
		var arrays := m.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var a := v[idx[t * 3]]
			assert_lt((v[idx[t * 3 + 1]] - a).cross(v[idx[t * 3 + 2]] - a).y, 0.0, "%s faces up" % id)

func test_edge_stones_flank_the_strip() -> void:
	for id in MapLayout.LANE_PATHS:
		var xfs := LaneStrip.edge_transforms(MapLayout.LANE_PATHS[id])
		assert_gt(xfs.size(), 10)
		var pts: Array = MapLayout.LANE_PATHS[id]
		for xf in xfs:
			var p := Vector2(xf.origin.x, xf.origin.z)
			assert_false(LaneStrip.STONE_SKIP.has_point(p), "%s: no stone inside the diner rect" % p)
			var best := 1e9
			for i in range(1, pts.size()):
				best = minf(best, Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i]).distance_to(p))
			assert_between(best, 1.5, 2.0, "outside the 3 m strip, next to it")

func test_ground_cache_returns_the_same_mesh() -> void:
	assert_same(GroundArt.terrain_mesh(World.ground_rect()), GroundArt.terrain_mesh(World.ground_rect()))

func test_world_static_draws() -> void:
	Balance.reset()
	var main: Main = Main.create()
	add_child_autofree(main)
	var w := main.world
	var terrain := w.get_node("Ground") as MeshInstance3D
	assert_eq(terrain.mesh.get_surface_count(), 1, "ground + road + lane strips: one surface")
	assert_null(w.get_node_or_null("Road"), "the road is part of the ground mesh")
	var stones := w.get_node("EdgeStones") as MultiMeshInstance3D
	assert_gt(stones.multimesh.instance_count, 30)
	for id in w.lanes:
		assert_eq((w.lanes[id] as Node3D).find_children("*", "MeshInstance3D", false, false).size(), 0, "lanes draw nothing themselves")
		assert_eq((w.lanes[id] as Node3D).find_children("*", "MultiMeshInstance3D", false, false).size(), 0)
	assert_eq(w.props.find_children("*", "MeshInstance3D", false, false).size(), 2)
	assert_eq(w.lighting.get_class(), "Node")

func _array_hash(a) -> int:
	return hash(a.to_byte_array().hex_encode())

## E5 Task 10 ruling 6: the tier-1 terrain (no yards) is byte-identical to the S4 ground, pinned from the pre-E5 build.
func test_tier1_terrain_is_unchanged_by_the_yards_feature() -> void:
	var m := GroundArt.terrain_mesh(World.ground_rect(), [])
	assert_eq(m, GroundArt.terrain_mesh(World.ground_rect()), "the default argument is the same cached mesh")
	var a := m.surface_get_arrays(0)
	assert_eq((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 10536)
	assert_eq((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 61872)
	assert_eq(_array_hash(a[Mesh.ARRAY_VERTEX]), 2768925050)
	assert_eq(_array_hash(a[Mesh.ARRAY_COLOR]), 599500315)
	assert_eq(_array_hash(a[Mesh.ARRAY_INDEX]), 1529329421)

func test_yard_cells_are_paved_and_inside_the_rect() -> void:
	var r := Rect2(2, 2, 4, 6)
	var a := GroundArt.yard_arrays(r)
	assert_gt((a.v as PackedVector3Array).size(), 0)
	var cream := Palette.color(&"diner_cream")
	var stone := Palette.color(&"stone")
	for i in (a.v as PackedVector3Array).size():
		var v: Vector3 = a.v[i]
		assert_true(r.grow(1e-4).has_point(Vector2(v.x, v.z)), str(v))
		assert_almost_eq(v.y, GroundArt.YARD_Y, 1e-6)
		var c: Color = a.c[i]
		assert_true(c.is_equal_approx(cream.lerp(stone, GroundArt.hash01(v.x, v.z) * 0.4)), "paved: cream hashed toward stone, palette only")

func test_terrain_with_yards_is_one_surface_and_cached() -> void:
	var m := GroundArt.terrain_mesh(World.ground_rect(), ["west"])
	assert_eq(m.get_surface_count(), 1)
	assert_eq(m, GroundArt.terrain_mesh(World.ground_rect(), ["west"]))
	assert_ne(m, GroundArt.terrain_mesh(World.ground_rect(), []))

func test_yard_stones_ring_the_outline() -> void:
	var r: Rect2 = MapLayout.YARDS["west"]
	var xfs := YardStones.transforms(r)
	assert_gt(xfs.size(), 10)
	for xf in xfs:
		var p := Vector2(xf.origin.x, xf.origin.z)
		assert_lte(Geometry.dist_point_rect(p, r), 0.4, "on the outline")
		assert_gte(Geometry.dist_point_rect(p, r.grow(-0.5)), 0.1, "not inside the yard")

func test_yard_stones_keep_clear_of_the_tier_sign() -> void:
	var r: Rect2 = MapLayout.YARDS["west"]
	for xf in YardStones.transforms(r):
		assert_gte(Vector2(xf.origin.x, xf.origin.z).distance_to(MapLayout.TIER_SIGN), YardStones.SIGN_CLEAR)
	# A synthetic rect whose top edge passes 0.2 m from the sign: 6 x 3 m gives 2 * (5 + 2) = 14 stones without the guard.
	var near := Rect2(MapLayout.TIER_SIGN - Vector2(3, 0.2), Vector2(6, 3))
	var xfs := YardStones.transforms(near)
	assert_lt(xfs.size(), 14, "the stone under the sign is dropped")
	assert_gt(xfs.size(), 10, "the rest of the ring stays")
	for xf in xfs:
		assert_gte(Vector2(xf.origin.x, xf.origin.z).distance_to(MapLayout.TIER_SIGN), YardStones.SIGN_CLEAR)
