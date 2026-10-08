extends GutTest
## Debug overlay: the ?autoplay= and ?policy= URL flags pick the self-play bot (the web-only branch of DebugOverlay.setup is
## reduced to the pure autoplay_args(flags); _attach_autoplay is what setup defers).

var DO = load("res://ui/debug/debug_overlay.gd")

func test_autoplay_1_picks_the_plain_bot() -> void:
	assert_eq(DO.autoplay_args(UrlFlags.parse("?autoplay=1")), ["res://ui/debug/autoplay.gd", ""])

func test_autoplay_tier_picks_the_tier_bot_with_the_given_policy() -> void:
	assert_eq(DO.autoplay_args(UrlFlags.parse("?autoplay=tier&policy=volley_stone")), ["res://ui/debug/autoplay_tier.gd", "volley_stone"])
	assert_eq(DO.autoplay_args(UrlFlags.parse("?autoplay=tier")), ["res://ui/debug/autoplay_tier.gd", "threat"], "the default policy is threat")

func test_no_autoplay_flag_attaches_nothing() -> void:
	assert_eq(DO.autoplay_args(UrlFlags.parse("?policy=mixed")), [])
	assert_eq(DO.autoplay_args(UrlFlags.parse("?autoplay=0")), [])

func test_the_overlay_attaches_autoplay_tier_with_the_policy() -> void:
	Balance.reset()
	var main: Main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(99)
	var o = main.get_node("DebugOverlay")
	var args: Array = DO.autoplay_args(UrlFlags.parse("?autoplay=tier&policy=all_b"))
	o._attach_autoplay(args[0], args[1])
	var bot: Node = main.get_node("Autoplay")
	assert_eq(bot.get_script().resource_path, "res://ui/debug/autoplay_tier.gd")
	assert_eq(bot.policy, "all_b")
	main.remove_child(bot)
	bot.free()
	var bad = DO.autoplay_args(UrlFlags.parse("?autoplay=tier&policy=nonsense"))
	o._attach_autoplay(bad[0], bad[1])
	var bot2: Node = main.get_node("Autoplay")
	assert_eq(bot2.policy, "threat", "an unknown policy falls back to threat")
	main.remove_child(bot2)
	bot2.free()
