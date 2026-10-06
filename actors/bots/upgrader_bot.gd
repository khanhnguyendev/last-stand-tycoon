class_name UpgraderBot
extends PlannerBot
## PlannerBot that spends what is left on station upgrades before closing up (E1 spec 5.6, D-230).
## Defense first: it only looks at the pads once the planner has no purchase for tonight.

func _init() -> void:
	# Its own graph: WaypointGraph.create_default() must stay as it is for the baseline bots.
	graph.add_node("pad_counter", MapLayout.STATION_PADS[&"counter"])
	graph.add_edge("pad_counter", "front_e")
	graph.add_edge("pad_counter", "home")
	graph.add_node("pad_freezer", MapLayout.STATION_PADS[&"freezer"])
	graph.add_edge("pad_freezer", "se")
	graph.add_edge("pad_freezer", "freezer")

func day_think(delta: float) -> void:
	# Defensive: keep standing on a pad that is mid-payment. While paying, the remaining cost and the gold fall
	# together, so idle_goal() cannot flip today.
	if goal.begins_with("pad_") and arrived():
		var id := StringName(goal.trim_prefix("pad_"))
		if int(GameState.stations[id].paid) > 0 and GameState.gold > 0 and GameState.station_remaining_cost(id) > 0:
			return
	super.day_think(delta)

## The cheapest station level the gold in hand can finish; ties go to the counter (IDS order).
func idle_goal() -> String:
	var best := ""
	var best_rem := 0
	for id in StationEffects.IDS:
		var rem := GameState.station_remaining_cost(id)
		if rem >= 0 and rem <= GameState.gold and (best == "" or rem < best_rem):
			best = "pad_%s" % id
			best_rem = rem
	return best if best != "" else "sign"
