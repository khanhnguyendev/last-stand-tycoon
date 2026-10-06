class_name SaveCodec
extends RefCounted
## The save envelope (S3 spec 4, D-172): a checksum over the raw state JSON, a migration hook, content validation.

const FORMAT := 1
const RESUME_PHASES := ["NIGHT", "DAY", "CARD_PICK"]
const STATE_KEYS := ["v", "resume_phase", "run_seed", "day", "gold", "gold_pile", "freezer_steaks",
	"counter_steaks", "carried_steaks", "diner_hp", "buildings", "lane_plan", "cards", "card_offer", "guards",
	"night_fails", "stations", "tier", "tier_day", "tier_paid", "boss_pending"]
## from_version (int) -> Callable(state: Dictionary) -> Dictionary. A test hook: an entry here overrides the
## built-in step of the same version (_built_in). Tests may clear it freely.
static var MIGRATIONS := {}

static func fresh_stations() -> Dictionary:
	var out := {}
	for id in StationEffects.IDS:
		out[String(id)] = {"level": 0, "paid": 0}
	return out

## The shipped migrations. Returns null when `from_v` has no step.
static func _built_in(from_v: int, state: Dictionary) -> Variant:
	match from_v:
		3:  # E1: station upgrades
			state.stations = fresh_stations()
			state.v = 4
			return state
		4:  # E5: the diner tier. A tier-1 save keeps its day; its next dawn re-plans at the tier-1 cap (D-237).
			state.tier = 1
			state.tier_day = 1
			state.tier_paid = 0
			state.boss_pending = false
			for w in state.get("lane_plan", []):
				if typeof(w) == TYPE_DICTIONARY:
					w.fast_main = 0
					w.fast_side = 0
					w.boss = false
			state.v = 5
			return state
	return null

static func encode(state: Dictionary, build: String, now_unix: int) -> String:
	var sj := JSON.stringify(state, "", true, true)
	return JSON.stringify({"format": FORMAT, "saved_at_unix": now_unix, "build": build, "state_json": sj,
		"check": Rng.fnv1a32(sj)})

static func decode(text: String, current_v: int, bd: BalanceData) -> Dictionary:
	var out := {"ok": false, "reason": "", "state": {}, "newer": false}
	var env = _parse(text)
	if typeof(env) != TYPE_DICTIONARY or not env.has_all(["format", "state_json", "check"]) \
			or not typeof(env.format) in [TYPE_INT, TYPE_FLOAT] or not typeof(env.check) in [TYPE_INT, TYPE_FLOAT]:
		out.reason = "json"
		return out
	if int(env.format) != FORMAT:
		out.reason = "format"
		out.newer = int(env.format) > FORMAT
		return out
	if typeof(env.state_json) != TYPE_STRING or Rng.fnv1a32(env.state_json) != int(env.check):
		out.reason = "check"
		return out
	var state = _parse(env.state_json)
	if typeof(state) != TYPE_DICTIONARY or not state.has("v") or not typeof(state.v) in [TYPE_INT, TYPE_FLOAT]:
		out.reason = "json"
		return out
	var v := int(state.v)
	if v > current_v:
		out.reason = "version"
		out.newer = true
		return out
	while v < current_v:
		state = MIGRATIONS[v].call(state) if MIGRATIONS.has(v) else _built_in(v, state)
		if typeof(state) != TYPE_DICTIONARY or not typeof(state.get("v")) in [TYPE_INT, TYPE_FLOAT] \
				or int(state.get("v", v)) <= v:
			out.reason = "version"
			return out
		v = int(state.v)
	if v != current_v:
		out.reason = "version"
		return out
	if validate(state, bd) != "":
		out.reason = "content"
		return out
	out.ok = true
	out.state = state
	return out

## JSON.new().parse(): unlike JSON.parse_string, a bad text returns an error code without an engine error
## (GUT fails tests on engine errors).
static func _parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data

