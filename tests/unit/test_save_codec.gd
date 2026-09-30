extends GutTest

var bd: BalanceData

func before_each() -> void:
	Balance.reset()
	bd = Balance.data
	GameState.new_game(20260930)

func after_each() -> void:
	SaveCodec.MIGRATIONS.clear()

func _state(resume := "DAY") -> Dictionary:
	GameState.new_game(20260930)  # fresh each call: repeated grants would pass max_level
	GameState.debug_grant_card(&"tank")
	GameState.damage_diner(1.0 / 3.0)
	GameState.set_night_fails(2)
	var d := GameState.to_dict()
	d.resume_phase = resume
	return d

func test_round_trip_is_exact_after_from_dict() -> void:
	var s := _state()
	var r := SaveCodec.decode(SaveCodec.encode(s, "abc", 1234), GameState.SCHEMA_VERSION, bd)
	assert_true(r.ok, r.reason)
	GameState.new_game(1)
	GameState.from_dict(r.state)
	assert_eq(GameState.to_dict(), s)

func test_tampered_state_fails_the_check() -> void:
	var env = JSON.parse_string(SaveCodec.encode(_state(), "abc", 1))
	env.state_json = String(env.state_json).replace("\"gold\":0", "\"gold\":999")
	var r := SaveCodec.decode(JSON.stringify(env), GameState.SCHEMA_VERSION, bd)
	assert_false(r.ok)
	assert_eq(r.reason, "check")

func test_bad_json_and_formats() -> void:
	assert_eq(SaveCodec.decode("not json", 3, bd).reason, "json")
	assert_eq(SaveCodec.decode('{"format": {}, "state_json": "", "check": 1}', 3, bd).reason, "json")
	assert_eq(SaveCodec.decode("{}", 3, bd).reason, "json")
	var env = JSON.parse_string(SaveCodec.encode(_state(), "abc", 1))
	env.format = 2
	var r := SaveCodec.decode(JSON.stringify(env), GameState.SCHEMA_VERSION, bd)
	assert_eq([r.ok, r.reason, r.newer], [false, "format", true])

func test_newer_version_is_flagged() -> void:
	var s := _state()
	s.v = GameState.SCHEMA_VERSION + 1
	var r := SaveCodec.decode(SaveCodec.encode(s, "abc", 1), GameState.SCHEMA_VERSION, bd)
	assert_eq([r.ok, r.reason, r.newer], [false, "version", true])

func test_older_version_migrates_through_the_hook() -> void:
	var s := _state()
	s.v = GameState.SCHEMA_VERSION - 1
	s.erase("night_fails")
	var text := SaveCodec.encode(s, "abc", 1)
	assert_eq(SaveCodec.decode(text, GameState.SCHEMA_VERSION, bd).reason, "version", "no step registered")
	SaveCodec.MIGRATIONS[GameState.SCHEMA_VERSION - 1] = func(st: Dictionary) -> Dictionary:
		st.v = GameState.SCHEMA_VERSION
		st.night_fails = 0
		return st
	var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, bd)
	assert_true(r.ok, r.reason)
	assert_eq(int(r.state.night_fails), 0)

func _content(mutate: Callable, resume := "DAY") -> String:
	var s := _state(resume)
	mutate.call(s)
	return SaveCodec.decode(SaveCodec.encode(s, "abc", 1), GameState.SCHEMA_VERSION, bd).reason

