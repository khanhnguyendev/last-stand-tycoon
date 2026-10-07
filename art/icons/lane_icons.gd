class_name LaneIcons
extends RefCounted
## The telegraph and edge-arrow glyphs (E5 tier 3 Task 14, D-264): flat vector heads for the Boar, the hare, the brute and
## the boss, built as meshes from palette colours (no texture, so nothing to bake or to mis-load). Each glyph is
## told apart by SHAPE: the Boar a round head with two tusks, the hare a small head with two long ears, the brute a
## big square head under a heavy brow, the boss a crown. Every layer is an ink outline (the same polygon grown) under the fill.
## Units: a glyph fits a 1 x 1 square centred on the origin, y up. No white anywhere (the hero-colour rule).

const KINDS: Array[StringName] = [&"boar", &"hare", &"brute", &"boss"]
## Gap between drawn layers along the view axis (m, at a 1 m glyph); the glyph is a billboard so +z faces the camera.
const LAYER_Z := 0.02
const OUTLINE := 0.07

static var _cache := {}

static func _ellipse(c: Vector2, r: Vector2, steps := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	return pts

## [polygon, palette colour name] layers, drawn first to last; each gets its own ink outline under all of them.
static func layers(kind: StringName) -> Array:
	match kind:
		&"boar":  # round head, small ears, a pink snout and two tusks curving up
			return [
				[PackedVector2Array([Vector2(-0.30, 0.20), Vector2(-0.42, 0.46), Vector2(-0.14, 0.38)]), &"enemy_maroon"],
				[PackedVector2Array([Vector2(0.30, 0.20), Vector2(0.42, 0.46), Vector2(0.14, 0.38)]), &"enemy_maroon"],
				[_ellipse(Vector2(0, 0.06), Vector2(0.42, 0.38)), &"enemy_red"],
				[PackedVector2Array([Vector2(-0.30, -0.22), Vector2(-0.44, -0.02), Vector2(-0.18, -0.12)]), &"gold"],
				[PackedVector2Array([Vector2(0.30, -0.22), Vector2(0.44, -0.02), Vector2(0.18, -0.12)]), &"gold"],
				[_ellipse(Vector2(0, -0.08), Vector2(0.22, 0.15)), &"enemy_snout"],
			]
		&"hare":  # a small head under two tall narrow ears
			return [
				[_ellipse(Vector2(-0.15, 0.30), Vector2(0.10, 0.34)), &"enemy_snout"],
				[_ellipse(Vector2(0.15, 0.30), Vector2(0.10, 0.34)), &"enemy_snout"],
				[_ellipse(Vector2(0, -0.20), Vector2(0.28, 0.24)), &"enemy_snout"],
				[_ellipse(Vector2(0, -0.26), Vector2(0.10, 0.07)), &"enemy_red"],
			]
		&"brute":  # fills the square: wide flat-topped head, a heavy ink brow, two tusks pointing down
			return [
				[PackedVector2Array([Vector2(-0.48, 0.40), Vector2(0.48, 0.40), Vector2(0.50, -0.10), Vector2(0.30, -0.42), Vector2(-0.30, -0.42), Vector2(-0.50, -0.10)]), &"enemy_maroon"],
				[PackedVector2Array([Vector2(-0.40, 0.18), Vector2(0.40, 0.18), Vector2(0.40, 0.04), Vector2(-0.40, 0.04)]), &"ink"],
				[PackedVector2Array([Vector2(-0.22, -0.30), Vector2(-0.10, -0.30), Vector2(-0.16, -0.50)]), &"gold"],
				[PackedVector2Array([Vector2(0.22, -0.30), Vector2(0.10, -0.30), Vector2(0.16, -0.50)]), &"gold"],
			]
		_:  # the boss: a crown, three points on a band
			return [
				[PackedVector2Array([Vector2(-0.46, -0.30), Vector2(-0.46, 0.34), Vector2(-0.22, 0.04), Vector2(0, 0.42), Vector2(0.22, 0.04), Vector2(0.46, 0.34), Vector2(0.46, -0.30)]), &"gold"],
				[PackedVector2Array([Vector2(-0.46, -0.30), Vector2(0.46, -0.30), Vector2(0.46, -0.12), Vector2(-0.46, -0.12)]), &"enemy_red"],
			]

## The glyph as one unshaded vertex-coloured mesh (cached). Use it with `material()`.
static func mesh(kind: StringName) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var ink := Palette.color(&"ink")
	var ls := layers(kind)
	var layer := 0
	# Every ink outline first (behind), then the fills in order, each a LAYER_Z step nearer the camera.
	for l in ls:
		layer += 1
		_add(verts, cols, _grown(l[0]), ink, LAYER_Z * layer)
	for l in ls:
		layer += 1
		_add(verts, cols, l[0], Palette.color(l[1]), LAYER_Z * layer)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[kind] = m
	return m

static var _mat: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.no_depth_test = true
	return _mat

static func _grown(poly: PackedVector2Array) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(poly, OUTLINE, Geometry2D.JOIN_ROUND)
	var best := PackedVector2Array()
	for q in res:
		if q.size() > best.size():
			best = q
	return best

static func _add(verts: PackedVector3Array, cols: PackedColorArray, poly: PackedVector2Array, col: Color, z: float) -> void:
	for i in Geometry2D.triangulate_polygon(poly):
		verts.append(Vector3(poly[i].x, poly[i].y, z))
		cols.append(col)
