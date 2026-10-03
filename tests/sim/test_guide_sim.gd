extends GutTest
## S5 spec 9: a bot that follows only the Guide clears night 1 and builds on day 2 (Review: the 0-fail `fight` assertion
## is never weakened). Two seeds: the canonical one and the first whose night-1 waves 1 and 2 are not north.

const SEED_A := 20260930
var h: SimHarness
var _violations: Array = []
var _fight_checks := 0
var _move_seen := false
var _move_cleared := false
var _t0 := 0

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_violations = []
	_fight_checks = 0
	_move_seen = false
	_move_cleared = false
	_t0 = Time.get_ticks_msec()

func after_each() -> void:
	h.finish()
	gut.p("timing: %.1f s wall" % ((Time.get_ticks_msec() - _t0) / 1000.0))

func _second_seed() -> int:
	for s in range(1, 1001):
		var pl := LanePlanner.plan(s, 1, Balance.data.wave)
		if pl[1].main != "north" and pl[2].main != "north":
			return s
	return -1

func _on_evaluated() -> void:
	var g := h.guide
	if g.rule_id == &"move":
		_move_seen = true
	elif _move_seen:
		_move_cleared = true
	if not _move_cleared or h.main.phase_controller.failing or h.main.phase_controller.phase != Phase.NIGHT:
		return
	var wd := h.main.world.wave_director
	var alive := wd.alive_enemies()
	if alive.is_empty():
		return
	var r := Balance.data.hero.attack_range
	for b in alive:
		var p: Vector3 = (b as Node3D).global_position
		if Vector2(p.x, p.z).distance_to(h.main.hero.xz()) <= r:
			return
	_fight_checks += 1
	if g.rule_id != &"fight":
		_violations.append("t=%.1f rule=%s diner=%.0f hero=%s boars=%d" % [h.elapsed, g.rule_id, GameState.diner_hp, h.main.hero.xz(), alive.size()])

func _play(p_seed: int) -> void:
	h.start(p_seed, GuideBot, true)
	h.guide.evaluated.connect(_on_evaluated)
	var r := await h.run_night()
	gut.p("seed %d night1: %s (move walked %.1f m, fight checks %d)" % [p_seed, r, h.guide.walked, _fight_checks])
	assert_true(r.cleared, "night 1 cleared (seed %d)" % p_seed)
	assert_false(r.failed, "night 1 not failed (seed %d)" % p_seed)
	assert_true(_move_cleared, "move cleared")
	assert_eq(_violations.size(), 0, "0-fail fight rule: %s" % [_violations.slice(0, 5)])
	# the day: a no-rule gap over 5 s only with steaks still on the counter
	var gap := 0.0
	var bad := 0
	var cond := func() -> bool:
		if h.main.phase_controller.phase == Phase.DAY and h.guide.rule_id == &"":
			gap += 1.0 / 60.0
			if gap > 5.0 and GameState.counter_steaks <= 0:
				bad += 1
		else:
			gap = 0.0
		return h.main.phase_controller.phase == Phase.NIGHT
	var closed := await h.run_until(cond, 600.0)
	assert_true(closed, "the day closed (seed %d)" % p_seed)
	assert_eq(bad, 0, "no 5 s no-rule gap with an empty counter")
	var built := 0
	for id in MapLayout.SPOT_IDS:
		if int(GameState.buildings[id].level) >= 1:
			built += 1
	gut.p("seed %d day2 done at %.1f sim s, spots built %d" % [p_seed, h.elapsed, built])
	assert_gt(built, 0, "at least one spot built by night 2")
	assert_true(h.main.settings_store.guide_done, "night 2 completed the Guide")

func test_guide_bot_canonical_seed() -> void:
	await _play(SEED_A)

func test_guide_bot_second_seed() -> void:
	var s := _second_seed()
	gut.p("second seed: %d" % s)
	assert_gt(s, 0, "a seed with non-north waves 1 and 2 exists")
	await _play(s)
