class_name BoarMesh
extends RefCounted
## The production Boar (S4 Task 9, D-192): the style-board prototype (tests/style_board/proto_boar.gd) merged into one
## ArrayMesh surface with sRGB vertex colours from Palette. Leg vertices carry COLOR.a = 0.0 (the shader swings them),
## everything else 1.0. Faces +z, stands on y = 0, about 1.0 m tall with the ridge and 1.45 m long. Built once and cached.

const BODY_Y := 0.47
const BODY_R := 0.5
const BODY_SCALE := Vector3(1.0, 0.75, 1.15)
const HEAD_POS := Vector3(0.0, 0.43, 0.46)
const HEAD_R := 0.3
const HEAD_TILT_DEG := 6.0
## Tusk flare out from the head's up axis (the prototype used 70; 55 reads better from the game camera) and lean forward.
const TUSK_OUT_DEG := 55.0
const TUSK_FWD_DEG := 20.0

static var _mesh: ArrayMesh

static func get_mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh

static func _sphere(r: float, seg: int, rings: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return s

## `caps` = [bottom, top]: a cap buried in the body or head, or a point, is never drawn (triangle budget).
static func _cone(bottom_r: float, top_r: float, h: float, seg := 8, caps := [true, true]) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.cap_bottom = caps[0]
	c.cap_top = caps[1]
	c.bottom_radius = bottom_r
	c.top_radius = top_r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func _add(acc: Dictionary, mesh: Mesh, xf: Transform3D, color: Color, leg := false) -> void:
	var src := mesh.surface_get_arrays(0)
	var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var si: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = acc.verts
	var norms: PackedVector3Array = acc.norms
	var cols: PackedColorArray = acc.cols
	var idx: PackedInt32Array = acc.idx
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	var c := Color(color, 0.0 if leg else 1.0)
	for i in sv.size():
		verts.append(xf * sv[i])
		norms.append((nb * sn[i]).normalized())
		cols.append(c)
	for i in si.size():
		idx.append(base + si[i])
	acc.verts = verts
	acc.norms = norms
	acc.cols = cols
	acc.idx = idx

static func _xf(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return Transform3D(b * Basis.from_scale(scl), pos)

## One curved tusk of two stacked segments, the upper bent further up and inward. `base` is in head space.
static func _tusk(acc: Dictionary, head: Transform3D, sx: float, base: Vector3, color: Color) -> void:
	var b1 := Basis.from_euler(Vector3(deg_to_rad(TUSK_FWD_DEG), 0.0, deg_to_rad(-sx * TUSK_OUT_DEG)))
	var d1: Vector3 = b1 * Vector3.UP
	var l1 := 0.28
	_add(acc, _cone(0.09, 0.06, l1, 6, [false, false]), head * _xf(base + d1 * l1 * 0.5, Vector3(TUSK_FWD_DEG, 0.0, -sx * TUSK_OUT_DEG)), color)
	var tip1 := base + d1 * l1
	var out2 := TUSK_OUT_DEG - 30.0
	var b2 := Basis.from_euler(Vector3(deg_to_rad(TUSK_FWD_DEG + 25.0), 0.0, deg_to_rad(-sx * out2)))
	var d2: Vector3 = b2 * Vector3.UP
	var l2 := 0.24
	_add(acc, _cone(0.06, 0.0, l2, 6, [false, false]), head * _xf(tip1 + d2 * l2 * 0.5, Vector3(TUSK_FWD_DEG + 25.0, 0.0, -sx * out2)), color)

static func _build() -> ArrayMesh:
	var acc := {"verts": PackedVector3Array(), "norms": PackedVector3Array(), "cols": PackedColorArray(), "idx": PackedInt32Array()}
	var maroon := Palette.color(&"enemy_maroon")
	var red := Palette.color(&"enemy_red")
	# The upper body and head lean toward enemy_red so the shaded flank still reads red-brown in the game camera; belly,
	# tail and legs keep the darker colours.
	var upper := maroon.lerp(red, 0.4)
	var snout := Palette.color(&"enemy_snout")
	var ink := Palette.color(&"ink")
	var ink_soft := Palette.color(&"ink_soft")
	var white := Palette.color(&"apron_white")

	# body and belly
	_add(acc, _sphere(BODY_R, 12, 6), _xf(Vector3(0, BODY_Y, 0), Vector3.ZERO, BODY_SCALE), upper)
	_add(acc, _sphere(BODY_R, 12, 6), _xf(Vector3(0, BODY_Y - 0.09, 0.02), Vector3.ZERO, Vector3(0.9, 0.62, 1.05)), red)

	# ridge: five cones along the back, tallest at the shoulders, leaning back
	var rz := [0.26, 0.1, -0.08, -0.26, -0.42]
	var rh := [0.25, 0.31, 0.28, 0.23, 0.17]
	var half_z: float = BODY_R * BODY_SCALE.z
	for k in 5:
		var z: float = rz[k]
		var top: float = BODY_Y + BODY_R * BODY_SCALE.y * sqrt(maxf(0.0, 1.0 - pow(z / half_z, 2.0)))
		var h: float = rh[k]
		_add(acc, _cone(0.12, 0.0, h, 8, [false, false]), _xf(Vector3(0, top - 0.03 + h * 0.5, z), Vector3(-14.0, 0, 0)), ink)

	# legs (alpha 0: the shader swings them about the hip)
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			_add(acc, _cone(0.095, 0.085, 0.25, 8, [true, false]), _xf(Vector3(lx * 0.27, 0.125, lz * 0.3)), ink_soft, true)

	# tail: a small curl
	var torus := TorusMesh.new()
	torus.inner_radius = 0.03
	torus.outer_radius = 0.075
	torus.rings = 10
	torus.ring_segments = 6
	var tail_pos := Vector3(0, BODY_Y + 0.12, -half_z + 0.02)
	_add(acc, torus, _xf(tail_pos + Vector3(0, 0.03, -0.04), Vector3(70.0, 0, 0)), maroon)

	# head: big and low at the front, tilted slightly down
	var head := _xf(HEAD_POS, Vector3(HEAD_TILT_DEG, 0, 0))
	_add(acc, _sphere(HEAD_R, 12, 6), head * _xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 1.0)), upper)
	_add(acc, _cone(0.14, 0.13, 0.07, 8, [false, true]), head * _xf(Vector3(0, -0.07, 0.275), Vector3(90, 0, 0)), snout)
	for sx in [-1.0, 1.0]:
		_add(acc, _sphere(0.022, 6, 3), head * _xf(Vector3(sx * 0.05, -0.05, 0.315), Vector3.ZERO, Vector3(1, 1.3, 0.7)), ink)
		_add(acc, _sphere(0.05, 8, 4), head * _xf(Vector3(sx * 0.125, 0.09, 0.235)), ink)
		_add(acc, _sphere(0.016, 6, 3), head * _xf(Vector3(sx * 0.14, 0.11, 0.275)), white)
		_add(acc, BoxMesh.new(), head * _xf(Vector3(sx * 0.125, 0.165, 0.225), Vector3(-30.0, 0.0, sx * 24.0), Vector3(0.12, 0.035, 0.05)), ink)
		_tusk(acc, head, sx, Vector3(sx * 0.17, -0.05, 0.18), white)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = acc.verts
	arrays[Mesh.ARRAY_NORMAL] = acc.norms
	arrays[Mesh.ARRAY_COLOR] = acc.cols
	arrays[Mesh.ARRAY_INDEX] = acc.idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.resource_name = "BoarMesh"
	return m
