extends GutTest
## E5 spec 6.4: boss night banner, retry keeps the payment, the tier-up dawn, the reveal delay.

var main: Main
var banners: Array = []
var offered: Array = []

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	banners.clear()
	offered.clear()
	EventBus.banner_requested.connect(_on_banner)
	EventBus.card_offered.connect(_on_offered)
	main.phase_controller.start_new_game(20260930)

func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.card_offered.disconnect(_on_offered)

func _on_banner(t: String) -> void: banners.append(t)
func _on_offered(o: Array) -> void: offered.append(o)

func _pay_and_close(extra := 0) -> void:
	main.phase_controller.debug_skip_to_day()
	var cost := GameState.tier_next_cost()
	GameState.add_gold(cost + extra)
	GameState.pay_into_tier(cost)
	banners.clear()
	offered.clear()
	main.phase_controller.debug_skip_to_night()

func _reveal_ticks() -> int:
	return int(ceil(Balance.data.tiers.tier_reveal_time * 60.0)) + 3

func test_boss_night_is_announced_and_planned() -> void:
	_pay_and_close()
	assert_true(GameState.is_boss_night())
	assert_true(banners.has(tr("The Boar King comes")), str(banners))
	assert_true(main.phase_controller.snapshot.boss_pending, "the close-up snapshot carries the pending boss")

func test_normal_night_has_no_boss_banner() -> void:
	main.phase_controller.debug_skip_to_day()
	banners.clear()
	main.phase_controller.debug_skip_to_night()
	assert_false(banners.has(tr("The Boar King comes")))

func test_lost_boss_night_restores_with_the_payment_kept() -> void:
	_pay_and_close(50)
	GameState.damage_diner(1e9)
	for i in int(ceil(Balance.ui.banner_time * 60.0)) + 3:
		await get_tree().physics_frame
	assert_eq(main.phase_controller.phase, Phase.DAY)
	assert_true(GameState.boss_pending, "still pending")
	assert_true(GameState.is_boss_night(), "the boss wave is back in the plan")
	assert_eq(GameState.tier, 1)
	assert_eq(GameState.night_fails, 1, "mercy counts the loss")
	assert_eq(GameState.gold, 50, "no refund")
	assert_eq(GameState.pay_into_tier(50), 0, "no double payment")
	assert_eq(GameState.gold, 50)

func test_won_boss_night_tiers_up_at_dawn_and_delays_the_card_pick() -> void:
	_pay_and_close()
	var day0 := GameState.day
	watch_signals(EventBus)
	main.phase_controller.debug_skip_to_day()  # runs the dawn as a win
	assert_eq([GameState.tier, GameState.tier_day, GameState.boss_pending], [2, day0 + 1, false])
	assert_signal_emitted(EventBus, "tier_reached")
	assert_true(GameState.buildings.has("tower_w"))
	assert_false(GameState.is_boss_night(), "the next plan has no boss")
	assert_eq(GameState.pressure(), 8)
	assert_eq(GameState.night_fails, 0)
	assert_true(main.phase_controller.reveal_pending)
	assert_eq(offered, [], "the card pick waits for the reveal")
	for i in _reveal_ticks():
		await get_tree().physics_frame
	assert_false(main.phase_controller.reveal_pending)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	assert_eq(offered.size(), 1)

func test_normal_dawn_has_no_delay_and_no_tier_up() -> void:
	main.phase_controller.debug_skip_to_day()
	assert_eq(GameState.tier, 1)
	assert_false(main.phase_controller.reveal_pending)

func test_resume_during_the_reveal_shows_tier_2_and_opens_the_pick() -> void:
	_pay_and_close()
	main.phase_controller.debug_skip_to_day()
	assert_true(main.phase_controller.reveal_pending)
	var mid := GameState.to_dict()  # what the tier_reached autosave wrote
	mid.resume_phase = "CARD_PICK"
	assert_false(mid.card_offer.is_empty(), "the offer was stashed before the reveal")
	assert_eq(SaveCodec.validate(mid, Balance.data), "")
	main.phase_controller.resume_from(mid)
	assert_eq(GameState.tier, 2)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	assert_false(main.phase_controller.reveal_pending, "no replay")
	assert_eq(offered.size(), 1, "the resume opened the pick")
	for i in _reveal_ticks():
		await get_tree().physics_frame
	assert_eq(offered.size(), 1, "the stale reveal timer opens no second pick")

func test_new_game_during_the_reveal_cancels_the_pick() -> void:
	_pay_and_close()
	main.phase_controller.debug_skip_to_day()
	main.phase_controller.start_new_game(7)
	assert_false(main.phase_controller.reveal_pending)
	for i in _reveal_ticks():
		await get_tree().physics_frame
	assert_eq(offered, [])
	assert_eq(main.phase_controller.dawn_substate, "")

func test_old_tier1_save_past_day_7_replans_at_the_cap_on_its_next_dawn() -> void:
	# Review Focus 1: a day-12 plan planned at day-12 pressure (as E1 wrote it) plays once, then the cap applies.
	var s := GameState.to_dict()
	s.day = 12
	s.lane_plan = LanePlanner.plan(s.run_seed, 12, Balance.data.wave, 1, 1, Balance.data.tiers)
	for w in s.lane_plan:
		w.main_count = 40  # test-only: an oversized old plan
	s.resume_phase = "NIGHT"
	main.phase_controller.resume_from(s)
	assert_eq(GameState.lane_plan[0].main_count, 40, "the saved night plays as saved")
	main.phase_controller.debug_skip_to_day()
	assert_eq(GameState.day, 13)
	assert_eq(GameState.pressure(), 7)
	assert_eq(GameState.lane_plan[0].main_count + GameState.lane_plan[0].side_count, WaveMath.total_count(7, 0, Balance.data.wave))

func test_top_tier_no_op_opens_the_pick_at_once() -> void:
	main.phase_controller.debug_skip_to_day()
	var top := TierEffects.top_tier(Balance.data.tiers)
	GameState.debug_set_tier(top, GameState.day)
	GameState.boss_pending = true  # test-only setup: a clamped save pending at the top tier
	GameState.lane_plan = LanePlanner.with_boss(GameState.lane_plan)  # test-only setup
	banners.clear()
	offered.clear()
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()
	assert_false(main.phase_controller.reveal_pending)
	assert_eq(GameState.tier, top)
	assert_false(GameState.boss_pending)
	# debug_skip_to_day closes the pick it finds open, so the pick's proof is the offer emitted on the same frame.
	assert_eq(offered.size(), 1, "the pick opened at once, no reveal")
	if not offered[0].is_empty():
		# With a non-empty offer, DAY is reachable only when debug_skip_to_day found the pick open and closed it.
		assert_eq(main.phase_controller.phase, Phase.DAY)
