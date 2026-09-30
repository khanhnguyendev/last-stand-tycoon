extends GutTest

const SEED := 20260930
var cb: CardBalance

func before_each() -> void:
	Balance.reset()
	cb = Balance.data.cards

func _all(level: int) -> Dictionary:
	var d := {}
	for id in CardCatalog.IDS:
		d[id] = level
	return d

func test_golden_offers() -> void:
	assert_eq(CardOffer.make(SEED, 2, {}, cb), [&"archer", &"tank", &"carry_capacity"] as Array[StringName])
	assert_eq(CardOffer.make(SEED, 3, {&"tank": 1}, cb),
		[&"archer", &"hero_damage", &"carry_capacity"] as Array[StringName])
	assert_eq(CardOffer.make(SEED, 4, {&"tank": 1, &"archer": 1}, cb),
		[&"carry_capacity", &"attack_speed", &"hero_damage"] as Array[StringName])

func test_first_offer_is_archer_tank_and_one_upgrade_for_any_seed() -> void:
	for s in [1, 7, 99, 20260930, 123456]:
		var o := CardOffer.make(s, 2, {}, cb)
		assert_eq(o.size(), 3)
		assert_eq([o[0], o[1]], [&"archer", &"tank"])
		assert_true(o[2] in CardCatalog.UPGRADES, "third is an upgrade: %s" % o[2])

func test_zero_level_entries_still_mean_first_offer() -> void:
	var o := CardOffer.make(SEED, 2, {&"tank": 0}, cb)
	assert_eq([o[0], o[1]], [&"archer", &"tank"])

func test_later_offers_are_distinct_and_eligible() -> void:
	var levels := {&"tank": 1, &"hero_damage": 5, &"archer": 5}
	for day in range(3, 30):
		var o := CardOffer.make(SEED, day, levels, cb)
		assert_eq(o.size(), 3)
		var seen := {}
		for id in o:
			assert_false(seen.has(id), "distinct on day %d" % day)
			seen[id] = true
			assert_ne(id, &"hero_damage", "maxed card offered")
			assert_ne(id, &"archer", "maxed card offered")

func test_fewer_eligible_means_fewer_cards() -> void:
	var levels := _all(5)
	levels[&"tank"] = 2
	levels[&"archer"] = 4
	assert_eq(CardOffer.make(SEED, 9, levels, cb), [&"archer", &"tank"] as Array[StringName])

func test_all_maxed_is_empty() -> void:
	assert_eq(CardOffer.make(SEED, 9, _all(5), cb), [] as Array[StringName])

func test_deterministic_per_seed_and_day() -> void:
	var lv := {&"tank": 2, &"move_speed": 1}
	assert_eq(CardOffer.make(SEED, 6, lv, cb), CardOffer.make(SEED, 6, lv, cb))
	var differ := false
	for day in range(3, 13):
		if CardOffer.make(SEED, day, lv, cb) != CardOffer.make(SEED, day + 1, lv, cb):
			differ = true
	assert_true(differ, "offers vary by day")
