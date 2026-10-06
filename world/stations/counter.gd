class_name Counter
extends Node3D
## Carry → counter, 1 steak per tick up to counter_capacity (spec 8.3). Travelers buy from it.

const COUNTER_ART := preload("res://art/env/counter_visual.tscn")

var zone: StationZone
var label: WorldLabel
var _pile: MultiMeshInstance3D
var _fx: FlyFx
var body_visual: Node3D
var _pop: Tween

func setup(world: World) -> void:
	name = "Counter"
	_fx = world.fly_fx
	var body := world.add_static_box("CounterBody", Vector3(MapLayout.COUNTER_SIZE.x, 1.0, MapLayout.COUNTER_SIZE.y), MapLayout.COUNTER, COUNTER_ART)
	body_visual = body.get_child(1) as Node3D  # add_static_box: child 0 is the shape, child 1 the visual root
	position = MapLayout.to3(MapLayout.COUNTER_DROP)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)
	label = WorldLabel.make("0")
	label.position = MapLayout.to3(MapLayout.COUNTER - MapLayout.COUNTER_DROP, 2.2)
	add_child(label)
	var sb := Balance.data.stations
	var slots := PackedVector3Array()
	for i in StationEffects.counter_capacity(sb.max_level, sb):
		var layer := floori(i / 12.0)  # 2 rows of 6 per layer; the pile grows upward
		var j := i % 12
		var col := j % 6
		var row := floori(j / 6.0)
		slots.append(MapLayout.to3(MapLayout.COUNTER - MapLayout.COUNTER_DROP + Vector2(-1.1 + col * 0.44, -0.2 + row * 0.4), 1.1 + layer * 0.18))
	_pile = PileMesh.steak_pile(slots)
	_pile.name = "Pile"
	add_child(_pile)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(_on_state_restored)
	EventBus.station_upgraded.connect(_on_station_upgraded)
	refresh()

func _on_tick() -> void:
	if GameState.move_carry_to_counter(1) > 0:
		EventBus.sfx_requested.emit(&"stock")
		var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
		if _fx != null and hero != null:
			_fx.fly("steak", hero.global_position + Vector3(0, 1.2, 0.5), MapLayout.to3(MapLayout.COUNTER, 1.2))

func refresh() -> void:
	label.text = str(GameState.counter_steaks)
	PileMesh.set_count(_pile, GameState.counter_steaks)

func stack_count() -> int:
	return PileMesh.count(_pile)

## Visual only: the model pops; the StaticBody3D and its shape are never scaled.
func _on_station_upgraded(id: StringName, _level: int) -> void:
	if id != &"counter" or body_visual == null:
		return
	_pop = PopFx.pop(self, body_visual, Vector3.ONE, _pop)

## A restore mid-pop must not leave the model scaled or a tween running.
func _on_state_restored() -> void:
	PopFx.kill(_pop)
	_pop = null
	if body_visual != null:
		body_visual.scale = Vector3.ONE
	refresh()
