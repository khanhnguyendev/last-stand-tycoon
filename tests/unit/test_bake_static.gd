extends GutTest
## S4 Task 11a (D-201): tools/bake_static.gd merges a static node tree into one surface per material.

const Bake := preload("res://tools/bake_static.gd")

var _mat_a := StandardMaterial3D.new()
var _mat_b := StandardMaterial3D.new()

func _mi(mesh: Mesh, mat: Material, xf: Transform3D, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi

func _box(size := Vector3.ONE) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _sphere() -> SphereMesh:
	var s := SphereMesh.new()
	s.radial_segments = 16
	s.rings = 8
	return s

func _tris(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n

## Two boxes on material A (one under a scaled parent) and a sphere on material B.
func _fixture() -> Node3D:
	var root := Node3D.new()
	_mi(_box(), _mat_a, Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)), root)
	var parent := Node3D.new()
	parent.transform = Transform3D(Basis.from_scale(Vector3(2, 2, 2)), Vector3(0, 3, 0))
	root.add_child(parent)
	_mi(_box(Vector3(1, 2, 3)), _mat_a, Transform3D(Basis.from_scale(Vector3(1, 0.5, 1)), Vector3(0.5, 0, 0)), parent)
	_mi(_sphere(), _mat_b, Transform3D(Basis.from_scale(Vector3(1.5, 1.5, 1.5)), Vector3(-2, 1, 4)), root)
	return root

func test_one_surface_per_material() -> void:
	var root := _fixture()
	var mesh: ArrayMesh = Bake.bake(root)
	assert_eq(mesh.get_surface_count(), 2)
	assert_eq(mesh.surface_get_material(0), _mat_a, "first appearance order")
	assert_eq(mesh.surface_get_material(1), _mat_b)
	root.free()

func test_triangle_count_is_the_sum() -> void:
	var root := _fixture()
	var expected := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		expected += _tris((mi as MeshInstance3D).mesh)
	assert_eq(_tris(Bake.bake(root)), expected)
	root.free()

func test_aabb_matches_merged_source() -> void:
	var root := _fixture()
	var expected := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := m.transform
		if m.get_parent() != root:
			xf = (m.get_parent() as Node3D).transform * xf
		var bb := xf * m.mesh.get_aabb()
		expected = bb if first else expected.merge(bb)
		first = false
	var got := (Bake.bake(root) as ArrayMesh).get_aabb()
	assert_lt(got.position.distance_to(expected.position), 1e-4)
	assert_lt(got.size.distance_to(expected.size), 1e-4)
	root.free()

