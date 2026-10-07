class_name FenceSpot
extends BuildSpot
## Fence bar across its lane (spec 7.6). Rubble at hp <= 0 until dawn resets it.

## Level models (S4 Task 12, D-194): 0.9 m tall, 3 m across. Rubble replaces the model at hp <= 0.
const MODELS: Array[PackedScene] = [
	preload("res://art/env/fence_l1.tscn"), preload("res://art/env/fence_l2.tscn"), preload("res://art/env/fence_l3.tscn"),
]
const RUBBLE: PackedScene = preload("res://art/env/fence_rubble.tscn")
const PIP_Y := 1.2  ## model height 0.9 + 0.3
## E5 tier 3 (Task 18, spec 7): a level-3 fence with a branch shows its branch model (rubble still wins).
const BRANCH_MODELS := {
	&"stone": preload("res://art/env/fence_stone.tscn"), &"spike": preload("res://art/env/fence_spike.tscn"),
}
const BRANCH_PIP_Y := {&"stone": 1.5, &"spike": 1.6}  ## model height (stone 1.2, spike 1.3) + 0.3

var _rubble := false

func _build_visual() -> void:
	var lane: String = MapLayout.fence_lane(spot_id)
	var path: Array = MapLayout.lane_path(lane)
	var tangent := Geometry.tangent_at(path, MapLayout.path_length(lane) - MapLayout.FENCE_OFFSET_FROM_END)
	visual.rotation.y = atan2(tangent.x, tangent.y)

## The branch that shows on the model: only at the top level, else &"".
static func shown_branch(p_level: int, branch: StringName) -> StringName:
	return branch if p_level == Balance.data.build.max_level and BRANCH_MODELS.has(branch) else &""

## The model of a standing fence (level 1-based, 0 = none; rubble is chosen by the caller) and branch.
static func model_for(p_level: int, branch: StringName) -> PackedScene:
	if p_level < 1:
		return null
	var br := shown_branch(p_level, branch)
	return BRANCH_MODELS[br] if br != &"" else MODELS[mini(p_level, MODELS.size()) - 1]

func _apply_level(p_level: int, b: Dictionary) -> void:
	visual.visible = p_level >= 1
	_rubble = p_level >= 1 and float(b.hp) <= 0.0
	var br := shown_branch(p_level, StringName(String(b.get("branch", ""))))
	var scene: PackedScene = null
	if p_level >= 1:
		scene = RUBBLE if _rubble else model_for(p_level, br)
	# _show_model swaps on a change of its first argument (with the rubble flag): a branch model takes a number above every plain level.
	_show_model(p_level + (MODELS.size() * (1 + BRANCH_MODELS.keys().find(br)) if br != &"" else 0), scene)

func is_rubble() -> bool:
	return _rubble

func _pip_y(p_level: int) -> float:
	var b: Dictionary = GameState.buildings.get(spot_id, {})
	if b.has("hp") and float(b.hp) <= 0.0:
		return PIP_Y  # rubble (refresh() sizes the pips before _apply_level has set _rubble): the unbranched rubble height
	var br := shown_branch(p_level, GameState.branch_of(spot_id))
	return float(BRANCH_PIP_Y[br]) if br != &"" else PIP_Y

func _label_y(p_level: int) -> float:
	return _pip_y(p_level) + 0.55 if p_level >= 1 else super(p_level)
