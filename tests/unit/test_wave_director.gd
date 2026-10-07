extends GutTest

## Ticks to let a same-tick effect (kill, signal) settle before asserting.
const SETTLE_TICKS := 2

var main: Main
var wd: WaveDirector

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(4242)
	wd = main.world.wave_director

func after_each() -> void:
	if EventBus.wave_cleared.is_connected(_stop_on_signal):
		EventBus.wave_cleared.disconnect(_stop_on_signal)
	if EventBus.wave_spawned_out.is_connected(_stop_on_signal):
		EventBus.wave_spawned_out.disconnect(_stop_on_signal)

func _stop_on_signal(_wave: int) -> void:
	wd.stop()

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _tk(seconds: float) -> int:
	return int(round(seconds * Engine.physics_ticks_per_second))

## Frame on which wave 0 starts (physics_frame fires before the director's tick, D-118).
func _wave_start_tick() -> int:
	return _tk(Balance.data.wave.first_wave_delay) + 1

## Frame by which the first `count` spawns of a group at group offset 0 have happened.
func _spawned_by(count: int) -> int:
	return _wave_start_tick() + _tk((count - 1) * Balance.data.wave.spawn_interval) + 1

func _plan0() -> Dictionary:
	return GameState.lane_plan[0]

func test_first_wave_starts_after_delay() -> void:
	var p := _plan0()
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	assert_signal_emitted_with_parameters(EventBus, "wave_incoming", [0, StringName(p.main), StringName(p.side)])
	await _ticks(_tk(Balance.data.wave.first_wave_delay) - 1)
	assert_signal_not_emitted(EventBus, "wave_started")
	await _ticks(SETTLE_TICKS)
	assert_signal_emitted_with_parameters(EventBus, "wave_started", [0, StringName(p.main), StringName(p.side)])
	assert_eq(wd.alive_count(), 1)

func test_spawns_follow_schedule_and_spawn_out() -> void:
	var p := _plan0()
	assert_eq(int(p.side_count), 0, "day 1 has no side group")
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	await _ticks(_spawned_by(int(p.main_count)))
	assert_eq(wd.alive_count(), int(p.main_count))
	assert_signal_emitted_with_parameters(EventBus, "wave_spawned_out", [0])

func test_clear_breather_next_wave() -> void:
	var p := _plan0()
	var breather := _tk(Balance.data.wave.breather)
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	await _ticks(_spawned_by(int(p.main_count)) + SETTLE_TICKS)
	wd.debug_kill_all()
	await _ticks(SETTLE_TICKS)
	assert_signal_emitted_with_parameters(EventBus, "wave_cleared", [0])
	var p1: Dictionary = GameState.lane_plan[1]
	assert_eq(get_signal_parameters(EventBus, "wave_incoming"), [1, StringName(p1.main), StringName(p1.side)])
	await _ticks(breather - SETTLE_TICKS - 3)
	assert_signal_emit_count(EventBus, "wave_started", 1)
	await _ticks(10)
	assert_signal_emit_count(EventBus, "wave_started", 2)

func test_main_group_dead_before_side_spawns_is_not_clear() -> void:
	GameState.advance_day()  # day 2: side groups
	var wb: WaveBalance = Balance.data.wave
	var p := _plan0()
	var main_n := int(p.main_count)
	var side_n := int(p.side_count)
	assert_gt(side_n, 0, "day 2 wave 0 has a side group")
	assert_lt((main_n - 1) * wb.spawn_interval, wb.side_group_delay, "all main spawn before the side group")
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	var elapsed := _spawned_by(main_n)
	await _ticks(elapsed)
	assert_eq(wd.alive_count(), main_n, "every main boar has spawned, no side boar yet")
	wd.debug_kill_all()
	var before_side := _wave_start_tick() + _tk(wb.side_group_delay) - 3
	await _ticks(before_side - elapsed)
	assert_eq(wd.alive_count(), 0)
	assert_signal_not_emitted(EventBus, "wave_cleared")
	await _ticks(_tk((side_n - 1) * wb.spawn_interval) + SETTLE_TICKS + 5)
	assert_eq(wd.alive_count(), side_n)
	wd.debug_kill_all()
	await _ticks(SETTLE_TICKS)
	assert_signal_emitted_with_parameters(EventBus, "wave_cleared", [0])
	assert_signal_emit_count(EventBus, "wave_cleared", 1)

func test_kill_drops_steaks_near_the_boar() -> void:
	wd.start_night(GameState.lane_plan)
	await _ticks(_wave_start_tick())
	assert_eq(wd.alive_count(), 1)
	var boar: Boar = wd.alive_enemies()[0]
	var pos := boar.global_position
	wd.debug_kill_all()
	await _ticks(1)
	var steaks: Array = main.world.steak_pool.active()
	assert_eq(steaks.size(), Balance.data.economy.steaks_per_kill)
	for s in steaks:
		var d := Vector2(s.position.x - pos.x, s.position.z - pos.z).length()
		assert_lte(d, Balance.data.enemy.drop_scatter + 1e-4)