## "" when the state can be loaded without a crash or a soft-lock; otherwise what is wrong.
static func validate(s: Dictionary, bd: BalanceData) -> String:
	for k in STATE_KEYS:
		if not s.has(k):
			return "missing " + str(k)
	for k in ["v", "run_seed", "day", "gold", "gold_pile", "freezer_steaks", "counter_steaks", "carried_steaks",
			"diner_hp", "night_fails", "tier", "tier_day", "tier_paid"]:
		if not typeof(s[k]) in [TYPE_INT, TYPE_FLOAT]:
			return "type " + str(k)
	if int(s.night_fails) < 0 or int(s.day) < 1 or int(s.gold) < 0 or int(s.gold_pile) < 0:
		return "range"
	if typeof(s.boss_pending) != TYPE_BOOL:
		return "type boss_pending"
	var tier := int(s.tier)
	if tier < 1 or tier > bd.tiers.max_tier:
		return "range tier"
	if int(s.tier_day) < 1 or int(s.tier_day) > int(s.day):
		return "range tier_day"
	if int(s.tier_paid) < 0:
		return "range tier_paid"
	var known_tier := mini(tier, TierEffects.top_tier(bd.tiers))  # GameState clamps the tier on load (spec 6.3)
	if typeof(s.resume_phase) != TYPE_STRING:
		return "type resume_phase"
	if not String(s.resume_phase) in RESUME_PHASES:
		return "resume_phase"
	if float(s.diner_hp) < 0.0 or (String(s.resume_phase) == "NIGHT" and float(s.diner_hp) <= 0.0):
		return "range diner_hp"
	for k in ["freezer_steaks", "counter_steaks", "carried_steaks"]:
		if float(s[k]) < 0.0:
			return "range " + k
	for k in ["buildings", "cards", "guards", "stations"]:
		if typeof(s[k]) != TYPE_DICTIONARY:
			return "type " + str(k)
	for k in ["lane_plan", "card_offer"]:
		if typeof(s[k]) != TYPE_ARRAY:
			return "type " + str(k)
	for id in s.buildings:
		if not String(id) in MapLayout.ALL_SPOT_IDS:
			return "building " + str(id)
		if MapLayout.spot_tier(String(id)) > known_tier:
			return "building tier " + str(id)
		if typeof(s.buildings[id]) != TYPE_DICTIONARY or not s.buildings[id].has_all(["level", "paid", "hp"]):
			return "building fields " + str(id)
		for f in ["level", "paid", "hp"]:
			if not typeof(s.buildings[id][f]) in [TYPE_INT, TYPE_FLOAT]:
				return "building field type " + str(id)
		if float(s.buildings[id].paid) < 0.0 or float(s.buildings[id].hp) < 0.0:
			return "range building " + str(id)
		var bl := int(s.buildings[id].level)
		if bl < 0 or bl > bd.build.max_level:
			return "building level " + str(id)
	for id in MapLayout.spots_for_tier(known_tier):
		if not s.buildings.has(id):
			return "missing building " + str(id)
	for id in s.stations:
		if typeof(id) != TYPE_STRING or not StringName(id) in StationEffects.IDS:
			return "station " + str(id)
	for id in StationEffects.IDS:
		if not s.stations.has(String(id)):
			return "missing station " + str(id)
		var st = s.stations[String(id)]
		if typeof(st) != TYPE_DICTIONARY or not st.has_all(["level", "paid"]):
			return "station fields " + str(id)
		for f in ["level", "paid"]:
			if not typeof(st[f]) in [TYPE_INT, TYPE_FLOAT]:
				return "station field type " + str(id)
		if int(st.level) < 0 or float(st.paid) < 0.0:
			return "range station " + str(id)
	if s.lane_plan.size() != bd.wave.base_counts.size():
		return "lane_plan"
	for w in s.lane_plan:
		if typeof(w) != TYPE_DICTIONARY or not w.has_all(["main", "side", "main_count", "side_count", "hp_mult", "fast_main", "fast_side", "boss"]):
			return "lane_plan fields"
		if typeof(w.main) != TYPE_STRING or not String(w.main) in LanePlanner.LANES \
				or typeof(w.side) != TYPE_STRING or not (String(w.side) == "" or String(w.side) in LanePlanner.LANES):
			return "lane"
		for f in ["main_count", "side_count", "hp_mult"]:
			if not typeof(w[f]) in [TYPE_INT, TYPE_FLOAT]:
				return "lane fields"
			if float(w[f]) < 0.0:
				return "range " + f
		for f in ["fast_main", "fast_side"]:
			if not typeof(w[f]) in [TYPE_INT, TYPE_FLOAT] or float(w[f]) < 0.0:
				return "lane fields"
		if int(w.fast_main) > int(w.main_count) or int(w.fast_side) > int(w.side_count):
			return "lane fast"
		if typeof(w.boss) != TYPE_BOOL:
			return "lane fields"
	for i in s.lane_plan.size() - 1:
		if bool(s.lane_plan[i].boss):
			return "lane boss"
	var max_level := bd.cards.max_level
	for id in s.cards:
		if typeof(id) != TYPE_STRING or not StringName(id) in CardCatalog.IDS:
			return "card " + str(id)
		if not typeof(s.cards[id]) in [TYPE_INT, TYPE_FLOAT]:
			return "level type " + str(id)
		var l := int(s.cards[id])
		if l < 0 or l > max_level:
			return "level " + str(id)
	for id in s.card_offer:
		if typeof(id) != TYPE_STRING or not StringName(id) in CardCatalog.IDS:
			return "offer " + str(id)
	for id in s.guards:
		if typeof(id) != TYPE_STRING or not StringName(id) in CardCatalog.ADVENTURERS:
			return "guard " + str(id)
		if typeof(s.guards[id]) != TYPE_DICTIONARY or not s.guards[id].has("hp") \
				or not typeof(s.guards[id].hp) in [TYPE_INT, TYPE_FLOAT]:
			return "guard fields " + str(id)
		if float(s.guards[id].hp) < 0.0:
			return "range guard " + str(id)
	if String(s.resume_phase) == "CARD_PICK":
		if s.card_offer.is_empty():
			return "empty offer"
		for id in s.card_offer:
			if int(s.cards.get(String(id), 0)) >= max_level:
				return "maxed offer"
	return ""