func test_content_rejects_bad_ids_levels_and_phase() -> void:
	assert_eq(_content(func(s): s.cards["bogus"] = 1), "content")
	assert_eq(_content(func(s): s.cards["tank"] = bd.cards.max_level + 1), "content")
	assert_eq(_content(func(s): s.resume_phase = "LUNCH"), "content")
	assert_eq(_content(func(s): s.erase("gold")), "content")
	assert_eq(_content(func(s): s.buildings["tower_x"] = {"level": 0, "paid": 0, "hp": 0.0}), "content")
	assert_eq(_content(func(s): s.lane_plan.pop_back()), "content")
	assert_eq(_content(func(s): s.guards["hero_damage"] = {"hp": 1.0}), "content")
	assert_eq(_content(func(s): s.card_offer = ["bogus"]), "content")
	assert_eq(_content(func(s): s.buildings.erase("fence_n")), "content")
	assert_eq(_content(func(s): s.lane_plan[0].erase("hp_mult")), "content")
	assert_eq(_content(func(s): s.cards = []), "content")
	assert_eq(_content(func(s): s.cards["tank"] = -1), "content")
	assert_eq(_content(func(s): s.cards["tank"] = "x"), "content")
	assert_eq(_content(func(s): s.buildings["fence_n"] = {"level": 0}), "content")
	assert_eq(_content(func(s): s.buildings["fence_n"].hp = "x"), "content")
	assert_eq(_content(func(s): s.buildings["tower_nw"].level = bd.build.max_level + 1), "content")
	assert_eq(_content(func(s): s.guards["tank"] = {}), "content")
	assert_eq(_content(func(s): s.card_offer = {}), "content")
	assert_eq(_content(func(s): s.card_offer = [1]), "content")
	assert_eq(_content(func(s): s.lane_plan[0] = 1), "content")
	assert_eq(_content(func(s): s.lane_plan[0].main = "south"), "content")
	assert_eq(_content(func(s): s.gold = {}), "content")
	assert_eq(_content(func(s): s.night_fails = -1), "content")
	assert_eq(_content(func(s): s.resume_phase = null), "content")
	assert_eq(_content(func(s): s.card_offer = [[1, 2]]), "content")
	assert_eq(_content(func(s): s.card_offer = [[]]), "content")
	assert_eq(_content(func(s): s.day = 0), "content")
	assert_eq(_content(func(s): s.gold = -1), "content")
	assert_eq(_content(func(s): s.gold_pile = -1), "content")
	assert_eq(_content(func(s): s.diner_hp = -1), "content")
	assert_eq(_content(func(s): s.diner_hp = 0, "NIGHT"), "content")
	assert_eq(_content(func(s): s.freezer_steaks = -1), "content")
	assert_eq(_content(func(s): s.lane_plan[0].main_count = "x"), "content")
	assert_eq(_content(func(s): s.lane_plan[0].side = "south"), "content")

func test_envelope_edge_cases() -> void:
	var env = JSON.parse_string(SaveCodec.encode(_state(), "abc", 1))
	env.state_json = 5
	assert_eq(SaveCodec.decode(JSON.stringify(env), GameState.SCHEMA_VERSION, bd).reason, "check")
	var x := JSON.stringify({"format": 1, "saved_at_unix": 1, "build": "b", "state_json": "x", "check": Rng.fnv1a32("x")})
	assert_eq(SaveCodec.decode(x, GameState.SCHEMA_VERSION, bd).reason, "json")
	var s := _state()
	s.erase("v")
	assert_eq(SaveCodec.decode(SaveCodec.encode(s, "abc", 1), GameState.SCHEMA_VERSION, bd).reason, "json")
	env = JSON.parse_string(SaveCodec.encode(_state(), "abc", 1))
	env.format = 0
	var r := SaveCodec.decode(JSON.stringify(env), GameState.SCHEMA_VERSION, bd)
	assert_eq([r.ok, r.reason, r.newer], [false, "format", false])

func test_migration_that_does_not_raise_v_is_rejected() -> void:
	var s := _state()
	s.v = GameState.SCHEMA_VERSION - 1
	SaveCodec.MIGRATIONS[GameState.SCHEMA_VERSION - 1] = func(st: Dictionary) -> Dictionary: return st
	var r := SaveCodec.decode(SaveCodec.encode(s, "abc", 1), GameState.SCHEMA_VERSION, bd)
	SaveCodec.MIGRATIONS.clear()
	assert_eq([r.ok, r.reason], [false, "version"])

func test_content_rejects_card_pick_with_empty_or_maxed_offer() -> void:
	assert_eq(_content(func(s): s.card_offer = [], "CARD_PICK"), "content")
	assert_eq(_content(func(s):
		s.card_offer = ["tank"]
		s.cards["tank"] = bd.cards.max_level, "CARD_PICK"), "content")
	assert_eq(_content(func(s): s.card_offer = ["archer", "move_speed"], "CARD_PICK"), "")

func test_v_as_json_string_is_a_json_failure() -> void:
	assert_eq(_content(func(s): s.v = "3"), "json")

func test_migration_that_jumps_past_the_current_version_is_rejected() -> void:
	var s := _state()
	s.v = GameState.SCHEMA_VERSION - 1
	SaveCodec.MIGRATIONS[GameState.SCHEMA_VERSION - 1] = func(st: Dictionary) -> Dictionary:
		st.v = GameState.SCHEMA_VERSION + 1
		return st
	var r := SaveCodec.decode(SaveCodec.encode(s, "abc", 1), GameState.SCHEMA_VERSION, bd)
	SaveCodec.MIGRATIONS.clear()
	assert_eq([r.ok, r.reason], [false, "version"])
