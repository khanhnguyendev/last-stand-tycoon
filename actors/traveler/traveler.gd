class_name Traveler
extends Node3D
## A buyer (spec 8.4). Moved in code; holds no game state (D-045).

var want := 1
var service_timer := 0.0
var leaving := false
## Which of the six muted looks (D-191). Visual only: set by the world.gd factory counter before add_child.
var variant := 0
var visual: KayKitVisual
## The world's shared blob-shadow field (S4 D-201); set by the world.gd factory before add_child. Null in bare tests.
var shadow_field: ShadowField
var _target := Vector2.ZERO
var _last_xz := Vector2.ZERO
var _hop: Tween
var _rest_y := 0.0

func _init() -> void:
	name = "Traveler"
	visual = preload("res://art/characters/traveler_visual.tscn").instantiate()
	add_child(visual)
	_rest_y = visual.position.y

func begin(p_want: int) -> void:
	_reset_hop()
	want = p_want
	service_timer = 0.0
	leaving = false
	position = MapLayout.to3(MapLayout.TRAVELER_ENTER)
	_target = MapLayout.TRAVELER_ENTER
	_last_xz = xz()
	visual.reset()
	TravelerVariants.apply(visual, variant)
	if shadow_field != null:
		shadow_field.register(visual, ShadowField.CHARACTER_RADIUS)

## NodePool hook: a released traveler leaves the shadow field.
func on_release() -> void:
	_reset_hop()
	if shadow_field != null:
		shadow_field.unregister(visual)

## Sale hop (S5 Task 5): up and back on the Visual only.
func hop() -> void:
	_reset_hop()
	var half := Balance.ui.traveler_hop_time * 0.5
	_hop = create_tween()
	_hop.tween_property(visual, "position:y", _rest_y + Balance.ui.traveler_hop_m, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop.tween_property(visual, "position:y", _rest_y, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _reset_hop() -> void:
	if _hop != null and _hop.is_valid():
		_hop.kill()
	_hop = null
	visual.position.y = _rest_y

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
	var before := xz()
	var speed: float = Balance.data.economy.traveler_speed
	position = MapLayout.to3(before.move_toward(_target, speed * delta))
	# Art only (D-190): motion and facing from this tick's position delta; walking speed is the 0.5 blend (Walking_A).
	var d := xz() - _last_xz
	_last_xz = xz()
	visual.set_motion(0.5 * d.length() / (speed * delta))
	visual.face(Vector3(d.x, 0.0, d.y))
