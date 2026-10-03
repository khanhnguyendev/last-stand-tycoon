class_name Boar
extends Node3D
## The one S1 monster (spec 7.2). Moved in code along its lane; never uses physics.

## Height above the feet the camera aims at when checking occlusion (D-151); the capsule centre.
const AIM_HEIGHT := 0.5
const VISUAL_SCENE := preload("res://art/boar/boar_visual.tscn")
## Blob shadow radius under a Boar (ShadowField.CHARACTER_RADIUS is the characters').
const SHADOW_RADIUS := 0.7

var lane := ""
var spawn_index := -1
## Increments on every spawn; projectiles/attackers compare it to detect pool reuse across nights (Review Focus 2).
var generation := 0
var dist := 0.0
var offset := 0.0
var alive := false
var health: Health
var targetable: Targetable
var visual: BoarVisual
## Set by the World's pool factory (S4 D-201): the shared blob-shadow field this Boar's Visual registers with.
var shadow_field: ShadowField
var current_target: Dictionary = {}
var _length := 0.0
var _attack_timer := 0.0
var _director: Object
var _death_tween: Tween
var _flash_left := 0.0

func _init() -> void:
	name = "Boar"
	health = Health.new()
	add_child(health)
	health.died.connect(_on_died)
	targetable = Targetable.new()
	targetable.kind = &"enemy"
	add_child(targetable)
	visual = VISUAL_SCENE.instantiate()
	add_child(visual)

func spawn(p_lane: String, p_index: int, p_offset: float, hp_mult: float, director: Object) -> void:
	generation += 1
	lane = p_lane
	spawn_index = p_index
	targetable.spawn_index = p_index
	offset = p_offset
	_director = director
	dist = 0.0
	_attack_timer = 0.0
	current_target = {}
	_length = MapLayout.path_length(lane)
	health.reset(Balance.data.enemy.hp * hp_mult)
	visual.scale = Vector3.ONE
	_reset_flash()
	visual.reset()
	if shadow_field != null:
		shadow_field.register(visual, SHADOW_RADIUS)
	alive = true
	_update_position(false)

func path_length() -> float:
	return _length

func at_path_end() -> bool:
	return dist >= _length - 1e-4

func _physics_process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			visual.set_flash(false)
	if not alive:
		return
	var eb := Balance.data.enemy
	current_target = _director.providers.find_target(self)
	if current_target.is_empty():
		_attack_timer = 0.0
		var step := eb.speed * delta
		var next := minf(dist + step, _length)
		# do not walk past a standing fence's stop point in one tick
		if _director.providers.has_kind(&"fence_on_lane") and dist <= TargetProviders.fence_stop_dist(self):
			next = minf(next, TargetProviders.fence_stop_dist(self))
		visual.set_motion(1.0 if next > dist else 0.0)
		dist = next
		_update_position()
		return
	visual.set_motion(0.0)
	_attack_timer += delta
	if _attack_timer >= eb.attack_interval - 1e-6:
		_attack_timer -= eb.attack_interval
		visual.attack()
		var dmg := eb.damage * GameState.mercy_factor()
		match current_target.kind:
			&"fence_on_lane":
				GameState.damage_fence(current_target.spot_id, dmg)
			&"guard":
				GameState.damage_guard(current_target.guard_id, dmg)
			&"diner":
				GameState.damage_diner(dmg)

func take_hit(amount: float) -> void:
	if alive:
		visual.set_flash(true)
		visual.hit()
		_flash_left = Balance.ui.hit_flash_time
		health.damage(amount)
		EventBus.sfx_requested.emit(&"hit")
		EventBus.fx_requested.emit(&"hit", global_position + Vector3(0, AIM_HEIGHT, 0))

func flash_active() -> bool:
	return _flash_left > 0.0

func _reset_flash() -> void:
	_flash_left = 0.0
	visual.set_flash(false)

func candidate() -> Dictionary:
	return {"position": global_position, "spawn_index": spawn_index, "ref": self}

func play_death(pool: NodePool) -> void:
	visual.die()
	_death_tween = create_tween()
	_death_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_death_tween.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	_death_tween.tween_callback(pool.release.bind(self))

func on_release() -> void:
	alive = false
	_reset_flash()
	visual.reset()
	if shadow_field != null:
		shadow_field.unregister(visual)
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null

func _on_died() -> void:
	alive = false
	_director.on_enemy_died(self)

func _update_position(turn := true) -> void:
	var p := EnemyPath.position_at(lane, dist, offset, Balance.data.enemy.offset_fade_distance)
	var prev := position
	position = MapLayout.to3(p)
	if turn:
		visual.face(position - prev)  # art only; ignores a zero step
