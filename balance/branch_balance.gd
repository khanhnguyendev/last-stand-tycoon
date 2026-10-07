class_name BranchBalance
extends Resource
## E5 tier-3 spec 3.5: the tower and fence branches chosen at level 3. Built by initializers (exports keep .tres as text).
## `tower("")` / `fence("")` are the unbranched level-3 stats, read live from BuildBalance (one source per number).

class TowerStats:
	extends Resource
	@export var attack_range := 8.0
	## Damage of ONE projectile.
	@export var damage := 18.0
	@export var interval := 0.5
	## Projectiles per attack, each at a different target (the first `count` of Targeting.select's order).
	@export var count := 1

class FenceStats:
	extends Resource
	@export var hp := 320.0
	## Damage taken x this, by the attacker's kind (absent kind = 1.0).
	@export var damage_taken_mult_by_kind: Dictionary = {}
	## Damage dealt back to the attacker on each hit the fence takes, at spike scale 1.0.
	@export var thorn_damage := 0.0
	## Damage dealt once to a monster of a `pass_kinds` kind crossing the fence's line, at spike scale 1.0.
	@export var pass_damage := 0.0
	@export var pass_kinds: Array[StringName] = []

const TOWER_BRANCHES: Array[StringName] = [&"longbow", &"volley"]
const FENCE_BRANCHES: Array[StringName] = [&"stone", &"spike"]

@export var tower_branch_cost := 500
@export var fence_branch_cost := 300
@export var longbow: TowerStats = BranchBalance._longbow()
@export var volley: TowerStats = BranchBalance._volley()
@export var stone: FenceStats = BranchBalance._stone()
@export var spike: FenceStats = BranchBalance._spike()

static func _tower(range_m: float, damage: float, interval: float, count: int) -> TowerStats:
	var s := TowerStats.new()
	s.attack_range = range_m
	s.damage = damage
	s.interval = interval
	s.count = count
	return s

static func _longbow() -> TowerStats:
	return BranchBalance._tower(9.98, 120.0, 3.0, 1)

static func _volley() -> TowerStats:
	return BranchBalance._tower(8.0, 10.0, 0.5, 3)

static func _stone() -> FenceStats:
	var s := FenceStats.new()
	s.hp = 640.0
	s.damage_taken_mult_by_kind = {&"brute": 0.5}
	return s

static func _spike() -> FenceStats:
	var s := FenceStats.new()
	s.hp = 320.0
	s.thorn_damage = 6.0
	s.pass_damage = 10.0
	s.pass_kinds = [&"hare", &"baron"]
	return s

func is_tower_branch(id: StringName) -> bool:
	return id in TOWER_BRANCHES

func is_fence_branch(id: StringName) -> bool:
	return id in FENCE_BRANCHES

## The stats of a tower branch; `&""` = the unbranched level 3 (a fresh object each call, built from the live BuildBalance).
func tower(branch_id: StringName) -> TowerStats:
	assert(branch_id == &"" or is_tower_branch(branch_id), "no tower branch %s" % branch_id)
	match branch_id:
		&"longbow":
			return longbow
		&"volley":
			return volley
	var b: BuildBalance = Balance.data.build
	var top := b.max_level - 1
	return BranchBalance._tower(b.tower_range[top], b.tower_damage[top], b.tower_interval, 1)

func fence(branch_id: StringName) -> FenceStats:
	assert(branch_id == &"" or is_fence_branch(branch_id), "no fence branch %s" % branch_id)
	match branch_id:
		&"stone":
			return stone
		&"spike":
			return spike
	var s := FenceStats.new()
	s.hp = (Balance.data.build as BuildBalance).fence_hp[Balance.data.build.max_level - 1]
	return s
