class_name TelegraphMarker
extends Node3D
## Day-only threat marker near each lane's fence spot (D-029, D-093). Hidden when threat is 0.

var lane_id := ""
var target_scale := 0.0
var _phase := Phase.NIGHT

func setup(id: String) -> void:
	lane_id = id
	name = "Telegraph_" + id
	position = MapLayout.to3(MapLayout.telegraph_spot(id))
	var v := Visuals.visual_root()
	var cone := Visuals.cone(0.5, 1.2, Visuals.COLORS.telegraph)
	cone.position.y = 0.6
	v.add_child(cone)
	add_child(v)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	refresh()

func refresh() -> void:
	if GameState.lane_plan.is_empty():
		target_scale = 0.0
		visible = false
		return
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var mx: float = threat.values().max()
	target_scale = LanePlanner.marker_scale(threat[lane_id], mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
	visible = _phase == Phase.DAY and target_scale > 0.0
	if target_scale > 0.0:
		scale = Vector3.ONE * target_scale
