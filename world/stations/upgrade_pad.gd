class_name UpgradePad
extends Node3D
## Stand-still payment for one station's next level (E1 spec 3). All state comes from GameState.stations.

const MARKER_SCENE := preload("res://art/env/spot_marker.tscn")
const PIP_Y := 1.1
const LABEL_Y := 1.6

var station_id: StringName
var label: WorldLabel
var zone: StationZone
var marker: Node3D
var _pips: Array = []
var _fx: FlyFx
## Paid ticks since the level started; drives the dust only (visual).
var _paid_ticks := 0

func setup(id: StringName, world: World) -> void:
	station_id = id
	_fx = world.fly_fx
	name = "Pad_%s" % id
	position = MapLayout.to3(MapLayout.STATION_PADS[id])
	label = WorldLabel.make("", 40)
	label.position = Vector3(0, LABEL_Y, 0)
	add_child(label)
	marker = MARKER_SCENE.instantiate()
	add_child(marker)
	_pips = LevelPips.make(self, Balance.data.stations.max_level, PIP_Y)
	zone = StationZone.new()
	zone.radius = MapLayout.BUILD_RADIUS
	zone.drive_ring = false  # the ring shows paid / cost
	add_child(zone)
	zone.ticked.connect(_on_tick)
	EventBus.station_changed.connect(_on_station_changed)
	EventBus.phase_changed.connect(_on_phase_changed)  # after the zone's own connection (it syncs its phase first)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	var cost := GameState.station_next_cost(station_id)
	if cost < 0:
		return
	var paid := GameState.pay_into_station(station_id, Economy.drain_per_tick(cost, Balance.data.build))
	if paid <= 0:
		return
	if GameState.station_remaining_cost(station_id) == GameState.station_next_cost(station_id):
		_paid_ticks = 0  # this tick completed a level
	else:
		_paid_ticks += 1
	if _paid_ticks > 0 and _paid_ticks % maxi(Balance.ui.build_dust_every, 1) == 0:
		EventBus.fx_requested.emit(&"dust", global_position)
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if _fx != null and hero != null:
		_fx.fly("coin", hero.global_position + Vector3(0, 1.2, 0), global_position + Vector3(0, 0.3, 0))

func _on_station_changed(id: StringName, _level: int, _paid: int) -> void:
	if id == station_id:
		refresh()

func _on_phase_changed(_phase: int, _day: int) -> void:
	refresh()

## Rebuilds everything from GameState. Safe before the first new_game (stations is empty then).
func refresh() -> void:
	var known := GameState.stations.has(station_id)
	var level := GameState.station_level(station_id)
	var cost := GameState.station_next_cost(station_id)
	var paid := int(GameState.stations[station_id].paid) if known else 0
	if paid == 0:
		_paid_ticks = 0
	var day := zone != null and zone.is_active()
	LevelPips.show_level(_pips, level, PIP_Y)
	if not known:
		label.text = ""
	elif cost < 0:
		label.text = tr("MAX")
	else:
		label.text = str(cost - paid)
	label.visible = day
	marker.visible = day and known and cost >= 0
	if zone != null:
		var progress := 0.0 if cost <= 0 else float(paid) / float(cost)
		zone.ring.visible = progress > 0.0 and day
		zone.ring.set_progress(progress)
