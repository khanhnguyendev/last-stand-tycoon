extends SceneTree
## Writes the four branch model sources (E5 tier 3 Task 18, spec 7, D-264): art/env/src/tower_longbow_src.tscn, tower_volley_src.tscn,
## fence_stone_src.tscn and fence_spike_src.tscn, and the four runtime wrappers art/env/tower_longbow.tscn, tower_volley.tscn,
## fence_stone.tscn, fence_spike.tscn (root "Model", one baked mesh, no physics, like every other art/env wrapper).
##
## Towers are kitbashed from the same Kenney tower pieces as the level-3 tower (same material, one surface after the bake) plus a
## few procedural parts on the tower-defense atlas; fences are fully procedural on the fantasy-town atlas. Every vertex of a
## procedural part sits on ONE palette texel of its atlas (found by colour, checked at run time), so the parts are on palette and
## on the shared material. Roles follow docs/ART_BIBLE.md: wood, wood_dark, stone, steel, steel_dark, ink; no gold, no enemy reds, no white.
##
## Silhouette (what the tests pin, tests/unit/test_branch_models.gd; the camera sees the ground axis z foreshortened, x not):
##   Longbow  slim and TALL: a 0.95-scale column of one more storey than level 3, a big ballista with a long wooden stock and a
##            steel head pointing up-lane (-z). "Reach".
##   Volley   WIDE and LOW-SET: a 1.75-scale base, one storey, three ballistas fanned -40, 0, +40 degrees. "Many shots".
##   Stone    grey blocks, 1.2 m tall and 0.9 m deep with five merlons, against the level-3 fence's 0.9 x 0.5 flat wall. "Holds".
##   Spike    the wooden fence plus a row of seven sharpened stakes angled up-lane (-z) and up, steel tips. "Hurts".
## A fence's local +z is the lane's tangent (toward the diner), so up-lane is -z; the width stays 3.0 m (x -1.5 .. 1.5).
## Regenerate (deterministic, headless), then rebake:
##   "$GODOT" --headless --path . -s res://tools/make_branch_src.gd
##   "$GODOT" --headless --path . -s res://tools/bake_static.gd -- --all
## Editor/test only (tools/ is excluded from every web export).
const TD_ATLAS := "res://art/palette/atlas/kenney-tower-defense__colormap.png"
const TD_MAT := "res://art/materials/kenney-tower-defense__colormap.tres"
const FT_ATLAS := "res://art/palette/atlas/kenney-fantasy-town__colormap.png"
const FT_MAT := "res://art/materials/kenney-fantasy-town__colormap.tres"
const TD := "res://assets/kenney-tower-defense/"
const SY := 1.2142857  ## the level-3 tower's y scale (3.4 m from 2.8 raw)

var _img: Image
var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _uvs := PackedVector2Array()

func _initialize() -> void:
	_tower("tower_longbow", _longbow_pieces(), _longbow_parts)
	_tower("tower_volley", _volley_pieces(), _volley_parts)
	_fence("fence_stone", _stone_parts)
	_fence("fence_spike", _spike_parts)
	quit()

# --- palette ---

func _load_atlas(path: String) -> void:
	_img = Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(_img != null, "cannot load " + path)
	_verts = PackedVector3Array()
	_norms = PackedVector3Array()
	_uvs = PackedVector2Array()

## UV of the first texel of the atlas that holds palette colour `name`.
func _uv(name: StringName) -> Vector2:
	var want := Palette.color(name)
	for y in _img.get_height():
		for x in _img.get_width():
			var c := _img.get_pixel(x, y)
			if absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b) < 0.006:
				return (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(_img.get_size())
	push_error("%s is not in the atlas" % name)
	return Vector2.ZERO

# --- primitives (every one convex: Godot front faces wind clockwise, normals are flat and outward) ---

func _tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, uv: Vector2) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return  # degenerate (a cone's apex ring)
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	# counter-clockwise from outside means n = (b-a) x (c-a) points out; Godot wants clockwise: emit a, c, b
	var ccw := (b - a).cross(c - a).normalized().dot(n) > 0.0
	for v in ([a, c, b] if ccw else [a, b, c]):
		_verts.append(v)
		_norms.append(n)
		_uvs.append(uv)

## A box with centre `c`, size `s`, optionally rotated by `basis` about `c`.
func _box(c: Vector3, s: Vector3, uv: Vector2, basis := Basis.IDENTITY) -> void:
	var h := s * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return c + basis * Vector3(x * h.x, y * h.y, z * h.z)
	var faces := [
		[[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]],
		[[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]], [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]],
		[[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]], [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]],
	]
	for f in faces:
		var q: Array = f.map(func(v): return p.call(v[0], v[1], v[2]))
		_tri(q[0], q[1], q[2], c, uv)
		_tri(q[0], q[2], q[3], c, uv)

