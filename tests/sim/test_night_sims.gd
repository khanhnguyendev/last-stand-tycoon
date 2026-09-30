extends GutTest
## Spec 13.4 night-1 rows (D-056, D-058, D-085, D-043). Thresholds only (D-105).

const SEED := 20260930
var h: SimHarness

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)

func after_each() -> void:
	h.finish()

func test_first_combat_within_30s() -> void:
	h.start(SEED, NaiveBot)
	await h.run_until(func(): return h.first_combat_s >= 0.0, 40.0)
	gut.p("first combat at %.2f s (on paper ~12 s from NIGHT1_START, D-126)" % h.first_combat_s)
	assert_between(h.first_combat_s, 0.0, Balance.data.sim.first_combat_max_s)

func test_night1_naive_bot_holds() -> void:
	h.start(SEED, NaiveBot)
	var r := await h.run_night()
	gut.p("night1 naive: %s" % r)
	assert_true(r.cleared, "night 1 must be cleared")
	assert_true(r.diner_frac >= Balance.data.sim.night1_win_min, "diner %.2f" % r.diner_frac)

func test_night1_parked_bot_falls() -> void:
	h.start(SEED, ParkedBot)
	var r := await h.run_night()
	gut.p("night1 parked: %s" % r)
	assert_true(r.failed, "parking must not be a strategy (D-056)")

func test_first_combat_idle_player_within_30s() -> void:
	# D-126: a new player who never touches the joystick still meets wave 0 at the start point.
	h.start(SEED, BotBase)  # base bot: no think(), the hero stays at NIGHT1_START
	await h.run_until(func(): return h.first_combat_s >= 0.0, 40.0)
	gut.p("idle first combat at %.2f s" % h.first_combat_s)
	assert_between(h.first_combat_s, 0.0, Balance.data.sim.first_combat_max_s)

func test_night1_fail_restarts_night() -> void:
	h.start(SEED, ParkedBot)
	var snap: Dictionary = h.main.phase_controller.snapshot.duplicate(true)
	var r := await h.run_night()
	assert_true(r.failed, "ParkedBot must fall")
	assert_true(await h.run_until(func(): return not h.main.phase_controller.failing, 5.0), "restore fired")
	assert_eq(h.main.phase_controller.phase, Phase.NIGHT)
	var now := GameState.to_dict()
	now.resume_phase = snap.resume_phase
	snap.night_fails = 1  # the night-1 retry carries one mercy step (S3 spec 6)
	assert_eq(now, snap)
	var t0 := h.elapsed
	await h.run_until(func(): return h.main.world.wave_director.state == WaveDirector.State.ACTIVE, 10.0)
	assert_almost_eq(h.elapsed - t0, Balance.data.wave.first_wave_delay, 3.0 / 60.0)

func test_night1_deterministic() -> void:
	var results: Array = []
	for run in 2:
		Balance.reset()
		var hh := SimHarness.new(self)
		hh.start(SEED, NaiveBot)
		var plan := GameState.lane_plan.duplicate(true)
		var r := await hh.run_night()
		r["plan"] = plan
		r["steaks"] = GameState.freezer_steaks + GameState.carried_steaks
		results.append(r)
		hh.finish()
		await get_tree().process_frame
	gut.p("determinism: %s" % [results])
	assert_eq(results[0], results[1])

func test_parked_retry_has_mercy_hp() -> void:
	h.start(SEED, ParkedBot)
	var r := await h.run_night()
	assert_true(r.failed)
	assert_true(await h.run_until(func(): return not h.main.phase_controller.failing, 5.0))
	assert_eq(GameState.night_fails, 1)
	await h.run_until(func(): return h.main.world.wave_director.alive_enemies().size() > 0, 15.0)
	var b: Boar = h.main.world.wave_director.alive_enemies()[0]
	assert_almost_eq(b.health.max_hp, Balance.data.enemy.hp * float(GameState.lane_plan[0].hp_mult) * GameState.mercy_factor(), 1e-4)
	assert_lt(b.health.max_hp, Balance.data.enemy.hp * float(GameState.lane_plan[0].hp_mult), "lower spawn HP on the retry")
