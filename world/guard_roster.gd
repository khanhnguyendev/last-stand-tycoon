class_name GuardRoster
extends Node3D
## Spawns guards from GameState card levels and registers the &"guard" target kind (S2 spec 6.3, 7, D-164).

var guards := {}
var _world: World

func setup(world: World) -> void:
	_world = world
	world.wave_director.providers.register(&"guard", guard_target)
	EventBus.card_picked.connect(_on_card_picked)
	EventBus.state_restored.connect(sync)
	sync()

## Match guards to GameState (restore, new game).
func sync() -> void:
	for id in CardCatalog.ADVENTURERS:
		var lvl := GameState.card_level(id)
		if lvl >= 1 and not guards.has(id):
			_spawn(id)
		elif lvl < 1 and guards.has(id):
			var g: Guard = guards[id]
			guards.erase(id)
			remove_child(g)
			g.queue_free()

func _on_card_picked(id: StringName, _level: int) -> void:
	if CardCatalog.kind(id) != &"adventurer" or guards.has(id):
		return
	var g := _spawn(id)
	if not bool(g.stats.on_roof):
		g.arrive_from_door()

func _spawn(id: StringName) -> Guard:
	var g := Guard.new()
	add_child(g)
	g.setup(id, _world)
	guards[id] = g
	g.poof(true)
	return g

## First targetable guard (CardCatalog.IDS order) within the enemy's reach + the guard's body radius (xz).
func guard_target(enemy) -> Dictionary:
	var reach := Balance.data.enemy.reach
	var p := Vector2(enemy.global_position.x, enemy.global_position.z)
	for id in CardCatalog.IDS:
		if not guards.has(id):
			continue
		var g: Guard = guards[id]
		if g.is_targetable() and p.distance_to(g.xz()) <= reach + float(g.stats.body_radius) + 1e-4:
			return {"kind": &"guard", "guard_id": id}
	return {}

## Aim points of visible guards, so the diner fades when it hides one (D-151).
func occluder_points() -> Array:
	var out: Array = []
	for id in guards:
		var g: Guard = guards[id]
		if g.visual.visible:
			out.append(g.global_position + Vector3(0, Guard.AIM_HEIGHT, 0))
	return out
