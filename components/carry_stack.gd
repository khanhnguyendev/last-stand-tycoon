class_name CarryStack
extends Node3D
## Visual steak stack on the hero's back, driven by GameState.carried_steaks (D-009).
## Slots are behind and above the head, tightly spaced, so the face stays clear (S4 R2).
## One MultiMeshInstance3D with a slot per steak the hero can ever carry (cards and freezer, D-201).

var _pile: MultiMeshInstance3D
var _squash: Tween

func _ready() -> void:
	var bd := Balance.data
	var cap := StationEffects.max_carry(bd.hero, bd.cards, bd.stations)
	var slots := PackedVector3Array()
	for i in cap:
		slots.append(Vector3(0, 1.3 + i * 0.09, -0.3))  # behind the hero on screen (the camera sits at +z): R2
	_pile = PileMesh.steak_pile(slots)
	add_child(_pile)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	EventBus.steak_picked.connect(func(_c): _squash_pop())
	refresh()

## S5 Task 5: a short squash on every pickup (visual only).
func _squash_pop() -> void:
	if _squash != null and _squash.is_valid():
		_squash.kill()
	scale = Vector3(1.0, Balance.ui.carry_squash, 1.0)
	_squash = create_tween()
	_squash.tween_property(self, "scale", Vector3.ONE, Balance.ui.carry_squash_time)

func refresh() -> void:
	PileMesh.set_count(_pile, GameState.carried_steaks)

func visible_count() -> int:
	return PileMesh.count(_pile)
