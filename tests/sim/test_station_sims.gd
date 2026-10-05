extends GutTest
## E1 spec criteria 6.1 to 6.3 (D-230).

const SEED := 20260930
const WINDOW_S := 60.0
var h: SimHarness
var _served := 0

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_served = 0
	EventBus.steak_sold.connect(_on_sold)

func after_each() -> void:
	EventBus.steak_sold.disconnect(_on_sold)
	h.finish()

func _on_sold(_count: int, _gold: int) -> void:
	_served += 1

## Travelers served in WINDOW_S of a day with the counter always stocked.
func _served_at(level: int) -> int:
	h.finish()
	await get_tree().process_frame
	Balance.reset()
	h = SimHarness.new(self)
	h.start(SEED, ParkedBot)  # parks the hero at home, off every zone
	h.main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", level)
	_served = 0
	var cap := GameState.counter_capacity()
	for i in int(WINDOW_S * Engine.physics_ticks_per_second):
		GameState.counter_steaks = cap  # test-only setup: always stocked
		await h.tick()
	return _served

func test_6_1_every_counter_level_serves_more_than_the_one_below() -> void:
	var sb := Balance.data.stations
	var gain: float = sb.min_level_gain
	var max_level: int = sb.max_level
	var counts: Array = []
	for level in range(0, max_level + 1):
		counts.append(await _served_at(level))
	gut.p("served per level in %ds: %s" % [int(WINDOW_S), counts])
	assert_gt(counts[0], 0)
	for level in range(1, counts.size()):
		assert_gte(float(counts[level]), float(counts[level - 1]) * (1.0 + gain),
			"level %d serves %d, level %d serves %d" % [level, counts[level], level - 1, counts[level - 1]])

## Seconds DAY phase 1 takes for the PlannerBot with the counter preset to `level`.
func _day1_seconds(level: int) -> float:
	h.finish()
	await get_tree().process_frame
	Balance.reset()
	h = SimHarness.new(self)
	h.start(SEED, PlannerBot)
	var n1 := await h.run_night()
	assert_true(n1.cleared, "night 1 must clear")
	GameState.debug_set_station_level(&"counter", level)
	var d := await h.run_day()
	assert_true(d.closed, "day 1 must close up at level %d" % level)
	return d.seconds

func test_6_2_a_level_3_counter_shortens_the_day() -> void:
	var base := await _day1_seconds(0)
	var upgraded := await _day1_seconds(3)
	gut.p("day 1: %.1fs at level 0, %.1fs at level 3" % [base, upgraded])
	assert_lt(upgraded, base)

func test_6_3_the_upgrader_holds_nights_1_to_3() -> void:
	h.start(SEED, UpgraderBot)
	for night in range(1, 4):
		var n := await h.run_night()
		assert_true(n.cleared, "night %d: %s" % [night, n])
		if night < 3:
			var d := await h.run_day()
			assert_true(d.closed, "day %d closes up" % night)
	gut.p("upgrader stations after night 3: %s, stuck %d" % [GameState.stations, h.bot.stuck_count])
	assert_gt(GameState.station_level(&"counter") + GameState.station_level(&"freezer"), 0, "the upgrader bought a station level by night 3")
	assert_eq(h.bot.stuck_count, 0, "the pad routes are walkable")
