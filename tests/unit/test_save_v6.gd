extends GutTest
## E5 tier 3 spec 3.6, D-270.2: schema 6, the 5 -> 6 step pinned on the eight committed fixtures (five are schema 5, day3_counter5 is schema 4, night3_start and night3_closeup are schema 3), branch validation,
## tier-3 lanes and brutes. A tier-3 state needs the tier-3 cost entry (added in setup; Balance.reset() drops it).

const FIXTURE_DIR := "res://tests/fixtures/v5/"
const V5_WAVE_KEYS := ["boss", "fast_main", "fast_side", "hp_mult", "main", "main_count", "side", "side_count"]
const V5_STATE_KEYS := ["boss_pending", "buildings", "card_offer", "cards", "carried_steaks", "counter_steaks", "day",
	"diner_hp", "freezer_steaks", "gold", "gold_pile", "guards", "lane_character", "lane_plan", "night_fails", "resume_phase", "run_seed",
	"stations", "tier", "tier_day", "tier_paid", "v"]

func before_each() -> void:
	Balance.reset()
	SaveCodec.MIGRATIONS.clear()
	GameState.new_game(20261007)

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

func _fixture_files() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(FIXTURE_DIR)
	for f in d.get_files():
		if f.ends_with(".save.json"):
			out.append(f)
	out.sort()
	return out

