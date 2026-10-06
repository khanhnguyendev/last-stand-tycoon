extends GutTest

func test_enemy_count_sums_waves_and_boss() -> void:
	var plan := [{"main_count": 10, "side_count": 4, "boss": false}, {"main_count": 6, "side_count": 0, "boss": false}]
	assert_eq(SweepMath.enemy_count(plan), 20)
	plan[1].boss = true
	assert_eq(SweepMath.enemy_count(plan), 21)
	assert_eq(SweepMath.enemy_count([]), 0)

func test_tier_summary() -> void:
	var nights := [
		{"day": 1, "tier": 1, "boss_night": false, "retries": 0, "at_cap": false},
		{"day": 8, "tier": 1, "boss_night": true, "retries": 2, "at_cap": false},
		{"day": 9, "tier": 2, "boss_night": false, "retries": 1, "at_cap": true},
		{"day": 10, "tier": 2, "boss_night": false, "retries": 0, "at_cap": true},
		{"day": 11, "tier": 2, "boss_night": false, "retries": 3, "at_cap": false},
	]
	assert_eq(SweepMath.tier_summary(nights), {"first_tier2_day": 9, "boss_retries": 2, "cap_nights": 2, "cap_retries": 1})
	assert_eq(SweepMath.tier_summary([]).first_tier2_day, -1)
