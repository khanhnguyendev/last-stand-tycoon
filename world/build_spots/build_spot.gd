class_name BuildSpot
extends Node3D
## Base for tower and fence spots. All state comes from GameState.buildings[spot_id] (D-036).

var spot_id := ""
var level := 0
var label: WorldLabel
var zone: StationZone
var visual: Node3D
## The "build here" ring (S4 Task 12): a sibling of `visual`, shown only while the spot is unbuilt in DAY.
var marker: Node3D
var _world: World
var _pips: Array = []
var _fx: FlyFx
var _pop: Tween
## "level/rubble" of the model shown now. The model is swapped only when this changes (no per-event instancing).
var _model_key := ""

const MARKER_SCENE := preload("res://art/env/spot_marker.tscn")

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
	label.position = Vector3(0, _label_y(0), 0)
	add_child(label)
	marker = MARKER_SCENE.instantiate()
	add_child(marker)
	var max_level: int = Balance.data.build.max_level
	for i in max_level:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		pip.mesh = LevelStar.mesh()
		pip.material_override = LevelStar.material()
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.position = Vector3((i - (max_level - 1) * 0.5) * 0.3, _pip_y(1), 0)
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
		_pips[i].position.y = _pip_y(level)
	marker.visible = level == 0 and zone != null and zone.is_active()  # DAY only (the zone's phase is already current)
	if GameState.buildings.has(spot_id):
		var remaining := GameState.remaining_cost(spot_id)
		label.text = tr("MAX") if remaining < 0 else str(remaining)
	else:
		label.text = ""
	label.position.y = _label_y(level)
	label.visible = zone == null or zone.is_active()  # cost text is a DAY thing; night is clutter
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

func is_rubble() -> bool:
	return false

## The level pips float 0.3 m above the model of the level shown (Pillar 1: growth reads).
func _pip_y(_level: int) -> float:
	return 2.1

## The cost label rides above the pips of a built tower; otherwise it keeps its S1 height.
func _label_y(_level: int) -> float:
	return 2.6

## Swaps the model under `visual` for `scene` (null = nothing) when the "level/rubble" key changes; never otherwise.
func _show_model(p_level: int, scene: PackedScene) -> void:
	var key := "%d/%s" % [p_level, is_rubble()]
	if key == _model_key:
		return
	_model_key = key
	for c in visual.get_children():
		visual.remove_child(c)
		c.free()  # a static model: nothing else holds it
	if scene != null:
		visual.add_child(scene.instantiate())
