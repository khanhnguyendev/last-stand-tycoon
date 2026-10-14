class_name TierBot
extends UpgraderBot
## E5 spec 8.1: UpgraderBot that buys the tier-up before station levels and builds the yard towers once they exist
## (the yard towers, threatened lane first, also on a lane with no threat tonight).
## Day order: the planner's hauling, defense for tonight (tier-1 spots, the yard and south-west spots, then the branch pads by policy),
## the tier sign when the gold in hand finishes the payment, then stations, then close up. It never starts a payment it cannot finish.

## E5 tier 3 (Task 22): how it chooses a branch for each max-level building (spec 9.4, D-263.5): all_a (Longbow, Stone wall), all_b (Volley,
## Spike fence), mixed (towers A, fences B: the spec names the policy but not its mix; this is the fixed one), volley_stone (towers Volley, fences Stone wall) and threat (Stone wall and
## Longbow on a lane with a brute in tonight's plan, Spike fence and Volley elsewhere). With a non-empty lane character (tier 3) `threat`
## follows the character instead of tonight's plan (see `branch_choices`); `unbranched` is in REPORT_POLICIES below.
const POLICIES: Array[String] = ["all_a", "all_b", "mixed", "threat"]
## Report-only policy (Task 24 fix round: the 2 x 2 table of tower x fence). Kept out of POLICIES, which the fixtures (make_save) and sim 6 iterate over.
## `unbranched` (E6, D-283) buys no branch at all: the report's floor. It still buys everything else, and is not a skipped goal.
const REPORT_POLICIES: Array[String] = ["volley_stone", "unbranched"]

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
## E7 (D-310): false switches the no-far-walk rule off (the sweep's `--bot-rule=old` and the study's `--oldbot=1`, for before/after measurements). Shipped: true.
var keep_lane := true
## E7 (D-310): a zone-to-zone walk longer than this (metres, straight line between the two zone nodes) is a far walk.
const FAR_WALK_M := 9.0

func _init() -> void:
	graph = _make_graph(1)

## The graph of `tier` (create_for_bot) plus the station pads. UpgraderBot._init added its pads to the default graph, which this
## replaces; the four pad lines below repeat that _init (known duplication, upgrader untouched).
func _make_graph(tier: int) -> WaypointGraph:
	var g := WaypointGraph.create_for_bot(tier)  # the bot walks to the pads where they stand (MapLayout.BRANCH_PADS)
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

## E6 phase 4: with a lane character (tier 3) the hero's one-second rule ranks lanes by the enemies already breaching (see NaiveBot.pick_lane);
## otherwise it is today's rule. Reads the enemies' lane, position and path distance, as the bot already does.
func _pick_lane(lanes: Array, counts: Dictionary, wd: WaveDirector) -> String:
	var character := GameState.lane_character()
	if character.is_empty():
		return super._pick_lane(lanes, counts, wd)
	var breached := {}
	for lane in lanes:
		breached[lane] = 0
	for b in wd.alive_enemies():
		var lane := String(b.lane)
		var walks_past: bool = not (b.stats().priority as Array).has(&"fence_on_lane")  # the game's own test for hares and the Baron
		if enemy_breached(lane, float(b.dist), float(b.stats().reach), TargetProviders.fence_stop_dist(b) < INF, walks_past):
			breached[lane] += 1
	var picked := pick_lane(lanes, counts, breached, character)
	if keep_lane and goal.begins_with("zone_") and picked != "" and graph.nodes.has("zone_" + picked):
		var mine := goal.trim_prefix("zone_")
		if mine != picked and graph.nodes.has(goal):
			var dist := graph.position_of(goal).distance_to(graph.position_of("zone_" + picked))
			if keep_own_lane(mine, picked, counts, dist):
				return mine
	return picked

## Pure. E7 (D-310, review queue E6-3): the hero does not cross to the far side of the diner while its own lane has monsters. True when the hero, whose
## current zone goal is `mine`, keeps `mine` instead of walking to `picked`: `mine` has live enemies (`counts`), `picked` differs, and the zones are
## more than FAR_WALK_M apart (`dist_m`). Zone distances at tier 3 (straight line, MapLayout lane ends): sw-north 10.8, west-east 10.4, sw-east 9.5 are far;
## north-west and north-east 7.35, sw-west 5.7 are near. Only called with a lane character (tier 3).
static func keep_own_lane(mine: String, picked: String, counts: Dictionary, dist_m: float) -> bool:
	return picked != mine and int(counts.get(mine, 0)) > 0 and dist_m > FAR_WALK_M

