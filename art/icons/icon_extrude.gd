class_name IconExtrude
extends RefCounted
## Procedural icon solids (S4 Task 15): a 2D outline extruded with one chamfer, flat-shaded, front face +Z.
## Shared by heart_mesh.gd and moon_mesh.gd. Pure geometry: no scene access.

## Rounds the convex corners (shrink then grow) and then the concave ones (grow then shrink) by about r.
static func rounded(poly: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := poly
	for d in [-r, r, r, -r]:
		var res := Geometry2D.offset_polygon(out, d, Geometry2D.JOIN_ROUND)
		var best := PackedVector2Array()
		for q in res:
			if q.size() > best.size():
				best = q
		if not best.is_empty():
			out = best
	return out

## outline: a simple polygon (any winding). depth: total thickness. bevel: chamfer width in the outline's units.
static func build(outline: PackedVector2Array, depth: float, bevel: float) -> ArrayMesh:
	var poly := outline
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()  # CCW with y up: the outward normal of edge (a->b) is (dy, -dx)
	var inner := PackedVector2Array()  # each vertex pulled in along the average of its two edges' inward normals
	var cnt := poly.size()
	for i in cnt:
		var prev := poly[(i + cnt - 1) % cnt]
		var cur := poly[i]
		var nxt := poly[(i + 1) % cnt]
		var n0 := Vector2((cur - prev).y, -(cur - prev).x).normalized()
		var n1 := Vector2((nxt - cur).y, -(nxt - cur).x).normalized()
		var bis := (n0 + n1)
		var l := bis.length()
		bis = bis / l if l > 0.2 else n1
		inner.append(cur - bis * minf(bevel / maxf(bis.dot(n1), 0.5), bevel * 1.6))
	var half := depth * 0.5
	var shoulder := half * 0.55
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Side walls between z = -shoulder and +shoulder.
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var e := (b - a)
		if e.length() < 0.00001:
			continue
		var nn := Vector3(e.y, -e.x, 0).normalized()
		_quad(st, Vector3(a.x, a.y, -shoulder), Vector3(b.x, b.y, -shoulder), Vector3(b.x, b.y, shoulder), Vector3(a.x, a.y, shoulder), nn)
	# Chamfer rings: outline @ shoulder -> inner @ half (and mirrored).
	var cap_poly := inner
	var cap_z := half
	for i in n:
		var j := (i + 1) % n
		var e2 := poly[j] - poly[i]
		if e2.length() < 0.00001:
			continue
		var nn2 := (Vector3(e2.y, -e2.x, 0).normalized() * (half - shoulder) + Vector3(0, 0, bevel)).normalized()
		_quad(st, Vector3(poly[i].x, poly[i].y, shoulder), Vector3(poly[j].x, poly[j].y, shoulder),
			Vector3(inner[j].x, inner[j].y, half), Vector3(inner[i].x, inner[i].y, half), nn2)
		var nn3 := Vector3(nn2.x, nn2.y, -nn2.z)
		_quad(st, Vector3(poly[i].x, poly[i].y, -shoulder), Vector3(poly[j].x, poly[j].y, -shoulder),
			Vector3(inner[j].x, inner[j].y, -half), Vector3(inner[i].x, inner[i].y, -half), nn3)
	var idx := Geometry2D.triangulate_polygon(poly)  # the inset has the same topology; its own triangulation can fail at cusps
	for k in range(0, idx.size(), 3):
		var p0 := cap_poly[idx[k]]
		var p1 := cap_poly[idx[k + 1]]
		var p2 := cap_poly[idx[k + 2]]
		_tri(st, Vector3(p0.x, p0.y, cap_z), Vector3(p1.x, p1.y, cap_z), Vector3(p2.x, p2.y, cap_z), Vector3(0, 0, 1))
		_tri(st, Vector3(p0.x, p0.y, -cap_z), Vector3(p1.x, p1.y, -cap_z), Vector3(p2.x, p2.y, -cap_z), Vector3(0, 0, -1))
	return st.commit()

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nn: Vector3) -> void:
	_tri(st, a, b, c, nn)
	_tri(st, a, c, d, nn)

## Godot front faces are clockwise: (b-a)x(c-a) must point against the outward normal.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nn: Vector3) -> void:
	if (b - a).cross(c - a).dot(nn) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(nn)
		st.add_vertex(v)
