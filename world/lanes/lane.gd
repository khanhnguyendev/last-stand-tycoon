class_name Lane
extends Node3D
## One lane: Path3D (editor/debug view of MapLayout.LANE_PATHS), ground strip, entrance post.

var lane_id := ""
var path3d: Path3D

func setup(id: String) -> void:
	lane_id = id
	name = "Lane_" + id
	path3d = Path3D.new()
	path3d.curve = Curve3D.new()
	for p in MapLayout.LANE_PATHS[id]:
		path3d.curve.add_point(MapLayout.to3(p))
	add_child(path3d)
	var pts: Array = MapLayout.LANE_PATHS[id]
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var strip := Visuals.box(Vector3(3.0, 0.02, a.distance_to(b)), Visuals.COLORS.lane)
		strip.position = MapLayout.to3((a + b) * 0.5, 0.01)
		strip.rotation.y = atan2(b.x - a.x, b.y - a.y)
		add_child(strip)
	var post := Visuals.cylinder(0.25, 1.5, Visuals.COLORS.telegraph)
	post.position = entrance_position() + Vector3(0, 0.75, 0)
	add_child(post)

func entrance_position() -> Vector3:
	return MapLayout.to3(MapLayout.LANE_PATHS[lane_id][0])
