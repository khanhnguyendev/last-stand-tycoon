class_name EnemyPath
extends RefCounted
## Boar position along its lane with a lateral offset that blends onto the zone axis near the end (D-111).

static func position_at(lane: String, dist: float, offset: float, fade: float) -> Vector2:
	var path: Array = MapLayout.LANE_PATHS[lane]
	var length := Geometry.path_length(path)
	var d := clampf(dist, 0.0, length)
	var base := Geometry.point_at(path, d)
	var tangent := Geometry.tangent_at(path, d)
	var perp := Vector2(-tangent.y, tangent.x)
	var k := clampf((length - d) / fade, 0.0, 1.0) if fade > 0.0 else (1.0 if d < length else 0.0)
	var axis: Vector2 = MapLayout.ZONE_AXIS[lane]
	return base + perp * offset * k + axis * offset * (1.0 - k)
