extends GutTest
## PINNED REFERENCE: asserts the spec 12 defaults on purpose. Task 35 updates these rows (and spec 12)
## in the same commit as any tuned value. Every other test derives its numbers from Balance.

func before_each() -> void:
	Balance.reset()

func test_spec_values_loaded() -> void:
	var d: BalanceData = Balance.data
	assert_eq(d.hero.attack_range, 4.0)
	assert_eq(d.hero.carry_capacity, 6)
	assert_eq(d.enemy.hp, 30.0)
	assert_eq(Array(d.wave.base_counts), [4, 6, 8])
	assert_eq(Array(d.wave.target_priority.kinds), [&"fence_on_lane", &"guard", &"diner"])
	assert_eq(d.economy.steaks_per_kill, 2)
	assert_eq(d.economy.gold_per_steak, 3)
	assert_eq(Array(d.build.tower_damage), [8.0, 12.0, 18.0])
	assert_eq(d.build.diner_max_hp, 300.0)
	assert_eq(d.build.fence_hp.size(), d.build.max_level)
	assert_eq(d.build.tower_damage.size(), d.build.max_level)
	assert_eq(d.build.tower_range.size(), d.build.max_level)
	assert_eq(d.sim.night2_comfort_min, 0.60)
	assert_eq(Balance.ui.camera_fov_h, 42.0)
	assert_eq(Balance.ui.edge_ignore_px, 16.0)

func test_reset_discards_mutation() -> void:
	Balance.data.hero.attack_range = 99.0
	Balance.reset()
	assert_eq(Balance.data.hero.attack_range, 4.0)

func test_inject_replaces_data() -> void:
	var d := BalanceData.new()
	d.hero.move_speed = 1.0
	Balance.inject(d)
	assert_eq(Balance.data.hero.move_speed, 1.0)
	Balance.reset()

func test_inject_ui_semantics() -> void:
	var d := BalanceData.new()
	var u := UiTuning.new()
	u.camera_fov_h = 1.0
	Balance.inject(d, u)
	assert_eq(Balance.ui.camera_fov_h, 1.0)
	var before := Balance.ui
	Balance.inject(BalanceData.new())
	assert_same(Balance.ui, before)
	Balance.reset()

func test_s2_card_balance_defaults() -> void:
	var c := Balance.data.cards
	assert_eq([c.max_level, c.offer_size, c.carry_step, c.gold_step], [5, 3, 2, 1])
	assert_almost_eq(c.damage_step, 0.20, 1e-6)
	assert_almost_eq(c.attack_speed_step, 0.15, 1e-6)
	assert_almost_eq(c.move_step, 0.08, 1e-6)

func test_s2_guard_balance_defaults() -> void:
	var a := Balance.data.guards.archer
	var t := Balance.data.guards.tank
	assert_eq([a.targetable, a.on_roof, t.targetable, t.on_roof], [false, true, true, false])
	assert_eq([a.damage, a.damage_growth, a.interval, a.attack_range, a.projectile_speed, a.body_radius],
		[4.0, 0.30, 0.6, 9.0, 16.0, 0.4])
	assert_eq([t.max_hp, t.hp_growth, t.damage, t.damage_growth, t.interval, t.attack_range, t.projectile_speed,
		t.body_radius, t.walk_speed, t.respawn_s], [160.0, 0.35, 5.0, 0.25, 0.8, 2.5, 60.0, 0.45, 3.0, 3.0])
	assert_eq(Balance.data.guards.stats(&"archer"), a)
	assert_eq(Balance.data.guards.stats(&"tank"), t)

func test_s2_thresholds_and_ui() -> void:
	assert_eq([Balance.data.sim.break_day_target, Balance.data.sim.break_day_tolerance], [10, 1])
	assert_almost_eq(Balance.ui.card_input_guard_s, 0.5, 1e-6)
	assert_eq(Balance.ui.card_panel_size, Vector2(560, 220))
	assert_almost_eq(Balance.ui.card_panel_gap, 24.0, 1e-6)
	assert_almost_eq(Balance.ui.card_panel_min_h, 120.0, 1e-6)

func test_s2_reset_deep_copies_guard_stats() -> void:
	Balance.data.guards.tank.max_hp = 1.0
	Balance.reset()
	assert_eq(Balance.data.guards.tank.max_hp, 160.0, "D-157: sub-resources built by initializers survive reset")

func test_s3_tuning_defaults() -> void:
	assert_almost_eq(Balance.data.wave.mercy_step, 0.15, 1e-6)
	assert_almost_eq(Balance.data.wave.mercy_floor, 0.40, 1e-6)
	assert_almost_eq(Balance.ui.banner_min_s, 0.6, 1e-6)
	assert_gt(Balance.ui.banner_time, 0.0)
	assert_gt(Balance.ui.banner_min_s, 0.0)
	assert_almost_eq(Balance.ui.autosave_interval_s, 3.0, 1e-6)
