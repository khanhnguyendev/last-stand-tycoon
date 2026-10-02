class_name LaneStrip
extends RefCounted
## A lane's dirt strip and its stone edge pieces (S4 Task 13, D-194, D-201). One mesh per lane: a mitred ribbon along the
## whole polyline (dirt centre, dirt_dark edges), so bends have no overlap. The edge stones are one MultiMesh per lane.
## Static, visual only: no Rng (the stone yaw is a position hash).

const WIDTH := 3.0
const EDGE := 0.3
const Y := 0.02
const STONE_SPACING := 2.5
const STONE_SCALE := 0.8
## Stones inside this rect (the diner and its walls) are skipped.
const STONE_SKIP := Rect2(-4.5, -4.5, 9, 9)
const STONE_MODEL := "res://art/env/baked/prop_rocks_small.res"

## The per-point mitre: the unit normal (xz) and the length factor 1 / dot(miter, segment normal).
static func _frames(pts: Array) -> Array:
	var out := []
	for i in pts.size():
		var n := Vector2.ZERO
		var k := 0.0
		if i > 0:
			var d: Vector2 = ((pts[i] as Vector2) - (pts[i - 1] as Vector2)).normalized()
			n += Vector2(-d.y, d.x)
		if i < pts.size() - 1:
			var d2: Vector2 = ((pts[i + 1] as Vector2) - (pts[i] as Vector2)).normalized()
			n += Vector2(-d2.y, d2.x)
		n = n.normalized()
		var seg: Vector2 = ((pts[i + 1] as Vector2) - (pts[i] as Vector2)).normalized() if i < pts.size() - 1 else ((pts[i] as Vector2) - (pts[i - 1] as Vector2)).normalized()
		k = 1.0 / maxf(n.dot(Vector2(-seg.y, seg.x)), 0.25)
		out.append([n, k])
	return out

## The strip's vertex arrays along `pts` (Array of Vector2 xz), `width` wide, with `edge`-wide dirt_dark borders.
static func strip_arrays(pts: Array, width := WIDTH, edge := EDGE) -> Dictionary:
	var frames := _frames(pts)
	var half := width * 0.5
	var offsets := [-half, -half + edge, half - edge, half]
	var dirt := Palette.color(&"dirt")
	var dark := Palette.color(&"dirt_dark")
	var cols := [dark, dirt, dirt, dark]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for i in pts.size():
		var n: Vector2 = frames[i][0]
		var k: float = frames[i][1]
		for o in 4:
			var p: Vector2 = (pts[i] as Vector2) + n * (offsets[o] * k)
			verts.append(Vector3(p.x, Y, p.y))
			normals.append(Vector3.UP)
			colors.append(cols[o])
	var idx := PackedInt32Array()
	for i in range(1, pts.size()):
		for o in 3:
			var a := (i - 1) * 4 + o
			var b := i * 4 + o
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	_fix_winding(verts, idx)
	return {"v": verts, "n": normals, "c": colors, "i": idx}

## The strip as a mesh (tests).
static func build_mesh(pts: Array) -> ArrayMesh:
	return GroundArt.mesh_from(strip_arrays(pts))

## Make the faces front-facing from above whatever the polyline direction is (Godot's front face is clockwise: its
## right-hand normal points down).
static func _fix_winding(verts: PackedVector3Array, idx: PackedInt32Array) -> void:
	if idx.size() < 3:
		return
	var a := verts[idx[0]]
	if (verts[idx[1]] - a).cross(verts[idx[2]] - a).y <= 0.0:
		return
	for t in idx.size() / 3:
		var tmp := idx[t * 3 + 1]
		idx[t * 3 + 1] = idx[t * 3 + 2]
		idx[t * 3 + 2] = tmp

## Edge-stone transforms: every STONE_SPACING m along the path, on both sides at the strip's outer edge.
static func edge_transforms(pts: Array, spacing := STONE_SPACING, width := WIDTH) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var side := width * 0.5 + 0.25
	var walked := 0.0
	var next := spacing * 0.5
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var len := a.distance_to(b)
		var d := (b - a) / len
		var nrm := Vector2(-d.y, d.x)
		while next <= walked + len:
			var c := a + d * (next - walked)
			for s in [-1.0, 1.0]:
				var p: Vector2 = c + nrm * (side * s)
				if STONE_SKIP.has_point(p):
					continue
				var yaw := GroundArt.hash01(p.x, p.y) * TAU
				out.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * STONE_SCALE), Vector3(p.x, 0.0, p.y)))
			next += spacing
		walked += len
	return out

## One world-level MultiMeshInstance3D with the edge stones of every lane (D-201).
static func edge_stones() -> MultiMeshInstance3D:
	var xfs: Array[Transform3D] = []
	for id in MapLayout.LANE_PATHS:
		xfs.append_array(edge_transforms(MapLayout.LANE_PATHS[id]))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = load(STONE_MODEL) as Mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "EdgeStones"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
