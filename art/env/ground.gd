class_name GroundArt
extends RefCounted
## The ground and the road (S4 Task 13, D-194, D-201). The ground is ONE subdivided mesh with a position-hash vertex
## colour variation (grass / grass_dark); the road is ONE flat mesh. Static builders, visual only: no Rng, no nodes.

const CELL := 2.0
const ROAD_Y := 0.02

static var _material: StandardMaterial3D

## The shared vertex-colour material (palette colours are sRGB, D-188). Also used by LaneStrip.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.resource_name = "ground_vertex_colour"
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
	return _material

## A position hash in [0, 1): the same point always gives the same value (never Rng, spec 6.3).
static func hash01(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)

## The grass colour at world (x, z): grass mixed toward grass_dark by the hash.
static func grass_at(x: float, z: float) -> Color:
	return Palette.color(&"grass").lerp(Palette.color(&"grass_dark"), hash01(x, z))

## A flat grid over `rect` (xz), `cell` metres per cell, at y = 0, vertex-coloured by `grass_at`.
static func ground_mesh(rect: Rect2, cell := CELL) -> ArrayMesh:
	var nx := ceili(rect.size.x / cell)
	var nz := ceili(rect.size.y / cell)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize((nx + 1) * (nz + 1))
	normals.resize(verts.size())
	colors.resize(verts.size())
	for j in nz + 1:
		for i in nx + 1:
			var x := minf(rect.position.x + i * cell, rect.end.x)
			var z := minf(rect.position.y + j * cell, rect.end.y)
			var k := j * (nx + 1) + i
			verts[k] = Vector3(x, 0.0, z)
			normals[k] = Vector3.UP
			colors[k] = grass_at(x, z)
	var idx := PackedInt32Array()
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])  # counter-clockwise seen from above (+y)
	return _mesh(verts, normals, colors, idx)

## The road: one flat stone quad of `size` (x, z), centred on the origin at y = ROAD_Y.
static func road_mesh(size: Vector2) -> ArrayMesh:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var verts := PackedVector3Array([Vector3(-hx, ROAD_Y, -hz), Vector3(hx, ROAD_Y, -hz), Vector3(-hx, ROAD_Y, hz), Vector3(hx, ROAD_Y, hz)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var c := Palette.color(&"stone")
	var colors := PackedColorArray([c, c, c, c])
	return _mesh(verts, normals, colors, PackedInt32Array([0, 1, 2, 1, 3, 2]))

static func _mesh(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh

## A MeshInstance3D for `mesh`, no shadows.
static func instance(mesh: Mesh, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
