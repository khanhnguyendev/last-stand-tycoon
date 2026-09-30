extends GutTest

var DS = load("res://ui/debug/debug_scenes.gd")
var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(99)

func test_parse() -> void:
	assert_eq(DS.parse("?cards=archer:1,tank:2&scene=cardpick"),
		{"cards": {&"archer": 1, &"tank": 2}, "scene": "cardpick"})
	assert_eq(DS.parse(""), {"cards": {}, "scene": ""})
	assert_eq(DS.parse("?cards=bogus:3,tank:x"), {"cards": {}, "scene": ""}, "unknown ids and bad levels are dropped")
	assert_eq(DS.parse("?cards=tank:9").cards, {&"tank": Balance.data.cards.max_level}, "levels clamp to max")

func test_has_fresh_start_key() -> void:
	for q in ["?scene=cardpick", "?cards=x", "?reset=1", "?a=1&reset=1"]:
		assert_true(DS.has_fresh_start_key(q), q)
	for q in ["?preset=x", "?noscene=1", ""]:
		assert_false(DS.has_fresh_start_key(q), q)

func test_apply_grants_cards_and_opens_pick() -> void:
	DS.apply(main, DS.parse("?cards=tank:2,move_speed:1&scene=cardpick"))
	assert_eq(GameState.card_level(&"tank"), 2)
	assert_eq(GameState.card_level(&"move_speed"), 1)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")

func test_parse_decodes_uri_escapes() -> void:
	assert_eq(DS.parse("?cards=tank%3A2").cards, {&"tank": 2})

func test_deferred_apply_runs_after_the_first_night_starts() -> void:
	var o = main.get_node("DebugOverlay")
	o._scene_query = DS.parse("?scene=cardpick")
	EventBus.phase_changed.connect(o._on_first_phase, CONNECT_ONE_SHOT)
	main.phase_controller.start_new_game(99)
	await get_tree().process_frame
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	assert_eq(main.world.wave_director.state, WaveDirector.State.IDLE)
