class_name Lane
extends Node3D
## One lane: Path3D (editor/debug view of MapLayout.LANE_PATHS), dirt strip and edge stones, entrance gate.

const GATE_SCENE := preload("res://art/env/lane_gate.tscn")

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
	# S4 Task 13 (D-201): one strip mesh for the lane, plus one MultiMesh of edge stones.
	add_child(GroundArt.instance(LaneStrip.build_mesh(pts), "Strip"))
	add_child(LaneStrip.edge_stones(pts))
	# Entrance gate posts (S4 Task 12): the model's +z runs along the lane's first segment.
	var gate := GATE_SCENE.instantiate() as Node3D
	gate.position = entrance_position()
	var dir: Vector2 = ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()
	gate.rotation.y = atan2(dir.x, dir.y)
	add_child(gate)

func entrance_position() -> Vector3:
	return MapLayout.to3(MapLayout.LANE_PATHS[lane_id][0])
