extends GutTest

var cb: CardBalance

func before_each() -> void:
	Balance.reset()
	cb = Balance.data.cards

func test_level_zero_is_base() -> void:
	var none := {}
	assert_eq(CardEffects.hero_damage(10.0, none, cb), 10.0)
	assert_eq(CardEffects.hero_attack_interval(0.5, none, cb), 0.5)
	assert_eq(CardEffects.hero_move_speed(5.0, none, cb), 5.0)
	assert_eq(CardEffects.carry_capacity(6, none, cb), 6)
	assert_eq(CardEffects.gold_per_steak(3, none, cb), 3)

func test_upgrades_at_every_level() -> void:
	for l in range(0, cb.max_level + 1):
		var m := cb.max_level + 1
		var lv := {&"hero_damage": l, &"attack_speed": (l + 1) % m, &"move_speed": (l + 2) % m,
			&"carry_capacity": (l + 3) % m, &"gold_per_steak": (l + 4) % m}
		assert_almost_eq(CardEffects.hero_damage(10.0, lv, cb), 10.0 * (1.0 + cb.damage_step * lv[&"hero_damage"]), 1e-5)
		assert_almost_eq(CardEffects.hero_attack_interval(0.5, lv, cb), 0.5 / (1.0 + cb.attack_speed_step * lv[&"attack_speed"]), 1e-5)
		assert_almost_eq(CardEffects.hero_move_speed(5.0, lv, cb), 5.0 * (1.0 + cb.move_step * lv[&"move_speed"]), 1e-5)
		assert_eq(CardEffects.carry_capacity(6, lv, cb), 6 + cb.carry_step * lv[&"carry_capacity"])
		assert_eq(CardEffects.gold_per_steak(3, lv, cb), 3 + cb.gold_step * lv[&"gold_per_steak"])

func test_guard_stats_scale_per_level() -> void:
	var gb := Balance.data.guards
	var t := gb.tank
	var a := gb.archer
	var t1 := CardEffects.guard_stats(&"tank", 1, gb)
	var t3 := CardEffects.guard_stats(&"tank", 3, gb)
	assert_almost_eq(t1.max_hp, t.max_hp, 1e-5)
	assert_almost_eq(t3.max_hp, t.max_hp * (1.0 + t.hp_growth * 2), 1e-4)
	assert_almost_eq(t3.damage, t.damage * (1.0 + t.damage_growth * 2), 1e-5)
	assert_eq([t3.interval, t3.range, t3.targetable, t3.on_roof], [t.interval, t.attack_range, true, false])
	assert_eq(t3.keys(), ["max_hp", "damage", "interval", "range", "projectile_speed", "body_radius", "walk_speed", "respawn_s", "targetable", "on_roof"])
	assert_eq([t3.projectile_speed, t3.body_radius, t3.walk_speed, t3.respawn_s], [t.projectile_speed, t.body_radius, t.walk_speed, t.respawn_s])
	var a5 := CardEffects.guard_stats(&"archer", 5, gb)
	assert_almost_eq(a5.damage, a.damage * (1.0 + a.damage_growth * 4), 1e-5)
	assert_eq([a5.range, a5.targetable, a5.on_roof], [a.attack_range, false, true])
