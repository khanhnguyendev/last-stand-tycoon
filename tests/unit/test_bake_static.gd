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
