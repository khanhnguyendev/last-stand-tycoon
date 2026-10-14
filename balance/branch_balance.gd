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

static func _tower(range_m: float, damage: float, interval: float, count: int) -> TowerBranchStats:
	var s := TowerBranchStats.new()
	s.attack_range = range_m
	s.damage = damage
	s.interval = interval
	s.count = count
	return s

## E6 (D-283, D-292, D-297, spec 4.1): damage 120 x 2.0 against a brute (no entry for the other kinds), range 9.98 and an interval of 2.0 s.
## Tuning rounds 1 and 2 (D-297, tuning on real play under the D-292 pre-authorization; the lane-type bench of D-292 is the measuring tool, not the reason for 2.0 s):
## on the hare lane the Longbow lost 2313 diner HP against the unbranched tower's 1693 at every kind multiplier (2 to 4) and every damage (120 to 240);
## only the interval moves it. At 2.4 s: siege 412, hare 1387, neutral 202 (2.6 s fails the floor); at 2.2 s: siege 233, hare 1092, neutral 82;
## at the committed 2.0 s: siege 114, hare 828, neutral 0, all bench rules pass. (The pre-retune interval was 3.0 s.)
static func _longbow() -> TowerBranchStats:
	var s := BranchBalance._tower(9.98, 120.0, 2.0, 1)
	s.kind_mults[&"brute"] = 2.0
	return s

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
	s.pass_damage = 24.0  # E6 tuning round 1 (D-292): 24 (the pre-retune value was 10.0; first retune set: 16); hare 855 against the Stone wall's 1355. Tuning range 12 to 24.
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
