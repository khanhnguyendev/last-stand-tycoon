class_name Boar
extends Node3D
## Every monster (E5 spec 7.1): the kind picks the stats; the class name is kept. Moved in code along its lane; never uses physics.

## Height above the feet the camera aims at when checking occlusion (D-151); the capsule centre.
const AIM_HEIGHT := 0.5
const VISUAL_SCENE := preload("res://art/boar/boar_visual.tscn")
## Blob shadow radius under a Boar (ShadowField.CHARACTER_RADIUS is the characters').
const SHADOW_RADIUS := 0.7

## E5: which monster this pooled node is right now (spec 4.3); every number is read through stats().
var kind: StringName = &"boar"
## Is this monster a boss right now (its kind is one of the ladder's boss kinds, TierEffects.is_boss_kind)? Set at spawn.
var is_boss := false
var _stats: MonsterStats
## Spike fence pass damage is taken once per life: set when this monster crosses its lane's fence line, cleared at spawn.
var _passed_fence := false
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
	var bar := BossBar.new()
	add_child(bar)
	bar.setup(self)

## Cached at spawn. The boar's view is a copy, so a balance edit applies to boars spawned after it; hare and boss hold the shared resource.
func stats() -> MonsterStats:
	if _stats == null:
		_stats = Balance.data.monsters.stats(kind)
	return _stats

func spawn(p_lane: String, p_index: int, p_offset: float, hp_mult: float, director: Object, p_kind: StringName = &"boar") -> void:
	assert(Balance.data.monsters.has_kind(p_kind), "unknown monster kind %s" % p_kind)
	generation += 1
	kind = p_kind
	is_boss = TierEffects.is_boss_kind(kind, Balance.data.tiers)
	_passed_fence = false
	_stats = Balance.data.monsters.stats(kind)
	lane = p_lane
	spawn_index = p_index
	targetable.spawn_index = p_index
	offset = p_offset
	_director = director
	dist = 0.0
	_attack_timer = 0.0
	current_target = {}
	_length = MapLayout.path_length(lane)
	health.reset(stats().hp * hp_mult)
	visual.scale = Vector3.ONE
	visual.set_kind(kind)
	_reset_flash()
	visual.reset()
	if shadow_field != null:
		shadow_field.register(visual, SHADOW_RADIUS * float(BoarMesh.params(kind).scale))
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
	var eb := stats()
	current_target = _director.providers.find_target(self)
	if current_target.is_empty():
		_attack_timer = 0.0
		var step := eb.speed * delta
		var next := minf(dist + step, _length)
		# do not walk past a standing fence's stop point in one tick
		if _director.providers.has_kind(&"fence_on_lane", self) and dist <= TargetProviders.fence_stop_dist(self):
			next = minf(next, TargetProviders.fence_stop_dist(self))
		visual.set_motion(1.0 if next > dist else 0.0)
		dist = next
		_update_position()
		_check_fence_crossing(eb)
		return
	visual.set_motion(0.0)
	_attack_timer += delta
	if _attack_timer >= eb.attack_interval - 1e-6:
		_attack_timer -= eb.attack_interval
		visual.attack()
		var dmg := eb.damage * GameState.mercy_factor()
		match current_target.kind:
			&"fence_on_lane":
				var spot_id := String(current_target.spot_id)
				var thorns := GameState.fence_thorn_damage(spot_id)  # read while the fence stands: the hit that breaks it still thorns
				GameState.damage_fence(spot_id, dmg * eb.fence_damage_mult, kind)
				if eb.fence_damage_mult > 1.0:
					_thump(spot_id)
				if thorns > 0.0:
					take_hit(thorns)  # after its own hit, through the normal damage path (it can die: one kill, one drop)
			&"guard":
				GameState.damage_guard(current_target.guard_id, dmg)
			&"diner":
				GameState.damage_diner(dmg)

## A monster with no fence entry in its priority list (the hares, the Baron) walks past the fence; the tick it crosses the
## fence's line it takes the Spike fence's pass damage once (0.0 unless that fence stands with branch spike and lists this kind).
## Only damage: its path, speed and timing are untouched.
func _check_fence_crossing(eb: MonsterStats) -> void:
	if _passed_fence or (eb.priority as Array).has(&"fence_on_lane") or dist < _length - MapLayout.FENCE_OFFSET_FROM_END:
		return
	_passed_fence = true
	var pass_damage := GameState.fence_pass_damage(MapLayout.lane_fence(lane), kind)
	if pass_damage > 0.0:
		take_hit(pass_damage)

## Dust bursts sit this far to each side of the lane centre on the fence line: outside the brute's half-width, never in its head.
const THUMP_SIDE := 1.3
const THUMP_HEIGHT := 0.3

## The siege brute's ground thump (spec 6.2): two dust bursts on the fence line, one each side of the body, and a heavy sound;
## only for a hit on a fence.
func _thump(spot_id: String) -> void:
	EventBus.sfx_requested.emit(&"thump")
	var centre := MapLayout.spot_position(spot_id)
	var axis := MapLayout.zone_axis(lane)  # the fence bar runs along the zone's width axis
	for side in [-1.0, 1.0]:
		EventBus.fx_requested.emit(&"dust", MapLayout.to3(centre + axis * THUMP_SIDE * side) + Vector3(0, THUMP_HEIGHT, 0))

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
