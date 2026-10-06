extends GutTest
## S4 Task 11 (D-194, D-201): the diner, counter and freezer art. One baked mesh each, within budget, no physics, the
## roof top where the Archer stands, and the committed bake equals a fresh bake of its source scene.

## A stale bake moves vertices by cm. Cross-platform noise: positions < 1e-4; normals ~1.2e-4 (compressed normal
## encoding differs between macOS arm64 and Linux x86), so normals get 2e-3.
const BAKE_TOL := 1e-4
const BAKE_NORMAL_TOL := 2e-3

const Bake := preload("res://tools/bake_static.gd")
const SCENES := {
	"res://art/env/diner.tscn": ["res://art/env/src/diner_src.tscn", "res://art/env/baked/diner.res", 3],
	"res://art/env/diner_t2.tscn": ["res://art/env/src/diner_t2_src.tscn", "res://art/env/baked/diner_t2.res", 3],
	"res://art/env/counter_visual.tscn": ["res://art/env/src/counter_src.tscn", "res://art/env/baked/counter.res", 1],
	"res://art/env/freezer_visual.tscn": ["res://art/env/src/freezer_src.tscn", "res://art/env/baked/freezer.res", 1],
}

func _inst(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n

func _body(n: Node) -> MeshInstance3D:
	return n.get_node("Body") as MeshInstance3D

func test_diner_instantiates_with_board() -> void:
	var d := _inst("res://art/env/diner.tscn")
	assert_eq(d.name, &"DinerArt")
	var board := d.get_node("Board") as WorldLabel
	assert_not_null(board, "the Board is a WorldLabel")
	assert_eq(board.text, tr("DINER"))

func test_no_physics_and_no_multimesh() -> void:
	for path in SCENES:
		var n := _inst(path)
		assert_eq(n.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s: no CollisionObject3D (validator rule 6)" % path)
		assert_eq(n.find_children("*", "MultiMeshInstance3D", true, false).size(), 0, "%s: no MultiMeshInstance3D (D-194)" % path)

func test_one_mesh_and_surfaces_within_target() -> void:
	for path in SCENES:
		var n := _inst(path)
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		assert_eq(meshes.size(), 1, "%s: one MeshInstance3D" % path)
		var surfaces := 0
		for m in meshes:
			surfaces += (m as MeshInstance3D).mesh.get_surface_count()
		assert_between(surfaces, 1, int(SCENES[path][2]), "%s: draws (D-201)" % path)

func test_diner_within_triangle_budget() -> void:
	var d := _inst("res://art/env/diner.tscn")
	var budget := ArtBudgets.budget_for("res://art/env/diner.tscn")
	assert_eq(budget, 12000)
	assert_between(AssetValidator.count_triangles(d), 1, budget)

func test_every_surface_uses_a_shared_material() -> void:
	for path in SCENES:
		var mesh := _body(_inst(path)).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			assert_not_null(mat, "%s surface %d has a material" % [path, i])
			if mat != null:
				assert_true(mat.resource_path.begins_with("res://art/materials/"), "%s surface %d: %s" % [path, i, mat.resource_path])

## Area of the upward-facing triangles whose three vertices lie in [y0, y1].
func _flat_area(mesh: ArrayMesh, y0: float, y1: float) -> float:
	var area := 0.0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var a := v[idx[t * 3]]
			var b := v[idx[t * 3 + 1]]
			var c := v[idx[t * 3 + 2]]
			if minf(a.y, minf(b.y, c.y)) < y0 or maxf(a.y, maxf(b.y, c.y)) > y1:
				continue
			var n := (b - a).cross(c - a)
			if n.y < 0.0:  # Godot's front faces wind clockwise, so the outward normal is the negated cross
				area += n.length() * 0.5
	return area

func test_roof_top_is_the_archer_perch() -> void:
	var mesh := _body(_inst("res://art/env/diner.tscn")).mesh as ArrayMesh
	var flat := _flat_area(mesh, MapLayout.DINER_HEIGHT - 0.05, MapLayout.DINER_HEIGHT + 0.05)
	assert_gt(flat, 50.0, "an 8 m roof surface faces up at y = 3.0 +- 0.05 (the Archer stands there)")
	var archer := MapLayout.guard_post(&"archer")
	assert_lt(absf(archer.x), MapLayout.DINER_HALF - 0.6, "the perch is clear of the parapet")
	assert_lt(absf(archer.y), MapLayout.DINER_HALF - 0.6)

func test_diner_footprint_and_height() -> void:
	var bb := _body(_inst("res://art/env/diner.tscn")).get_aabb()
	assert_between(bb.position.x, -4.5, -3.9)
	assert_between(bb.end.x, 3.9, 4.5)
	assert_between(bb.position.z, -4.5, -3.9)
	assert_between(bb.end.z, 3.9, 4.5, "the awning is a lip, not a porch (hero at the counter must not fade it)")
	assert_between(bb.position.y, -0.01, 0.01)
	assert_gt(bb.end.y, MapLayout.DINER_HEIGHT + 0.3, "a parapet stands above the roof")

func test_counter_and_freezer_match_their_footprints() -> void:
	var c := _body(_inst("res://art/env/counter_visual.tscn")).get_aabb()
	assert_almost_eq(c.end.y, 1.0, 0.05, "counter top at 1.0 m")
	assert_almost_eq(c.size.x, MapLayout.COUNTER_SIZE.x, 0.2)
	assert_almost_eq(c.size.z, MapLayout.COUNTER_SIZE.y, 0.2)
	var f := _body(_inst("res://art/env/freezer_visual.tscn")).get_aabb()
	assert_almost_eq(f.end.y, 1.4, 0.05, "fridge about 1.4 m")
	assert_lt(f.size.x, MapLayout.FREEZER_SIZE.x + 0.1)
	assert_lt(f.size.z, MapLayout.FREEZER_SIZE.y + 0.1)

func test_committed_bake_is_current() -> void:
	for path in SCENES:
		var src := (load(SCENES[path][0]) as PackedScene).instantiate() as Node3D
		add_child_autofree(src)
		var fresh: ArrayMesh = Bake.bake(src)
		var committed := load(SCENES[path][1]) as ArrayMesh
		assert_eq(fresh.get_surface_count(), committed.get_surface_count(), "%s surfaces" % path)
		for s in mini(fresh.get_surface_count(), committed.get_surface_count()):
			var a := fresh.surface_get_arrays(s)
			var b := committed.surface_get_arrays(s)
			assert_true(a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX], "%s surface %d indices are current: rerun tools/bake_static.gd --all" % [path, s])
			assert_true(a[Mesh.ARRAY_TEX_UV] == b[Mesh.ARRAY_TEX_UV], "%s surface %d UVs" % [path, s])
			assert_true(a[Mesh.ARRAY_COLOR] == b[Mesh.ARRAY_COLOR], "%s surface %d vertex colours" % [path, s])
			for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
				var fa: PackedVector3Array = a[k]
				var fb: PackedVector3Array = b[k]
				assert_eq(fa.size(), fb.size(), "%s surface %d array %d size" % [path, s, k])
				var off := 0
				for i in mini(fa.size(), fb.size()):
					if fa[i].distance_to(fb[i]) > (BAKE_NORMAL_TOL if k == Mesh.ARRAY_NORMAL else BAKE_TOL):
						off += 1
				assert_eq(off, 0, "%s surface %d array %d: vertices that differ from the fresh bake" % [path, s, k])
			assert_eq(fresh.surface_get_material(s), committed.surface_get_material(s), "%s surface %d material" % [path, s])

func test_tall_vertices_lie_inside_the_occluder_boxes() -> void:
	var d := _inst("res://art/env/diner.tscn")
	var boxes: Array[AABB] = d.occluder_boxes
	var mesh := _body(d).mesh
	var outside := 0
	var tall := 0
	for s in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if v.y <= 3.45:
				continue
			tall += 1
			var inside := false
			for b in boxes:
				if b.grow(0.05).has_point(v):
					inside = true
					break
			if not inside:
				outside += 1
	assert_gt(tall, 0, "the diner has vertices above the parapet")
	assert_eq(outside, 0, "vertices above y 3.45 outside every DinerArt.occluder_boxes (grown 0.05): the boxes drifted from the art")


# ---- E5 Task 11: the tier-2 diner (terraces on the flanks, four short corner awnings) ----

func _triangles(mesh: ArrayMesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n

func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out

func test_tier2_diner_keeps_the_footprint_and_adds_the_flanks() -> void:
	var t1: ArrayMesh = load("res://art/env/baked/diner.res")
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var a1 := t1.get_aabb()
	var a2 := t2.get_aabb()
	assert_almost_eq(a2.size.y, a1.size.y, 0.3, "same height class")
	assert_gt(a2.size.x, a1.size.x + 1.0, "terraces and awnings widen the look")
	assert_lte(a2.size.x, 11.3, "but stay inside the yards' inner edges")
	assert_lte(_triangles(t2), ArtBudgets.budget_for("res://art/env/diner"))

func test_tier2_diner_surfaces_use_shared_materials() -> void:
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	for i in t2.get_surface_count():
		var m := t2.surface_get_material(i)
		assert_not_null(m)
		assert_true(m.resource_path.begins_with("res://art/materials/"), m.resource_path)

func test_tier2_diner_adds_nothing_tall_over_a_lane_zone() -> void:
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var checked := 0
	for v in _vertices(t2):
		if v.y <= 0.3:
			continue
		if not (absf(v.x) > 4.0 + 1e-3 or v.z < -4.0 - 1e-3):
			continue
		checked += 1
		for id in MapLayout.ZONE_RECTS:
			var d := Geometry.dist_point_rect(Vector2(v.x, v.z), MapLayout.ZONE_RECTS[id])
			assert_gte(d, 0.5, "vertex %s is %.2f m from the %s zone" % [v, d, id])
			# Where the camera sees it land on the ground: a point at height y projects north by y / tan(pitch).
			var lean := v.y * tan(deg_to_rad(90.0 - absf(Balance.ui.camera_pitch)))
			var dp := Geometry.dist_point_rect(Vector2(v.x, v.z - lean), MapLayout.ZONE_RECTS[id])
			assert_gte(dp, 0.3, "vertex %s seen from the camera lands %.2f m from the %s zone" % [v, dp, id])
	assert_gt(checked, 0, "the awnings exist")

func test_tier2_diner_stays_inside_its_envelope() -> void:
	var a1: AABB = (load("res://art/env/baked/diner.res") as ArrayMesh).get_aabb()
	var a2: AABB = (load("res://art/env/baked/diner_t2.res") as ArrayMesh).get_aabb()
	assert_gte(a2.position.x, -5.65)
	assert_lte(a2.end.x, 5.65)
	assert_lte(a2.end.y, a1.end.y + 1e-3, "nothing rises above the tier-1 diner")
	assert_almost_eq(a2.position.z, a1.position.z, 1e-3)
	assert_almost_eq(a2.end.z, a1.end.z, 1e-3)

func _diner_body_mesh(main: Node) -> MeshInstance3D:
	return main.world.diner_body.get_node("Visual").get_node("DinerArt").get_node("Body") as MeshInstance3D

func test_world_swaps_the_diner_on_tier_reached() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(1)
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner.res")
	GameState.debug_set_tier(2, 1)
	await get_tree().process_frame
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner_t2.res")
	var vis := main.world.diner_body.get_node("Visual")
	assert_not_null(vis.get_node_or_null("OccluderFade"), "the fade survives the swap")
	assert_eq(vis.get_child(0).name, &"DinerArt", "the art stays child 0")
	var shape: BoxShape3D = main.world.diner_body.find_children("*", "CollisionShape3D", false, false)[0].shape
	assert_eq(shape.size, Vector3(8, 3, 8), "collision never changes")
	GameState.new_game(3)
	await get_tree().process_frame
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner.res", "a new game is tier 1 again")
	assert_eq(World.diner_scene_for(1), World.DINER_ART)
	assert_eq(World.diner_scene_for(2), World.DINER_ART_T2)

func test_swapping_the_diner_while_faded_ends_opaque() -> void:
	var main := Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(72)
	var fade: OccluderFade = main.world.diner_body.get_node("Visual/OccluderFade")
	main.hero.teleport((MapLayout.ZONE_RECTS["north"] as Rect2).get_center())
	main.camera_rig.snap()
	for i in 30:
		await get_tree().process_frame
	assert_true(fade.is_faded(), "the diner is faded")
	GameState.debug_set_tier(2, 1)
	await get_tree().process_frame
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner_t2.res")
	main.hero.teleport(MapLayout.HOME)
	main.camera_rig.snap()
	for i in 40:
		await get_tree().process_frame
	assert_false(fade.is_faded())
	var body := _diner_body_mesh(main)
	assert_null(body.material_override)
	for i in body.mesh.get_surface_count():
		assert_null(body.get_surface_override_material(i), "surface %d is back to its shared material" % i)

func test_tier2_terraces_are_diner_cream() -> void:
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var want := Palette.color(&"diner_cream")
	var checked := 0
	for s in t2.get_surface_count():
		var arr := t2.surface_get_arrays(s)
		var img := ((t2.surface_get_material(s) as BaseMaterial3D).albedo_texture as Texture2D).get_image()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in v.size():
			if v[i].y > 0.13 or absf(v[i].x) <= 4.0 + 1e-3:
				continue
			checked += 1
			var c := img.get_pixel(clampi(int(uv[i].x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv[i].y * img.get_height()), 0, img.get_height() - 1))
			assert_lt(absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b), 0.03, "vertex %s samples %s, not diner_cream" % [v[i], c])
	assert_gt(checked, 0, "the terraces exist")
