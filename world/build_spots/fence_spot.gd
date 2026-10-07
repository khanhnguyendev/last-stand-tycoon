class_name FenceSpot
extends BuildSpot
## Fence bar across its lane (spec 7.6). Rubble at hp <= 0 until dawn resets it.

## Level models (S4 Task 12, D-194): 0.9 m tall, 3 m across. Rubble replaces the model at hp <= 0.
const MODELS: Array[PackedScene] = [
	preload("res://art/env/fence_l1.tscn"), preload("res://art/env/fence_l2.tscn"), preload("res://art/env/fence_l3.tscn"),
]
const RUBBLE: PackedScene = preload("res://art/env/fence_rubble.tscn")
const PIP_Y := 1.2  ## model height 0.9 + 0.3

var _rubble := false

func _build_visual() -> void:
	var lane: String = MapLayout.fence_lane(spot_id)
	var path: Array = MapLayout.lane_path(lane)
	var tangent := Geometry.tangent_at(path, MapLayout.path_length(lane) - MapLayout.FENCE_OFFSET_FROM_END)
	visual.rotation.y = atan2(tangent.x, tangent.y)

func _apply_level(p_level: int, b: Dictionary) -> void:
	visual.visible = p_level >= 1
	_rubble = p_level >= 1 and float(b.hp) <= 0.0
	var scene: PackedScene = null
	if p_level >= 1:
		scene = RUBBLE if _rubble else MODELS[mini(p_level, MODELS.size()) - 1]
	_show_model(p_level, scene)

func is_rubble() -> bool:
	return _rubble

func _pip_y(_level: int) -> float:
	return PIP_Y

func _label_y(p_level: int) -> float:
	return PIP_Y + 0.55 if p_level >= 1 else super(p_level)
