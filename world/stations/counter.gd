class_name Counter
extends Node3D
## Carry → counter, 1 steak per tick up to counter_capacity (spec 8.3). Travelers buy from it.

var zone: StationZone
var label: WorldLabel
var _stack: Array = []
var _fx: FlyFx

func setup(world: World) -> void:
	name = "Counter"
	_fx = world.fly_fx
	world.add_static_box("CounterBody", Vector3(MapLayout.COUNTER_SIZE.x, 1.0, MapLayout.COUNTER_SIZE.y), MapLayout.COUNTER, Visuals.COLORS.counter)
	position = MapLayout.to3(MapLayout.COUNTER_DROP)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)
	label = WorldLabel.make("0")
	label.position = MapLayout.to3(MapLayout.COUNTER - MapLayout.COUNTER_DROP, 2.2)
	add_child(label)
	for i in Balance.data.economy.counter_capacity:
		var m := Visuals.box(Vector3(0.35, 0.16, 0.25), Visuals.COLORS.steak)
		var col := i % 6
		var row := floori(i / 6.0)
		m.position = MapLayout.to3(MapLayout.COUNTER - MapLayout.COUNTER_DROP + Vector2(-1.1 + col * 0.44, -0.2 + row * 0.4), 1.1)
		add_child(m)
		_stack.append(m)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	if GameState.move_carry_to_counter(1) > 0:
		var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
		if _fx != null and hero != null:
			_fx.fly("steak", hero.global_position + Vector3(0, 1.2, 0.5), MapLayout.to3(MapLayout.COUNTER, 1.2))

func refresh() -> void:
	label.text = str(GameState.counter_steaks)
	for i in _stack.size():
		_stack[i].visible = i < GameState.counter_steaks

func stack_count() -> int:
	return _stack.filter(func(m): return m.visible).size()
