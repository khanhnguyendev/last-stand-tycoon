class_name FenceSpot
extends BuildSpot
## Fence bar across its lane (spec 7.6). Rubble at hp <= 0 until dawn resets it.

var _bar: MeshInstance3D
var _rubble := false

func _build_visual() -> void:
	var lane: String = MapLayout.FENCE_LANE[spot_id]
	var path: Array = MapLayout.LANE_PATHS[lane]
	var tangent := Geometry.tangent_at(path, MapLayout.path_length(lane) - MapLayout.FENCE_OFFSET_FROM_END)
	_bar = Visuals.box(Vector3(3.0, 0.8, 0.3), Visuals.COLORS.fence)
	_bar.position.y = 0.4
	visual.rotation.y = atan2(tangent.x, tangent.y)
	visual.add_child(_bar)

func _apply_level(p_level: int, b: Dictionary) -> void:
	visual.visible = p_level >= 1
	_rubble = p_level >= 1 and float(b.hp) <= 0.0
	_bar.scale = Vector3(1.0, 0.15 if _rubble else 1.0, 1.0)
	_bar.position.y = 0.06 if _rubble else 0.4

func is_rubble() -> bool:
	return _rubble
