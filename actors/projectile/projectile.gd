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
## Art side (S4 Task 7a, D-191): `_art` is a knife or arrow scene under the "Visual" node; `_dir` is the last flight
## direction and `_spin` the knife's roll. Written only by launch/_physics_process reads and _process; never read by gameplay.
var _visual: Node3D
var _art: Node3D
var _art_kind: StringName = &""
var _dir := Vector3.FORWARD
var _spin := 0.0

const ART_SCENES := {
	&"knife": "res://art/pickups/knife_projectile.tscn",
	&"arrow": "res://art/pickups/arrow_projectile.tscn",
}

func _init() -> void:
	name = "Projectile"
	_visual = Visuals.visual_root()
	add_child(_visual)

## Chooses the art by the shooter's kind (&"knife" hero, &"arrow" guards/towers). Pooled projectiles are re-acquired on
## every shot, so an unchanged kind returns at once; a changed kind frees the old art and instances the new one.
func set_art(kind: StringName) -> void:
	if kind == _art_kind:
		return
	if _art != null:
		_visual.remove_child(_art)
		_art.free()
		_art = null
	_art_kind = kind
	if not ART_SCENES.has(kind):
		return
	_art = (load(ART_SCENES[kind]) as PackedScene).instantiate()
	_visual.add_child(_art)

func _process(delta: float) -> void:
	if _art == null:
		return
	var up := Vector3.UP if absf(_dir.y) < 0.99 else Vector3.RIGHT
	var b := Basis.looking_at(_dir, up)
	if _art_kind == &"knife":
		_spin = fposmod(_spin + deg_to_rad(Balance.ui.knife_spin_deg_s) * delta, TAU)
		b = b * Basis(Vector3.RIGHT, _spin)
	_visual.basis = b

func launch(from: Vector3, target: Object, target_index: int, damage: float, speed: float, pool: NodePool) -> void:
	global_position = from
	_target = target
	_target_index = target_index
	_target_generation = Projectile.generation_of(target)
	_damage = damage
	_speed = speed
	_pool = pool
	if target is Node3D:
		var d: Vector3 = (target as Node3D).global_position + Vector3(0, 0.5, 0) - from
		if d.length() > 0.001:
			_dir = d.normalized()

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
		_dir = to.normalized()
		global_position += _dir * step

func on_release() -> void:
	_pool = null
	_target = null

func _finish() -> void:
	var p := _pool
	if p != null:
		p.release(self)
