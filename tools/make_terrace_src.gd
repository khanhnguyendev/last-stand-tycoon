extends SceneTree
## Writes art/env/src/terrace_slab.res (E5 Task 11): one flat box, 1.6 x 0.015 x 8.0, centred on x = 0 with its base at
## y = 0 (top at 0.015: under the blob shadows at +0.04 and the ground steaks at 0.02), every vertex UV on the diner_cream texel of the shared fantasy-town atlas, so the slab is on palette and uses
## a shared material. Run: "$GODOT" --headless --path . -s res://tools/make_terrace_src.gd
const ATLAS := "res://art/palette/atlas/kenney-fantasy-town__colormap.png"
const SIZE := Vector3(1.6, 0.015, 8.0)

func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	if img == null:
		push_error("cannot load " + ATLAS)
		quit(1)
		return
	var want := Palette.color(&"diner_cream")
	var texel := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if _near(img.get_pixel(x, y), want):
				texel = Vector2i(x, y)
				break
		if texel.x >= 0:
			break
	if texel.x < 0:
		push_error("diner_cream not in the atlas")
		quit(1)
		return
	print("diner_cream texel ", texel, " of ", img.get_size())
	var uv := (Vector2(texel) + Vector2(0.5, 0.5)) / Vector2(img.get_size())
	var h := SIZE / 2.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# face: normal, u axis, v axis (right-handed; Godot front faces wind clockwise, so indices go 0,2,1 / 0,3,2)
	for f in [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
			[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
			[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var base := verts.size()
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			verts.append(n * h + a * h * c[0] + b * h * c[1] + Vector3(0, h.y, 0))
			norms.append(n)
			uvs.append(uv)
		# winding so the geometric normal (b-a x c-a, Godot clockwise = front) faces n
		var e1 := verts[base + 1] - verts[base]
		var e2 := verts[base + 2] - verts[base]
		if e1.cross(e2).dot(n) > 0.0:
			idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
		else:
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, load("res://art/materials/kenney-fantasy-town__colormap.tres"))
	var err := ResourceSaver.save(mesh, "res://art/env/src/terrace_slab.res")
	if err != OK:
		push_error("cannot save terrace_slab.res: %d" % err)
		quit(1)
		return
	quit(0)

static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and a.a > 0.99
