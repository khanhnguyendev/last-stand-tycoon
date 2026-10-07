class_name TierBot
extends UpgraderBot
## E5 spec 8.1: UpgraderBot that buys the tier-up before station levels and builds the yard towers once they exist
## (the yard towers, threatened lane first, also on a lane with no threat tonight).
## Day order: the planner's hauling, defense for tonight (tier-1 spots, the yard and south-west spots, then the branch pads by policy),
## the tier sign when the gold in hand finishes the payment, then stations, then close up. It never starts a payment it cannot finish.

## E5 tier 3 (Task 22): how it chooses a branch for each max-level building (spec 9.4, D-263.5): all_a (Longbow, Stone wall), all_b (Volley,
## Spike fence), mixed (towers A, fences B: the spec names the policy but not its mix; this is the fixed one) volley_stone (towers Volley, fences Stone wall) and threat (Stone wall and
## Longbow on a lane with a brute in tonight's plan, Spike fence and Volley elsewhere).
const POLICIES: Array[String] = ["all_a", "all_b", "mixed", "threat"]
## Report-only policy (Task 24 fix round: the 2 x 2 table of tower x fence). Kept out of POLICIES, which the fixtures (make_save) and sim 6 iterate over.
const REPORT_POLICIES: Array[String] = ["volley_stone"]

var tier_ups := 0
var boss_nights_won := 0
var policy := "threat"
## Physics ticks the bot waits on an arrived branch pad for the payment to start (the stand-still is 1.5 s; this is 5 s). Past it the pad
## counts as one skipped goal and is not picked again today (a pad that never arms must not stall the run).
const PAD_WAIT_CAP_TICKS := 300
var _pad_wait := 0
var _blocked_pads := {}
var _blocked_day := -1
var _graph_tier := 1

func _init() -> void:
	graph = _make_graph(1)

## The graph of `tier` (create_for_bot) plus the station pads. UpgraderBot._init added its pads to the default graph, which this
## replaces; the four pad lines below repeat that _init (known duplication, upgrader untouched).
func _make_graph(tier: int) -> WaypointGraph:
	var g := WaypointGraph.create_for_bot(tier)
	g.add_node("pad_counter", MapLayout.STATION_PADS[&"counter"])
	g.add_edge("pad_counter", "front_e")
	g.add_edge("pad_counter", "home")
	g.add_node("pad_freezer", MapLayout.STATION_PADS[&"freezer"])
	g.add_edge("pad_freezer", "se")
	g.add_edge("pad_freezer", "freezer")
	return g

## The graph follows the tier (every old node keeps its name and position, so a goal and a route in progress stay valid).
func _sync_graph() -> void:
	var t := clampi(GameState.tier, 1, 3)
	if t != _graph_tier:
		_graph_tier = t
		graph = _make_graph(t)

func think(delta: float) -> void:
	_sync_graph()
	super.think(delta)

## Pure: {spot_id: branch id} for `spot_ids` under `policy`, from tonight's `plan` (a lane has a brute when composition_by_lane says so).
static func branch_choices(p_policy: String, spot_ids: Array, plan: Array, tier := 3) -> Dictionary:
	assert(p_policy in POLICIES or p_policy in REPORT_POLICIES, "unknown policy " + p_policy)  # the sweep runner validates --policy and exits 1 before any bot exists
	var comp := LanePlanner.composition_by_lane(plan, tier)
	var out := {}
	for id in spot_ids:
		var tower := MapLayout.spot_kind(id) == "tower"
		var opts: Array[StringName] = BranchBalance.TOWER_BRANCHES if tower else BranchBalance.FENCE_BRANCHES
		var lanes: Array = MapLayout.tower_lanes(id) if tower else [MapLayout.fence_lane(id)]
		var a := false
		match p_policy:
			"all_a":
				a = true
			"mixed":
				a = tower
			"volley_stone":  # towers Volley, fences Stone wall (the report's 2 x 2 table)
				a = not tower
			"threat":
				for l in lanes:
					if int(comp.get(l, {}).get("brute", 0)) > 0:
						a = true
		out[id] = opts[0] if a else opts[1]
	return out

## The pad goal name of `branch` at `spot_id` (the graph's `pad_<spot>_<a|b>`).
static func pad_goal(spot_id: String, branch: StringName) -> String:
	var opts: Array[StringName] = BranchBalance.TOWER_BRANCHES if MapLayout.spot_kind(spot_id) == "tower" else BranchBalance.FENCE_BRANCHES
	return "pad_%s_%s" % [spot_id, "ab"[opts.find(branch)]]

## [spot_id, branch id] of a branch pad goal, or [] for any other goal.
static func _pad_target(g: String) -> Array:
	if not g.begins_with("pad_") or not (g.ends_with("_a") or g.ends_with("_b")):
		return []
	var spot := g.trim_prefix("pad_").trim_suffix(g.right(2))
	if not spot in MapLayout.ALL_SPOT_IDS:
		return []
	var opts: Array[StringName] = BranchBalance.TOWER_BRANCHES if MapLayout.spot_kind(spot) == "tower" else BranchBalance.FENCE_BRANCHES
	return [spot, opts["ab".find(g.right(1))]]