func test_same_seed_same_offsets() -> void:
	var p := _plan0()
	assert_eq(int(p.side_count), 0, "day 1 has no side group")
	var n := int(p.main_count)
	wd.start_night(GameState.lane_plan)
	await _ticks(_spawned_by(n))
	var a: Array = wd.alive_enemies().map(func(b): return b.offset)
	wd.stop()
	main.world.enemy_pool.recall_all()
	wd.start_night(GameState.lane_plan)
	await _ticks(_spawned_by(n))
	var b: Array = wd.alive_enemies().map(func(x): return x.offset)
	assert_eq(a.size(), n)
	assert_eq(a, b)
	var rng := Rng.stream(GameState.run_seed, GameState.day, &"spawns")
	assert_eq(a[0], rng.randf_range(-1.0, 1.0) * Balance.data.enemy.lateral_spread)

func test_stop_halts_everything() -> void:
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	wd.stop()
	await _ticks(_wave_start_tick() + SETTLE_TICKS + 100)
	assert_signal_not_emitted(EventBus, "wave_started")

func test_stop_mid_wave_no_clear() -> void:
	var p := _plan0()
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	await _ticks(_spawned_by(int(p.main_count)))
	var doomed: Array = wd.alive_enemies()
	assert_gt(doomed.size(), 0)
	wd.stop()
	for b in doomed:
		b.take_hit(1e9)
	await _ticks(SETTLE_TICKS + 3)
	assert_signal_not_emitted(EventBus, "wave_cleared")
	assert_signal_not_emitted(EventBus, "enemy_killed")
	assert_eq(wd.state, WaveDirector.State.IDLE)
	assert_eq(main.world.steak_pool.active().size(), 0, "no drops for kills after stop()")

func test_stop_in_cleared_handler_starts_no_breather() -> void:
	var p := _plan0()
	watch_signals(EventBus)
	EventBus.wave_cleared.connect(_stop_on_signal)
	wd.start_night(GameState.lane_plan)
	await _ticks(_spawned_by(int(p.main_count)) + SETTLE_TICKS)
	wd.debug_kill_all()
	await _ticks(SETTLE_TICKS)
	assert_signal_emitted_with_parameters(EventBus, "wave_cleared", [0])
	assert_signal_emit_count(EventBus, "wave_incoming", 1, "only wave 0's")
	assert_eq(wd.state, WaveDirector.State.IDLE)

func test_stop_in_spawned_out_handler_is_not_a_clear() -> void:
	var p := _plan0()
	watch_signals(EventBus)
	EventBus.wave_spawned_out.connect(_stop_on_signal)
	wd.start_night(GameState.lane_plan)
	await _ticks(_spawned_by(int(p.main_count)) + SETTLE_TICKS)
	assert_signal_emitted_with_parameters(EventBus, "wave_spawned_out", [0])
	assert_signal_not_emitted(EventBus, "wave_cleared")
	assert_eq(wd.state, WaveDirector.State.IDLE)

func test_boss_wave_spawns_the_boss_first_and_reports_it_alive() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(20260930)
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.advance_day()
	var wd := main.world.wave_director
	wd.start_night(GameState.lane_plan)
	wd._start_wave(2)  # jump to the boss wave
	await get_tree().physics_frame
	var alive := wd.alive_enemies()
	assert_eq(alive.size(), 1, "only the boss at t = 0")
	assert_eq((alive[0] as Boar).kind, &"boss")
	assert_true(wd.boss_alive())
	for i in int(ceil(Balance.data.tiers.boss_lead * 60.0)) + 2:
		await get_tree().physics_frame
	assert_gt(wd.alive_count(), 1, "the wave's boars follow after boss_lead")

func test_enemy_killed_carries_the_kind_and_the_boss_drops_its_pile() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(20260930)
	var wd := main.world.wave_director
	wd.start_night(GameState.lane_plan)
	var got: Array = []
	var cb := func(i, l, p, k): got.append([i, k])
	EventBus.enemy_killed.connect(cb)
	var boss := wd.debug_spawn("north", 0.0, 1.0, &"boss")
	boss.take_hit(1e9)
	await get_tree().physics_frame
	EventBus.enemy_killed.disconnect(cb)
	assert_eq(got, [[boss.spawn_index, &"boss"]])
	assert_eq(main.world.steak_pool.active().size(), Balance.data.monsters.stats(&"boss").steaks_per_kill)
	for s in main.world.steak_pool.active():
		var d := Vector2((s as Node3D).position.x - boss.position.x, (s as Node3D).position.z - boss.position.z).length()
		assert_lte(d, Balance.data.monsters.stats(&"boss").drop_scatter + 1e-4)

func test_steak_pool_holds_a_tier3_night_plus_its_brutes_and_the_biggest_boss() -> void:
	var sizes := World.pool_sizes(Balance.data)
	var tb := Balance.data.tiers
	var kills := 0
	for w in 3:
		kills += WaveMath.total_count(tb.tier_cap[TierEffects.top_tier(tb)], w, Balance.data.wave)
	assert_eq(TierEffects.top_tier(tb), 3)
	var brutes: int = 3 * (tb.brute_cap_main[3] + tb.brute_cap_side[3]) * Balance.data.monsters.stats(&"brute").steaks_per_kill
	var biggest_boss: int = maxi(Balance.data.monsters.stats(&"boss").steaks_per_kill, Balance.data.monsters.stats(&"baron").steaks_per_kill)
	var need := int(ceil((kills * Balance.data.economy.steaks_per_kill + brutes + biggest_boss) * 1.2))
	assert_eq(sizes.steak, need)
	assert_eq(sizes.steak, 396, "the literal: 78 kills x 2 + 24 + 150 = 330, x 1.2")
	assert_gte(sizes.enemy, Balance.data.wave.max_wave_size + 1 + 10, "the boss is one more spawn")
