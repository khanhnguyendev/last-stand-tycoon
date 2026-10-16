extends GutTest
## E5 spec 4.3: one stats table per kind; the boar's is a view of EnemyBalance (one source per number).

func before_each() -> void:
	Balance.reset()

func test_kinds() -> void:
	assert_eq(Array(MonsterBalance.KINDS), [&"boar", &"hare", &"boss", &"brute", &"baron", &"wrecker"])

func test_boar_view_equals_enemy_balance() -> void:
	var eb := Balance.data.enemy
	var s := Balance.data.monsters.stats(&"boar")
	assert_eq([s.hp, s.speed, s.damage, s.attack_interval, s.reach], [eb.hp, eb.speed, eb.damage, eb.attack_interval, eb.reach])
	assert_eq(s.steaks_per_kill, Balance.data.economy.steaks_per_kill)
	assert_eq(s.drop_scatter, eb.drop_scatter)
	assert_eq(Array(s.priority), Array(Balance.data.wave.target_priority.kinds))

func test_boar_view_follows_a_mutation() -> void:
	var eb := Balance.data.enemy
	eb.speed = 9.0
	eb.hp = 61.0
	eb.damage = 7.0
	eb.attack_interval = 1.5
	eb.reach = 2.25
	eb.drop_scatter = 1.75
	Balance.data.economy.steaks_per_kill = 4
	var s := Balance.data.monsters.stats(&"boar")
	assert_eq([s.speed, s.hp, s.damage, s.attack_interval, s.reach, s.drop_scatter, s.steaks_per_kill], [9.0, 61.0, 7.0, 1.5, 2.25, 1.75, 4], "every field of the boar's view follows its source")

func test_hare_and_boss_spec_values() -> void:
	var h := Balance.data.monsters.stats(&"hare")
	assert_eq([h.hp, h.speed, h.damage, h.attack_interval, h.reach, h.steaks_per_kill], [15.0, 3.6, 4.0, 1.0, 1.2, 2])
	assert_eq(Array(h.priority), [&"guard", &"diner"])
	var b := Balance.data.monsters.stats(&"boss")
	assert_eq([b.hp, b.speed, b.damage, b.attack_interval, b.reach, b.steaks_per_kill], [800.0, 1.2, 15.0, 1.0, 1.6, 100])
	assert_eq(Array(b.priority), [&"fence_on_lane", &"guard", &"diner"])
	assert_eq(b.drop_scatter, 2.5)

func test_unknown_kind_is_rejected() -> void:
	assert_false(Balance.data.monsters.has_kind(&"dragon"))
	assert_true(Balance.data.monsters.has_kind(&"hare"))

## E8 (D-314.10): the Baron meets branch multipliers as a hare; every other kind (and an unknown one) as itself.
func test_kind_class_maps_the_baron_to_the_hare_the_wrecker_to_the_brute_and_the_rest_to_themselves() -> void:
	assert_eq(MonsterBalance.kind_class(&"baron"), &"hare")
	assert_eq(MonsterBalance.kind_class(&"wrecker"), &"brute")
	for kind in [&"boar", &"hare", &"brute", &"boss", &"no_such_kind"]:
		assert_eq(MonsterBalance.kind_class(kind), kind, "%s is its own class" % kind)

## E8 phase 2 Task 2 (spec 4.2, B4): the Wrecker's numbers, literal.
func test_the_wreckers_values() -> void:
	var w := Balance.data.monsters.stats(&"wrecker")
	var brute := Balance.data.monsters.stats(&"brute")
	var king := Balance.data.monsters.stats(&"boss")
	assert_eq([w.hp, w.damage, w.attack_interval, w.speed, w.reach, w.fence_damage_mult], [1080.0, 15.0, 1.0, 1.2, 1.2, 12.0])
	assert_eq(w.hp, brute.hp * 4.5, "4.5 times the brute's 240 (6 times in round 1; E8 phase-2 round 2: 1440 -> 1080)")
	assert_eq(w.fence_damage_mult, brute.fence_damage_mult * 3.0, "3 times the brute's 4")
	assert_eq([w.damage / w.attack_interval], [king.damage / king.attack_interval], "the Boar King's diner damage per second")
	assert_eq([w.steaks_per_kill, w.drop_scatter], [king.steaks_per_kill, king.drop_scatter])
	assert_eq(Array(w.priority), Array(brute.priority), "the brute's target order")
	assert_eq(w.reach, brute.reach)
	assert_eq(w.speed, brute.speed)

## The brute's class: a Longbow does 240 (120 x its brute multiplier 2.0), a Stone wall halves its hits, a Spike takes 4x.
func test_the_wrecker_meets_the_brutes_branch_multipliers() -> void:
	var bb := Balance.data.branches
	var w := Balance.data.monsters.stats(&"wrecker")
	var cls := MonsterBalance.kind_class(&"wrecker")
	assert_eq(cls, &"brute")
	assert_eq(float(bb.longbow.kind_mults.get(cls, 1.0)), float(bb.longbow.kind_mults.get(&"brute", 1.0)))
	assert_almost_eq(bb.longbow.damage * float(bb.longbow.kind_mults.get(cls, 1.0)), 240.0, 1e-6, "a Longbow arrow does 240 to a Wrecker")
	assert_eq(float(bb.stone.damage_taken_mult_by_kind.get(cls, 1.0)), 0.5, "a Stone wall halves its hits")
	assert_eq(float(bb.spike.damage_taken_mult_by_kind.get(cls, 1.0)), 4.0, "a Spike takes 4x")
	var fh := BranchMath.fence_hold_seconds(640, w, bb.stone, &"wrecker")
	assert_eq(fh, BranchMath.fence_hold_seconds(640, w, bb.stone, &"brute"), "a Wrecker is held by a Stone wall as a brute is")
	assert_eq(BranchMath.pass_damage(bb.spike, &"wrecker", 1.0), 0.0, "a Spike wall does no pass damage to a Wrecker")

## Sim 2's rule as arithmetic (spec 4.2), measured as sim 2 does (tests/unit/test_baron.gd): from the first hit on the diner to the hit that fells it,
## (ceil(diner_max_hp / damage) - 1) * attack_interval. The damage does not scale with hp_mult, so the cap multiplier only changes its HP.
func _hold_s(w: MonsterStats) -> float:
	var hits := int(ceil(Balance.data.build.diner_max_hp / w.damage))
	return (hits - 1) * w.attack_interval

func test_the_wrecker_alone_holds_the_diner_for_the_minimum() -> void:
	var w := Balance.data.monsters.stats(&"wrecker")
	var hold := _hold_s(w)
	assert_almost_eq(hold, 19.0, 1e-9, "ceil(300 / 15) = 20 hits, the 20th 19 intervals after the first")
	assert_gte(hold, Balance.data.tiers.boss_min_hold_s)

## Recorded mutations: damage 21 (15 hits, 14 s) and damage 20 (15 hits, 14 s) are under the 15 s minimum, so the rule must catch them.
func test_the_hold_rule_catches_a_stronger_wrecker() -> void:
	var w: MonsterStats = Balance.data.monsters.stats(&"wrecker").duplicate()
	w.damage = 21.0
	assert_lt(_hold_s(w), Balance.data.tiers.boss_min_hold_s)
	w.damage = 20.0
	assert_eq(_hold_s(w), 14.0, "ceil(300 / 20) = 15 hits, 14 intervals")
	assert_lt(_hold_s(w), Balance.data.tiers.boss_min_hold_s)
	w.damage = 15.0
	w.attack_interval = 0.7
	assert_lt(_hold_s(w), Balance.data.tiers.boss_min_hold_s)