func setup(m: Main) -> void:
	super.setup(m)
	EventBus.tier_paid_up.connect(_on_tier_paid_up)
	EventBus.tier_reached.connect(_on_tier_reached)

func _on_tier_paid_up(_next_tier: int) -> void:
	tier_ups += 1

func _on_tier_reached(_tier: int) -> void:
	boss_nights_won += 1

func day_think(delta: float) -> void:
	# keep standing on the sign mid-payment (gold and remaining cost fall together)
	if (goal == "tier_sign" or goal == "tier_sign_3") and arrived() and GameState.tier_paid > 0 and GameState.gold > 0 \
			and GameState.tier_remaining_cost() > 0:
		return
	# the same for a yard tower spot (the planner's check covers SPOT_IDS only)
	if goal in GameState.buildings and not goal in MapLayout.SPOT_IDS and arrived() \
			and int(GameState.buildings[goal].paid) > 0 and GameState.gold > 0 \
			and GameState.remaining_cost(goal) > 0:
		return
	# Standing on a branch pad. UpgraderBot reads every arrived "pad_*" goal as a station pad (and would index stations with the spot's
	# name), so it never sees one: hold while the payment runs, or while the stand-still before it ticks (the purchase is still the pick),
	# and drop the goal once the pad is done or the pick changed. A walk to a pad is left alone (the goal is kept, the route is not reset).
	var target := _pad_target(goal)
	if not target.is_empty() and arrived():
		var spot: String = target[0]
		var paying: bool = GameState.can_branch(spot) and GameState.gold > 0 \
				and int(GameState.buildings[spot].branch_paid.get(String(target[1]), 0)) > 0 and GameState.branch_remaining(spot, target[1]) > 0
		if paying:
			_pad_wait = 0
			return
		if GameState.can_branch(spot) and next_purchase() == goal:
			_pad_wait += 1
			if _pad_wait <= PAD_WAIT_CAP_TICKS:
				return
			skipped_goals += 1
			_blocked_pads[goal] = true
		_pad_wait = 0
		goal = ""
	super.day_think(delta)

## The tier-up when the gold in hand finishes it, else the upgrader's cheapest station level, else the sign.
## Rule (tiers 2 and 3 alike): this runs only when next_purchase() found nothing to build, so the gold in hand is what is left after
## the defense purchases; the sign is sought when the remaining cost is above 0 (not paid, not the top tier) and the gold covers it.
func idle_goal() -> String:
	_sync_graph()
	var rem := GameState.tier_remaining_cost()
	if rem > 0 and rem <= GameState.gold:
		return "tier_sign_3" if GameState.tier >= 2 else "tier_sign"
	return super.idle_goal()

## Defense first, exactly the planner's over the tier-1 spots. Only when it has nothing: the yard spots the planner
## does not know. An unbuilt affordable one by lane threat, else the cheapest affordable upgrade.
func next_purchase() -> String:
	_sync_graph()
	var p := super.next_purchase()
	if p != "":
		return p
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp, GameState.tier)
	var spots := MapLayout.spots_for_tier(GameState.tier)
	var best := ""
	var best_t := 0.0
	for id in spots:
		if id in MapLayout.SPOT_IDS or not GameState.buildings.has(id):
			continue
		if not graph.nodes.has(id):
			skipped_goals += 1
			continue
		if int(GameState.buildings[id].level) != 0 or GameState.remaining_cost(id) > GameState.gold:
			continue
		var t := _spot_threat(id, threat)
		if best == "" or t > best_t + 1e-6:  # ties keep the earlier in spots_for_tier order
			best = id
			best_t = t
	if best != "":
		return best
	var best_rem := 0
	for id in spots:
		if id in MapLayout.SPOT_IDS or not GameState.buildings.has(id) or int(GameState.buildings[id].level) < 1:
			continue
		if not graph.nodes.has(id):
			skipped_goals += 1
			continue
		var rem := GameState.remaining_cost(id)
		if rem > 0 and rem <= GameState.gold and (best == "" or rem < best_rem):
			best = id
			best_rem = rem
	if best != "":
		return best
	return _next_branch_pad()

## Tier 3: the pad (goal name) of the first max-level building of the tier, in spots_for_tier order, that can branch and whose
## chosen pad the gold in hand finishes (it never starts a payment it cannot finish). The branch is the policy's.
func _next_branch_pad() -> String:
	if GameState.tier < 3:
		return ""
	var spots := MapLayout.spots_for_tier(GameState.tier)
	if _blocked_day != GameState.day:
		_blocked_day = GameState.day
		_blocked_pads.clear()
	var choices := branch_choices(policy, spots, GameState.lane_plan, GameState.tier)
	for id in spots:
		if not GameState.can_branch(id):
			continue
		var pad := pad_goal(id, choices[id])
		if not graph.nodes.has(pad):
			skipped_goals += 1
			continue
		if _blocked_pads.has(pad):
			continue
		if GameState.branch_remaining(id, choices[id]) <= GameState.gold:
			return pad
	return ""
