extends GutTest
## S5 Task 10 (spec 6, D-213): the Guide's rule table as a pure function of a snapshot.

func _spots() -> Array:
	var out: Array = []
	var costs := [20, 20, 20, 40, 40]
	for i in MapLayout.SPOT_IDS.size():
		var id: String = MapLayout.SPOT_IDS[i]
		out.append({"id": id, "remaining": costs[i], "next_cost": costs[i], "pos": MapLayout.to3(MapLayout.spot_position(id))})
	return out

func _s(over: Dictionary = {}) -> Dictionary:
	var s := {
		"phase": Phase.DAY, "day": 2, "hero_xz": MapLayout.HOME, "walked": 0.0, "attack_range": 4.0,
		"boars": [], "steaks": [], "carried": 0, "carry_capacity": 6, "freezer": 0, "counter": 0,
		"counter_capacity": 12, "gold": 0, "gold_pile": 0, "move_m": 2.0, "spots": _spots(), "should_pulse": false,
	}
	for k in over:
		s[k] = over[k]
	return s

func _boar(x: float, z: float, remaining: float, idx: int) -> Dictionary:
	return {"xz": Vector2(x, z), "remaining": remaining, "spawn_index": idx, "pos": Vector3(x, 0, z)}

func _night(over: Dictionary = {}) -> Dictionary:
	var d := {"phase": Phase.NIGHT, "day": 1, "walked": 5.0, "hero_xz": MapLayout.NIGHT1_START}
	for k in over:
		d[k] = over[k]
	return _s(d)

func test_texts_have_at_most_three_words() -> void:
	assert_eq(GuideRules.TEXT.size(), 8)
	for id in GuideRules.TEXT:
		assert_lte(String(GuideRules.TEXT[id]).split(" ", false).size(), 3, String(id))

func test_move_on_night_one_until_walked() -> void:
	var r := GuideRules.evaluate(_night({"walked": 0.0}))
	assert_eq(r.rule_id, &"move")
	assert_eq(r.target_id, &"")
	assert_ne(GuideRules.evaluate(_night({"walked": 2.0})).rule_id, &"move")

func test_fight_targets_smallest_remaining() -> void:
	var near := _boar(-2.5, -17, 8.0, 5)
	var far := _boar(-2.5, -17, 20.0, 1)
	var r := GuideRules.evaluate(_night({"walked": 3.0, "boars": [far, near]}))
	assert_eq(r.rule_id, &"fight")
	assert_eq(r.target_id, &"boar")
	assert_eq(r.target_position, near.pos)

func test_fight_tie_goes_to_lower_spawn_index() -> void:
	var a := _boar(0, -17, 8.0, 7)
	var b := _boar(3, -17, 8.0, 2)
	var r := GuideRules.evaluate(_night({"boars": [a, b]}))
	assert_eq(r.target_position, b.pos)

func test_boar_in_range_is_a_quiet_state() -> void:
	var b := _boar(-2.5, -4.0, 5.0, 0)  # 3 m from the hero at NIGHT1_START
	var r := GuideRules.evaluate(_night({"boars": [b], "steaks": [Vector3(1, 0, 1)]}))
	assert_eq(r.rule_id, &"")

func test_grab_after_the_kill() -> void:
	var far := Vector3(8, 0, -7)
	var near := Vector3(-1, 0, -7)
	var r := GuideRules.evaluate(_night({"steaks": [far, near]}))
	assert_eq(r.rule_id, &"grab")
	assert_eq(r.target_id, &"steak")
	assert_eq(r.target_position, near)
	assert_eq(GuideRules.evaluate(_night({"steaks": [near], "carried": 6})).rule_id, &"")

func test_night_two_has_no_rule() -> void:
	assert_eq(GuideRules.evaluate(_s({"phase": Phase.NIGHT, "day": 2, "walked": 0.0, "steaks": [Vector3.ZERO]})).rule_id, &"")

func test_dawn_has_no_rule() -> void:
	assert_eq(GuideRules.evaluate(_s({"phase": Phase.DAWN, "gold": 999})).rule_id, &"")

