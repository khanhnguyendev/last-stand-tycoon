class_name Props
extends Node3D
## The hand-placed props (S4 Task 13, D-201): every item's transform is baked into static meshes, one MeshInstance3D per
## atlas material (castle atlas, tower-defense atlas): 2 draws for all of them. No collision. Visual only: no Rng, no
## gameplay state. The merge runs once per distinct exclusion (62 small meshes, a few ms).

## The merged meshes are built once per run per exclusion and shared by every Props node (tests create Main many times).
## Key "" is the whole layout (tier 1).
static var _merged := {}

var _built_key := "<none>"

const CLEAR_DIST := 1.0

## The layout items that stay when the `exclude` rects (open yards) are cleared: an item whose position lies within
## CLEAR_DIST of a rect is hidden (E5 Task 10). No exclusion: the whole layout.

static func items_for(exclude: Array = []) -> Array:
	if exclude.is_empty():
		return PropsLayout.ITEMS
	var out := []
	for it in PropsLayout.ITEMS:
		var hidden := false
		for r in exclude:
			if Geometry.dist_point_rect(it.pos, r) <= CLEAR_DIST:
				hidden = true
				break
		if not hidden:
			out.append(it)
	return out

## Builds the MeshInstance3D children for the layout minus the props near the `exclude` rects. Idempotent for the same
## exclusion; a different one swaps the (cached) meshes: still one MeshInstance3D per atlas material.
func build(exclude: Array[Rect2] = []) -> void:
	var key := _key(exclude)
	if key == _built_key:
		return
	_built_key = key
	for c in get_children():
		remove_child(c)
		c.queue_free()
	prebuild(exclude)
	for merged: ArrayMesh in _merged[key]:
		var mat := merged.surface_get_material(0)
		var mi := MeshInstance3D.new()
		mi.name = "Props_" + (mat.resource_path.get_file().get_basename() if mat != null and mat.resource_path != "" else str(get_child_count()))
		mi.mesh = merged
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

static func _key(exclude: Array) -> String:
	return "" if exclude.is_empty() else str(exclude)

## True when the merged meshes for this exclusion are already built.
static func is_cached(exclude: Array = []) -> bool:
	return _merged.has(_key(exclude))

## Fills the merge cache for this exclusion without adding nodes (the warm-up calls this, E5 Task 12).
static func prebuild(exclude: Array = []) -> void:
	var key := _key(exclude)
	if not _merged.has(key):
		_merged[key] = _merge_all(items_for(exclude))

static func _merge_all(items: Array) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	var groups := {}  # Material -> {v, n, uv, i}
	var order: Array[Material] = []
	for it in items:
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

## E5 tier 3 Task 2: the owned-land props of the open yards (PropsLayout.OWNED) as palette vertex-colour arrays. GroundArt.terrain_mesh
## merges them into the ground mesh, so no draw is added (D-201). Procedural, no collision, no Rng.
static func owned_arrays(items: Array) -> Dictionary:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	var wood := Palette.color(&"wood")
	var dark := Palette.color(&"wood_dark")
	var steel := Palette.color(&"steel_dark")
	for it in items:
		var xf := Transform3D(Basis(Vector3.UP, float(it.rot)).scaled(Vector3.ONE * float(it.scale)), MapLayout.to3(it.pos))
		match String(it.kind):
			"crate":
				_box(g, xf, Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), wood)
				_box(g, xf, Vector3(0, 0.62, 0), Vector3(0.66, 0.06, 0.66), dark)
			"barrel":
				_cylinder(g, xf, 0.0, 0.7, 0.28, dark)
				_cylinder(g, xf, 0.16, 0.06, 0.3, steel)
				_cylinder(g, xf, 0.48, 0.06, 0.3, steel)
			"bench":
				_box(g, xf, Vector3(0, 0.45, 0), Vector3(1.2, 0.08, 0.4), wood)
				_box(g, xf, Vector3(-0.45, 0.2, 0), Vector3(0.1, 0.4, 0.34), dark)
				_box(g, xf, Vector3(0.45, 0.2, 0), Vector3(0.1, 0.4, 0.34), dark)
			_:
				assert(false, "unknown owned prop kind %s" % it.kind)
	return g

## One triangle with the front face clockwise seen from outside (Godot's winding), whatever order a, b, c come in.
static func _tri(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	var base: int = (g.v as PackedVector3Array).size()
	for p in [a, b, c]:
		g.v.append(p)
		g.n.append(n)
		g.c.append(col)
	g.i.append_array([base, base + 1, base + 2])

static func _box(g: Dictionary, xf: Transform3D, center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = sgn
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = h[(axis + 1) % 3]
			var w := Vector3.ZERO
			w[(axis + 2) % 3] = h[(axis + 2) % 3]
			var c := center + n * h[axis]
			var wn := (xf.basis * n).normalized()
			var p0 := xf * (c - u - w)
			var p1 := xf * (c + u - w)
			var p2 := xf * (c + u + w)
			var p3 := xf * (c - u + w)
			_tri(g, p0, p1, p2, wn, col)
			_tri(g, p0, p2, p3, wn, col)

static func _cylinder(g: Dictionary, xf: Transform3D, y0: float, height: float, radius: float, col: Color) -> void:
	const SIDES := 8
	var nb := xf.basis.inverse().transposed()
	for k in SIDES:
		var a0 := TAU * k / SIDES
		var a1 := TAU * (k + 1) / SIDES
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := xf * (d0 * radius + Vector3(0, y0, 0))
		var p1 := xf * (d1 * radius + Vector3(0, y0, 0))
		var p2 := xf * (d1 * radius + Vector3(0, y0 + height, 0))
		var p3 := xf * (d0 * radius + Vector3(0, y0 + height, 0))
		var n := (nb * (d0 + d1)).normalized()
		_tri(g, p0, p1, p2, n, col)
		_tri(g, p0, p2, p3, n, col)
		var top := xf * Vector3(0, y0 + height, 0)
		_tri(g, top, p3, p2, (nb * Vector3.UP).normalized(), col)