func test_normals_unit_and_outward_on_non_uniform_scale() -> void:
	var root := Node3D.new()
	var center := Vector3(0, 3, 0)
	_mi(_box(), _mat_a, Transform3D(Basis.from_scale(Vector3(4, 1, 0.5)), center), root)
	var arr := (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var checked_x := 0
	for i in v.size():
		assert_almost_eq(n[i].length(), 1.0, 1e-4)
		assert_gt(n[i].dot(v[i] - center), 0.0, "outward")
		if n[i].x > 0.9:  # the +X face: it stays axis aligned, at x = +2 (half of the 4x scale)
			assert_almost_eq(v[i].x, 2.0, 1e-4)
			checked_x += 1
	assert_eq(checked_x, 4)
	root.free()

## Sign of dot(geometric normal, vertex normal) for every triangle.
func _winding_signs(arr: Array) -> Array:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out: Array = []
	for t in idx.size() / 3:
		var a := idx[t * 3]
		var b := idx[t * 3 + 1]
		var c := idx[t * 3 + 2]
		out.append(signf((v[b] - v[a]).cross(v[c] - v[a]).dot(n[a])))
	return out

func test_negative_scale_keeps_outward_normals_and_winding() -> void:
	var src := _box()
	var src_signs := _winding_signs(src.get_mesh_arrays())
	var root := Node3D.new()
	var center := Vector3(1, 1, 1)
	_mi(src, _mat_a, Transform3D(Basis.from_scale(Vector3(-2, 1, 1)), center), root)
	var arr := (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in v.size():
		assert_gt(n[i].dot(v[i] - center), 0.0, "outward")
	assert_eq(_winding_signs(arr), src_signs, "winding agrees with normals as in the source")
	root.free()

func test_hidden_piece_is_excluded() -> void:
	var root := _fixture()
	var before := _tris(Bake.bake(root))
	var hidden := _mi(_sphere(), _mat_b, Transform3D.IDENTITY, root)
	hidden.visible = false
	var hidden_parent := Node3D.new()
	hidden_parent.visible = false
	root.add_child(hidden_parent)
	_mi(_box(), _mat_a, Transform3D.IDENTITY, hidden_parent)
	assert_eq(_tris(Bake.bake(root)), before)
	root.free()

func test_deterministic() -> void:
	var root := _fixture()
	var a := Bake.bake(root) as ArrayMesh
	var b := Bake.bake(root) as ArrayMesh
	assert_eq(a.get_surface_count(), b.get_surface_count())
	for s in a.get_surface_count():
		assert_eq(a.surface_get_arrays(s), b.surface_get_arrays(s))
	root.free()

func test_uvs_and_colors_are_kept() -> void:
	var root := Node3D.new()
	_mi(_box(), _mat_a, Transform3D.IDENTITY, root)
	var arr := (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)
	assert_eq((arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size(), (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	root.free()

func _inside(p: Vector3, box: AABB) -> bool:
	return box.grow(1e-4).has_point(p)

func test_index_offsets_across_boxes_on_one_material() -> void:
	var root := Node3D.new()
	var xfs := [Transform3D(Basis.from_scale(Vector3(1, 1, 1)), Vector3(10, 0, 0)),
		Transform3D(Basis.from_scale(Vector3(2, 3, 1)), Vector3(-10, 5, 0))]
	var meshes := [_box(), _box(Vector3(1, 2, 3))]
	var boxes: Array[AABB] = []
	for i in 2:
		_mi(meshes[i], _mat_a, xfs[i], root)
		boxes.append(xfs[i] * (meshes[i] as Mesh).get_aabb())
	var arr := (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	assert_eq(idx.size() / 3, 24)
	for t in idx.size() / 3:
		var hits := 0
		for b in boxes:
			if _inside(v[idx[t * 3]], b) and _inside(v[idx[t * 3 + 1]], b) and _inside(v[idx[t * 3 + 2]], b):
				hits += 1
		assert_eq(hits, 1, "triangle %d lies in exactly one box" % t)
	root.free()

func test_normals_use_the_inverse_transpose() -> void:
	var root := Node3D.new()
	var center := Vector3(1, 2, 3)
	_mi(_sphere(), _mat_a, Transform3D(Basis.from_scale(Vector3(4, 1, 1)), center), root)
	var arr := (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in v.size():
		var p := v[i] - center
		assert_gt(n[i].dot(Vector3(p.x / 16.0, p.y, p.z).normalized()), 0.999)
	root.free()

func test_material_sources_and_order() -> void:
	var root := Node3D.new()
	var plain := MeshInstance3D.new()  # mesh material A
	plain.mesh = _box()
	plain.mesh.surface_set_material(0, _mat_a)
	root.add_child(plain)
	var surf := MeshInstance3D.new()  # surface override B over mesh material A
	surf.mesh = _box()
	surf.mesh.surface_set_material(0, _mat_a)
	surf.set_surface_override_material(0, _mat_b)
	root.add_child(surf)
	var over := MeshInstance3D.new()  # material_override A over surface override B
	over.mesh = _box()
	over.set_surface_override_material(0, _mat_b)
	over.material_override = _mat_a
	root.add_child(over)
	var none := MeshInstance3D.new()  # no material
	none.mesh = _box()
	root.add_child(none)
	var mesh := Bake.bake(root) as ArrayMesh
	assert_eq(mesh.get_surface_count(), 3)
	assert_eq(mesh.surface_get_material(0), _mat_a)
	assert_eq(mesh.surface_get_material(1), _mat_b)
	assert_null(mesh.surface_get_material(2))
	assert_eq(_tris(mesh), 48)
	assert_eq((mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, 24, "plain + override A")
	root.free()

func _colored_triangle() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func test_uvs_equal_source_and_colors_backfill_white() -> void:
	var src := _box()
	var root := Node3D.new()
	_mi(src, _mat_a, Transform3D.IDENTITY, root)
	_mi(_colored_triangle(), _mat_a, Transform3D.IDENTITY, root)
	var arr := (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)
	var src_arr := src.get_mesh_arrays()
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var src_uv: PackedVector2Array = src_arr[Mesh.ARRAY_TEX_UV]
	for i in src_uv.size():
		assert_eq(uv[i], src_uv[i])
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	assert_eq(col.size(), src_uv.size() + 3)
	for i in src_uv.size():
		assert_eq(col[i], Color.WHITE)
	assert_eq(col[src_uv.size()], Color.RED)
	assert_eq(col[src_uv.size() + 2], Color.BLUE)
	root.free()

func test_non_indexed_array_mesh() -> void:
	var root := Node3D.new()
	_mi(_colored_triangle(), _mat_a, Transform3D(Basis.IDENTITY, Vector3(5, 0, 0)), root)
	var arr := (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)
	assert_eq((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, 1)
	assert_eq(arr[Mesh.ARRAY_VERTEX], PackedVector3Array([Vector3(5, 0, 0), Vector3(5, 1, 0), Vector3(6, 0, 0)]))
	root.free()

func test_missing_normals_get_flat_face_normals() -> void:
	var m := _colored_triangle()
	var arrays := m.surface_get_arrays(0)
	arrays[Mesh.ARRAY_NORMAL] = null
	var m2 := ArrayMesh.new()
	m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var root := Node3D.new()
	_mi(m2, _mat_a, Transform3D.IDENTITY, root)
	var n: PackedVector3Array = (Bake.bake(root) as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_eq(n.size(), 3)
	for x in n:
		assert_almost_eq(x.length(), 1.0, 1e-4)
		assert_almost_eq(absf(x.z), 1.0, 1e-4)
	root.free()

func test_deterministic_across_separate_builds() -> void:
	var r1 := _fixture()
	var r2 := _fixture()
	var a := Bake.bake(r1) as ArrayMesh
	var b := Bake.bake(r2) as ArrayMesh
	assert_eq(a.get_surface_count(), b.get_surface_count())
	for s in a.get_surface_count():
		assert_eq(a.surface_get_arrays(s), b.surface_get_arrays(s))
	r1.free()
	r2.free()
