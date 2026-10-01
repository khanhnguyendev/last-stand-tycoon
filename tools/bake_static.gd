extends SceneTree
## Offline static-mesh bake (S4 Task 11a, D-201). Run:
##   "$GODOT" --headless --path . -s res://tools/bake_static.gd -- --in=res://art/env/src/diner_src.tscn --out=res://art/env/baked/diner.res
##   "$GODOT" --headless --path . -s res://tools/bake_static.gd -- --all      (every entry of art/env/bake_manifest.gd)
## Merges every visible MeshInstance3D under a source node (any depth, instanced glb pieces included) into ONE ArrayMesh
## with ONE surface per unique material, in the source node's local space. Normals use the inverse transpose, the
## winding flips under a negative determinant, UVs and vertex colours are kept. Tangents and UV2 are dropped.
## Deterministic: surfaces are ordered by the first appearance of their material in a depth-first walk in child order,
## so the same input gives the same bytes. Editor/test only (tools/ is excluded from every web export).

const MANIFEST := preload("res://art/env/bake_manifest.gd")

func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var entries: Array = []
	if args.has("all"):
		entries = MANIFEST.ENTRIES
	elif args.has("in") and args.has("out"):
		entries = [{"in": args["in"], "out": args["out"]}]
	else:
		push_error("usage: -- --in=res://src.tscn --out=res://out.res | --all")
		quit(2)
		return
	var failed := false
	for e in entries:
		failed = not await _bake_entry(String(e["in"]), String(e["out"])) or failed
	quit(1 if failed else 0)

static func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out := {}
	for a in argv:
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out

func _bake_entry(in_path: String, out_path: String) -> bool:
	var scene := load(in_path) as PackedScene
	if scene == null:
		push_error("bake_static: cannot load %s" % in_path)
		return false
	var src := scene.instantiate() as Node3D
	if src == null:
		push_error("bake_static: %s root is not a Node3D" % in_path)
		return false
	root.add_child(src)
	await process_frame  # any _ready / deferred setup has run
	var mesh := bake(src)
	src.queue_free()
	if mesh.get_surface_count() == 0:
		push_error("bake_static: %s has no visible meshes" % in_path)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	mesh.resource_name = out_path.get_file().get_basename()
	var err := ResourceSaver.save(mesh, out_path)
	if err != OK:
		push_error("bake_static: save %s failed (%s)" % [out_path, error_string(err)])
		return false
	var tris := 0
	for i in mesh.get_surface_count():
		tris += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("BAKED %s: %d surfaces, %d triangles -> %s" % [in_path, mesh.get_surface_count(), tris, out_path])
	return true

## `source`'s visible meshes merged into source-local space, one surface per unique active material.
static func bake(source: Node3D) -> ArrayMesh:
	var groups: Dictionary = {}  # Material (or null) -> group dict
	var order: Array = []
	_walk(source, Transform3D.IDENTITY, groups, order)
	var mesh := ArrayMesh.new()
	for mat in order:
		var g: Dictionary = groups[mat]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.verts
		arrays[Mesh.ARRAY_NORMAL] = g.normals
		arrays[Mesh.ARRAY_TEX_UV] = g.uvs
		if g.has_colors:
			arrays[Mesh.ARRAY_COLOR] = g.colors
		arrays[Mesh.ARRAY_INDEX] = g.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh

static func _walk(node: Node, xf: Transform3D, groups: Dictionary, order: Array) -> void:
	for c in node.get_children():
		var n3 := c as Node3D
		if n3 == null:
			continue
		if not n3.visible:
			continue
		var cxf := xf * n3.transform
		var mi := n3 as MeshInstance3D
		if mi != null and mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				_add_surface(mi, s, cxf, groups, order)
		_walk(n3, cxf, groups, order)

static func _add_surface(mi: MeshInstance3D, s: int, xf: Transform3D, groups: Dictionary, order: Array) -> void:
	# PrimitiveMesh (Box, Sphere, ...) is always triangles; ArrayMesh/imported meshes can say otherwise.
	if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
		push_error("bake_static: %s surface %d is not triangles; skipped" % [mi.name, s])
		return
	var mat := mi.get_active_material(s)
	if not groups.has(mat):
		groups[mat] = {"verts": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array(),
			"colors": PackedColorArray(), "has_colors": false, "indices": PackedInt32Array()}
		order.append(mat)
	var g: Dictionary = groups[mat]
	var arr := mi.mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: Variant = arr[Mesh.ARRAY_NORMAL]
	var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
	var col: Variant = arr[Mesh.ARRAY_COLOR]
	var idx: Variant = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	var flip := xf.basis.determinant() < 0.0
	var base: int = (g.verts as PackedVector3Array).size()
	if col != null and not g.has_colors:
		g.has_colors = true
		(g.colors as PackedColorArray).resize(base)
		(g.colors as PackedColorArray).fill(Color.WHITE)
	for i in v.size():
		g.verts.append(xf * v[i])
		g.normals.append((nb * n[i]).normalized() if n != null else Vector3.UP)
		g.uvs.append(uv[i] if uv != null else Vector2.ZERO)
		if g.has_colors:
			g.colors.append(col[i] if col != null else Color.WHITE)
	var tri_count: int = (idx.size() if idx != null else v.size()) / 3
	for t in tri_count:
		var a: int = idx[t * 3] if idx != null else t * 3
		var b: int = idx[t * 3 + 1] if idx != null else t * 3 + 1
		var c: int = idx[t * 3 + 2] if idx != null else t * 3 + 2
		if flip:
			g.indices.append_array(PackedInt32Array([base + a, base + c, base + b]))
		else:
			g.indices.append_array(PackedInt32Array([base + a, base + b, base + c]))
