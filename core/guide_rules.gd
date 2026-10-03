class_name GuideRules
extends RefCounted
## The Guide's rule table (S5 spec 6, D-213): the first rule, in order, whose predicate is true for a snapshot. Pure: the Guide
## builds the snapshot from the game; nothing here touches a scene.
## Snapshot keys: phase, day, hero_xz, walked, attack_range, boars [{xz, remaining, spawn_index, pos}], steaks [Vector3],
## carried, carry_capacity, freezer, counter, counter_capacity, gold, gold_pile, move_m, spots [{id, remaining, next_cost,
## pos}] in SPOT_IDS order, should_pulse.

## Keys of the on-screen text; the Guide wraps each in tr().
const TEXT := {
	&"move": "Drag to move", &"fight": "Stay close", &"grab": "Grab steaks", &"build": "Build here",
	&"collect": "Collect gold", &"take": "Take steaks", &"stock": "Stock counter", &"close": "Close up",
}

static func _result(rule: StringName, target: StringName = &"", pos := Vector3.ZERO) -> Dictionary:
	return {"rule_id": rule, "target_id": target, "target_position": pos}

static func evaluate(s: Dictionary) -> Dictionary:
	var phase: int = s.phase
	var day: int = s.day
	if phase == Phase.NIGHT and day == 1:
		return _night_one(s)
	if phase == Phase.DAY and day == 2:
		return _first_day(s)
	return _result(&"")

static func _night_one(s: Dictionary) -> Dictionary:
	if float(s.walked) < float(s.move_m):
		return _result(&"move")
	var boars: Array = s.boars
	if not boars.is_empty():
		var hero: Vector2 = s.hero_xz
		for b in boars:
			if hero.distance_to(b.xz) <= float(s.attack_range):
				return _result(&"")
		var pick: Dictionary = boars[0]
		for b in boars:
			if float(b.remaining) < float(pick.remaining) or (is_equal_approx(float(b.remaining), float(pick.remaining)) and int(b.spawn_index) < int(pick.spawn_index)):
				pick = b
		return _result(&"fight", &"boar", pick.pos)
	var steaks: Array = s.steaks
	if not steaks.is_empty() and int(s.carried) < int(s.carry_capacity):
		var hero2: Vector2 = s.hero_xz
		var best: Vector3 = steaks[0]
		var best_d := INF
		for st in steaks:
			var d := hero2.distance_to(Vector2(st.x, st.z))
			if d < best_d:
				best_d = d
				best = st
		return _result(&"grab", &"steak", best)
	return _result(&"")

static func _first_day(s: Dictionary) -> Dictionary:
	var spot := _build_spot(s)
	if not spot.is_empty():
		return _result(&"build", StringName(spot.id), spot.pos)
	if _collect(s):
		return _result(&"collect", &"gold_pile", MapLayout.to3(MapLayout.GOLD_PILE))
	if _take(s):
		return _result(&"take", &"freezer", MapLayout.to3(MapLayout.FREEZER_ZONE))
	if int(s.carried) > 0 and _room(s) > 0:
		return _result(&"stock", &"counter", MapLayout.to3(MapLayout.COUNTER_DROP))
	if bool(s.should_pulse):
		return _result(&"close", &"sign", MapLayout.to3(MapLayout.SIGN))
	return _result(&"")

## Some spot with 0 < remaining <= gold. A maxed spot (remaining -1) never qualifies.
static func _affordable_with(s: Dictionary, gold: int) -> bool:
	for sp in s.spots:
		if int(sp.remaining) > 0 and int(sp.remaining) <= gold:
			return true
	return false

## The affordable spot with the lowest next_cost; ties by SPOT_IDS order (the spots array order). Empty if none.
static func _build_spot(s: Dictionary) -> Dictionary:
	var best := {}
	for sp in s.spots:
		if int(sp.remaining) > 0 and int(sp.remaining) <= int(s.gold):
			if best.is_empty() or int(sp.next_cost) < int(best.next_cost):
				best = sp
	return best

static func _load(s: Dictionary) -> int:
	return mini(int(s.carry_capacity), mini(int(s.freezer), int(s.counter_capacity)))

static func _room(s: Dictionary) -> int:
	return int(s.counter_capacity) - int(s.counter)

static func _in_freezer(s: Dictionary) -> bool:
	return (s.hero_xz as Vector2).distance_to(MapLayout.FREEZER_ZONE) <= MapLayout.STATION_RADIUS

static func _take(s: Dictionary) -> bool:
	if int(s.freezer) <= 0 or _room(s) < _load(s):
		return false
	var carried := int(s.carried)
	return carried == 0 or (_in_freezer(s) and carried < mini(int(s.carry_capacity), _room(s)))

static func _collect(s: Dictionary) -> bool:
	if int(s.gold_pile) <= 0:
		return false
	var take := _take(s)
	if _affordable_with(s, int(s.gold) + int(s.gold_pile)) and not (_in_freezer(s) and take):
		return true
	return int(s.carried) == 0 and not take
