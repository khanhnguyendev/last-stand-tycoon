extends SceneTree
## Writes art/env/src/tier_sign_src.tscn (E5 Task 9): the tier sign as four hand-built meshes (two posts, a board, a star)
## whose UVs sit on palette swatches of the shared fantasy-town atlas, so the bake is one surface on the shared material.
## Regenerate (headless; deterministic, no randomness), then rebake:
##   "$GODOT" --headless --path . -s res://tools/make_tier_sign_src.gd
##   "$GODOT" --headless --path . -s res://tools/bake_static.gd -- --all
## Editor/test only (tools/ is excluded from every web export).
const ATLAS := 512.0
const MAT := "res://art/materials/kenney-fantasy-town__colormap.tres"
## Texel inside each palette swatch of the atlas, with the colour it must hold (checked at run time).
const WOOD_TEXEL := Vector2(130, 130)
const WOOD_HEX := "a8683c"
const DINER_CREAM_TEXEL := Vector2(290, 136)
const DINER_CREAM_HEX := "f3e3c3"
const GOLD_TEXEL := Vector2(2, 130)
const GOLD_HEX := "f2c230"

func cell(px: Vector2, want: String) -> Vector2:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/palette/atlas/kenney-fantasy-town__colormap.png"))
	assert(img.get_pixelv(Vector2i(px)).to_html(false) == want, "cell %s" % want)
	return (px + Vector2(0.5, 0.5)) / ATLAS

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv: Vector2) -> void:
	for v in [a, c, b, a, d, c]:  # Godot front faces are clockwise
		st.set_normal(n); st.set_uv(uv); st.add_vertex(v)

func box(center: Vector3, size: Vector3, uv: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var p := func(x, y, z): return center + Vector3(x * h.x, y * h.y, z * h.z)
	quad(st, p.call(-1,-1,1), p.call(1,-1,1), p.call(1,1,1), p.call(-1,1,1), Vector3.BACK, uv)
	quad(st, p.call(1,-1,-1), p.call(-1,-1,-1), p.call(-1,1,-1), p.call(1,1,-1), Vector3.FORWARD, uv)
	quad(st, p.call(1,-1,1), p.call(1,-1,-1), p.call(1,1,-1), p.call(1,1,1), Vector3.RIGHT, uv)
	quad(st, p.call(-1,-1,-1), p.call(-1,-1,1), p.call(-1,1,1), p.call(-1,1,-1), Vector3.LEFT, uv)
	quad(st, p.call(-1,1,1), p.call(1,1,1), p.call(1,1,-1), p.call(-1,1,-1), Vector3.UP, uv)
	quad(st, p.call(-1,-1,-1), p.call(1,-1,-1), p.call(1,-1,1), p.call(-1,-1,1), Vector3.DOWN, uv)
	return st.commit()

func star(center: Vector3, r_out: float, depth: float, uv: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for i in 10:
		var a := PI * 0.5 + float(i) * PI / 5.0
		var r := r_out if i % 2 == 0 else r_out * 0.45
		ring.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for side in [1.0, -1.0]:
		for i in 10:
			var a: Vector3 = ring[i]; var b: Vector3 = ring[(i + 1) % 10]
			var tri := [Vector3(0, 0, depth * 0.5 * side) + center, a + center + Vector3(0, 0, depth * 0.5 * side), b + center + Vector3(0, 0, depth * 0.5 * side)]
			if side > 0: tri = [tri[0], tri[2], tri[1]]
			for v in tri:
				st.set_normal(Vector3(0, 0, side)); st.set_uv(uv); st.add_vertex(v)
	for i in 10:
		var a: Vector3 = ring[i]; var b: Vector3 = ring[(i + 1) % 10]
		var e := b - a
		var nrm := Vector3(e.y, -e.x, 0).normalized()
		var h := Vector3(0, 0, depth * 0.5)
		quad(st, a + center - h, b + center - h, b + center + h, a + center + h, nrm, uv)
	return st.commit()

func _initialize() -> void:
	var mat: Material = load(MAT)
	var cream := cell(DINER_CREAM_TEXEL, DINER_CREAM_HEX)
	var wood := cell(WOOD_TEXEL, WOOD_HEX)
	var gold := cell(GOLD_TEXEL, GOLD_HEX)
	var root := Node3D.new(); root.name = "TierSignSrc"
	var parts := [
		["PostL", box(Vector3(-0.7, 0.7, 0), Vector3(0.14, 1.4, 0.14), wood)],
		["PostR", box(Vector3(0.7, 0.7, 0), Vector3(0.14, 1.4, 0.14), wood)],
		["Board", box(Vector3(0, 1.3, 0.09), Vector3(1.9, 0.7, 0.08), cream)],
		["Star", star(Vector3(0, 1.95, 0.09), 0.26, 0.08, gold)],
	]
	for pr in parts:
		var m: ArrayMesh = pr[1]
		m.surface_set_material(0, mat)
		var mi := MeshInstance3D.new(); mi.name = pr[0]; mi.mesh = m
		root.add_child(mi); mi.owner = root
	var ps := PackedScene.new(); ps.pack(root)
	print(ResourceSaver.save(ps, "res://art/env/src/tier_sign_src.tscn"))
	quit()
