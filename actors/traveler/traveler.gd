class_name Traveler
extends Node3D
## A buyer (spec 8.4). Moved in code; holds no game state (D-045).

var want := 1
var service_timer := 0.0
var leaving := false
var _target := Vector2.ZERO

func _init() -> void:
	name = "Traveler"
	var v := Visuals.visual_root()
	var m := Visuals.capsule(0.35, 1.4, Visuals.COLORS.traveler)
	m.position.y = 0.7
	v.add_child(m)
	add_child(v)

func begin(p_want: int) -> void:
	want = p_want
	service_timer = 0.0
	leaving = false
	position = MapLayout.to3(MapLayout.TRAVELER_ENTER)
	_target = MapLayout.TRAVELER_ENTER

func set_target(p: Vector2) -> void:
	_target = p

func leave() -> void:
	leaving = true
	_target = MapLayout.TRAVELER_EXIT

func xz() -> Vector2:
	return Vector2(position.x, position.z)

func at_target() -> bool:
	return xz().distance_to(_target) < 0.05

func gone() -> bool:
	return leaving and at_target()

func _physics_process(delta: float) -> void:
	position = MapLayout.to3(xz().move_toward(_target, Balance.data.economy.traveler_speed * delta))
