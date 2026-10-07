class_name TelegraphMarker
extends Node3D
## Day-only threat marker near each lane's fence spot (D-029, D-093). Hidden when threat is 0.

const FLAG_SCENE := preload("res://art/env/telegraph_flag.tscn")

var lane_id := ""
var target_scale := 0.0
var _phase := Phase.NIGHT

func setup(id: String) -> void:
	lane_id = id
	name = "Telegraph_" + id
	position = MapLayout.to3(MapLayout.telegraph_spot(id))
	add_child(FLAG_SCENE.instantiate())  # root "Visual"; the flag mesh carries the enemy_red override (R4)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(refresh)
	EventBus.tier_changed.connect(_on_tier_changed)  # the day the tier is paid, the boss lane already shows
	refresh()

## A marker made mid-game missed phase_changed: the world hands it the phase it last announced.
func sync_phase(p: int) -> void:
	_phase = p
	refresh()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	refresh()

func _on_tier_changed(_tier: int, _paid: int, _boss_pending: bool) -> void:
	refresh()

func refresh() -> void:
	if GameState.lane_plan.is_empty():
		target_scale = 0.0
		visible = false
		return
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp, GameState.tier)
	var mx: float = threat.values().max()
	target_scale = LanePlanner.marker_scale(float(threat.get(lane_id, 0.0)), mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
	visible = _phase == Phase.DAY and target_scale > 0.0
	if target_scale > 0.0:
		scale = Vector3.ONE * target_scale
