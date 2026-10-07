class_name MonsterBalance
extends Resource
## E5 spec 4.3: the hare and the boss as resources; the boar is read from EnemyBalance (one source per number).

const KINDS: Array[StringName] = [&"boar", &"hare", &"boss", &"brute", &"baron"]

@export var hare: MonsterStats = MonsterBalance._hare()
@export var boss: MonsterStats = MonsterBalance._boss()
## E5 tier 3 (spec 3.4). The brute keeps the Boar's reach and target order (a test pins both to EnemyBalance and the
## wave target priority); the baron is the hare's rules at boss scale.
@export var brute: MonsterStats = MonsterBalance._brute()
@export var baron: MonsterStats = MonsterBalance._baron()

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

static func _brute() -> MonsterStats:
	var s := MonsterStats.new()
	s.hp = 240.0
	s.speed = 1.2
	s.damage = 8.0
	s.attack_interval = 1.0
	s.reach = 1.2
	s.steaks_per_kill = 8
	s.drop_scatter = 0.8
	s.priority = [&"fence_on_lane", &"guard", &"diner"]
	s.fence_damage_mult = 4.0
	return s

static func _baron() -> MonsterStats:
	var s := MonsterStats.new()
	s.hp = 500.0
	s.speed = 2.4
	s.damage = 12.0
	s.attack_interval = 1.0
	s.reach = 1.6
	s.steaks_per_kill = 150
	s.drop_scatter = 2.5
	s.priority = [&"guard", &"diner"]
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
		&"brute":
			return brute
		&"baron":
			return baron
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
