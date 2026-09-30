class_name StationZone
extends Node3D
## Stand-still interaction (D-006, spec 8.1): hero inside radius, still for stand_still_time, phase active.
## Zones must exist before the first phase_changed; an owner that spawns one mid-game calls sync_phase().
## Emits `ticked` every transfer_tick while standing. State changes happen in the owner's tick handler.

signal stand_started
signal ticked
signal stand_ended

var radius := 1.0
var active_phases: Array[int] = [Phase.DAY]
var standing := false
## Armed only when the hero walks INTO the radius while the zone is active (D-121).
var armed := false
var ring: ProgressRing
## Tasks 23/24 set false and drive the ring themselves.
var drive_ring := true
var _phase := Phase.NIGHT
var _tick_timer := 0.0
var _seen_outside := false
var _seen_teleport := -1

func _ready() -> void:
	ring = ProgressRing.new()
	ring.scale = Vector3.ONE * (radius / 1.2)
	ring.visible = false
	add_child(ring)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(disarm)

func is_active() -> bool:
	return _phase in active_phases

## A hero already inside must leave and re-enter before the zone works again.
func disarm() -> void:
	armed = false
	_seen_outside = false
	if standing:
		_end()

func _on_phase_changed(p: int, _day: int) -> void:
	sync_phase(p)

func sync_phase(p: int) -> void:
	_phase = p
	disarm()

func _physics_process(delta: float) -> void:
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null:
		return
	if hero.teleport_serial != _seen_teleport:
		_seen_teleport = hero.teleport_serial
		disarm()
	var d := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	var inside := d <= radius
	if is_active():
		if not inside:
			_seen_outside = true
			armed = false
		elif _seen_outside:
			armed = true
	var ok := is_active() and inside and armed and hero.still_time >= Balance.data.economy.stand_still_time - 1e-6
	if ok:
		if not standing:
			standing = true
			_tick_timer = 0.0
			stand_started.emit()
		_tick_timer += delta
		var tick := Balance.data.economy.transfer_tick
		while _tick_timer >= tick - 1e-9:
			_tick_timer -= tick
			ticked.emit()
	elif standing:
		_end()
	if drive_ring:
		# Visual only: shows the stand-still charge while armed (spec 8.1).
		var charge := 0.0
		if is_active() and inside and armed:
			charge = clampf(hero.still_time / Balance.data.economy.stand_still_time, 0.0, 1.0)
		ring.visible = charge > 0.0
		ring.set_progress(charge)

func _end() -> void:
	standing = false
	stand_ended.emit()