## A round (or tapered) post from `p0` to `p1`: `r0` at p0, `r1` at p1 (0 = a point), `n` sides. Caps are closed.
func _post(p0: Vector3, p1: Vector3, r0: float, r1: float, n: int, uv: Vector2) -> void:
	var axis := (p1 - p0).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var inside := p0.lerp(p1, 0.3)
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		var b0 := p0 + d0 * r0
		var b1 := p0 + d1 * r0
		var t0 := p1 + d0 * r1
		var t1 := p1 + d1 * r1
		_tri(b0, b1, t1, inside, uv)
		_tri(b0, t1, t0, inside, uv)
		_tri(p0, b1, b0, inside, uv)
		_tri(p1, t0, t1, inside, uv)

func _commit(mat_path: String) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _verts
	arr[Mesh.ARRAY_NORMAL] = _norms
	arr[Mesh.ARRAY_TEX_UV] = _uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, load(mat_path))
	return m

# --- scenes ---

func _save(name: String, root: Node3D) -> void:
	var ps := PackedScene.new()
	assert(ps.pack(root) == OK)
	print(name, " ", ResourceSaver.save(ps, "res://art/env/src/%s_src.tscn" % name))
	root.free()
	var wrap := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"ArrayMesh\" path=\"res://art/env/baked/%s.res\" id=\"1_mesh\"]\n\n" % name
	wrap += "[node name=\"Model\" type=\"Node3D\"]\n\n[node name=\"Mesh\" type=\"MeshInstance3D\" parent=\".\"]\nmesh = ExtResource(\"1_mesh\")\ncast_shadow = 0\n"
	var f := FileAccess.open("res://art/env/%s.tscn" % name, FileAccess.WRITE)
	f.store_string(wrap)
	f.close()

## `pieces`: [[glb file, Vector3 position, Vector3 scale, y rotation in degrees], ...]; `parts` adds the procedural boxes and posts.
func _tower(name: String, pieces: Array, parts: Callable) -> void:
	_load_atlas(TD_ATLAS)
	var root := Node3D.new()
	root.name = name.to_pascal_case() + "Src"
	var i := 0
	for pc in pieces:
		var n: Node3D = (load(TD + pc[0]) as PackedScene).instantiate()
		n.name = "%s%d" % [String(pc[0]).get_basename().replace("-", "_"), i]
		n.transform = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(pc[3]), 0)).scaled(pc[2]), pc[1])
		root.add_child(n)
		n.owner = root
		i += 1
	parts.call()
	_add_mesh(root, "Parts", TD_MAT)
	_save(name, root)

func _fence(name: String, parts: Callable) -> void:
	_load_atlas(FT_ATLAS)
	var root := Node3D.new()
	root.name = name.to_pascal_case() + "Src"
	parts.call()
	_add_mesh(root, "Parts", FT_MAT)
	_save(name, root)