func test_build_picks_lowest_next_cost_then_order() -> void:
	var sp := _spots()
	var r := GuideRules.evaluate(_s({"gold": 25, "spots": sp}))
	assert_eq(r.rule_id, &"build")
	assert_eq(r.target_id, &"tower_nw")
	sp[2].next_cost = 10  # fence_w is the cheapest whole upgrade
	r = GuideRules.evaluate(_s({"gold": 25, "spots": sp}))
	assert_eq(r.target_id, &"fence_w")

func test_maxed_spot_is_not_build() -> void:
	var sp := _spots()
	for s in sp:
		s.remaining = -1
	assert_ne(GuideRules.evaluate(_s({"gold": 999, "spots": sp})).rule_id, &"build")

func test_build_target_is_stable_while_paying() -> void:
	var sp := _spots()
	sp[1].next_cost = 5  # tower_ne is the pick
	var first := GuideRules.evaluate(_s({"gold": 25, "spots": sp}))
	assert_eq(first.target_id, &"tower_ne")
	sp[1].remaining = 10  # half paid; gold fell with it
	var second := GuideRules.evaluate(_s({"gold": 15, "spots": sp}))
	assert_eq(second.target_id, &"tower_ne")

func test_collect_when_the_pile_makes_a_spot_affordable() -> void:
	var r := GuideRules.evaluate(_s({"gold_pile": 30}))
	assert_eq(r.rule_id, &"collect")
	assert_eq(r.target_id, &"gold_pile")
	assert_eq(r.target_position, MapLayout.to3(MapLayout.GOLD_PILE))

func test_collect_yields_to_take_when_filling_up_at_the_freezer() -> void:
	var r := GuideRules.evaluate(_s({"gold_pile": 30, "freezer": 36, "hero_xz": MapLayout.FREEZER_ZONE}))
	assert_eq(r.rule_id, &"take")
	assert_eq(r.target_position, MapLayout.to3(MapLayout.FREEZER_ZONE))

func test_collect_with_empty_hands_and_nothing_to_take() -> void:
	var r := GuideRules.evaluate(_s({"gold_pile": 5}))  # not affordable even with the pile, hands empty, no take
	assert_eq(r.rule_id, &"collect")

func test_take_cases() -> void:
	assert_eq(GuideRules.evaluate(_s({"freezer": 36})).rule_id, &"take")
	var at_freezer := {"freezer": 36, "hero_xz": MapLayout.FREEZER_ZONE}
	assert_eq(GuideRules.evaluate(_s(at_freezer.merged({"carried": 3}))).rule_id, &"take")
	var full := GuideRules.evaluate(_s(at_freezer.merged({"carried": 6})))
	assert_eq(full.rule_id, &"stock")
	assert_eq(full.target_id, &"counter")
	assert_eq(full.target_position, MapLayout.to3(MapLayout.COUNTER_DROP))

func test_take_waits_for_room_for_a_full_load() -> void:
	assert_eq(GuideRules.evaluate(_s({"freezer": 36, "counter": 11})).rule_id, &"")

func test_take_reachable_when_carry_exceeds_counter() -> void:
	assert_eq(GuideRules.evaluate(_s({"freezer": 20, "carry_capacity": 14})).rule_id, &"take")

func test_stock_not_when_counter_full() -> void:
	assert_eq(GuideRules.evaluate(_s({"carried": 3, "counter": 12})).rule_id, &"")

func test_close_only_on_pulse() -> void:
	assert_eq(GuideRules.evaluate(_s({"should_pulse": false})).rule_id, &"")
	var r := GuideRules.evaluate(_s({"should_pulse": true}))
	assert_eq(r.rule_id, &"close")
	assert_eq(r.target_id, &"sign")
	assert_eq(r.target_position, MapLayout.to3(MapLayout.SIGN))

func test_day_five_shows_nothing() -> void:
	assert_eq(GuideRules.evaluate(_s({"day": 5, "gold": 999, "gold_pile": 30, "freezer": 36, "should_pulse": true})).rule_id, &"")
