class_name Projectile
extends Node3D
## Homing cleaver/bolt (D-050, D-060). Damage on hit only; despawns if its target died or was recycled
## (spawn_index changed, or the target's generation changed: spawn_index restarts every night, D-148).

var _target: Object
var _target_index := -1
var _target_generation := 0
var _damage := 0.0
var _speed := 0.0
var _pool: NodePool

func _init() -> void:
	name = "Projectile"
	var v := Visuals.visual_root()
	v.add_child(Visuals.box(Vector3(0.25, 0.08, 0.35), Visuals.COLORS.hat))
	add_child(v)

func launch(from: Vector3, target: Object, target_index: int, damage: float, speed: float, pool: NodePool) -> void:
	global_position = from
	_target = target
	_target_index = target_index
	_target_generation = Projectile.generation_of(target)
	_damage = damage
	_speed = speed
	_pool = pool

## Pool-reuse counter of a target; 0 when the target has none.
static func generation_of(target: Object) -> int:
	if target == null:
		return 0
	var g: Variant = target.get("generation")
	return int(g) if g is int else 0

func _physics_process(delta: float) -> void:
	if _pool == null:
		return
	if not is_instance_valid(_target) or not _target.alive or _target.spawn_index != _target_index \
			or Projectile.generation_of(_target) != _target_generation:
		_finish()
		return
	var aim: Vector3 = _target.global_position + Vector3(0, 0.5, 0)
	var to := aim - global_position
	var step := _speed * delta
	if to.length() <= step:
		_target.take_hit(_damage)
		_finish()
	else:
		global_position += to.normalized() * step

func on_release() -> void:
	_pool = null
	_target = null

func _finish() -> void:
	var p := _pool
	if p != null:
		p.release(self)
