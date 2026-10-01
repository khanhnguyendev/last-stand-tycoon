class_name CarryStack
extends Node3D
## Visual steak stack on the hero's back, driven by GameState.carried_steaks (D-009).
## One MultiMeshInstance3D with a slot per steak the hero can ever carry (D-201).

var _pile: MultiMeshInstance3D

func _ready() -> void:
	var cb := Balance.data.cards
	var cap := CardEffects.carry_capacity(Balance.data.hero.carry_capacity, {&"carry_capacity": cb.max_level}, cb)
	var slots := PackedVector3Array()
	for i in cap:
		slots.append(Vector3(0, 1.0 + i * 0.2, 0.5))
	_pile = PileMesh.steak_pile(slots)
	add_child(_pile)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	PileMesh.set_count(_pile, GameState.carried_steaks)

func visible_count() -> int:
	return PileMesh.count(_pile)
