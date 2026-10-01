class_name LevelStar
extends RefCounted
## The level pip (S4 Task 12, spec 7): one merged 5-point star prism, 0.18 m across, palette `gold` unshaded, built once and
## shared by every pip (one surface, 40 triangles). Flat in the xy plane, facing +z toward the camera.

const SIZE := 0.18  ## across the points
const DEPTH := 0.05
const POINTS := 5
const INNER_RATIO := 0.45

static var _mesh: ArrayMesh
static var _material: StandardMaterial3D

static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Palette.color(&"gold")
		_material.roughness = 1.0
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # a 0.18 m star must read at phone size
	return _material

static func _build() -> ArrayMesh:
	var r_out := SIZE * 0.5
	var ring: Array[Vector2] = []
	for i in POINTS * 2:
		var a := PI * 0.5 + float(i) * PI / float(POINTS)  # one point straight up
		var r := r_out if i % 2 == 0 else r_out * INNER_RATIO
		ring.append(Vector2(cos(a), sin(a)) * r)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var h := DEPTH * 0.5
	# Front (+z) and back (-z): a fan around the centre.
	for side in [1.0, -1.0]:
		var base := v.size()
		v.append(Vector3(0, 0, h * side))
		n.append(Vector3(0, 0, side))
		for p in ring:
			v.append(Vector3(p.x, p.y, h * side))
			n.append(Vector3(0, 0, side))
		for i in ring.size():
			var a := base + 1 + i
			var b := base + 1 + (i + 1) % ring.size()
			if side > 0.0:
				idx.append_array(PackedInt32Array([base, a, b]))  # counter-clockwise seen from +z
			else:
				idx.append_array(PackedInt32Array([base, b, a]))
	# Sides: one flat quad per edge.
	for i in ring.size():
		var p0 := ring[i]
		var p1 := ring[(i + 1) % ring.size()]
		var edge := p1 - p0
		var nn := Vector3(edge.y, -edge.x, 0).normalized()  # outward for a counter-clockwise ring
		var base := v.size()
		v.append(Vector3(p0.x, p0.y, h))
		v.append(Vector3(p1.x, p1.y, h))
		v.append(Vector3(p1.x, p1.y, -h))
		v.append(Vector3(p0.x, p0.y, -h))
		for k in 4:
			n.append(nn)
		idx.append_array(PackedInt32Array([base, base + 3, base + 2, base, base + 2, base + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.resource_name = "level_star"
	return m
