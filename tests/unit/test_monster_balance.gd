extends GutTest
## E5 spec 4.3: one stats table per kind; the boar's is a view of EnemyBalance (one source per number).

func before_each() -> void:
	Balance.reset()

func test_kinds() -> void:
	assert_eq(Array(MonsterBalance.KINDS), [&"boar", &"hare", &"boss", &"brute", &"baron"])

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
func test_kind_class_maps_the_baron_to_the_hare_and_the_rest_to_themselves() -> void:
	assert_eq(MonsterBalance.kind_class(&"baron"), &"hare")
	for kind in [&"boar", &"hare", &"brute", &"boss", &"no_such_kind"]:
		assert_eq(MonsterBalance.kind_class(kind), kind, "%s is its own class" % kind)
