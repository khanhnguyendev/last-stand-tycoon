class_name PlannerBot
extends NaiveBot
## NaiveBot at night; by day: haul and sell everything, collect gold, then build/upgrade by tonight's
## telegraph (spec 13.3, D-067), then close up. Drives only through HeroInput (BotBase.go_to).

## Card preference (D-168): the Tank first (its post is on a lane with one tower), then the Archer, then upgrades.
const CARD_PREFERENCE: Array[StringName] = [&"tank", &"archer", &"hero_damage", &"attack_speed",
	&"gold_per_steak", &"carry_capacity", &"move_speed"]

func choose_card(offer: Array) -> StringName:
	for id in CARD_PREFERENCE:
		if id in offer:
			return id
	return offer[0]

func day_think(_delta: float) -> void:
	var cap := GameState.carry_capacity()
	var counter_cap := GameState.counter_capacity()
	# keep loading / unloading until the stack or the station is done
	if goal == "freezer" and GameState.freezer_steaks > 0 and GameState.carried_steaks < cap:
		return
	if goal == "counter_drop" and GameState.carried_steaks > 0 and GameState.counter_steaks < counter_cap:
		return
	# keep standing on a spot that is mid-payment (each tick drains gold, so the affordability check below
	# would flip before the level completes); only once arrived, so a walk is never held by it
	if goal in MapLayout.SPOT_IDS and arrived() and int(GameState.buildings[goal].paid) > 0 \
			and GameState.gold > 0 and GameState.remaining_cost(goal) > 0:
		return
	if GameState.carried_steaks > 0 and GameState.counter_steaks < counter_cap:
		go_to("counter_drop")
	elif GameState.freezer_steaks > 0 and GameState.carried_steaks < cap:
		go_to("freezer")
	elif GameState.gold_pile > 0:
		go_to("gold_pile")
	elif GameState.counter_steaks > 0 or GameState.carried_steaks > 0:
		go_to("counter_drop")  # wait for travelers
	else:
		var spot := next_purchase()
		go_to(spot if spot != "" else "sign")

## The spot id to build or upgrade next with the gold in hand, or "" (spec 13.3, D-067, D-154).
## 1 fence on the top side lane (side lanes ranked by their side-group threat, count x hp_mult; first in
## lane order on ties); 2 the tower next to it (for north, the one with the higher threat); 3 more fences and any unbuilt tower, by the
## threat on their lanes (a tower scores the max of its two lanes); 4 upgrades next to the top-threat lane.
## Ties by lane order / SPOT_IDS order, never by float equality.
func next_purchase() -> String:
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var side := {"west": 0.0, "north": 0.0, "east": 0.0}
	for w in GameState.lane_plan:
		if String(w.side) != "":
			side[w.side] += int(w.side_count) * float(w.hp_mult)
	var side_lane := ""
	for l in LanePlanner.LANES:
		if side[l] > 0.0 and (side_lane == "" or side[l] > side[side_lane]):
			side_lane = l
	# steps 1-2
	var builds: Array = []
	if side_lane != "":
		builds.append(MapLayout.LANE_FENCE[side_lane])
		var tower := ""
		for t in ["tower_nw", "tower_ne"]:  # SPOT_IDS order; a strictly higher threat replaces
			if side_lane in MapLayout.TOWER_LANES[t] and (tower == "" or _spot_threat(t, threat) > _spot_threat(tower, threat) + 1e-6):
				tower = t
		builds.append(tower)
	# step 3
	var rest: Array = []
	for id in MapLayout.SPOT_IDS:
		if not id in builds and _spot_threat(id, threat) > 0.0:
			rest.append(id)
	rest.sort_custom(func(a: String, b: String) -> bool:
		var ta := _spot_threat(a, threat)
		var tb := _spot_threat(b, threat)
		if not is_equal_approx(ta, tb):
			return ta > tb
		return MapLayout.SPOT_IDS.find(a) < MapLayout.SPOT_IDS.find(b))
	builds.append_array(rest)
	for id in builds:
		if int(GameState.buildings[id].level) == 0 and GameState.remaining_cost(id) <= GameState.gold:
			return id
	# step 4: upgrades; lanes by threat, and next to a lane the towers before the fences, the cheapest affordable of a kind
	var lanes: Array = LanePlanner.LANES.duplicate()
	lanes.sort_custom(func(a: String, b: String) -> bool:
		if not is_equal_approx(threat[a], threat[b]):
			return threat[a] > threat[b]
		return LanePlanner.LANES.find(a) < LanePlanner.LANES.find(b))  # ties by index order
	for l in lanes:
		if threat[l] <= 0.0:
			continue
		for kind in ["tower", "fence"]:  # towers first; within a kind the cheapest affordable
			var best := ""
			var best_rem := 0
			for id in MapLayout.SPOT_IDS:
				if MapLayout.spot_kind(id) != kind:
					continue
				var next_to: bool = (l in MapLayout.TOWER_LANES[id]) if kind == "tower" else (MapLayout.FENCE_LANE[id] == l)
				if not next_to or int(GameState.buildings[id].level) < 1:
					continue
				var rem := GameState.remaining_cost(id)
				if rem >= 0 and rem <= GameState.gold and (best == "" or rem < best_rem):
					best = id
					best_rem = rem
			if best != "":
				return best
	return ""

func _spot_threat(id: String, threat: Dictionary) -> float:
	if MapLayout.spot_kind(id) == "fence":
		return threat[MapLayout.FENCE_LANE[id]]
	var m := 0.0
	for l in MapLayout.TOWER_LANES[id]:
		m = maxf(m, threat[l])
	return m