## Pure. E7 sweep metric (FAR_WALKS): true when a hero goal change from the zone of `prev_lane` to the zone of `new_lane` is a far walk made while the previous lane
## had live enemies (`prev_live`). With the rule shipped (keep_lane) this is never true at a re-decision; the count is 0 by construction.
static func is_far_walk(prev_lane: String, new_lane: String, prev_live: int, dist_m: float) -> bool:
	return prev_lane != new_lane and prev_live > 0 and dist_m > FAR_WALK_M

## Where a fence-stopping kind of `reach` waits at the fence of `lane`: TargetProviders.fence_stop_dist returns this while the fence stands, but INF once
## it has fallen, so the bot keeps the formula (a test pins that the two agree for every lane and kind).
static func fence_stop_point(lane: String, reach: float) -> float:
	return MapLayout.path_length(lane) - MapLayout.FENCE_OFFSET_FROM_END - reach

## Pure: is an enemy of `lane`, `dist` along its path, breaching. At the diner (the end of the path, Boar.at_path_end) always. A kind that walks
## past fences (hares, the Baron) once it is past the fence line of its lane, whether the fence stands or has fallen. A fence-stopping kind once it
## is at or past its stop point of a FALLEN fence (`fence_standing` false, from TargetProviders.fence_stop_dist being INF): a boar held at a
## standing fence is not breaching. The stop point, not the line: the monsters held at a fence that has just fallen are the breach, one second
## before they cross the line.
static func enemy_breached(lane: String, dist: float, reach: float, fence_standing: bool, walks_past: bool) -> bool:
	var length := MapLayout.path_length(lane)
	if dist >= length - 1e-4:
		return true
	if walks_past:
		return dist >= length - MapLayout.FENCE_OFFSET_FROM_END
	return not fence_standing and dist >= fence_stop_point(lane, reach) - 1e-4

## Pure: {spot_id: branch id} for `spot_ids` under `policy`, from tonight's `plan` (a lane has a brute when composition_by_lane says so).
## E6 (spec 4.4, D-283): a non-empty lane `character` ({siege, hare}) makes `threat` read the run's lane character instead of the plan: a fence
## on the siege lane takes Stone wall, any other fence Spike fence; a tower covering the siege lane (also when it covers the hare lane too)
## takes Longbow, any other tower Volley. The same every day. An empty character is today's rule. `unbranched` chooses nothing ({}).
static func branch_choices(p_policy: String, spot_ids: Array, plan: Array, tier := 3, character := {}) -> Dictionary:
	assert(p_policy in POLICIES or p_policy in REPORT_POLICIES, "unknown policy " + p_policy)  # the sweep runner validates --policy and exits 2 before any bot exists
	var out := {}
	if p_policy == "unbranched":
		return out
	var comp := LanePlanner.composition_by_lane(plan, tier)
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
					if not character.is_empty():
						if LaneCharacter.lane_type(character, String(l)) == LaneCharacter.SIEGE:
							a = true
					elif int(comp.get(l, {}).get("brute", 0)) > 0:
						a = true
		out[id] = opts[0] if a else opts[1]
	return out

## Pure: `spot_ids` ordered for the buyer of every branch policy when the run has a lane character (E6, D-297): (1) towers covering the siege lane, (2) towers covering the hare lane,
## (3) the siege lane's fence, (4) the hare lane's fence, (5) the rest. A spot is in the first group that fits; inside a group the input order stays.
static func marked_lane_order(spot_ids: Array, character: Dictionary) -> Array:
	var siege := String(character.get("siege", ""))
	var hare := String(character.get("hare", ""))
	var groups: Array = [[], [], [], [], []]
	for id in spot_ids:
		var tower := MapLayout.spot_kind(id) == "tower"
		var lanes: Array = MapLayout.tower_lanes(id) if tower else [MapLayout.fence_lane(id)]
		if tower and siege in lanes:
			groups[0].append(id)
		elif tower and hare in lanes:
			groups[1].append(id)
		elif not tower and siege in lanes:
			groups[2].append(id)
		elif not tower and hare in lanes:
			groups[3].append(id)
		else:
			groups[4].append(id)
	var out: Array = []
	for g in groups:
		out.append_array(g)
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
	if policy == "unbranched":
		return ""  # the report's floor: no branch is a goal, so none is a skipped goal either
	var character := GameState.lane_character()
	var choices := branch_choices(policy, spots, GameState.lane_plan, GameState.tier, character)
	if not character.is_empty():  # E6 (D-297): a player reads the lane badges and buys for the marked lanes first, whatever the branch policy
		spots.assign(marked_lane_order(spots, character))
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
