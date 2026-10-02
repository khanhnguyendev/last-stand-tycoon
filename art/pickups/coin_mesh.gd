class_name CoinMesh
extends RefCounted
## The procedural gold coin (S4 Task 15 follow-up): a round, bevelled disc standing in the XY plane (faces +Z / -Z), 0.3 m
## across and 0.05 m thick, with a raised embossed ring on both faces. One surface, one shared material, vertex colours
## gold (faces) and gold_dark (rim, bevel, ridge shadow). PileMesh lays it flat; FlyFx and the icon render use it
## upright. Palette-only, flat-shaded, 16 segments, 288 triangles. Visual only.

const SEGMENTS := 16
const RADIUS := 0.15
const HALF_THICK := 0.025
const BEVEL_R := 0.135  # where the flat face ends and the bevel starts; the bevel meets the mid plane at RADIUS
const RIDGE_IN_R := 0.06  # the embossed ring: slopes up from here, peaks at RIDGE_R, back down at RIDGE_OUT_R
const RIDGE_R := 0.075
const RIDGE_OUT_R := 0.09
const RIDGE_H := 0.008

static var _mesh: ArrayMesh

static func get_mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh

static func _ring(r: float, z: float, i: int) -> Vector3:
	var a := TAU * float(i) / float(SEGMENTS)
	return Vector3(cos(a) * r, sin(a) * r, z)

static func _build() -> ArrayMesh:
	var gold := Palette.color(&"gold")
	var dark := Palette.color(&"gold_dark")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		var zf: float = HALF_THICK * side
		var zp: float = (HALF_THICK + RIDGE_H) * side
		var face_n := Vector3(0, 0, side)
		for i in SEGMENTS:
			var j := (i + 1) % SEGMENTS
			var mid := TAU * (float(i) + 0.5) / float(SEGMENTS)
			var radial := Vector3(cos(mid), sin(mid), 0)
			# inner field (fan), the ridge's inner slope (shadow) and outer slope (lit), the outer flat annulus
			_tri(st, Vector3(0, 0, zf), _ring(RIDGE_IN_R, zf, i), _ring(RIDGE_IN_R, zf, j), face_n, gold)
			var slope := (RIDGE_R - RIDGE_IN_R)
			_quad(st, _ring(RIDGE_IN_R, zf, i), _ring(RIDGE_IN_R, zf, j), _ring(RIDGE_R, zp, j), _ring(RIDGE_R, zp, i),
				(face_n * slope - radial * RIDGE_H * side).normalized(), dark)
			_quad(st, _ring(RIDGE_R, zp, i), _ring(RIDGE_R, zp, j), _ring(RIDGE_OUT_R, zf, j), _ring(RIDGE_OUT_R, zf, i),
				(face_n * slope + radial * RIDGE_H * side).normalized(), gold)
			_quad(st, _ring(RIDGE_OUT_R, zf, i), _ring(RIDGE_OUT_R, zf, j), _ring(BEVEL_R, zf, j), _ring(BEVEL_R, zf, i), face_n, gold)
			# bevel from the face edge down to the rim edge on the mid plane
			var bn := (radial * HALF_THICK + Vector3(0, 0, side * (RADIUS - BEVEL_R))).normalized()
			_quad(st, _ring(BEVEL_R, zf, i), _ring(BEVEL_R, zf, j), _ring(RADIUS, 0.0, j), _ring(RADIUS, 0.0, i), bn, dark)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0  # ART_BIBLE §4: one shading model
	st.set_material(m)
	return st.commit()

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nn: Vector3, col: Color) -> void:
	_tri(st, a, b, c, nn, col)
	_tri(st, a, c, d, nn, col)

## Godot front faces are clockwise: (b-a)x(c-a) must point against the outward normal nn.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nn: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(nn) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(nn)
		st.add_vertex(v)
