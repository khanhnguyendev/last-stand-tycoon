extends GutTest
## S4 Task 11 (D-194, D-201): the diner, counter and freezer art. One baked mesh each, within budget, no physics, the
## roof top where the Archer stands, and the committed bake equals a fresh bake of its source scene.

const Bake := preload("res://tools/bake_static.gd")
const SCENES := {
	"res://art/env/diner.tscn": ["res://art/env/src/diner_src.tscn", "res://art/env/baked/diner.res", 3],
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
			for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
				var fa: PackedVector3Array = a[k]
				var fb: PackedVector3Array = b[k]
				assert_eq(fa.size(), fb.size(), "%s surface %d array %d size" % [path, s, k])
				var off := 0
				for i in mini(fa.size(), fb.size()):
					if not fa[i].is_equal_approx(fb[i]):
						off += 1
				assert_eq(off, 0, "%s surface %d array %d: vertices that differ from the fresh bake" % [path, s, k])
			assert_eq(fresh.surface_get_material(s), committed.surface_get_material(s), "%s surface %d material" % [path, s])
