class_name Guard
extends Node3D
## An adventurer guard at its fixed post (S2 spec 6, D-163 to D-165). HP lives in GameState.guards (Tank only).
## No physics body: the hero walks through guards (as towers, D-125).

enum State { POSTED, DOWN, RETURNING }

## Height above the feet the camera aims at when checking occlusion (D-151).
const AIM_HEIGHT := 1.0
const BAR_WIDTH := 1.0

var id: StringName
var state := State.POSTED
var stats: Dictionary = {}
var attacker: Attacker
var visual: Node3D
var _bar: MeshInstance3D
var _respawn_left := 0.0
var _path: Array = []
var _poof_tween: Tween

func setup(p_id: StringName, world: World) -> void:
	id = p_id
	name = "Guard_%s" % p_id
	visual = Visuals.visual_root()
	var body := Visuals.capsule(0.4, 1.4, Visuals.COLORS[String(p_id)])
	body.position.y = 0.7
	visual.add_child(body)
	add_child(visual)
	_bar = Visuals.box(Vector3(BAR_WIDTH, 0.08, 0.08), Visuals.COLORS.diner_hp)
	_bar.position.y = 1.8
	_bar.visible = false
	add_child(_bar)
	attacker = Attacker.new()
	attacker.position.y = 1.0
	attacker.candidates = world.wave_director.enemy_candidates
	attacker.projectile_pool = world.projectile_pool
	add_child(attacker)
	EventBus.card_picked.connect(_on_card_picked)
	EventBus.guard_damaged.connect(_on_guard_hp)
	EventBus.guard_healed.connect(_on_guard_hp)
	EventBus.guard_revived.connect(_on_guard_revived)
	EventBus.guard_knocked_out.connect(_on_knocked_out)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(_on_state_restored)
	apply_stats()
	place_at_post()

func apply_stats() -> void:
	stats = CardEffects.guard_stats(id, maxi(GameState.card_level(id), 1), Balance.data.guards)
	attacker.configure(stats.damage, stats.range, stats.interval, Balance.data.hero.retarget_interval, 1.0,
		stats.projectile_speed)
	_refresh_bar()

func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func is_targetable() -> bool:
	return bool(stats.targetable) and state != State.DOWN and GameState.guards.has(id) \
		and float(GameState.guards[id].hp) > 0.0

func place_at_post() -> void:
	state = State.POSTED
	_respawn_left = 0.0
	_path = []
	if _poof_tween != null and _poof_tween.is_valid():
		_poof_tween.kill()
	visual.scale = Vector3.ONE
	visual.visible = true
	attacker.enabled = true
	position = MapLayout.to3(MapLayout.guard_post(id), MapLayout.DINER_HEIGHT if bool(stats.on_roof) else 0.0)
	_refresh_bar()

## Appear at the diner door and walk the fixed path to the post (hire and respawn, D-165).
func arrive_from_door() -> void:
	_path = MapLayout.tank_return_path()
	position = MapLayout.to3(_path.pop_front())
	state = State.RETURNING
	poof(true)  # pops in at the door; also undoes a knockout's shrink (spec 6.2)
	attacker.enabled = true
	_refresh_bar()

func _physics_process(delta: float) -> void:
	match state:
		State.DOWN:
			_respawn_left -= delta
			if _respawn_left <= 1e-6:
				GameState.revive_guard(id)
				arrive_from_door()
		State.RETURNING:
			_walk(delta)

func _walk(delta: float) -> void:
	var step := float(stats.walk_speed) * delta
	while step > 0.0 and not _path.is_empty():
		var target: Vector2 = _path[0]
		var d := target - xz()
		if d.length() <= step:
			position = MapLayout.to3(target)
			step -= d.length()
			_path.pop_front()
		else:
			position = MapLayout.to3(xz() + d.normalized() * step)
			step = 0.0
	if _path.is_empty():
		state = State.POSTED

func _on_knocked_out(g: StringName) -> void:
	if g != id:
		return
	state = State.DOWN
	_respawn_left = float(stats.respawn_s)
	attacker.enabled = false
	_bar.visible = false
	poof(false)

## Spec 6.2 poof: a 0.15 s scale tween on the visual (physics time, like Boar.play_death).
## appear=true pops the guard in from zero; appear=false shrinks it away and hides it.
func poof(appear: bool) -> void:
	if _poof_tween != null and _poof_tween.is_valid():
		_poof_tween.kill()
	visual.visible = true
	visual.scale = Vector3.ONE * (0.01 if appear else 1.0)
	_poof_tween = create_tween()
	_poof_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_poof_tween.tween_property(visual, "scale", Vector3.ONE if appear else Vector3.ONE * 0.01, 0.15)
	if not appear:
		_poof_tween.tween_callback(func(): visual.visible = false)

func _on_card_picked(c: StringName, _level: int) -> void:
	if c == id:
		apply_stats()

func _on_guard_hp(g: StringName, _hp: float) -> void:
	if g == id:
		_refresh_bar()

func _on_guard_revived(g: StringName) -> void:
	if g == id:
		_refresh_bar()

func _on_phase_changed(phase: int, _day: int) -> void:
	if phase == Phase.DAWN:
		place_at_post()

func _on_state_restored() -> void:
	apply_stats()
	place_at_post()

func _refresh_bar() -> void:
	if not GameState.guards.has(id) or state == State.DOWN:
		_bar.visible = false
		return
	var mx := GameState.guard_max_hp(id)
	var hp := float(GameState.guards[id].hp)
	_bar.visible = mx > 0.0 and hp < mx - 1e-6
	_bar.scale.x = clampf(hp / mx, 0.0, 1.0) if mx > 0.0 else 0.0
