extends GutTest
## E5 spec 8.1: the tier fixtures are valid schema 5 saves with the states the sims rely on. They come from a real
## TierBot run (make_save.gd -- --fixture=tier, seed 20260930): the bot paid the tier on day 12, tier-1 defense full.

const STEMS := ["boss_night_tier1", "boss_only", "tier2_night1", "tier2_full", "tier2_night"]

var banners: Array = []

func before_each() -> void:
	Balance.reset()
	banners.clear()

func _on_banner(t: String) -> void:
	banners.append(t)

func _decode(stem: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
	return SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)

func _hares(s: Dictionary) -> int:
	var n := 0
	for w in s.lane_plan:
		n += int(w.fast_main) + int(w.fast_side)
	return n

func _resume(stem: String) -> Main:
	var main: Main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var r: Dictionary = _decode(stem)
	assert_true(r.ok, r.reason)
	main.phase_controller.resume_from(r.state)
	return main

func test_every_fixture_decodes_at_the_current_schema() -> void:
	for stem in STEMS:
		var r: Dictionary = _decode(stem)
		assert_true(r.ok, "%s: %s" % [stem, r.reason])
		assert_eq(int(r.state.v), GameState.SCHEMA_VERSION, stem)
		assert_eq(int(r.state.run_seed), 20260930, stem)
		assert_eq([int(r.state.gold_pile), int(r.state.carried_steaks), r.state.card_offer], [0, 0, []], stem)

func test_boss_night_tier1() -> void:
	var r: Dictionary = _decode("boss_night_tier1")
	assert_true(r.ok, r.reason)
	var s: Dictionary = r.state
	assert_eq([s.resume_phase, int(s.tier), s.boss_pending, int(s.night_fails)], ["NIGHT", 1, true, 0])
	assert_gte(int(s.day), 8)
	assert_true(bool(s.lane_plan[2].boss))
	assert_gt(int(s.cards.get("tank", 0)), 0, "a tank guard was picked (the run had tank 5)")
	assert_gt(s.guards.size(), 0, "a guard stands")
	var max_towers := 0
	var fences_3 := 0
	for id in MapLayout.SPOT_IDS:
		var lvl: int = int(s.buildings[id].level)
		if MapLayout.spot_kind(id) == "fence":
			fences_3 += 1 if lvl == Balance.data.build.max_level else 0
		else:
			max_towers += 1 if lvl == Balance.data.build.max_level else 0
	assert_gte(max_towers, 1, "at least one tower at level 3")
	assert_gte(fences_3, 1, "at least one fence at level 3")
	assert_gt(int(s.stations.counter.level) + int(s.stations.freezer.level), 0, "the bot upgraded stations")

func test_boss_only() -> void:
	var r: Dictionary = _decode("boss_only")
	assert_true(r.ok, r.reason)
	var s: Dictionary = r.state
	assert_eq([s.resume_phase, s.boss_pending], ["NIGHT", true])
	for w in 2:
		assert_eq([int(s.lane_plan[w].main_count), int(s.lane_plan[w].side_count), s.lane_plan[w].boss], [0, 0, false])
	assert_eq([int(s.lane_plan[2].main_count), int(s.lane_plan[2].side_count), s.lane_plan[2].boss], [0, 0, true])
	assert_eq(_hares(s), 0)
	for id in s.buildings:
		assert_eq(int(s.buildings[id].level), 0, "no builds")
	assert_eq(s.cards, {}, "no cards")
	assert_eq(s.guards, {}, "no guards")

func test_tier2_night1() -> void:
	var s: Dictionary = _decode("tier2_night1").state
	assert_eq([s.resume_phase, int(s.tier), s.boss_pending, int(s.night_fails), int(s.tier_paid)], ["NIGHT", 2, false, 0, 0])
	assert_eq(int(s.tier_day), int(s.day), "the first night of the tier")
	assert_eq([int(s.buildings.tower_w.level), int(s.buildings.tower_e.level)], [0, 0])
	assert_false(bool(s.lane_plan[2].boss))
	assert_gt(_hares(s), 0, "hares in the plan")
	assert_eq(float(s.diner_hp), Balance.data.build.diner_max_hp)
	for id in s.guards:
		assert_eq(float(s.guards[id].hp), float(CardEffects.guard_stats(StringName(id), maxi(int(s.cards[id]), 1), Balance.data.guards).max_hp))

func test_tier2_full_and_perf() -> void:
	var cap: int = Balance.data.tiers.tier_cap[2]
	for stem in ["tier2_full", "tier2_night"]:
		var f: Dictionary = _decode(stem).state
		assert_eq([f.resume_phase, int(f.tier), f.boss_pending], ["NIGHT", 2, false])
		assert_eq(WaveMath.pressure(int(f.day), 2, int(f.tier_day), Balance.data.tiers), cap, "pressure at the cap")
		assert_eq(int(f.day) - int(f.tier_day), Balance.data.tiers.fast_ramp_days[2])
		for id in MapLayout.spots_for_tier(2):
			assert_eq(int(f.buildings[id].level), Balance.data.build.max_level, id)
			if MapLayout.spot_kind(id) == "fence":
				assert_eq(float(f.buildings[id].hp), Balance.data.build.fence_hp[Balance.data.build.max_level - 1], id)
		assert_gt(_hares(f), 0)
	assert_eq(FileAccess.get_file_as_string("res://export/fixtures/tier2_full.save.json"),
		FileAccess.get_file_as_string("res://export/fixtures/tier2_night.save.json"), "two files, one content")

func test_boss_fixtures_resume_into_the_boss_night() -> void:
	for stem in ["boss_night_tier1", "boss_only"]:
		banners.clear()
		EventBus.banner_requested.connect(_on_banner)
		var main := await _resume(stem)
		EventBus.banner_requested.disconnect(_on_banner)
		assert_eq(main.phase_controller.phase, Phase.NIGHT, stem)
		assert_true(GameState.is_boss_night(), stem)
		assert_true(banners.has(tr("The Boar King comes")), "%s: %s" % [stem, banners])

func test_tier2_night1_resumes_with_the_world_at_tier_2() -> void:
	var main := await _resume("tier2_night1")
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(GameState.tier, 2)
	assert_false(main.world.yard_ids().is_empty(), "the side yards are open")
	assert_true(main.world.build_spots.has("tower_w"), "the yard tower spot exists")
	assert_gt(_hares(_decode("tier2_night1").state), 0)

func test_every_fixture_survives_five_seconds_of_night() -> void:
	for stem in STEMS:
		var main := await _resume(stem)
		for i in 5 * 60:
			await get_tree().physics_frame
		assert_eq(main.phase_controller.phase, Phase.NIGHT, stem)
		main.get_parent().remove_child(main)
		main.free()
