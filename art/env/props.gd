class_name Props
extends Node3D
## The hand-placed props (S4 Task 13, D-201): every item's transform is baked into static meshes, one MeshInstance3D per
## atlas material (castle atlas, tower-defense atlas): 2 draws for all of them. No collision. Visual only: no Rng, no
## gameplay state. The merge runs once at build() (62 small meshes, a few ms).

## The merged meshes are built once per run and shared by every Props node (tests create Main many times).
static var _merged: Array[ArrayMesh] = []

## Builds the MeshInstance3D children once (idempotent).
func build() -> void:
	if get_child_count() > 0:
		return
	if _merged.is_empty():
		_merged = _merge_all()
	for merged in _merged:
		var mat := merged.surface_get_material(0)
		var mi := MeshInstance3D.new()
		mi.name = "Props_" + (mat.resource_path.get_file().get_basename() if mat != null and mat.resource_path != "" else str(get_child_count()))
		mi.mesh = merged
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

static func _merge_all() -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	var groups := {}  # Material -> {v, n, uv, i}
	var order: Array[Material] = []
	for it in PropsLayout.ITEMS:
		var mesh := load(it.model) as ArrayMesh
		var p: Vector2 = it.pos
		var xf := Transform3D(Basis(Vector3.UP, float(it.rot)).scaled(Vector3.ONE * float(it.scale)), MapLayout.to3(p))
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if not groups.has(mat):
				groups[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
				order.append(mat)
			_append(groups[mat], mesh.surface_get_arrays(s), xf)
	for mat in order:
		var g: Dictionary = groups[mat]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_TEX_UV] = g.uv
		arrays[Mesh.ARRAY_INDEX] = g.i
		var merged := ArrayMesh.new()
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		merged.surface_set_material(0, mat)
		out.append(merged)
	return out

static func _append(g: Dictionary, arrays: Array, xf: Transform3D) -> void:
	var v: PackedVector3Array = g.v
	var n: PackedVector3Array = g.n
	var uv: PackedVector2Array = g.uv
	var idx: PackedInt32Array = g.i
	var base := v.size()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var nb := xf.basis.inverse().transposed()
	for k in verts.size():
		v.append(xf * verts[k])
		n.append((nb * normals[k]).normalized())
		uv.append(uvs[k] if k < uvs.size() else Vector2.ZERO)
	for k in arrays[Mesh.ARRAY_INDEX] as PackedInt32Array:
		idx.append(k + base)
	g.v = v
	g.n = n
	g.uv = uv
	g.i = idx
