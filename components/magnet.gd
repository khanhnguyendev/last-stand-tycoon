class_name Magnet
extends Node
## Walk-over pickup by distance check each tick (D-008, D-034). Parent must be the Hero.

var _steaks: NodePool
var _fx: FlyFx

func setup(steak_pool: NodePool, fly_fx: FlyFx = null) -> void:
	_steaks = steak_pool
	_fx = fly_fx

func _physics_process(_delta: float) -> void:
	var owner3d := get_parent() as Node3D
	var p := Vector2(owner3d.global_position.x, owner3d.global_position.z)
	var r := Balance.data.hero.magnet_radius
	if _steaks != null:
		for s in _steaks.active().duplicate():
			if p.distance_to(Vector2(s.position.x, s.position.z)) <= r:
				if not GameState.pick_steak():
					break
				if _fx != null:
					_fx.fly("steak", s.position, owner3d.global_position + Vector3(0, 1.2, 0.5))
				_steaks.release(s)
	if GameState.gold_pile > 0 and p.distance_to(MapLayout.GOLD_PILE) <= r:
		if GameState.collect_pile() > 0 and _fx != null:
			_fx.fly("coin", MapLayout.to3(MapLayout.GOLD_PILE, 0.3), owner3d.global_position + Vector3(0, 1.2, 0))
