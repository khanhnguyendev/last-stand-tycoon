class_name BranchBalance
extends Resource
## E5 tier-3 spec 3.5: the tower and fence branches chosen at level 3. Built by initializers (exports keep .tres as text).
## `tower("")` / `fence("")` are the unbranched level-3 stats, read live from BuildBalance (one source per number).

const TOWER_BRANCHES: Array[StringName] = [&"longbow", &"volley"]
const FENCE_BRANCHES: Array[StringName] = [&"stone", &"spike"]

@export var tower_branch_cost := 500
@export var fence_branch_cost := 300
@export var longbow: TowerBranchStats = BranchBalance._longbow()
@export var volley: TowerBranchStats = BranchBalance._volley()
@export var stone: FenceBranchStats = BranchBalance._stone()
@export var spike: FenceBranchStats = BranchBalance._spike()
## E6 RETUNE SET (D-283, D-286, D-292, spec 4.1): read ONLY through BranchMath.longbow_kind_mult(s) / tower_interval / spike_pass_base,
## which pick it by the retune flag. Removed with the old set at the E6 cleanup. Stone wall and Volley have no new value.
## Longbow damage x this by the kind of the monster it hits (an absent kind = 1.0; no entry for the Baron or the Boar King).
@export var longbow_kind_mult_retune: Dictionary[StringName, float] = {&"brute": 2.0}
## Tuning round 1 (D-292, author pre-authorized): the lane-type bench forced two values.
## Longbow interval 2.4 s (old set: 3.0 on `longbow`). On the hare lane the Longbow lost 2313 diner HP against the unbranched
## tower's 1693 at every kind multiplier (2 to 4) and every damage (120 to 240); only the interval moves it. At 2.4 s: siege 412,
## hare 1387, neutral 202; 2.6 s fails the floor. Damage 120, range 9.98 and the brute multiplier 2.0 are unchanged.
@export var longbow_interval_retune := 2.4
## Spike pass damage at scale 1.0 (old set: 10.0 on `spike`); tuning range 12 to 24. Its scaling and the thorns are unchanged.
## Tuning round 1 (D-292): 24 (first retune set: 16); hare 855 against the Stone wall's 1355.
@export var spike_pass_damage_retune := 24.0

static func _tower(range_m: float, damage: float, interval: float, count: int) -> TowerBranchStats:
	var s := TowerBranchStats.new()
	s.attack_range = range_m
	s.damage = damage
	s.interval = interval
	s.count = count
	return s

static func _longbow() -> TowerBranchStats:
	return BranchBalance._tower(9.98, 120.0, 3.0, 1)

static func _volley() -> TowerBranchStats:
	return BranchBalance._tower(8.0, 10.0, 0.5, 3)

static func _stone() -> FenceBranchStats:
	var s := FenceBranchStats.new()
	s.hp = 640.0
	s.damage_taken_mult_by_kind[&"brute"] = 0.5
	return s

static func _spike() -> FenceBranchStats:
	var s := FenceBranchStats.new()
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
func tower(branch_id: StringName) -> TowerBranchStats:
	assert(branch_id == &"" or is_tower_branch(branch_id), "no tower branch %s" % branch_id)
	match branch_id:
		&"longbow":
			return longbow
		&"volley":
			return volley
	var b: BuildBalance = Balance.data.build
	var top := b.max_level - 1
	return BranchBalance._tower(b.tower_range[top], b.tower_damage[top], b.tower_interval, 1)

func fence(branch_id: StringName) -> FenceBranchStats:
	assert(branch_id == &"" or is_fence_branch(branch_id), "no fence branch %s" % branch_id)
	match branch_id:
		&"stone":
			return stone
		&"spike":
			return spike
	var s := FenceBranchStats.new()
	s.hp = (Balance.data.build as BuildBalance).fence_hp[Balance.data.build.max_level - 1]
	return s
