extends GutTest
## PINNED REFERENCE: spec 8.6 / 8.9 values at the default Balance (the margin check is computed).
## Update the pinned rows with Task 35 if tuned.

var bd: BalanceData

func before_each() -> void:
	Balance.reset()
	bd = Balance.data

func test_level_costs() -> void:
	var costs_t: Array = []
	var costs_f: Array = []
	for lvl in 4:
		costs_t.append(Economy.level_cost("tower_nw", lvl, bd.build))
		costs_f.append(Economy.level_cost("fence_n", lvl, bd.build))
	assert_eq(costs_t, [40, 80, 160, -1])
	assert_eq(costs_f, [20, 40, 80, -1])

func test_drain_per_tick() -> void:
	assert_eq(Economy.drain_per_tick(40, bd.build), 2)
	assert_eq(Economy.drain_per_tick(20, bd.build), 1)
	assert_eq(Economy.drain_per_tick(160, bd.build), 8)
	assert_eq(Economy.drain_per_tick(21, bd.build), 2)

func test_night_yield() -> void:
	assert_eq(Economy.night_kills(1, bd.wave), 18)
	assert_eq(Economy.night_kills(2, bd.wave), 24)
	assert_eq(Economy.night_gold(1, bd), 108)
	assert_eq(Economy.night_gold(2, bd), 144)

func test_economy_check_night1_covers_tower_plus_fence_with_margin() -> void:
	# Spec 8.9 / D-063
	var need := bd.economy.economy_margin * (bd.build.tower_cost + bd.build.fence_cost)
	assert_true(Economy.night_gold(1, bd) >= need, "%d < %.1f" % [Economy.night_gold(1, bd), need])
