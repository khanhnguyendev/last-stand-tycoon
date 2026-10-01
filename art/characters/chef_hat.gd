class_name ChefHat
extends RefCounted
## The cook's hat (S4 Task 7b, D-191): one ArrayMesh merged from a band (cylinder r 0.38, h 0.42) and a puff (sphere
## r 0.46), vertex colour apron_white, sized for the KayKit head (skeleton units; the head bone sits at its base).
## Static and visual-only; built once per hero visual.

const BAND_RADIUS := 0.38
const BAND_HEIGHT := 0.42
const PUFF_RADIUS := 0.46
const PUFF_HEIGHT := 0.78
## Band centre above the head bone, and the puff's centre above the band's centre.
const BAND_Y := 0.85
const PUFF_RISE := 0.38

static func build() -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = BAND_RADIUS
	cyl.bottom_radius = BAND_RADIUS
	cyl.height = BAND_HEIGHT
	cyl.radial_segments = 16
	cyl.rings = 1
	var sph := SphereMesh.new()
	sph.radius = PUFF_RADIUS
	sph.height = PUFF_HEIGHT
	sph.radial_segments = 16
	sph.rings = 8
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var white := Palette.color(&"apron_white")
	for part in [[cyl, Vector3(0, BAND_Y, 0)], [sph, Vector3(0, BAND_Y + PUFF_RISE, 0)]]:
		var arr: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := verts.size()
		for i in v.size():
			verts.append(v[i] + (part[1] as Vector3))
			normals.append(n[i])
			colors.append(white)
		for i in idx:
			indices.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "ChefHat"
	mi.mesh = mesh
	return mi
