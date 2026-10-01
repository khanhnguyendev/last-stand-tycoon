extends GutTest
## S4 Task 4: every imported Kenney / KayKit surface uses a shared art/materials StandardMaterial3D (D-188):
## roughness 1, nearest filtering with no mipmaps, so neighbouring swatches never blend into off-palette colours.

func _models(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".glb") or f.ends_with(".gltf"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub != "_candidates":
			_models(dir.path_join(sub), out)

func test_every_surface_uses_a_shared_material() -> void:
	var files: Array = []
	_models("res://assets", files)
	assert_gt(files.size(), 40, "found the imported models")
	for p in files:
		var inst: Node = load(p).instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for i in m.mesh.get_surface_count():
				var mat := m.get_active_material(i) as BaseMaterial3D
				assert_not_null(mat, "%s surface %d material" % [p, i])
				if mat == null:
					continue
				assert_true(mat.resource_path.begins_with("res://art/materials/"), "%s uses %s" % [p, mat.resource_path])
				assert_eq(mat.roughness, 1.0, "%s roughness" % mat.resource_path)
				assert_eq(mat.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s texture_filter" % mat.resource_path)
		inst.free()
