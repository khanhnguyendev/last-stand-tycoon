class_name GuardBalance
extends Resource
## Archer and Tank stats (S2 spec 8, D-163). Built by initializers: exports keep .tres as text (D-157).

@export var archer: GuardStats = GuardBalance._archer()
@export var tank: GuardStats = GuardBalance._tank()

func stats(id: StringName) -> GuardStats:
	assert(id == &"archer" or id == &"tank", "no guard stats for %s" % id)
	return archer if id == &"archer" else tank

static func _archer() -> GuardStats:
	var s := GuardStats.new()
	s.damage = 6.0
	s.damage_growth = 0.30
	s.interval = 0.6
	s.attack_range = 9.0
	s.projectile_speed = 16.0
	s.body_radius = 0.4
	s.targetable = false
	s.on_roof = true
	return s

static func _tank() -> GuardStats:
	var s := GuardStats.new()
	s.max_hp = 160.0
	s.hp_growth = 0.35
	s.damage = 5.0
	s.damage_growth = 0.25
	s.interval = 0.8
	s.attack_range = 2.5
	s.projectile_speed = 60.0  # melee: the same Attacker, a near-instant projectile
	s.body_radius = 0.45
	s.walk_speed = 3.0
	s.respawn_s = 3.0
	s.targetable = true
	s.on_roof = false
	return s
