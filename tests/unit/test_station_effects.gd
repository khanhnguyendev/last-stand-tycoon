extends GutTest

var sb: StationBalance

func before_each() -> void:
	Balance.reset()
	sb = Balance.data.stations

func test_every_table_has_max_level_plus_one_entries() -> void:
	for arr in [sb.queue_max, sb.traveler_interval, sb.service_time, sb.counter_capacity, sb.carry_bonus, sb.load_per_tick]:
		assert_eq(arr.size(), sb.max_level + 1)

func test_level_0_is_the_s5_game() -> void:
	assert_eq(StationEffects.queue_max(0, sb), 4)
	assert_eq(StationEffects.traveler_interval(0, sb), 2.5)
	assert_eq(StationEffects.service_time(0, sb), 1.0)
	assert_eq(StationEffects.counter_capacity(0, sb), 12)
	assert_eq(StationEffects.carry_bonus(0, sb), 0)
	assert_eq(StationEffects.load_per_tick(0, sb), 1)

func test_level_5_values() -> void:
	var m := sb.max_level
	assert_eq(StationEffects.queue_max(m, sb), sb.queue_max[m])
	assert_eq(StationEffects.traveler_interval(m, sb), sb.traveler_interval[m])
	assert_eq(StationEffects.service_time(m, sb), sb.service_time[m])
	assert_eq(StationEffects.counter_capacity(m, sb), sb.counter_capacity[m])
	assert_eq(StationEffects.carry_bonus(m, sb), sb.carry_bonus[m])
	assert_eq(StationEffects.load_per_tick(m, sb), sb.load_per_tick[m])

func test_tables_never_get_worse_with_level() -> void:
	for l in range(1, sb.max_level + 1):
		assert_gte(sb.queue_max[l], sb.queue_max[l - 1])
		assert_lte(sb.traveler_interval[l], sb.traveler_interval[l - 1])
		assert_lte(sb.service_time[l], sb.service_time[l - 1])
		assert_gt(sb.counter_capacity[l], sb.counter_capacity[l - 1])
		assert_gte(sb.carry_bonus[l], sb.carry_bonus[l - 1])
		assert_gte(sb.load_per_tick[l], sb.load_per_tick[l - 1])
		assert_gt(sb.traveler_interval[l], 0.0)
		assert_gt(sb.service_time[l], 0.0)

func test_levels_out_of_range_clamp() -> void:
	assert_eq(StationEffects.queue_max(-1, sb), sb.queue_max[0])
	assert_eq(StationEffects.queue_max(99, sb), sb.queue_max[sb.max_level])

func test_cost_curve() -> void:
	assert_eq(StationEffects.level_cost(&"counter", 0, sb), 30)
	assert_eq(StationEffects.level_cost(&"counter", 1, sb), 60)
	assert_eq(StationEffects.level_cost(&"counter", 4, sb), 480)
	assert_eq(StationEffects.level_cost(&"freezer", 0, sb), 25)
	assert_eq(StationEffects.level_cost(&"freezer", 4, sb), 400)
	assert_eq(StationEffects.level_cost(&"counter", sb.max_level, sb), -1)
	assert_eq(StationEffects.level_cost(&"freezer", sb.max_level + 3, sb), -1)

func test_max_carry_and_pool_size() -> void:
	var bd := Balance.data
	assert_eq(StationEffects.max_carry(bd.hero, bd.cards, sb),
		bd.hero.carry_capacity + bd.cards.carry_step * bd.cards.max_level + sb.carry_bonus[sb.max_level])
	assert_eq(StationEffects.max_carry(bd.hero, bd.cards, sb), 26)
	var walk := MapLayout.SERVICE_POINT.distance_to(MapLayout.TRAVELER_EXIT) / bd.economy.traveler_speed
	assert_eq(StationEffects.traveler_pool_size(sb, bd.economy),
		sb.queue_max[sb.max_level] + int(ceil(walk / sb.service_time[sb.max_level])) + 2)
	assert_gte(StationEffects.traveler_pool_size(sb, bd.economy), 8, "never smaller than today's pool")
