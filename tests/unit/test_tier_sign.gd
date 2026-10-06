extends GutTest
## E5 spec 7.2: the tier sign's states, payment and night hiding.

var main: Main
var sign: TierSign

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	sign = main.world.tier_sign
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame

func test_sells_the_yards_by_day_and_hides_at_night() -> void:
	var cost := GameState.tier_next_cost()
	assert_gt(cost, 0)
	assert_eq(sign.state(), &"selling")
	assert_true(sign.label.visible)
	assert_true(sign.marker.visible, "the marker shows while selling by day")
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(cost))
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.TIER_SIGN)))
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	assert_false(sign.label.visible)
	assert_false(sign.marker.visible, "no marker at night")
	assert_false(sign.zone.ring.visible)

func test_standing_still_pays_and_completes() -> void:
	var cost := GameState.tier_next_cost()
	GameState.add_gold(cost + 100)
	var held := GameState.gold
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	var ticks := 0
	while not GameState.boss_pending and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	assert_true(GameState.boss_pending, "paid in full within 20 s")
	assert_eq(GameState.gold, held - cost)
	assert_eq(sign.state(), &"boss")
	assert_eq(sign.label.text, tr("Boss tonight"), "Review Focus 2: the label flips on the completing tick")
	assert_false(sign.zone.ring.visible)
	assert_false(sign.marker.visible, "no marker in the boss state")
	var g := GameState.gold
	for i in 30:
		await get_tree().physics_frame
	assert_eq(GameState.gold, g, "Review Focus 2: no more gold is taken")
	assert_eq(sign.label.text, tr("Boss tonight"))

func test_partial_payment_shows_on_the_ring_and_survives_a_restore() -> void:
	var cost := GameState.tier_next_cost()
	var offer := cost / 4
	GameState.add_gold(offer)
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	var ticks := 0
	while GameState.gold > 0 and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	assert_eq(GameState.gold, 0, "the offer was taken within 20 s")
	assert_eq(GameState.tier_paid, offer)
	assert_true(sign.zone.ring.visible)
	assert_almost_eq(sign.zone.ring.progress, float(offer) / float(cost), 1e-6)
	var d := GameState.to_dict()
	GameState.new_game(3)
	await get_tree().physics_frame
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(cost), "a fresh game starts unpaid")
	assert_false(sign.zone.ring.visible)
	GameState.from_dict(d)
	await get_tree().physics_frame
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(cost - offer))
	assert_true(sign.zone.ring.visible, "the restore redraws the ring")
	assert_almost_eq(sign.zone.ring.progress, float(offer) / float(cost), 1e-6)

func test_walking_through_pays_nothing() -> void:
	GameState.add_gold(100)
	main.hero.teleport(MapLayout.TIER_SIGN + Vector2(0, 3.0))
	for i in 90:
		main.hero.input.set_move(Vector2(0, -1))
		await get_tree().physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	assert_lt(main.hero.xz().y, MapLayout.TIER_SIGN.y - MapLayout.STATION_RADIUS, "the hero crossed the whole zone")
	assert_eq(GameState.gold, 100)

func test_standing_on_the_sign_at_night_pays_nothing() -> void:
	GameState.add_gold(GameState.tier_next_cost())
	var held := GameState.gold
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	for i in 90:
		await get_tree().physics_frame
	assert_eq(GameState.gold, held)
	assert_eq(GameState.tier_paid, 0)

func test_hidden_at_the_top_tier() -> void:
	GameState.debug_set_tier(TierEffects.top_tier(Balance.data.tiers), GameState.day)
	await get_tree().physics_frame
	assert_eq(sign.state(), &"hidden")
	assert_false(sign.label.visible)
	assert_false(sign.visible)
