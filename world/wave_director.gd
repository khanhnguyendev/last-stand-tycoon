class_name WaveDirector
extends Node
## Runs the 3 waves of a night from _plan (spec 7.1). Never changes the phase.

enum State { IDLE, WAITING, ACTIVE }

var enemy_pool: NodePool
var steak_pool: NodePool
var providers := TargetProviders.new()
var wave_index := -1
var state := State.IDLE
var _pending_wave := 0
var _timer := 0.0
var _t := 0.0
var _schedule: Array = []
var _next := 0
var _alive: Array = []
var _spawn_counter := 0
var _spawned_out_sent := false
var _spawn_rng: RandomNumberGenerator
var _drop_rng: RandomNumberGenerator
var _plan: Array = []
## Bumped by start_night() and stop(); lets a signal handler that stops the night cancel the rest of a tick.
var _night_id := 0

func setup(p_enemy_pool: NodePool, p_steak_pool: NodePool) -> void:
	enemy_pool = p_enemy_pool
	steak_pool = p_steak_pool
	providers.register(&"fence_on_lane", func(e): return TargetProviders.fence_on_lane(e))
	providers.register(&"diner", func(e): return TargetProviders.diner(e))

## D-128 interface.
func start_night(plan: Array) -> void:
	stop()
	_night_id += 1
	_plan = plan
	_spawn_counter = 0
	_spawn_rng = Rng.stream(GameState.run_seed, GameState.day, &"spawns")
	_drop_rng = Rng.stream(GameState.run_seed, GameState.day, &"drops")
	wave_index = -1
	_begin_wait(Balance.data.wave.first_wave_delay, 0)

## D-128 interface.
func stop() -> void:
	_night_id += 1
	state = State.IDLE
	_alive.clear()
	_schedule = []
	_next = 0

func _begin_wait(seconds: float, w: int) -> void:
	state = State.WAITING
	_timer = seconds
	_pending_wave = w
	var plan: Dictionary = _plan[w]
	EventBus.wave_incoming.emit(w, StringName(plan.main), StringName(plan.side))

func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			_timer -= delta
			if _timer <= 1e-6:
				_start_wave(_pending_wave)
		State.ACTIVE:
			_t += delta
			_spawn_due()
			if state != State.ACTIVE:
				return  # a wave_spawned_out handler stopped the night
			if WaveSchedule.is_cleared(_schedule.size(), _next, _alive.size()):
				var cleared := wave_index
				var night := _night_id
				state = State.IDLE
				EventBus.wave_cleared.emit(cleared)
				if night == _night_id and cleared < _plan.size() - 1:
					_begin_wait(Balance.data.wave.breather, cleared + 1)

func _start_wave(w: int) -> void:
	wave_index = w
	var plan: Dictionary = _plan[w]
	_schedule = WaveSchedule.build(plan, Balance.data.wave)
	_next = 0
	_t = 0.0
	_spawned_out_sent = false
	state = State.ACTIVE
	EventBus.wave_started.emit(w, StringName(plan.main), StringName(plan.side))
	_spawn_due()

func _spawn_due() -> void:
	while _next < _schedule.size() and float(_schedule[_next].t) <= _t + 1e-6:
		_spawn(String(_schedule[_next].lane), _spawn_rng.randf_range(-1.0, 1.0))
		_next += 1
	if _next >= _schedule.size() and not _spawned_out_sent:
		_spawned_out_sent = true
		EventBus.wave_spawned_out.emit(wave_index)

func _spawn(lane: String, unit_offset: float, hp_mult: float = -1.0) -> Boar:
	var boar: Boar = enemy_pool.acquire()
	var mult := hp_mult if hp_mult > 0.0 else float(_plan[maxi(wave_index, 0)].hp_mult) * GameState.mercy_factor()
	boar.spawn(lane, _spawn_counter, unit_offset * Balance.data.enemy.lateral_spread, mult, self)
	_spawn_counter += 1
	_alive.append(boar)
	return boar

func on_enemy_died(boar: Boar) -> void:
	var idx := _alive.find(boar)
	if idx < 0:
		# Killed after stop() (or not ours): no signal, no drops.
		boar.play_death(enemy_pool)
		return
	_alive.remove_at(idx)
	EventBus.enemy_killed.emit(boar.spawn_index, StringName(boar.lane), boar.global_position)
	for i in Balance.data.economy.steaks_per_kill:
		var s: Steak = steak_pool.acquire()
		var a := _drop_rng.randf() * TAU
		var r := _drop_rng.randf() * Balance.data.enemy.drop_scatter
		s.place(boar.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r))
	boar.play_death(enemy_pool)

func alive_enemies() -> Array:
	return _alive.duplicate()

func alive_count() -> int:
	return _alive.size()

func enemy_candidates() -> Array:
	var out: Array = []
	for b in _alive:
		out.append(b.candidate())
	return out

func upcoming_main_lane() -> String:
	var w := _pending_wave if state == State.WAITING else wave_index
	if w < 0 or w >= _plan.size():
		return "north"
	return String(_plan[w].main)

## Test/debug helpers (used by tests and ui/debug only).
func debug_spawn(lane: String, unit_offset: float = 0.0, hp_mult: float = 1.0) -> Boar:
	if _drop_rng == null:
		_drop_rng = Rng.stream(GameState.run_seed, GameState.day, &"drops")
	return _spawn(lane, unit_offset, hp_mult)

func debug_kill_all() -> void:
	for b in _alive.duplicate():
		b.take_hit(1e9)
