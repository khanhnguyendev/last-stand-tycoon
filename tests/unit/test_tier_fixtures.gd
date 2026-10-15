extends GutTest
## E5 spec 8.1: the tier fixtures are valid schema 5 saves with the states the sims rely on. They come from a real
## TierBot run (make_save.gd -- --fixture=tier, seed 20260930): the bot paid the tier on day 12, tier-1 defense full.

const STEMS := ["boss_night_tier1", "boss_only", "tier2_night1", "tier2_full", "tier2_night"]

var banners: Array = []

func before_each() -> void:
	Balance.reset()
	banners.clear()
	EventBus.banner_requested.connect(_on_banner)

func after_each() -> void:
	if EventBus.banner_requested.is_connected(_on_banner):
		EventBus.banner_requested.disconnect(_on_banner)

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

func _resume(stem: String, before := Callable()) -> Main:
	var main: Main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(1)  # a tier-1 world: the resume is what changes it
	if before.is_valid():
		before.call(main)
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

const T3_STEMS := ["tier3_baron_full", "tier3_baron_no_yard", "tier3_baron_alone", "tier3_night1", "tier3_cap_all_a", "tier3_cap_all_b", "tier3_cap_mixed", "tier3_cap_threat"]

func test_every_tier3_fixture_decodes_at_the_current_schema_with_a_valid_checksum() -> void:
	for stem in T3_STEMS:
		var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
		assert_ne(text, "", "%s exists" % stem)
		var r: Dictionary = SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
		assert_true(r.ok, "%s: %s" % [stem, r.get("reason", "")])
		assert_eq(int(r.state.v), GameState.SCHEMA_VERSION, "%s: migrated to the current schema" % stem)
		assert_eq(int(r.state.run_seed), 20260930, stem)

func test_boss_night_tier1() -> void:
	var r: Dictionary = _decode("boss_night_tier1")
	assert_true(r.ok, r.reason)
	var s: Dictionary = r.state
	assert_eq([s.resume_phase, int(s.tier), s.boss_pending, int(s.night_fails)], ["NIGHT", 1, true, 0])
	assert_gte(int(s.day), 8)
	assert_true(bool(s.lane_plan[2].boss))
	assert_gt(int(s.cards.get("archer", 0)), 0, "archer picked")
	assert_gt(int(s.cards.get("tank", 0)), 0, "tank picked")
	var total := 0
	for id in MapLayout.SPOT_IDS:
		total += int(s.buildings[id].level)
	assert_gte(total, 12, "the tier-1 defense is built")
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
		var main := await _resume(stem)
		assert_eq(main.phase_controller.phase, Phase.NIGHT, stem)
		assert_true(GameState.is_boss_night(), stem)
		assert_true(banners.has(tr("The Boar King comes")), "%s: %s" % [stem, banners])
		main.get_parent().remove_child(main)
		main.free()

func test_tier2_night1_resumes_with_the_world_at_tier_2() -> void:
	var main := await _resume("tier2_night1", func(m: Main): assert_false(m.world.build_spots.has("tower_w"), "tier 1 world before the resume"))
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(GameState.tier, 2)
	assert_false(main.world.yard_ids().is_empty(), "the side yards are open")
	assert_true(main.world.build_spots.has("tower_w"), "the yard tower spot exists")
	assert_gt(_hares(_decode("tier2_night1").state), 0)
	main.get_parent().remove_child(main)
	main.free()

func test_every_fixture_survives_five_seconds_of_night() -> void:
	for stem in STEMS:
		var main := await _resume(stem)
		for i in int(ceil((Balance.data.wave.first_wave_delay + 2.0) * 60.0)):
			await get_tree().physics_frame
		assert_eq(main.phase_controller.phase, Phase.NIGHT, stem)
		if stem != "boss_only":  # its first two waves are empty
			assert_gt(main.phase_controller.wave_director.alive_count(), 0, "%s: monsters are out" % stem)
		main.get_parent().remove_child(main)
		main.free()

## Keys of the decoded day fixture allowed to differ from tier3_cap_threat, with the value the day fixture must hold (none so far: the test fails
## on any other difference and names the key; add a key here with the reason it legitimately differs, e.g. a dawn-only card offer).
const DAY_FIXTURE_DIFFERS := {}

## E6 A4: the day fixture the PLAY_ENTERED perf runs resume (`make_save.gd -- --fixture=tier3_cap_day`, written at the current schema).
## It must decode, resume into the DAY, and differ from the night fixture it was made from in `resume_phase` only.
## Fails when the file is stale (a schema the codec rejects), is a night, or differs from tier3_cap_threat in any key but resume_phase (or the listed DAY_FIXTURE_DIFFERS).
func test_tier3_cap_threat_day_decodes_resumes_in_the_day_and_matches_the_night_fixture() -> void:
	var day := _decode("tier3_cap_threat_day")
	var night := _decode("tier3_cap_threat")
	var wrapper = JSON.parse_string(FileAccess.get_file_as_string("res://export/fixtures/tier3_cap_threat_day.save.json"))
	var raw = JSON.parse_string(String(wrapper.state_json))
	assert_eq(int(raw.v), GameState.SCHEMA_VERSION, "the file is written at the current schema (the documented command reproduces it)")
	assert_true(day.ok, str(day.get("reason", "")))
	assert_true(night.ok, str(night.get("reason", "")))
	assert_eq(day.state.resume_phase, "DAY")
	assert_eq(night.state.resume_phase, "NIGHT", "the source is the night fixture")
	# Every key of both decoded saves except resume_phase (checked above) must be equal, unless it is listed in DAY_FIXTURE_DIFFERS.
	var keys := {}
	for k in day.state.keys():
		keys[k] = true
	for k in night.state.keys():
		keys[k] = true
	for k in keys.keys():
		if k == "resume_phase":
			continue
		assert_true(day.state.has(k), "the day fixture has key %s" % k)
		assert_true(night.state.has(k), "tier3_cap_threat has key %s" % k)
		if DAY_FIXTURE_DIFFERS.has(k):
			assert_eq(day.state[k], DAY_FIXTURE_DIFFERS[k], "key %s: the listed expected day value" % k)
		else:
			assert_eq(day.state[k], night.state[k], "key %s: same as tier3_cap_threat" % k)

## E6 phase A: the DAY HOME perf fixture (`make_save.gd -- --fixture=tier3_branch_day`, committed, deterministic). It decodes at the current schema, resumes into a tier-3 DAY
## and shows at least one branch pad (a max-level, unbranched building): the pads' draw calls are what the DAY HOME reading measures.
func test_tier3_branch_day_decodes_is_a_tier_3_day_and_shows_a_branch_pad() -> void:
	var wrapper = JSON.parse_string(FileAccess.get_file_as_string("res://export/fixtures/tier3_branch_day.save.json"))
	var raw = JSON.parse_string(String(wrapper.state_json))
	assert_eq(int(raw.v), GameState.SCHEMA_VERSION, "the file is written at the current schema (a stale file fails here, before the migration hides it)")
	var r := _decode("tier3_branch_day")
	assert_true(r.ok, str(r.get("reason", "")))
	assert_eq(r.state.resume_phase, "DAY")
	assert_eq(int(r.state.tier), 3)
	var main := await _resume("tier3_branch_day")
	await get_tree().physics_frame
	assert_eq(main.phase_controller.phase, Phase.DAY)
	var shown := 0
	for id in main.world.branch_pads:
		for p in main.world.branch_pads[id]:
			if (p as BranchPad).is_shown():
				shown += 1
	assert_gt(shown, 0, "at least one unbought branch pad shows")
	main.get_parent().remove_child(main)
	main.free()
