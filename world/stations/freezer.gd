class_name Freezer
extends Node3D
## Freezer → carry, 1 steak per tick (spec 8.2). Visual stack up to 10 plus a count label.

const FREEZER_ART := preload("res://art/env/freezer_visual.tscn")

var zone: StationZone
var label: WorldLabel
var _pile: MultiMeshInstance3D
var _fx: FlyFx
const _stack_cap := 10

func setup(world: World) -> void:
	name = "Freezer"
	_fx = world.fly_fx
	world.add_static_box("FreezerBody", Vector3(MapLayout.FREEZER_SIZE.x, 1.4, MapLayout.FREEZER_SIZE.y), MapLayout.FREEZER, FREEZER_ART)
	position = MapLayout.to3(MapLayout.FREEZER_ZONE)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)
	label = WorldLabel.make("0")
	label.position = MapLayout.to3(MapLayout.FREEZER - MapLayout.FREEZER_ZONE, 1.5 + _stack_cap * 0.18 + 0.5)
	add_child(label)
	var slots := PackedVector3Array()
	for i in _stack_cap:
		slots.append(MapLayout.to3(MapLayout.FREEZER - MapLayout.FREEZER_ZONE, 1.5 + i * 0.18))
	_pile = PileMesh.steak_pile(slots)
	_pile.name = "Pile"
	add_child(_pile)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	if GameState.move_freezer_to_carry(1) > 0:
		EventBus.sfx_requested.emit(&"take")
		var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
		if _fx != null and hero != null:
			_fx.fly("steak", MapLayout.to3(MapLayout.FREEZER, 1.6), hero.global_position + Vector3(0, 1.2, 0.5))

func refresh() -> void:
	label.text = str(GameState.freezer_steaks)
	PileMesh.set_count(_pile, GameState.freezer_steaks)

func stack_count() -> int:
	return PileMesh.count(_pile)
