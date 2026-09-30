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

func test_apply_grants_cards_and_opens_pick() -> void:
	DS.apply(main, DS.parse("?cards=tank:2,move_speed:1&scene=cardpick"))
	assert_eq(GameState.card_level(&"tank"), 2)
	assert_eq(GameState.card_level(&"move_speed"), 1)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
