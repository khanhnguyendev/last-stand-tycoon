extends GutTest
## The procedural coin (S4 Task 15 follow-up): one surface, a small triangle count, cached, gold palette colours.

func test_one_surface_and_few_triangles() -> void:
	var m := CoinMesh.get_mesh()
	assert_eq(m.get_surface_count(), 1)
	var tris := m.surface_get_array_len(0) / 3
	assert_lte(tris, 300)
	assert_gt(tris, 100)

func test_cached() -> void:
	assert_same(CoinMesh.get_mesh(), CoinMesh.get_mesh())

func test_size_and_material() -> void:
	var box := CoinMesh.get_mesh().get_aabb()
	assert_almost_eq(box.size.x, 0.3, 0.005)
	assert_almost_eq(box.size.y, 0.3, 0.03)
	assert_lt(box.size.z, 0.07)
	assert_gt(box.size.z, 0.04)
	var mat := CoinMesh.get_mesh().surface_get_material(0) as StandardMaterial3D
	assert_not_null(mat)
	assert_true(mat.vertex_color_use_as_albedo)
	assert_true(mat.vertex_color_is_srgb)
	assert_eq(mat.roughness, 1.0)

func test_vertex_colours_are_only_gold_and_gold_dark() -> void:
	var cols: PackedColorArray = CoinMesh.get_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var ok := [Palette.color(&"gold").to_html(false), Palette.color(&"gold_dark").to_html(false)]
	for c in cols:
		assert_true(c.to_html(false) in ok, c.to_html(false))
		if not c.to_html(false) in ok:
			break

func test_coin_scene_uses_the_shared_mesh() -> void:
	var root: Node = (load("res://art/pickups/coin.tscn") as PackedScene).instantiate()
	var mi := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_same(mi.mesh, CoinMesh.get_mesh())
	root.free()
