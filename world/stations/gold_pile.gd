class_name GoldPile
extends Node3D
## Coins waiting to be collected by walking over (spec 8.5). Drawn from GameState.gold_pile.

const MAX_COINS := 30
var label: WorldLabel
var _pile: MultiMeshInstance3D

func setup(_world: World) -> void:
	name = "GoldPile"
	position = MapLayout.to3(MapLayout.GOLD_PILE)
	var slots := PackedVector3Array()
	for i in MAX_COINS:
		slots.append(Vector3((i % 3) * 0.38 - 0.38, 0.04 + floori(i / 3.0) * 0.07, 0))
	_pile = PileMesh.coin_pile(slots)
	_pile.name = "Pile"
	add_child(_pile)
	label = WorldLabel.make("")
	label.position.y = 1.6
	add_child(label)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	var n := GameState.gold_pile
	PileMesh.set_count(_pile, n)
	label.text = str(n) if n > 0 else ""

func coin_count() -> int:
	return PileMesh.count(_pile)
