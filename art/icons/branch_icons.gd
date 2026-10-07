class_name BranchIcons
extends RefCounted
## The branch pad glyphs (E5 tier 3 Task 17, D-263.3, D-273.4): flat vector pictures built as meshes from palette colours, the
## same pattern as LaneIcons (and the same billboard material). Each is told apart by SHAPE at phone size: the Longbow a bow
## with one long arrow, the Volley three arrows fanned out, the Stone wall a shield, the Spike fence three spikes on a rail, and
## the "broken" glyph (the fence pads' warning) a fence with a snapped plank under a red slash.
## Units: a glyph fits a 1 x 1 square centred on the origin, y up, +z toward the camera. Every layer is an ink outline (the same
## polygon grown) under the fill. No white and no gold anywhere (the hero and reward colours).
## Also the two ground meshes the pads use: a flat ring (the pad marker and the preview range rings).

const KINDS: Array[StringName] = [&"longbow", &"volley", &"stone", &"spike", &"broken"]
const LAYER_Z := 0.02
const OUTLINE := 0.07
## Ground meshes lie this high (m), just over the ground plane.
const GROUND_Y := 0.04

static var _cache := {}
static var _ground_mat: StandardMaterial3D

static func _arc_band(center: Vector2, r_out: float, r_in: float, a0: float, a1: float, steps := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := deg_to_rad(lerpf(a0, a1, float(i) / float(steps)))
		pts.append(center + Vector2(cos(t), sin(t)) * r_out)
	for i in steps + 1:
		var t := deg_to_rad(lerpf(a1, a0, float(i) / float(steps)))
		pts.append(center + Vector2(cos(t), sin(t)) * r_in)
	return pts

static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

## An arrow from `base` along `angle_deg` (0 = up, clockwise positive): [shaft, head] polygons.
static func _arrow(base: Vector2, angle_deg: float, length: float, shaft_w: float, head_w: float, head_len: float) -> Array:
	var a := deg_to_rad(angle_deg)
	var up := Vector2(sin(a), cos(a))
	var side := Vector2(cos(a), -sin(a))
	var tip := base + up * length
	var neck := tip - up * head_len
	var shaft := PackedVector2Array([base - side * shaft_w * 0.5, base + side * shaft_w * 0.5, neck + side * shaft_w * 0.5, neck - side * shaft_w * 0.5])
	var head := PackedVector2Array([neck - side * head_w * 0.5, neck + side * head_w * 0.5, tip])
	return [shaft, head]

## [polygon, palette colour name] layers, drawn first to last; each gets its own ink outline under all of them.
static func layers(kind: StringName) -> Array:
	match kind:
		&"longbow":  # a wooden bow bulging left, one long steel arrow across it
			var arrow := _arrow(Vector2(-0.46, 0.0), 90.0, 0.94, 0.07, 0.24, 0.26)
			return [
				[_arc_band(Vector2(0.14, 0.0), 0.50, 0.36, 128.0, 232.0), &"wood"],
				[_rect(-0.10, -0.40, -0.07, 0.40), &"traveler_beige"],
				[arrow[0], &"steel"],
				[arrow[1], &"steel_dark"],
			]
		&"volley":  # three arrows fanned out from one point: "x3"
			var out: Array = []
			for ang in [-30.0, 0.0, 30.0]:
				var ar := _arrow(Vector2(0.0, -0.46), ang, 0.92, 0.09, 0.26, 0.28)
				out.append([ar[0], &"wood"])
				out.append([ar[1], &"steel_dark"])
			return out
		&"stone":  # a heavy shield: stone body, a steel boss
			return [
				[PackedVector2Array([Vector2(-0.42, 0.44), Vector2(0.42, 0.44), Vector2(0.42, -0.04), Vector2(0.0, -0.50), Vector2(-0.42, -0.04)]), &"stone"],
				[PackedVector2Array([Vector2(-0.26, 0.30), Vector2(0.26, 0.30), Vector2(0.26, -0.02), Vector2(0.0, -0.32), Vector2(-0.26, -0.02)]), &"steel"],
				[PackedVector2Array([Vector2(-0.07, 0.24), Vector2(0.07, 0.24), Vector2(0.07, -0.16), Vector2(-0.07, -0.16)]), &"steel_dark"],
			]
		&"spike":  # three spikes pointing up from a rail
			return [
				[PackedVector2Array([Vector2(-0.46, -0.46), Vector2(0.46, -0.46), Vector2(0.46, -0.28), Vector2(-0.46, -0.28)]), &"wood_dark"],
				[PackedVector2Array([Vector2(-0.46, -0.28), Vector2(-0.16, -0.28), Vector2(-0.31, 0.46)]), &"steel"],
				[PackedVector2Array([Vector2(-0.15, -0.28), Vector2(0.15, -0.28), Vector2(0.0, 0.50)]), &"steel"],
				[PackedVector2Array([Vector2(0.16, -0.28), Vector2(0.46, -0.28), Vector2(0.31, 0.46)]), &"steel"],
			]
		_:  # "broken": two posts, a plank snapped in two, a red slash through it
			return [
				[_rect(-0.46, -0.44, -0.32, 0.34), &"wood_dark"],
				[_rect(0.32, -0.44, 0.46, 0.34), &"wood_dark"],
				[PackedVector2Array([Vector2(-0.32, 0.22), Vector2(-0.04, 0.12), Vector2(-0.04, -0.04), Vector2(-0.32, 0.06)]), &"wood"],
				[PackedVector2Array([Vector2(0.32, 0.02), Vector2(0.04, -0.14), Vector2(0.04, -0.30), Vector2(0.32, -0.14)]), &"wood"],
				[PackedVector2Array([Vector2(-0.46, 0.38), Vector2(-0.34, 0.48), Vector2(0.48, -0.38), Vector2(0.36, -0.48)]), &"enemy_red"],
			]

## Number of vertices the mesh of `kind` must have (every layer twice: its outline, then its fill). The tests pin that no
## layer failed to triangulate.
static func expected_vertices(kind: StringName) -> int:
	var n := 0
	for l in layers(kind):
		n += 3 * (l[0].size() - 2) + 3 * (_grown(l[0]).size() - 2)
	return n

## The glyph as one unshaded vertex-coloured mesh (cached). Use it with `material()`.
static func mesh(kind: StringName) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var ink := Palette.color(&"ink")
	var ls := layers(kind)
	var layer := 0
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
	assert(verts.size() == expected_vertices(kind), "a %s layer did not triangulate" % kind)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[kind] = m
	return m

## The billboard material of every glyph: the lane glyphs' (unshaded, vertex colours, keeps the node's scale).
static func material() -> StandardMaterial3D:
	return LaneIcons.material()

## A flat ring in the xz plane at GROUND_Y: outer radius 1, inner radius `inner` (0..1), and a faint disc inside when
## `disc_alpha` > 0. `colour` is a palette name. Scale the node to the wanted radius (the band scales with it). Cached.
static func ring_mesh(colour: StringName, inner: float, disc_alpha: float) -> ArrayMesh:
	var key := "ring_%s_%.3f_%.2f" % [colour, inner, disc_alpha]
	if _cache.has(key):
		return _cache[key]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var c := Palette.color(colour)
	var steps := 48
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var o0 := Vector3(cos(a0), GROUND_Y, sin(a0))
		var o1 := Vector3(cos(a1), GROUND_Y, sin(a1))
		var i0 := Vector3(cos(a0) * inner, GROUND_Y, sin(a0) * inner)
		var i1 := Vector3(cos(a1) * inner, GROUND_Y, sin(a1) * inner)
		for v in [o0, i0, o1, o1, i0, i1]:  # the band, facing up
			verts.append(v)
			cols.append(c)
		if disc_alpha > 0.0:
			var ctr := Vector3(0, GROUND_Y, 0)
			for v in [i0, ctr, i1]:
				verts.append(v)
				cols.append(Color(c.r, c.g, c.b, disc_alpha))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = m
	return m

static func ground_material() -> StandardMaterial3D:
	if _ground_mat == null:
		_ground_mat = StandardMaterial3D.new()
		_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ground_mat.vertex_color_use_as_albedo = true
		_ground_mat.vertex_color_is_srgb = true
		_ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ground_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _ground_mat

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