func _add_mesh(root: Node3D, node_name: String, mat_path: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _commit(mat_path)
	root.add_child(mi)
	mi.owner = root

# --- Longbow ---

const LB_XZ := 0.95
const LB_BALLISTA := 1.6
const LB_TIP := -1.75  ## z of the steel head's point

func _longbow_pieces() -> Array:
	var s := Vector3(LB_XZ, SY, LB_XZ)
	var p := [["tower-round-bottom-a.glb", Vector3(0, 0, 0), s, 0.0]]
	for k in 3:
		p.append(["tower-round-middle-a.glb", Vector3(0, 0.7285714 * (k + 1), 0), s, 0.0])
	p.append(["tower-round-top-a.glb", Vector3(0, 0.7285714 * 4, 0), s, 0.0])
	p.append(["weapon-ballista.glb", Vector3(0, 0.7285714 * 4 + 0.607, 0), Vector3(LB_BALLISTA, LB_BALLISTA, LB_BALLISTA), 0.0])
	return p

## A long wooden stock along -z carrying a steel head, and a steel-dark brace under it: the tower "points" up-lane.
func _longbow_parts() -> void:
	var deck := 0.7285714 * 4 + 0.607
	var y := deck + 0.5
	var tip := LB_TIP
	var head := 0.55
	_box(Vector3(0, y, (tip + head + 0.3) * 0.5), Vector3(0.14, 0.12, 0.3 - (tip + head)), _uv(&"wood"))  # stock, from the head back to z 0.3
	_post(Vector3(0, y, tip + head), Vector3(0, y, tip), 0.10, 0.0, 6, _uv(&"steel"))  # head
	_box(Vector3(0, y - 0.15, -0.2), Vector3(0.1, 0.24, 0.1), _uv(&"steel_dark"))  # brace

# --- Volley ---

const VY_XZ := 1.75
const VY_FAN := [-40.0, 0.0, 40.0]
const VY_R := 0.4  ## distance of each ballista from the axis
const VY_BARREL := 0.55  ## steel-dark barrel length ahead of each

func _volley_pieces() -> Array:
	var s := Vector3(VY_XZ, 1.0, VY_XZ)
	var p := [
		["tower-round-bottom-a.glb", Vector3(0, 0, 0), s, 0.0],
		["tower-round-middle-a.glb", Vector3(0, 0.6, 0), Vector3(VY_XZ * 0.92, 1.0, VY_XZ * 0.92), 0.0],
		["tower-round-top-a.glb", Vector3(0, 1.2, 0), Vector3(VY_XZ * 0.9, 1.0, VY_XZ * 0.9), 0.0],
	]
	for a in VY_FAN:
		var dir := Vector3(sin(deg_to_rad(a)), 0, -cos(deg_to_rad(a)))
		p.append(["weapon-ballista.glb", Vector3(0, 1.7, 0) + dir * VY_R, Vector3(1.2, 1.2, 1.2), -a])
	return p

## Three steel-dark barrel stubs on the fan's axes read as "many shots" even where the ballista bows overlap.
func _volley_parts() -> void:
	for a in VY_FAN:
		var dir := Vector3(sin(deg_to_rad(a)), 0, -cos(deg_to_rad(a)))
		var base := Vector3(0, 2.05, 0) + dir * VY_R
		_post(base, base + dir * VY_BARREL, 0.1, 0.1, 6, _uv(&"steel_dark"))
		_post(base + dir * VY_BARREL, base + dir * (VY_BARREL + 0.3), 0.1, 0.0, 6, _uv(&"steel"))

# --- Stone wall ---

## 3.0 m across (x -1.5 .. 1.5), 0.9 m deep (z -0.45 .. 0.45), 1.2 m tall: a plinth, two courses of big blocks, five merlons.
func _stone_parts() -> void:
	var stone := _uv(&"stone")
	var steel := _uv(&"steel")
	var dark := _uv(&"steel_dark")
	_box(Vector3(0, 0.07, 0), Vector3(3.0, 0.14, 0.9), dark)  # plinth
	for i in 3:  # lower course, 0.94 wide blocks with 0.09 gaps (the gaps are the plinth's dark)
		_box(Vector3(-1.0 + 1.0 * i, 0.14 + 0.2, 0), Vector3(0.94, 0.4, 0.8), stone if i != 1 else steel)
	for x in [-0.5, 0.5]:  # upper course, offset by half a block so the joints do not line up
		_box(Vector3(x, 0.54 + 0.2, 0), Vector3(0.94, 0.4, 0.8), steel if x < 0.0 else stone)
	for x in [-1.25, 1.25]:  # half blocks close the offset's ends
		_box(Vector3(x, 0.74, 0), Vector3(0.44, 0.4, 0.8), stone)
	for i in 5:  # merlons
		_box(Vector3(-1.2 + 0.6 * i, 1.07, 0), Vector3(0.4, 0.26, 0.7), steel if i % 2 == 0 else stone)

# --- Spike fence ---

const SPIKE_COUNT := 7
const SPIKE_ELEVATION := 50.0  ## degrees above the ground plane, leaning up-lane (-z)

## The wooden fence (posts, two rails) 3.0 m across, 1.0 m tall, with seven stakes leaning up-lane.
func _spike_parts() -> void:
	var wood := _uv(&"wood")
	var dark := _uv(&"wood_dark")
	var steel := _uv(&"steel")
	for i in 5:  # posts
		_box(Vector3(-1.4 + 0.7 * i, 0.5, 0.1), Vector3(0.2, 1.0, 0.2), dark)
	_box(Vector3(0, 0.3, 0.1), Vector3(3.0, 0.16, 0.12), wood)   # lower rail
	_box(Vector3(0, 0.72, 0.1), Vector3(3.0, 0.16, 0.12), wood)  # upper rail
	_box(Vector3(0, 0.15, 0.0), Vector3(3.0, 0.3, 0.5), dark)    # sill / footing
	var dir := Vector3(0, sin(deg_to_rad(SPIKE_ELEVATION)), -cos(deg_to_rad(SPIKE_ELEVATION)))
	for i in SPIKE_COUNT:
		var x := -1.35 + 2.7 * float(i) / (SPIKE_COUNT - 1)
		var base := Vector3(x, 0.42, 0.0)
		var shaft_end := base + dir * 0.7
		_post(base - dir * 0.1, shaft_end, 0.09, 0.07, 6, wood)
		_post(shaft_end, shaft_end + dir * 0.45, 0.07, 0.0, 6, steel)
