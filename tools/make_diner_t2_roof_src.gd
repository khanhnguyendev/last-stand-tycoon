extends SceneTree
## Writes art/env/src/diner_t2_top.res (E5 slice 2 Task 1): what the tier-2 diner adds above the tier-1 roof, as ONE
## mesh on ONE surface of the shared fantasy-town atlas (every box is one palette texel, so it stays on palette):
##   - roof_cap: a thin terracotta slab laid on the flat roof (3.0 to 3.03: the Archer's perch stays at 3.0),
##   - chimney: a tall stone stack at the north-west corner with a dark steel cap (tier 1 has one at the north-east),
##   - sign board: a gold plate on two dark posts above the middle of the roof.
## Everything stays inside |x| <= 4.0 and |z| <= 4.0 (nothing overhangs the walls: awnings hid actors, slice 1).
## Run: "$GODOT" --headless --path . -s res://tools/make_diner_t2_roof_src.gd
const ATLAS := "res://art/palette/atlas/kenney-fantasy-town__colormap.png"
## [palette name, centre x, base y, centre z, size x, size y, size z]
const BOXES := [
	[&"steak_brown", 0.0, 3.0, 0.0, 5.6, 0.03, 5.6],     # roof_cap
	[&"stone", -3.0, 3.0, -3.0, 0.7, 2.9, 0.7],          # chimney stack, top at 5.9
	[&"steel_dark", -3.0, 5.9, -3.0, 0.95, 0.2, 0.95],   # chimney cap, top at 6.1 (tier 1's highest point is 5.1)
	[&"wood_dark", -1.1, 3.0, -1.2, 0.2, 1.3, 0.2],      # sign post
	[&"wood_dark", 1.1, 3.0, -1.2, 0.2, 1.3, 0.2],       # sign post
	[&"gold", 0.0, 4.2, -1.2, 3.0, 1.2, 0.2],            # sign board, top at 5.4
]

func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	if img == null:
		push_error("cannot load " + ATLAS)
		quit(1)
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for b in BOXES:
		var texel := _find_texel(img, Palette.color(b[0]))
		if texel.x < 0:
			push_error("%s not in the atlas" % b[0])
			quit(1)
			return
		print(b[0], " texel ", texel)
		var uv := (Vector2(texel) + Vector2(0.5, 0.5)) / Vector2(img.get_size())
		_box(verts, norms, uvs, idx, Vector3(b[1], b[2], b[3]), Vector3(b[4], b[5], b[6]), uv)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, load("res://art/materials/kenney-fantasy-town__colormap.tres"))
	var err := ResourceSaver.save(mesh, "res://art/env/src/diner_t2_top.res")
	if err != OK:
		push_error("cannot save diner_t2_top.res: %d" % err)
		quit(1)
		return
	quit(0)

## A box with its base centre at `base` (x, y, z), every vertex on one UV.
static func _box(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, base: Vector3, size: Vector3, uv: Vector2) -> void:
	var h := size / 2.0
	for f in [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
			[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
			[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var first := verts.size()
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			verts.append(base + Vector3(0, h.y, 0) + n * h + a * h * c[0] + b * h * c[1])
			norms.append(n)
			uvs.append(uv)
		var e1 := verts[first + 1] - verts[first]
		var e2 := verts[first + 2] - verts[first]
		if e1.cross(e2).dot(n) > 0.0:
			idx.append_array([first, first + 2, first + 1, first, first + 3, first + 2])
		else:
			idx.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

static func _find_texel(img: Image, want: Color) -> Vector2i:
	for y in img.get_height():
		for x in img.get_width():
			if _near(img.get_pixel(x, y), want):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and a.a > 0.99
