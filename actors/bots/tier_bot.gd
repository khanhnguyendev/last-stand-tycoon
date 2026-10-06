class_name TierBot
extends UpgraderBot
## E5 spec 8.1: UpgraderBot that buys the tier-up before station levels and builds the yard towers once they exist.
## Day order: the planner's hauling, defense for tonight (tier-1 spots, then the yard towers), the tier sign when the
## gold in hand finishes the payment, then stations, then close up. It never starts a payment it cannot finish.

var tier_ups := 0
var boss_nights_won := 0

func _init() -> void:
	# The tier-2 graph (the sign and the yard spots reachable). UpgraderBot._init added its pads to the default
	# graph, which this replaces; the four pad lines below repeat that _init (known duplication, upgrader untouched).
	graph = WaypointGraph.create_for_tier(2)
	graph.add_node("pad_counter", MapLayout.STATION_PADS[&"counter"])
	graph.add_edge("pad_counter", "front_e")
	graph.add_edge("pad_counter", "home")
	graph.add_node("pad_freezer", MapLayout.STATION_PADS[&"freezer"])
	graph.add_edge("pad_freezer", "se")
	graph.add_edge("pad_freezer", "freezer")

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
	if goal == "tier_sign" and arrived() and GameState.tier_paid > 0 and GameState.gold > 0 \
			and GameState.tier_remaining_cost() > 0:
		return
	# the same for a yard tower spot (the planner's check covers SPOT_IDS only)
	if goal in GameState.buildings and not goal in MapLayout.SPOT_IDS and arrived() \
			and int(GameState.buildings[goal].paid) > 0 and GameState.gold > 0 \
			and GameState.remaining_cost(goal) > 0:
		return
	super.day_think(delta)

## The tier-up when the gold in hand finishes it, else the upgrader's cheapest station level, else the sign.
func idle_goal() -> String:
	var rem := GameState.tier_remaining_cost()
	if rem > 0 and rem <= GameState.gold:
		return "tier_sign"
	return super.idle_goal()

## Defense first, exactly the planner's over the tier-1 spots. Only when it has nothing: the yard spots the planner
## does not know. An unbuilt affordable one by lane threat, else the cheapest affordable upgrade.
func next_purchase() -> String:
	var p := super.next_purchase()
	if p != "":
		return p
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var best := ""
	var best_t := 0.0
	for id in MapLayout.ALL_SPOT_IDS:
		if id in MapLayout.SPOT_IDS or not GameState.buildings.has(id):
			continue
		if int(GameState.buildings[id].level) != 0 or GameState.remaining_cost(id) > GameState.gold:
			continue
		var t := _spot_threat(id, threat)
		if best == "" or t > best_t + 1e-6:  # ties keep the earlier in ALL_SPOT_IDS order
			best = id
			best_t = t
	if best != "":
		return best
	var best_rem := 0
	for id in MapLayout.ALL_SPOT_IDS:
		if id in MapLayout.SPOT_IDS or not GameState.buildings.has(id) or int(GameState.buildings[id].level) < 1:
			continue
		var rem := GameState.remaining_cost(id)
		if rem > 0 and rem <= GameState.gold and (best == "" or rem < best_rem):
			best = id
			best_rem = rem
	return best
