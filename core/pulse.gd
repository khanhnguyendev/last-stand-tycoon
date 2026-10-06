class_name Pulse
extends RefCounted
## Close-up sign pulse predicate (spec 8.8, D-068). `state` is a GameState.to_dict() dictionary.

static func should_pulse(state: Dictionary, bd: BalanceData) -> bool:
	for key in ["freezer_steaks", "carried_steaks", "counter_steaks", "gold_pile"]:
		if int(state[key]) != 0:
			return false
	var gold := int(state.gold)
	for spot_id in state.buildings:
		var b: Dictionary = state.buildings[spot_id]
		var cost := Economy.level_cost(spot_id, int(b.level), bd.build)
		if cost < 0:
			continue
		if gold >= cost - int(b.paid):
			return false
	# E1: an affordable station upgrade is something left to do. No `stations` key = none (the guide passes that).
	var stations: Dictionary = state.get("stations", {})
	for id in stations:
		var st: Dictionary = stations[id]
		var cost := StationEffects.level_cost(StringName(id), int(st.level), bd.stations)
		if cost >= 0 and gold >= cost - int(st.paid):
			return false
	# E5: an affordable tier-up is something left to do. No `tier` key = ignore the tier (the guide's view).
	if state.has("tier") and not bool(state.get("boss_pending", false)):
		var tcost := TierEffects.tier_cost(int(state.tier), bd.tiers)
		if tcost >= 0 and gold >= tcost - int(state.get("tier_paid", 0)):
			return false
	return true