## All numbers as floats, so a JSON-parsed dictionary compares with a to_dict one (int 5 vs float 5.0).
func _canon(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT:
			return float(v)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[String(k)] = _canon(v[k])
			return d
		TYPE_ARRAY:
			return v.map(func(x): return _canon(x))
	return v

## Every difference between two JSON trees, as "path: a -> b" lines.
func _diff(a: Variant, b: Variant, path: String, out: Array[String]) -> void:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for k in a:
			if not b.has(k):
				out.append("%s/%s: removed" % [path, k])
			else:
				_diff(a[k], b[k], path + "/" + str(k), out)
		for k in b:
			if not a.has(k):
				out.append("%s/%s: added %s" % [path, k, str(b[k])])
	elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			out.append("%s: size %d -> %d" % [path, a.size(), b.size()])
			return
		for i in a.size():
			_diff(a[i], b[i], "%s[%d]" % [path, i], out)
	elif typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		if float(a) != float(b):
			out.append("%s: %s -> %s" % [path, str(a), str(b)])
	elif typeof(a) != typeof(b) or a != b:
		out.append("%s: %s -> %s" % [path, str(a), str(b)])

func _v5_state(file: String) -> Dictionary:
	var env = SaveCodec._parse(FileAccess.get_file_as_string(FIXTURE_DIR + file))
	return SaveCodec._parse(env.state_json)

func _tier3_setup() -> void:
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	GameState.new_game(20261007)
	GameState.day = 12
	GameState.debug_set_tier(3, 9)
	var max_level: int = Balance.data.build.max_level
	for id in ["tower_nw", "fence_n", "fence_w"]:
		GameState.buildings[id].level = max_level
	GameState.buildings.fence_n.hp = 320.0
	GameState.buildings.fence_w.hp = 320.0
	GameState.buildings.tower_nw.branch = "longbow"
	GameState.buildings.fence_n.branch_paid = {"stone": 120, "spike": 45}
	GameState.lane_plan[0].main = "sw"
	GameState.lane_plan[0].brute_main = 3
	GameState.lane_plan[0].brute_side = 1
	GameState.gold = 321

func _t3_dict() -> Dictionary:
	_tier3_setup()
	return GameState.to_dict()

func _decode(s: Dictionary, bd: BalanceData = null) -> Dictionary:
	return SaveCodec.decode(SaveCodec.encode(s, "t", 0), GameState.SCHEMA_VERSION, bd if bd != null else Balance.data)

# --- migration on the real schema-5 saves ------------------------------------------------------

## The committed fixtures are the real saves of earlier slices: five were written at schema 5; day3_counter5 is schema 4
## and night3_start / night3_closeup are schema 3 (they still load through the whole chain, so they are covered too).
const FIXTURE_VERSIONS := {"boss_night_tier1": 5, "boss_only": 5, "day3_counter5": 4, "night3_closeup": 3,
	"night3_start": 3, "tier2_full": 5, "tier2_night": 5, "tier2_night1": 5}

func test_the_fixture_directory_holds_the_eight_real_saves() -> void:
	var files := _fixture_files()
	assert_eq(files.size(), 8)
	for f in files:
		assert_eq(int(_v5_state(f).v), FIXTURE_VERSIONS[f.get_basename().get_basename()], f)

## The additions of the older steps (3 -> 4: stations; 4 -> 5: the tier keys and the plan's hare/boss fields), written
## out here as the oracle for the three older fixtures; a schema-5 fixture may show none of them.
func _is_older_step_addition(line: String, from_v: int) -> bool:
	if from_v >= 5:
		return false
	var plan_field := RegEx.create_from_string("^/lane_plan\\[\\d+\\]/(fast_main|fast_side): added 0$|^/lane_plan\\[\\d+\\]/boss: added false$")
	if plan_field.search(line) != null:
		return true
	if line in ["/tier: added 1", "/tier_day: added 1", "/tier_paid: added 0", "/boss_pending: added false"]:
		return true
	if from_v == 3:
		# the 3 -> 4 step adds exactly the two fresh stations (either key order: the step builds it in StationEffects.IDS order)
		var a := {"counter": {"level": 0, "paid": 0}, "freezer": {"level": 0, "paid": 0}}
		var b := {"freezer": {"level": 0, "paid": 0}, "counter": {"level": 0, "paid": 0}}
		return line == "/stations: added " + str(a) or line == "/stations: added " + str(b)
	return false

## Schema 7 (E6) adds one more field to what this chain produces: an empty `lane_character`; it is the only addition allowed besides the v6 ones.
func test_every_fixture_migrates_to_v6_changing_only_the_two_building_fields() -> void:
	assert_eq(GameState.SCHEMA_VERSION, 7)
	for f in _fixture_files():
		var old := _v5_state(f)
		var from_v := int(old.v)
		var r := SaveCodec.decode(FileAccess.get_file_as_string(FIXTURE_DIR + f), GameState.SCHEMA_VERSION, Balance.data)
		assert_true(r.ok, "%s: %s" % [f, r.reason])
		if not r.ok:
			continue
		assert_eq(int(r.state.v), 7, f)
		assert_eq(r.state.lane_character, {}, f)
		var diffs: Array[String] = []
		_diff(old, r.state, "", diffs)
		var unexpected: Array[String] = []
		var new_fields := 0
		for line in diffs:
			if line.begins_with("/v: ") or line == "/lane_character: added {  }" or line == "/lane_character: added {}":
				continue
			var is_new_field := false
			for id in old.buildings:
				if line == "/buildings/%s/branch: added " % id or line == "/buildings/%s/branch_paid: added {  }" % id \
						or line == "/buildings/%s/branch_paid: added {}" % id:
					is_new_field = true
					new_fields += 1
			if not is_new_field and not _is_older_step_addition(line, from_v):
				unexpected.append(line)
		assert_eq(unexpected, [], f + ": differences beyond the version, the older steps and the two new fields")
		assert_eq(new_fields, 2 * old.buildings.size(), f + ": exactly two new fields per building")
		for id in r.state.buildings:
			assert_eq(r.state.buildings[id].branch, "", f)
			assert_eq(r.state.buildings[id].branch_paid, {}, f)
		for w in r.state.lane_plan:
			assert_false(w.has("brute_main") or w.has("brute_side"), f + ": no brute keys on a tier-1/2 plan")

func test_every_migrated_fixture_round_trips_through_game_state() -> void:
	for f in _fixture_files():
		var r := SaveCodec.decode(FileAccess.get_file_as_string(FIXTURE_DIR + f), GameState.SCHEMA_VERSION, Balance.data)
		assert_true(r.ok, f)
		GameState.from_dict(r.state)
		var again := GameState.to_dict()
		var diffs: Array[String] = []
		_diff(_canon(r.state), _canon(again), "", diffs)
		assert_eq(diffs, [], f + ": from_dict + to_dict equals the migrated v6 dictionary")

# --- a v6 round trip at tier 3 -----------------------------------------------------------------------

func test_v6_round_trip_with_a_branch_a_partial_payment_a_lane_sw_and_brutes() -> void:
	var s := _t3_dict()
	assert_eq(s.buildings.tower_nw.branch, "longbow", "setup: the test state really holds the data")
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.new_game(3)
	GameState.from_dict(r.state)
	assert_eq(GameState.tier, 3)
	assert_eq(GameState.branch_of("tower_nw"), &"longbow")
	assert_eq(GameState.buildings.fence_n.branch_paid, {"stone": 120, "spike": 45})
	assert_eq([GameState.lane_plan[0].main, GameState.lane_plan[0].brute_main, GameState.lane_plan[0].brute_side], ["sw", 3, 1])
	var diffs: Array[String] = []
	_diff(_canon(r.state), _canon(GameState.to_dict()), "", diffs)
	assert_eq(diffs, [])

func test_the_same_save_is_rejected_when_the_build_has_no_tier_3() -> void:
	var s := _t3_dict()
	Balance.reset()
	Balance.data.tiers.tier_costs = [0, 500]  # setup: a two-tier build (the shipped build has three now): the top tier is 2
	var why := SaveCodec.validate(s, Balance.data)
	# tower_nw (branched, tier clamps to 2) comes first in building order, so the branch rule names it first
	assert_eq(why, "branch level tower_nw longbow")
	var unbranched := s.duplicate(true)
	unbranched.buildings.tower_nw.branch = ""
	unbranched.buildings.fence_n.branch_paid = {}
	assert_eq(SaveCodec.validate(unbranched, Balance.data), "building tier tower_sw", "then the tier-3 spot the build does not know")
	assert_false(_decode(s).ok)
	# each tier-3 ingredient alone is invalid on a tier-2 build (clamped tier), so none can slip through
	GameState.new_game(20261007)
	GameState.day = 12
	GameState.debug_set_tier(2, 5)
	var base := GameState.to_dict()
	var lane := base.duplicate(true)
	lane.lane_plan[0].main = "sw"
	assert_string_contains(SaveCodec.validate(lane, Balance.data), "sw")
	var branch := base.duplicate(true)
	branch.buildings.tower_nw.level = 3
	branch.buildings.tower_nw.branch = "longbow"
	assert_string_contains(SaveCodec.validate(branch, Balance.data), "tower_nw")
	var brutes := base.duplicate(true)
	brutes.lane_plan[0].brute_main = 1
	assert_string_contains(SaveCodec.validate(brutes, Balance.data), "brute_main")

func test_the_tier_3_state_itself_validates() -> void:
	assert_eq(SaveCodec.validate(_t3_dict(), Balance.data), "")

# --- validation of branch fields ---------------------------------------------------------------------------

func _invalid(mutate: Callable, offending: String) -> void:
	var s := _t3_dict()
	mutate.call(s)
	var why := SaveCodec.validate(s, Balance.data)
	assert_ne(why, "", "rejected: " + offending)
	assert_string_contains(why, offending)
	assert_false(_decode(s).ok, "decode rejects it: " + offending)

func test_unknown_branch_is_rejected() -> void:
	_invalid(func(s): s.buildings.tower_nw.branch = "nonsense", "tower_nw")

func test_a_branch_of_the_wrong_kind_is_rejected() -> void:
	_invalid(func(s): s.buildings.tower_nw.branch = "stone", "tower_nw")
	_invalid(func(s): s.buildings.fence_w.branch = "longbow", "fence_w")

func test_a_branch_below_max_level_is_rejected() -> void:
	_invalid(func(s): s.buildings.fence_w.level = 2; s.buildings.fence_w.branch = "spike", "fence_w")

func test_branch_paid_with_a_branch_set_is_rejected() -> void:
	_invalid(func(s): s.buildings.tower_nw.branch_paid = {"volley": 10}, "tower_nw")

func test_branch_paid_keys_and_values_are_checked() -> void:
	_invalid(func(s): s.buildings.fence_n.branch_paid = {"longbow": 10}, "fence_n")
	_invalid(func(s): s.buildings.fence_n.branch_paid = {"stone": -1}, "fence_n")
	_invalid(func(s): s.buildings.fence_n.branch_paid = {"stone": "x"}, "fence_n")
	_invalid(func(s): s.buildings.fence_n.branch_paid = [1], "fence_n")

func test_branch_paid_below_max_level_is_rejected() -> void:
	_invalid(func(s): s.buildings.fence_e.branch_paid = {"stone": 10}, "fence_e")

func test_a_payment_at_or_above_the_cost_is_valid_and_clamps_on_load() -> void:
	# D-234: a later balance change never loses a save. Precedent: test_save_tier.test_paid_at_or_above_cost_is_clamped_on_load
	# (tier_paid) and the station payments: clamp to cost - 1, the excess is not refunded.
	var s := _t3_dict()
	var tc: int = Balance.data.branches.tower_branch_cost
	var fc: int = Balance.data.branches.fence_branch_cost
	s.buildings.tower_ne.level = 3
	s.buildings.tower_ne.branch_paid = {"volley": tc + 250, "longbow": 7}
	s.buildings.fence_n.branch_paid = {"stone": fc, "spike": 0}
	assert_eq(SaveCodec.validate(s, Balance.data), "")
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	var gold_before: int = int(r.state.gold)
	GameState.new_game(1)
	GameState.from_dict(r.state)
	assert_eq(GameState.buildings.tower_ne.branch_paid, {"volley": tc - 1, "longbow": 7})
	assert_eq(GameState.buildings.fence_n.branch_paid, {"stone": fc - 1, "spike": 0})
	assert_eq(GameState.gold, gold_before, "the clamped excess is not refunded")
	assert_eq(GameState.pay_into_branch("fence_n", &"stone", 1), 1, "and the pad can complete after the clamp")

func test_a_building_without_the_branch_fields_is_rejected() -> void:
	_invalid(func(s): s.buildings.fence_w.erase("branch"), "fence_w")
	_invalid(func(s): s.buildings.fence_w.erase("branch_paid"), "fence_w")

func test_a_non_string_branch_is_rejected() -> void:
	_invalid(func(s): s.buildings.tower_nw.branch = 5, "tower_nw")

func test_branch_paid_below_tier_3_is_rejected() -> void:
	GameState.new_game(20261007)
	GameState.day = 12
	GameState.debug_set_tier(2, 5)
	var s := GameState.to_dict()
	s.buildings.fence_n.level = 3
	s.buildings.fence_n.branch_paid = {"stone": 10}
	assert_string_contains(SaveCodec.validate(s, Balance.data), "fence_n")
	s.buildings.fence_n.branch_paid = {}
	assert_eq(SaveCodec.validate(s, Balance.data), "", "the same building without the payment is fine")

func test_lane_names_are_checked_against_the_tiers_list() -> void:
	_invalid(func(s): s.lane_plan[1].main = "nowhere", "nowhere")
	_invalid(func(s): s.lane_plan[1].side = "sw2", "sw2")
	var s := _t3_dict()
	s.lane_plan[1].side = "sw"
	assert_eq(SaveCodec.validate(s, Balance.data), "", "sw is a tier-3 lane")

func test_brutes_must_be_non_negative_whole_numbers() -> void:
	_invalid(func(s): s.lane_plan[0].brute_main = -1, "brute_main")
	_invalid(func(s): s.lane_plan[0].brute_side = 1.5, "brute_side")
	_invalid(func(s): s.lane_plan[0].brute_side = "2", "brute_side")

func test_at_tier_3_every_wave_carries_both_brute_keys() -> void:
	_invalid(func(s): s.lane_plan[1].erase("brute_main"), "brute_main")
	_invalid(func(s): s.lane_plan[2].erase("brute_side"), "brute_side")

# --- the tier-1/2 shape is unchanged ---------------------------------------------------------------------------

func test_a_new_game_at_tier_1_has_the_v5_keys_and_the_two_building_fields() -> void:
	GameState.new_game(7)
	var d := GameState.to_dict()
	var keys: Array = d.keys()
	keys.sort()
	assert_eq(keys, V5_STATE_KEYS)
	for id in d.buildings:
		var bk: Array = d.buildings[id].keys()
		bk.sort()
		assert_eq(bk, ["branch", "branch_paid", "hp", "level", "paid"], id)
	for w in d.lane_plan:
		var wk: Array = w.keys()
		wk.sort()
		assert_eq(wk, V5_WAVE_KEYS)

func test_a_tier_2_plan_has_exactly_the_eight_wave_keys_before_and_after_a_load() -> void:
	GameState.debug_set_tier(2, 4)
	var d := GameState.to_dict()
	for w in d.lane_plan:
		var wk: Array = w.keys()
		wk.sort()
		assert_eq(wk, V5_WAVE_KEYS)
	# a hand-made tier-2 save that carries brute keys is invalid, and from_dict never copies them either
	var with_brutes := d.duplicate(true)
	with_brutes.lane_plan[0].brute_main = 2
	assert_ne(SaveCodec.validate(with_brutes, Balance.data), "")
	GameState.from_dict(with_brutes)
	assert_false(GameState.lane_plan[0].has("brute_main"), "from_dict mirrors the planner's gate")

func test_a_tier_3_plan_keeps_its_brute_keys_through_from_dict() -> void:
	var s := _t3_dict()
	GameState.new_game(1)
	GameState.from_dict(s)
	for w in GameState.lane_plan:
		assert_true(w.has("brute_main") and w.has("brute_side"))
