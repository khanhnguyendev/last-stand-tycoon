class_name CloseUpSign
extends Node3D
## "Close up" sign (spec 5.6, 8.8, D-039, D-068). Hold closeup_hold standing still -> closeup_requested.
## The zone's own still-charge ring is off (drive_ring = false): this node drives the ring with the hold.

const SIGN_SCENE := preload("res://art/env/closeup_sign.tscn")

var zone: StationZone
var hold := 0.0
var pulsing := false
var _visual: Node3D
var _phase := Phase.NIGHT
var _t := 0.0

func setup(_world: World) -> void:
	name = "CloseUpSign"
	position = MapLayout.to3(MapLayout.SIGN)
	_visual = SIGN_SCENE.instantiate()  # root "Visual": the pulse scales it (S4 Task 12, D-201: one baked mesh)
	add_child(_visual)
	var l := WorldLabel.make(tr("Close up"), 36)
	l.position.y = 1.95
	add_child(l)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	zone.drive_ring = false  # the sign drives the ring with the hold
	add_child(zone)
	zone.stand_started.connect(_on_stand_started)
	zone.ticked.connect(_on_tick)
	zone.stand_ended.connect(_on_stand_ended)
	EventBus.stocks_changed.connect(refresh_pulse)
	EventBus.state_restored.connect(refresh_pulse)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.building_changed.connect(_on_building_changed)
	EventBus.station_changed.connect(_on_station_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	refresh_pulse()

func _on_stand_started() -> void:
	hold = 0.0
	zone.ring.visible = true
	zone.ring.set_progress(0.0)

func _on_stand_ended() -> void:
	hold = 0.0
	zone.ring.set_progress(0.0)
	zone.ring.visible = false

func _on_gold_changed(_gold: int, _delta: int) -> void:
	refresh_pulse()

func _on_building_changed(_id: StringName, _level: int, _paid: int) -> void:
	refresh_pulse()

## gold_changed fires before the level increments, so the pulse must be re-read after station_changed (E1).
func _on_station_changed(_id: StringName, _level: int, _paid: int) -> void:
	refresh_pulse()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	refresh_pulse()

## Runs on the zone's physics ticks (gameplay, D-118).
func _on_tick() -> void:
	var eco := Balance.data.economy
	hold += eco.transfer_tick
	zone.ring.set_progress(hold / eco.closeup_hold)
	if hold >= eco.closeup_hold - 1e-6:
		hold = 0.0
		zone.ring.set_progress(0.0)
		EventBus.closeup_requested.emit()

func refresh_pulse() -> void:
	pulsing = _phase == Phase.DAY and not GameState.buildings.is_empty() and Pulse.should_pulse(GameState.to_dict(), Balance.data)
	if not pulsing:
		_t = 0.0
		_visual.scale = Vector3.ONE

## Visual only (spec 8.8): the sign breathes while there is nothing left to do but close up.
func _process(delta: float) -> void:
	if pulsing:
		_t += delta
		var k := 0.5 + 0.5 * sin(_t * TAU * Balance.ui.pulse_hz)
		_visual.scale = Vector3.ONE * lerpf(1.0, Balance.ui.pulse_scale, k)
