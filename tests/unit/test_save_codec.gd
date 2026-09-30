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

func test_content_rejects_card_pick_with_empty_or_maxed_offer() -> void:
	assert_eq(_content(func(s): s.card_offer = [], "CARD_PICK"), "content")
	assert_eq(_content(func(s):
		s.card_offer = ["tank"]
		s.cards["tank"] = bd.cards.max_level, "CARD_PICK"), "content")
	assert_eq(_content(func(s): s.card_offer = ["archer", "move_speed"], "CARD_PICK"), "")
