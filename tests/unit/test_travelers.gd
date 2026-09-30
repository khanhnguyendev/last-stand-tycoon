extends GutTest

var main: Main
var sp: TravelerSpawner

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(21)
	main.hero.teleport(Vector2(15, 8))  # well away from every station zone
	sp = main.world.traveler_spawner

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Ticks needed for `seconds` of physics time, plus a margin.
func _secs(seconds: float, margin := 1.1) -> int:
	return int(ceil(seconds * Engine.physics_ticks_per_second * margin))

func test_no_travelers_at_night() -> void:
	await _ticks(300)
	assert_eq(sp.queue.size(), 0)

func test_spawn_and_queue_cap_in_day() -> void:
	var e := Balance.data.economy
	main.phase_controller.debug_skip_to_day()
	await _ticks(_secs(e.traveler_interval + e.traveler_jitter))
	assert_gt(sp.queue.size(), 0)
	await _ticks(_secs((e.queue_max + 1) * (e.traveler_interval + e.traveler_jitter)))
	assert_eq(sp.queue.size(), e.queue_max)

func test_purchase_is_atomic_after_service_time() -> void:
	var e := Balance.data.economy
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 5  # test-only setup
	var ok := await _wait_front_at_counter()
	assert_true(ok)
	var front: Traveler = sp.queue[0]
	var want := front.want
	var guard := _secs(e.service_time)
	while not front.leaving and guard > 0:
		assert_eq(GameState.counter_steaks, 5, "nothing sold before the service time")
		assert_eq(GameState.gold_pile, 0, "no gold before the service time")
		await get_tree().physics_frame
		guard -= 1
	assert_true(front.leaving, "sale happened within the service time")
	assert_eq(GameState.counter_steaks, 5 - want)
	assert_eq(GameState.gold_pile, want * e.gold_per_steak)

func test_empty_counter_front_waits() -> void:
	main.phase_controller.debug_skip_to_day()
	assert_true(await _wait_front_at_counter())
	await _ticks(_secs(Balance.data.economy.service_time * 2.0))
	assert_false((sp.queue[0] as Traveler).leaving)
	assert_eq(GameState.gold_pile, 0)

func test_close_up_sends_everyone_away_and_stops() -> void:
	main.phase_controller.debug_skip_to_day()
	await _ticks(_secs(Balance.data.economy.traveler_interval * 2.0))
	assert_gt(sp.queue.size(), 0, "precondition: someone is queued")
	main.phase_controller.close_up()
	assert_eq(sp.queue.size(), 0)
	assert_gt(sp.leaving.size(), 0)
	for t in sp.leaving:
		assert_true(t.leaving)
	await _ticks(_secs(Balance.data.economy.service_time * 5.0))
	assert_eq(sp.queue.size(), 0)

func test_clear_queue_recalls_everyone() -> void:
	main.phase_controller.debug_skip_to_day()
	await _ticks(_secs(Balance.data.economy.traveler_interval * 2.0))
	assert_gt(sp.queue.size(), 0)
	sp.clear_queue()
	assert_eq(sp.queue.size(), 0)
	assert_eq(sp.leaving.size(), 0)
	assert_eq(sp.pool.active().size(), 0)

## Spawns of the first day: (tick, want) for the first queue_max travelers.
func _record_spawns() -> Array:
	var e := Balance.data.economy
	main.phase_controller.start_new_game(21)
	main.phase_controller.debug_skip_to_day()
	var seen := {}
	var rec: Array = []
	for tick in _secs(e.queue_max * (e.traveler_interval + e.traveler_jitter)):
		await get_tree().physics_frame
		for t in sp.queue:
			if not seen.has(t.get_instance_id()):
				seen[t.get_instance_id()] = true
				rec.append([tick, t.want])
		if rec.size() >= e.queue_max:
			break
	return rec

func test_same_seed_gives_the_same_traveler_spawns() -> void:
	var a := await _record_spawns()
	var b := await _record_spawns()
	assert_eq(a.size(), Balance.data.economy.queue_max)
	assert_eq(a, b)

func test_gold_pile_visual() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 1
	GameState.sell_from_counter(1)
	assert_eq(main.world.gold_pile.coin_count(), Balance.data.economy.gold_per_steak)

func _wait_front_at_counter() -> bool:
	var e := Balance.data.economy
	for i in _secs((e.traveler_interval + e.traveler_jitter) + 25.0):
		if not sp.queue.is_empty() and (sp.queue[0] as Traveler).at_target():
			return true
		await get_tree().physics_frame
	return false
