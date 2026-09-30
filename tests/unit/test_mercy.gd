extends GutTest

var main: Main
var pc: PhaseController

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	pc.start_new_game(61)
	main.hero.teleport(Vector2(15, 8))  # the hero must not kill the test boars

func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_night1_fail_adds_mercy_and_snapshots_it() -> void:
	watch_signals(EventBus)
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(GameState.night_fails, 1)
	assert_eq(int(pc.snapshot.night_fails), 1)
	assert_signal_emit_count(EventBus, "snapshot_taken", 1, "the night-1 retry re-emits its restore point")
	assert_signal_emitted_with_parameters(EventBus, "banner_requested", ["The monsters look tired tonight."])
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_eq(GameState.night_fails, 2)

func test_day_fail_carries_mercy_and_dawn_clears_it() -> void:
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(GameState.card_offer[0])
	watch_signals(EventBus)
	pc.close_up()
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_signal_emit_count(EventBus, "snapshot_taken", 1, "close_up emits; a DAY fail does not")
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.night_fails, 1)
	pc.close_up()
	EventBus.wave_cleared.emit(2)
	assert_eq(GameState.night_fails, 0, "a cleared night resets mercy")

func test_mercy_scales_boar_hp_and_damage() -> void:
	GameState.set_night_fails(1)
	var f := GameState.mercy_factor()
	var wd := main.world.wave_director
	wd.stop()
	var plan_boar: Boar = wd._spawn("north", 0.0)  # plan path (hp_mult <= 0)
	assert_almost_eq(plan_boar.health.max_hp, Balance.data.enemy.hp * float(GameState.lane_plan[0].hp_mult) * f, 1e-4)
	var debug_boar: Boar = wd.debug_spawn("north", 0.0, 1.0)
	assert_almost_eq(debug_boar.health.max_hp, Balance.data.enemy.hp, 1e-4, "debug_spawn stays exact")
	debug_boar.dist = debug_boar.path_length()
	debug_boar._update_position()
	var hp0 := GameState.diner_hp
	await _ticks(int(ceil(Balance.data.enemy.attack_interval * 60.0)) + 2)
	assert_almost_eq(hp0 - GameState.diner_hp, Balance.data.enemy.damage * f, 1e-4, "diner arm scaled")

func test_snapshot_taken_emits_a_copy() -> void:
	var got := []
	var cb := func(s: Dictionary) -> void:
		s.x = 1
		got.append(s)
	EventBus.snapshot_taken.connect(cb)
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(GameState.card_offer[0])
	pc.close_up()
	EventBus.snapshot_taken.disconnect(cb)
	assert_eq(got.size(), 1)
	assert_false(pc.snapshot.has("x"))

func test_fail_banner_sequence_end_to_end() -> void:
	GameState.damage_diner(1e6)
	var seen: Array = []
	var return_frames := 0
	var n := int(ceil((Balance.ui.banner_time * 2.0 + Balance.ui.banner_min_s) * 60.0)) + 30
	for i in n:
		await get_tree().process_frame
		if main.hud.banner.visible:
			var t: String = main.hud.banner.text
			if seen.is_empty() or seen[-1] != t:
				seen.append(t)
				if t == "The monsters return":
					return_frames = 0  # count only the last run (start_new_game shows one too)
			if t == "The monsters return":
				return_frames += 1
	assert_gte(seen.size(), 3, "sequence recorded")
	assert_eq(seen.slice(seen.size() - 3), ["The diner fell", "The monsters return", "The monsters look tired tonight."])
	assert_lte(return_frames, int(ceil(Balance.ui.banner_min_s * 60.0)) + 3, "monsters-return not held long")
