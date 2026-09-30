class_name Geometry
extends RefCounted
## 2D (XZ) geometry helpers. Paths are Arrays of Vector2.

static func path_length(path: Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector2).distance_to(path[i - 1])
	return total

static func _segment_at(path: Array, dist: float) -> Array:
	# returns [segment_index, distance_into_segment]
	var d := clampf(dist, 0.0, path_length(path))
	for i in range(1, path.size()):
		var seg := (path[i] as Vector2).distance_to(path[i - 1])
		assert(seg > 0.0, "zero-length path segment")
		if d <= seg or i == path.size() - 1:
			return [i, minf(d, seg)]
		d -= seg
	return [path.size() - 1, 0.0]

static func point_at(path: Array, dist: float) -> Vector2:
	var s := _segment_at(path, dist)
	var a: Vector2 = path[s[0] - 1]
	var b: Vector2 = path[s[0]]
	return a + (b - a).normalized() * float(s[1])

static func tangent_at(path: Array, dist: float) -> Vector2:
	var s := _segment_at(path, dist)
	return ((path[s[0]] as Vector2) - (path[s[0] - 1] as Vector2)).normalized()

static func point_back_from_end(path: Array, back: float) -> Vector2:
	return point_at(path, path_length(path) - back)

static func dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func dist_point_rect(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()

static func rect_contains(r: Rect2, p: Vector2, eps := 1e-4) -> bool:
	return p.x >= r.position.x - eps and p.x <= r.end.x + eps and p.y >= r.position.y - eps and p.y <= r.end.y + eps

static func rect_corners(r: Rect2) -> Array:
	return [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]

static func _contains_all(c: Vector2, radius: float, points: Array) -> bool:
	for p in points:
		if (p as Vector2).distance_to(c) > radius + 1e-6:
			return false
	return true

static func enclosing_radius(points: Array) -> float:
	# Brute-force minimal enclosing circle: fine for a few dozen points.
	if points.size() <= 1:
		return 0.0
	var best := INF
	var n := points.size()
	for i in n:
		for j in range(i + 1, n):
			var c: Vector2 = ((points[i] as Vector2) + (points[j] as Vector2)) * 0.5
			var r := (points[i] as Vector2).distance_to(c)
			if r < best and _contains_all(c, r, points):
				best = r
			for k in range(j + 1, n):
				var cc := _circumcenter(points[i], points[j], points[k])
				if cc.x == INF:
					continue
				var rr := (points[i] as Vector2).distance_to(cc)
				if rr < best and _contains_all(cc, rr, points):
					best = rr
	return best

static func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-9:
		return Vector2(INF, INF)
	var a2 := a.length_squared()
	var b2 := b.length_squared()
	var c2 := c.length_squared()
	return Vector2(
		(a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
		(a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d)
