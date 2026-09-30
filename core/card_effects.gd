class_name CardEffects
extends RefCounted
## Card levels -> the stats in effect (S2 spec 4.2, D-167). Pure: base values, levels and balance in; value out.

static func level_of(levels: Dictionary, id: StringName) -> int:
	return int(levels.get(id, 0))

static func hero_damage(base: float, levels: Dictionary, cb: CardBalance) -> float:
	return base * (1.0 + cb.damage_step * level_of(levels, &"hero_damage"))

static func hero_attack_interval(base: float, levels: Dictionary, cb: CardBalance) -> float:
	return base / (1.0 + cb.attack_speed_step * level_of(levels, &"attack_speed"))

static func hero_move_speed(base: float, levels: Dictionary, cb: CardBalance) -> float:
	return base * (1.0 + cb.move_step * level_of(levels, &"move_speed"))

static func carry_capacity(base: int, levels: Dictionary, cb: CardBalance) -> int:
	return base + cb.carry_step * level_of(levels, &"carry_capacity")

static func gold_per_steak(base: int, levels: Dictionary, cb: CardBalance) -> int:
	return base + cb.gold_step * level_of(levels, &"gold_per_steak")

## A guard's stats at level >= 1: base x (1 + growth x (level - 1)).
static func guard_stats(id: StringName, level: int, gb: GuardBalance) -> Dictionary:
	assert(level >= 1, "guard_stats needs level >= 1")
	var s := gb.stats(id)
	var k := float(level - 1)
	return {
		"max_hp": s.max_hp * (1.0 + s.hp_growth * k),
		"damage": s.damage * (1.0 + s.damage_growth * k),
		"interval": s.interval,
		"range": s.attack_range,
		"projectile_speed": s.projectile_speed,
		"body_radius": s.body_radius,
		"walk_speed": s.walk_speed,
		"respawn_s": s.respawn_s,
		"targetable": s.targetable,
		"on_roof": s.on_roof,
	}
