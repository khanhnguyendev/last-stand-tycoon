class_name Freezer
extends Node3D
## Freezer → carry, `load_per_tick` steaks per tick (spec 8.2, E1 spec 4). Visual stack up to 10 plus a count label.

const FREEZER_ART := preload("res://art/env/freezer_visual.tscn")

var zone: StationZone
var label: WorldLabel
var _pile: MultiMeshInstance3D
var _fx: FlyFx
var body_visual: Node3D
var _pop: Tween
const _stack_cap := 10

func setup(world: World) -> void:
	name = "Freezer"
	_fx = world.fly_fx
	var body := world.add_static_box("FreezerBody", Vector3(MapLayout.FREEZER_SIZE.x, 1.4, MapLayout.FREEZER_SIZE.y), MapLayout.FREEZER, FREEZER_ART)
	body_visual = body.get_child(1) as Node3D  # add_static_box: child 0 is the shape, child 1 the visual root
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
	EventBus.state_restored.connect(_on_state_restored)
	EventBus.station_upgraded.connect(_on_station_upgraded)
	refresh()

func _on_tick() -> void:
	if GameState.move_freezer_to_carry(StationEffects.load_per_tick(GameState.station_level(&"freezer"), Balance.data.stations)) > 0:
		EventBus.sfx_requested.emit(&"take")
		var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
		if _fx != null and hero != null:
			_fx.fly("steak", MapLayout.to3(MapLayout.FREEZER, 1.6), hero.global_position + Vector3(0, 1.2, 0.5))

func refresh() -> void:
	label.text = str(GameState.freezer_steaks)
	PileMesh.set_count(_pile, GameState.freezer_steaks)

func stack_count() -> int:
	return PileMesh.count(_pile)

## Visual only: the model pops; the StaticBody3D and its shape are never scaled.
func _on_station_upgraded(id: StringName, _level: int) -> void:
	if id != &"freezer" or body_visual == null:
		return
	_pop = PopFx.pop(self, body_visual, Vector3.ONE, _pop)

## A restore mid-pop must not leave the model scaled or a tween running.
func _on_state_restored() -> void:
	PopFx.kill(_pop)
	_pop = null
	if body_visual != null:
		body_visual.scale = Vector3.ONE
	refresh()
