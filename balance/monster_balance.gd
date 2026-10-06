class_name MonsterBalance
extends Resource
## E5 spec 4.3: the hare and the boss as resources; the boar is read from EnemyBalance (one source per number).

const KINDS: Array[StringName] = [&"boar", &"hare", &"boss"]

@export var hare: MonsterStats = MonsterBalance._hare()
@export var boss: MonsterStats = MonsterBalance._boss()

static func _hare() -> MonsterStats:
	var s := MonsterStats.new()
	s.hp = 15.0
	s.speed = 3.6
	s.damage = 4.0
	s.attack_interval = 1.0
	s.reach = 1.2
	s.steaks_per_kill = 2
	s.drop_scatter = 0.6
	s.priority = [&"guard", &"diner"]
	return s

static func _boss() -> MonsterStats:
	var s := MonsterStats.new()
	s.hp = 800.0
	s.speed = 1.2
	s.damage = 15.0
	s.attack_interval = 1.0
	s.reach = 1.6
	s.steaks_per_kill = 100
	s.drop_scatter = 2.5
	s.priority = [&"fence_on_lane", &"guard", &"diner"]
	return s

func has_kind(kind: StringName) -> bool:
	return kind in KINDS

## The boar's view is built on every call from the live EnemyBalance, so a mutated value is seen at once.
func stats(kind: StringName) -> MonsterStats:
	assert(has_kind(kind), "unknown monster kind %s" % kind)
	match kind:
		&"hare":
			return hare
		&"boss":
			return boss
	var eb: EnemyBalance = Balance.data.enemy
	var s := MonsterStats.new()
	s.hp = eb.hp
	s.speed = eb.speed
	s.damage = eb.damage
	s.attack_interval = eb.attack_interval
	s.reach = eb.reach
	s.steaks_per_kill = Balance.data.economy.steaks_per_kill
	s.drop_scatter = eb.drop_scatter
	s.priority = Balance.data.wave.target_priority.kinds.duplicate()
	return s
