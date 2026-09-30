class_name SaveCodec
extends RefCounted
## The save envelope (S3 spec 4, D-172): a checksum over the raw state JSON, a migration hook, content validation.

const FORMAT := 1
const RESUME_PHASES := ["NIGHT", "DAY", "CARD_PICK"]
const STATE_KEYS := ["v", "resume_phase", "run_seed", "day", "gold", "gold_pile", "freezer_steaks",
	"counter_steaks", "carried_steaks", "diner_hp", "buildings", "lane_plan", "cards", "card_offer", "guards",
	"night_fails"]
## from_version (int) -> Callable(state: Dictionary) -> Dictionary. Empty at ship (no older disk saves exist).
static var MIGRATIONS := {}

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
	if typeof(state) != TYPE_DICTIONARY or not state.has("v"):
		out.reason = "json"
		return out
	var v := int(state.v)
	if v > current_v:
		out.reason = "version"
		out.newer = true
		return out
	while v < current_v:
		if not MIGRATIONS.has(v):
			out.reason = "version"
			return out
		state = MIGRATIONS[v].call(state)
		v = int(state.v)
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
			return "missing %s" % k
	if not String(s.resume_phase) in RESUME_PHASES:
		return "resume_phase"
	for k in ["buildings", "cards", "guards"]:
		if typeof(s[k]) != TYPE_DICTIONARY:
			return "type %s" % k
	for k in ["lane_plan", "card_offer"]:
		if typeof(s[k]) != TYPE_ARRAY:
			return "type %s" % k
	for id in s.buildings:
		if not String(id) in MapLayout.SPOT_IDS:
			return "building %s" % id
		if typeof(s.buildings[id]) != TYPE_DICTIONARY or not s.buildings[id].has_all(["level", "paid", "hp"]):
			return "building fields %s" % id
		for f in ["level", "paid", "hp"]:
			if not typeof(s.buildings[id][f]) in [TYPE_INT, TYPE_FLOAT]:
				return "building field type %s" % id
	for id in MapLayout.SPOT_IDS:
		if not s.buildings.has(id):
			return "missing building %s" % id
	if s.lane_plan.size() != bd.wave.base_counts.size():
		return "lane_plan"
	for w in s.lane_plan:
		if typeof(w) != TYPE_DICTIONARY or not w.has_all(["main", "side", "main_count", "side_count", "hp_mult"]):
			return "lane_plan fields"
	var max_level := bd.cards.max_level
	for id in s.cards:
		if not StringName(id) in CardCatalog.IDS:
			return "card %s" % id
		if not typeof(s.cards[id]) in [TYPE_INT, TYPE_FLOAT]:
			return "level type %s" % id
		var l := int(s.cards[id])
		if l < 0 or l > max_level:
			return "level %s" % id
	for id in s.card_offer:
		if not StringName(id) in CardCatalog.IDS:
			return "offer %s" % id
	for id in s.guards:
		if not StringName(id) in CardCatalog.ADVENTURERS:
			return "guard %s" % id
		if typeof(s.guards[id]) != TYPE_DICTIONARY or not s.guards[id].has("hp") \
				or not typeof(s.guards[id].hp) in [TYPE_INT, TYPE_FLOAT]:
			return "guard fields %s" % id
	if String(s.resume_phase) == "CARD_PICK":
		if s.card_offer.is_empty():
			return "empty offer"
		for id in s.card_offer:
			if int(s.cards.get(String(id), 0)) >= max_level:
				return "maxed offer"
	return ""
