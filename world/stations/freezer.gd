class_name Freezer
extends Node3D
## Freezer → carry, 1 steak per tick (spec 8.2). Visual stack up to 10 plus a count label.

var zone: StationZone
var label: WorldLabel
var _stack: Array = []
const _stack_cap := 10

func setup(world: World) -> void:
	name = "Freezer"
	world.add_static_box("FreezerBody", Vector3(MapLayout.FREEZER_SIZE.x, 1.4, MapLayout.FREEZER_SIZE.y), MapLayout.FREEZER, Visuals.COLORS.freezer)
	position = MapLayout.to3(MapLayout.FREEZER_ZONE)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)
	label = WorldLabel.make("0")
	label.position = MapLayout.to3(MapLayout.FREEZER - MapLayout.FREEZER_ZONE, 1.5 + _stack_cap * 0.18 + 0.5)
	add_child(label)
	for i in _stack_cap:
		var m := Visuals.box(Vector3(0.35, 0.16, 0.25), Visuals.COLORS.steak)
		m.position = MapLayout.to3(MapLayout.FREEZER - MapLayout.FREEZER_ZONE, 1.5 + i * 0.18)
		add_child(m)
		_stack.append(m)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	GameState.move_freezer_to_carry(1)

func refresh() -> void:
	label.text = str(GameState.freezer_steaks)
	for i in _stack.size():
		_stack[i].visible = i < GameState.freezer_steaks

func stack_count() -> int:
	return _stack.filter(func(m): return m.visible).size()
