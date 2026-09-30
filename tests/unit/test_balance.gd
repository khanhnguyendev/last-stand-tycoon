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
	assert_eq(Array(d.wave.target_priority.kinds), [&"fence_on_lane", &"diner"])
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
