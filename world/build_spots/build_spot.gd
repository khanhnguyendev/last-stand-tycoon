class_name BuildSpot
extends Node3D
## Base for tower and fence spots. All state comes from GameState.buildings[spot_id] (D-036).

var spot_id := ""
var level := 0
var label: WorldLabel
var zone: StationZone
var visual: Node3D
var _world: World
var _pips: Array = []
var _fx: FlyFx
var _pop: Tween

func setup(id: String, world: World) -> void:
	spot_id = id
	_world = world
	_fx = world.fly_fx
	name = "Spot_" + id
	position = MapLayout.to3(MapLayout.spot_position(id))
	visual = Visuals.visual_root()
	add_child(visual)
	_build_visual()
	label = WorldLabel.make("", 40)
	label.position = Vector3(0, 2.6, 0)
	add_child(label)
	var max_level: int = Balance.data.build.max_level
	for i in max_level:
		var pip := Visuals.box(Vector3(0.18, 0.18, 0.18), Visuals.COLORS.pip)
		pip.position = Vector3((i - (max_level - 1) * 0.5) * 0.3, 2.1, 0)
		add_child(pip)
		_pips.append(pip)
	# Stand-still payment (spec 8.x). The spot drives its own ring: paid / cost, not the stand charge.
	zone = StationZone.new()
	zone.radius = MapLayout.BUILD_RADIUS
	zone.drive_ring = false
	add_child(zone)
	zone.ticked.connect(_on_tick)
	EventBus.building_changed.connect(_on_building_changed)
	EventBus.build_completed.connect(_on_build_completed)  # after building_changed: the pop starts from the new scale
	EventBus.phase_changed.connect(_on_phase_changed)  # after the zone's own connection (it syncs its phase first)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	var cost := GameState.next_level_cost(spot_id)
	if cost < 0:
		return
	var paid := GameState.pay_into_spot(spot_id, Economy.drain_per_tick(cost, Balance.data.build))
	if paid > 0:
		var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
		if _fx != null and hero != null:
			_fx.fly("coin", hero.global_position + Vector3(0, 1.2, 0), global_position + Vector3(0, 1.0, 0))

func _on_building_changed(id: StringName, _level: int, _paid: int) -> void:
	if String(id) == spot_id:
		refresh()

func _on_build_completed(id: StringName, _level: int) -> void:
	if String(id) != spot_id:
		return
	_kill_pop()
	var base := visual.scale
	visual.scale = base * Balance.ui.build_pop_scale
	_pop = create_tween()
	_pop.tween_property(visual, "scale", base, Balance.ui.build_pop_time)

func _kill_pop() -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_pop = null

## Task 23 review: partial-payment rings don't glow on the lanes during combat.
func _on_phase_changed(_phase: int, _day: int) -> void:
	refresh()

## Rebuilds everything from GameState. Safe before the first new_game (buildings is empty then).
func refresh() -> void:
	_kill_pop()
	var b: Dictionary = GameState.buildings.get(spot_id, {"level": 0, "paid": 0, "hp": 0.0})
	level = int(b.level)
	visual.scale = Vector3.ONE * pow(Balance.ui.build_level_scale, maxi(level - 1, 0))
	for i in _pips.size():
		_pips[i].visible = i < level
	if GameState.buildings.has(spot_id):
		var remaining := GameState.remaining_cost(spot_id)
		label.text = tr("MAX") if remaining < 0 else str(remaining)
	else:
		label.text = ""
	_apply_level(level, b)
	if zone != null:
		var cost := GameState.next_level_cost(spot_id) if GameState.buildings.has(spot_id) else -1
		var progress := 0.0 if cost <= 0 else float(b.paid) / float(cost)
		zone.ring.visible = progress > 0.0 and zone.is_active()
		zone.ring.set_progress(progress)

## Subclasses build their meshes under `visual`.
func _build_visual() -> void:
	pass

## Subclasses react to level/hp.
func _apply_level(_level: int, _b: Dictionary) -> void:
	pass
