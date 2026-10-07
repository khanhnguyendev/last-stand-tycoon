extends GutTest
## PINNED REFERENCE: spec 6.2 reference values at the default WaveBalance. Update with Task 35 if tuned.

var wb: WaveBalance

func before_each() -> void:
	Balance.reset()
	wb = Balance.data.wave

func test_day1_totals() -> void:
	assert_eq([WaveMath.total_count(1, 0, wb), WaveMath.total_count(1, 1, wb), WaveMath.total_count(1, 2, wb)], [4, 6, 8])

func test_day2_reference_values() -> void:
	assert_eq([WaveMath.total_count(2, 0, wb), WaveMath.total_count(2, 1, wb), WaveMath.total_count(2, 2, wb)], [5, 8, 11])
	assert_almost_eq(WaveMath.hp_mult(2, 0, wb), 1.15, 0.0001)
	assert_almost_eq(WaveMath.hp_mult(1, 0, wb), 1.0, 0.0001)
	assert_almost_eq(Balance.data.enemy.hp * WaveMath.hp_mult(2, 0, wb), 34.5, 0.0001)
	assert_eq(WaveMath.total_count(6, 1, wb), 17)
	assert_eq(WaveMath.split(3, 1, wb), {"main": 7, "side": 3})
	assert_eq(WaveMath.split(2, 0, wb), {"main": 4, "side": 1})
	assert_eq(WaveMath.split(2, 1, wb), {"main": 6, "side": 2})
	assert_eq(WaveMath.split(2, 2, wb), {"main": 9, "side": 2})

func test_day1_has_no_side_group() -> void:
	for w in 3:
		assert_eq(WaveMath.split(1, w, wb).side, 0)

func test_side_share_curve_and_cap() -> void:
	assert_eq(WaveMath.side_share(1, wb), 0.0)
	assert_almost_eq(WaveMath.side_share(2, wb), 0.20, 0.0001)
	assert_almost_eq(WaveMath.side_share(4, wb), 0.30, 0.0001)
	assert_almost_eq(WaveMath.side_share(7, wb), 0.45, 0.0001)
	assert_almost_eq(WaveMath.side_share(20, wb), 0.45, 0.0001)

func test_cap_overflows_into_hp() -> void:
	# day 10, wave 2: raw = round(8 * 4.15) = 33 -> capped to 30, hp x 33/30
	assert_eq(WaveMath.raw_total(10, 2, wb), 33)
	assert_eq(WaveMath.total_count(10, 2, wb), 30)
	assert_almost_eq(WaveMath.hp_mult(10, 2, wb), (1.0 + 0.15 * 9) * 33.0 / 30.0, 0.0001)

func test_side_at_least_one_from_day2() -> void:
	wb.side_share_base = 0.01
	assert_eq(WaveMath.split(2, 0, wb).side, 1)

func test_pressure_caps_per_tier() -> void:
	var tb := Balance.data.tiers
	for day in range(1, 8):
		assert_eq(WaveMath.pressure(day, 1, 1, tb), day, "tier 1 day %d is today's day" % day)
	assert_eq(WaveMath.pressure(8, 1, 1, tb), 7)
	assert_eq(WaveMath.pressure(30, 1, 1, tb), 7)
	assert_eq([WaveMath.pressure(9, 2, 9, tb), WaveMath.pressure(10, 2, 9, tb), WaveMath.pressure(12, 2, 9, tb), WaveMath.pressure(13, 2, 9, tb)], [8, 9, 10, 10])
	assert_eq(WaveMath.pressure(40, 2, 40, tb), 8, "a late tier-up starts at the tier's base")

func test_capped_night_kills() -> void:
	# spec 4.1: tier 1 cap 12 + 19 + 25 = 56; tier 2 (cap 10) = 72
	var k1 := 0
	var k2 := 0
	for w in 3:
		k1 += WaveMath.total_count(7, w, wb)
		k2 += WaveMath.total_count(10, w, wb)
	assert_eq([k1, k2], [56, 72])
