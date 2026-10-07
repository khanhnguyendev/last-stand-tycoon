extends SceneTree
## Writes art/env/src/diner_t2_top.res (E5 slice 2 Task 1): what the tier-2 diner adds above the tier-1 roof, as ONE
## mesh on ONE surface of the shared atlas (every box is one palette texel, so it stays on palette; the colours follow
## docs/ART_BIBLE.md roles: no gold, no steak_brown on the building):
##   - roof cap: a thin wood slab laid on the flat roof out to the parapet's inner edge (3.0 to 3.03: the Archer's
##     perch stays at 3.0),
##   - chimney: a stone stack with a wood_dark band and cap a little west of the roof's middle (a corner stack or a taller one hid the yards' ground or the Archer at wide aspects),
##   - sign board: a wood plate with a diner_cream face on two short posts in the south half of the roof.
## The camera looks north from the south, so a raised part hides what lies north of it: both stand in the south half
## and low enough that their "shadow" ends on the roof (tests/unit/test_diner_art.gd sweeps the camera to prove they hide
## no ground and never the Archer that tier 1 does not already hide). Everything stays inside |x|, |z| <= 4.0.
## Run: "$GODOT" --headless --path . -s res://tools/make_diner_t2_roof_src.gd
const ATLAS := "res://art/palette/atlas/kenney-fantasy-town__colormap.png"
## [palette name, centre x, base y, centre z, size x, size y, size z]; the test reads these (24 vertices per box, in order).
const BOXES := [
	[&"wood", 0.0, 3.0, 0.0, 7.7, 0.03, 7.7],            # 0 roof cap, to the parapet's inner edge (3.85)
	[&"stone", -1.0, 3.0, 0.0, 0.7, 1.4, 0.7],           # 1 chimney stack, top at 4.4, mid-roof
	[&"wood_dark", -1.0, 3.9, 0.0, 0.84, 0.15, 0.84],    # 2 chimney band
	[&"wood_dark", -1.0, 4.4, 0.0, 0.95, 0.2, 0.95],     # 3 chimney cap, top at 4.6
	[&"wood_dark", -1.1, 3.0, 1.8, 0.2, 0.5, 0.2],       # 4 sign post (ends where the plate begins)
	[&"wood_dark", 1.1, 3.0, 1.8, 0.2, 0.5, 0.2],        # 5 sign post
	[&"wood", 0.0, 3.5, 1.8, 3.0, 1.0, 0.2],             # 6 sign board plate, z 1.7 to 1.9, top at 4.5
	[&"diner_cream", 0.0, 3.65, 1.92, 2.6, 0.7, 0.04],   # 7 board face on the south side, z 1.9 to 1.94
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
