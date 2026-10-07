class_name Attacker
extends Node3D
## Auto-attack: retargets on an interval, fires homing projectiles (D-019, D-020, D-060).

signal fired(target: Object)

var damage := 0.0
var attack_range := 0.0
var interval := 1.0
var retarget_interval := 0.2
var moving_mult := 1.0
var projectile_speed := 14.0
var enabled := true
## Projectiles per attack, one at each of the first `count` targets of Targeting.select_many (Volley, E5 tier 3).
var count := 1
## Which projectile art this shooter's shots wear (S4 Task 7a, D-191): the hero's is &"knife".
@export var projectile_art: StringName = &"arrow"
var candidates: Callable
var projectile_pool: NodePool
var is_moving: Callable = func(): return false
var _cooldown := 0.0
var _retarget := 0.0
var _target: Dictionary = {}
var _target_generation := 0

func _ready() -> void:
	EventBus.state_restored.connect(_on_state_restored)

## A restore drops every target and cooldown (D-036): nothing carries over from the lost timeline.
func _on_state_restored() -> void:
	_cooldown = 0.0
	_retarget = 0.0
	_target = {}
	_target_generation = 0

func configure(p_damage: float, p_range: float, p_interval: float, p_retarget: float, p_moving_mult: float, p_speed: float, p_count := 1) -> void:
	count = p_count
	damage = p_damage
	attack_range = p_range
	interval = p_interval
	retarget_interval = p_retarget
	moving_mult = p_moving_mult
	projectile_speed = p_speed

func _physics_process(delta: float) -> void:
	if not enabled or not candidates.is_valid() or projectile_pool == null:
		return
	var origin := global_position
	if count > 1:
		_volley(origin, delta)
		return
	_retarget -= delta
	if _retarget <= 0.0 or (not _target.is_empty() and not _target_valid(origin)):
		_retarget = retarget_interval
		_target = Targeting.select(origin, attack_range, candidates.call())
		_target_generation = Projectile.generation_of(_target.ref) if not _target.is_empty() else 0
	var rate := moving_mult if is_moving.call() else 1.0
	_cooldown = maxf(_cooldown - delta * rate, 0.0)
	if _cooldown <= 1e-6 and _target_valid(origin):
		_cooldown = interval
		var ref: Object = _target.ref
		var p: Projectile = projectile_pool.acquire()
		p.set_art(projectile_art)
		p.launch(origin + Vector3(0, 1.0, 0), ref, int(_target.spawn_index), damage, projectile_speed, projectile_pool)
		fired.emit(ref)

## Multi-projectile attack: when the cooldown is ready, pick the first `count` targets afresh and fire one at each.
## With nothing in range it looks again after `retarget_interval`, like the single-target path.
func _volley(origin: Vector3, delta: float) -> void:
	_retarget -= delta
	var rate := moving_mult if is_moving.call() else 1.0
	_cooldown = maxf(_cooldown - delta * rate, 0.0)
	if _cooldown > 1e-6 or _retarget > 0.0:
		return
	var targets := Targeting.select_many(origin, attack_range, candidates.call(), count)
	if targets.is_empty():
		_retarget = retarget_interval
		return
	_cooldown = interval
	for t in targets:
		var p: Projectile = projectile_pool.acquire()
		p.set_art(projectile_art)
		p.launch(origin + Vector3(0, 1.0, 0), t.ref, int(t.spawn_index), damage, projectile_speed, projectile_pool)
		fired.emit(t.ref)

func _target_valid(origin: Vector3) -> bool:
	if _target.is_empty():
		return false
	var r: Object = _target.ref
	if not is_instance_valid(r) or not r.alive or r.spawn_index != int(_target.spawn_index) \
			or Projectile.generation_of(r) != _target_generation:
		return false
	var pos: Vector3 = r.global_position
	return Vector2(pos.x - origin.x, pos.z - origin.z).length() <= attack_range
