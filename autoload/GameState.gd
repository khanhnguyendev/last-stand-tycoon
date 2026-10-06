extends Node
## The only mutable game data (spec 4, D-096). Only these methods change it; they emit EventBus signals.

const SCHEMA_VERSION := 5

var resume_phase := "NIGHT"
var run_seed := 0
var day := 1
var gold := 0
var gold_pile := 0
var freezer_steaks := 0
var counter_steaks := 0
var carried_steaks := 0
var diner_hp := 0.0
var buildings := {}
var lane_plan: Array = []
## S2: card levels (StringName -> int; missing = 0), the open dawn offer, and targetable guards' HP.
var cards := {}
var card_offer: Array[StringName] = []
var guards := {}
## Consecutive failures of the current night (S3 mercy, D-175).
var night_fails := 0
## E1: station upgrades (StringName -> {level, paid}). Empty until the first new_game.
var stations := {}
## E5: the diner tier (spec 6.1). tier_day = the day the tier was entered; tier_paid = the sign's partial payment;
## boss_pending = paid in full, the coming night is a boss night.
var tier := 1
var tier_day := 1
var tier_paid := 0
var boss_pending := false

func new_game(seed: int = 0) -> void:
	run_seed = seed if seed != 0 else Rng.new_run_seed()
	resume_phase = "NIGHT"
	day = 1
	gold = 0
	gold_pile = 0
	freezer_steaks = 0
	counter_steaks = 0
	carried_steaks = 0
	diner_hp = Balance.data.build.diner_max_hp
	tier = 1
	tier_day = 1
	tier_paid = 0
	boss_pending = false
	buildings = {}
	for id in MapLayout.spots_for_tier(tier):
		buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	stations = _fresh_stations()
	cards = {}
	card_offer = []
	guards = {}
	night_fails = 0
	lane_plan = _plan_today()
	EventBus.state_restored.emit()

# --- snapshot -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"v": SCHEMA_VERSION, "resume_phase": resume_phase, "run_seed": run_seed, "day": day,
		"gold": gold, "gold_pile": gold_pile, "freezer_steaks": freezer_steaks,
		"counter_steaks": counter_steaks, "carried_steaks": carried_steaks, "diner_hp": diner_hp,
		"buildings": buildings.duplicate(true), "lane_plan": lane_plan.duplicate(true),
		"cards": _string_keys(cards), "card_offer": card_offer.map(func(id): return String(id)),
		"guards": _guards_out(), "night_fails": night_fails,
		"stations": _stations_out(),
		"tier": tier, "tier_day": tier_day, "tier_paid": tier_paid, "boss_pending": boss_pending,
	}

func from_dict(d: Dictionary) -> void:
	assert(int(d.v) == SCHEMA_VERSION, "unknown snapshot schema")
	resume_phase = String(d.resume_phase)
	run_seed = int(d.run_seed)
	day = int(d.day)
	gold = int(d.gold)
	gold_pile = int(d.gold_pile)
	freezer_steaks = int(d.freezer_steaks)
	counter_steaks = int(d.counter_steaks)
	carried_steaks = int(d.carried_steaks)
	diner_hp = float(d.diner_hp)
	tier = clampi(int(d.tier), 1, TierEffects.top_tier(Balance.data.tiers))
	tier_day = int(d.tier_day)
	boss_pending = bool(d.boss_pending)
	var tcost := TierEffects.tier_cost(tier, Balance.data.tiers)
	# A paid amount at or above the cost would never complete (D-231's rule for pads); 0 at the top or while pending.
	tier_paid = 0 if (tcost < 0 or boss_pending) else clampi(int(d.tier_paid), 0, maxi(tcost - 1, 0))
	buildings = {}
	for id in d.buildings:
		var b: Dictionary = d.buildings[id]
		buildings[String(id)] = {"level": int(b.level), "paid": int(b.paid), "hp": float(b.hp)}
	stations = _fresh_stations()
	for id in StationEffects.IDS:
		var st: Dictionary = d.stations[String(id)]
		var level := clampi(int(st.level), 0, Balance.data.stations.max_level)
		var cost := StationEffects.level_cost(id, level, Balance.data.stations)
		# A paid amount at or above the cost would never complete (pay_into_station pays cost - paid): clamp it.
		stations[id] = {"level": level, "paid": 0 if cost < 0 else clampi(int(st.paid), 0, maxi(cost - 1, 0))}
	lane_plan = []
	for w in d.lane_plan:
		lane_plan.append({
			"main": String(w.main), "side": String(w.side),
			"main_count": int(w.main_count), "side_count": int(w.side_count), "hp_mult": float(w.hp_mult),
			# E5: hares and the boss ride in the plan; a wave saved before E5 has none.
			"fast_main": int(w.get("fast_main", 0)), "fast_side": int(w.get("fast_side", 0)), "boss": bool(w.get("boss", false)),
		})
	# A pending boss always rides tonight's plan (a hand-edited save cannot skip it).
	if boss_pending and not lane_plan.is_empty():
		lane_plan[lane_plan.size() - 1].boss = true
	cards = {}
	for k in d.cards:
		cards[StringName(k)] = int(d.cards[k])
	card_offer = []
	for id in d.card_offer:
		card_offer.append(StringName(id))
	guards = {}
	for k in d.guards:
		guards[StringName(k)] = {"hp": float(d.guards[k].hp)}
	night_fails = int(d.night_fails)
	EventBus.state_restored.emit()

# --- gold and stocks ------------------------------------------------------

func add_gold(n: int) -> void:
	if n <= 0:
		return
	gold += n
	EventBus.gold_changed.emit(gold, n)

func collect_pile() -> int:
	var n := gold_pile
	if n <= 0:
		return 0
	gold_pile = 0
	gold += n
	EventBus.stocks_changed.emit()
	EventBus.gold_changed.emit(gold, n)
	return n

func add_freezer(n: int) -> void:
	if n <= 0:
		return
	freezer_steaks += n
	EventBus.stocks_changed.emit()

func pick_steak() -> bool:
	if carried_steaks >= carry_capacity():
		return false
	carried_steaks += 1
	EventBus.steak_picked.emit(carried_steaks)
	EventBus.stocks_changed.emit()
	return true

func move_freezer_to_carry(n: int = 1) -> int:
	var m := mini(n, mini(freezer_steaks, carry_capacity() - carried_steaks))
	if m <= 0:
		return 0
	freezer_steaks -= m
	carried_steaks += m
	EventBus.stocks_changed.emit()
	return m

func move_carry_to_counter(n: int = 1) -> int:
	var m := mini(n, mini(carried_steaks, counter_capacity() - counter_steaks))
	if m <= 0:
		return 0
	carried_steaks -= m
	counter_steaks += m
	EventBus.stocks_changed.emit()
	return m

func sell_from_counter(want: int) -> int:
	var m := mini(want, counter_steaks)
	if m <= 0:
		return 0
	counter_steaks -= m
	var g := m * gold_per_steak()
	gold_pile += g
	EventBus.steak_sold.emit(m, g)
	EventBus.stocks_changed.emit()
	return m

# --- buildings ------------------------------------------------------------

func next_level_cost(spot_id: String) -> int:
	return Economy.level_cost(spot_id, int(buildings[spot_id].level), Balance.data.build)

func remaining_cost(spot_id: String) -> int:
	var cost := next_level_cost(spot_id)
	return -1 if cost < 0 else cost - int(buildings[spot_id].paid)

func fence_max_hp(level: int) -> float:
	assert(level >= 1 and level <= Balance.data.build.fence_hp.size(), "fence_max_hp level out of range")
	return Balance.data.build.fence_hp[level - 1]

## Shared by pay_into_spot and pay_into_station. Returns the gold taken (0 = nothing happened).
func _pay_towards(entry: Dictionary, cost: int, amount: int) -> int:
	var pay := mini(amount, mini(gold, cost - int(entry.paid)))
	if pay <= 0:
		return 0
	gold -= pay
	entry.paid = int(entry.paid) + pay
	EventBus.gold_changed.emit(gold, -pay)
	return pay

func pay_into_spot(spot_id: String, amount: int) -> int:
	var cost := next_level_cost(spot_id)
	if cost < 0:
		return 0
	var b: Dictionary = buildings[spot_id]
	var pay := _pay_towards(b, cost, amount)
	if pay <= 0:
		return 0
	if int(b.paid) >= cost:
		b.level = int(b.level) + 1
		b.paid = 0
		if MapLayout.spot_kind(spot_id) == "fence":
			b.hp = fence_max_hp(b.level)
		EventBus.building_changed.emit(StringName(spot_id), b.level, b.paid)
		EventBus.build_completed.emit(StringName(spot_id), b.level)
	else:
		EventBus.building_changed.emit(StringName(spot_id), b.level, b.paid)
	return pay

func damage_fence(spot_id: String, amount: float) -> void:
	var b: Dictionary = buildings[spot_id]
	if int(b.level) < 1 or float(b.hp) <= 0.0:
		return
	b.hp = maxf(float(b.hp) - amount, 0.0)
	EventBus.building_changed.emit(StringName(spot_id), b.level, b.paid)

func damage_diner(amount: float) -> void:
	if diner_hp <= 0.0:
		return
	diner_hp = maxf(diner_hp - amount, 0.0)
	EventBus.diner_damaged.emit(amount, diner_hp)
	if diner_hp <= 0.0:
		EventBus.diner_fell.emit()

func diner_fraction() -> float:
	return diner_hp / Balance.data.build.diner_max_hp

# --- stations (E1) ---------------------------------------------------------

static func _fresh_stations() -> Dictionary:
	var out := {}
	for id in StationEffects.IDS:
		out[id] = {"level": 0, "paid": 0}
	return out

## 0 before the first new_game (the world is built and ticks while `stations` is still empty).
func station_level(id: StringName) -> int:
	assert(id in StationEffects.IDS, "unknown station %s" % id)
	return int(stations[id].level) if stations.has(id) else 0

func station_next_cost(id: StringName) -> int:
	assert(id in StationEffects.IDS, "unknown station %s" % id)
	if not stations.has(id):
		return -1
	return StationEffects.level_cost(id, int(stations[id].level), Balance.data.stations)

func station_remaining_cost(id: StringName) -> int:
	var cost := station_next_cost(id)
	return -1 if cost < 0 else cost - int(stations[id].paid)

func counter_capacity() -> int:
	return StationEffects.counter_capacity(station_level(&"counter"), Balance.data.stations)

func pay_into_station(id: StringName, amount: int) -> int:
	var cost := station_next_cost(id)
	if cost < 0:
		return 0
	var s: Dictionary = stations[id]
	var pay := _pay_towards(s, cost, amount)
	if pay <= 0:
		return 0
	if int(s.paid) >= cost:
		s.level = int(s.level) + 1
		s.paid = 0
		EventBus.station_changed.emit(id, s.level, s.paid)
		EventBus.station_upgraded.emit(id, s.level)
	else:
		EventBus.station_changed.emit(id, s.level, s.paid)
	return pay

## Tests, sims and fixtures only.
func debug_set_station_level(id: StringName, level: int) -> void:
	assert(id in StationEffects.IDS, "unknown station %s" % id)
	stations[id] = {"level": clampi(level, 0, Balance.data.stations.max_level), "paid": 0}
	EventBus.station_changed.emit(id, int(stations[id].level), 0)

# --- dawn -----------------------------------------------------------------

func heal_for_dawn() -> void:
	diner_hp = Balance.data.build.diner_max_hp
	for id in buildings:
		var b: Dictionary = buildings[id]
		if MapLayout.spot_kind(id) == "fence" and int(b.level) >= 1 and float(b.hp) > 0.0:
			b.hp = fence_max_hp(b.level)
			EventBus.building_changed.emit(StringName(id), b.level, b.paid)
	for id in guards:
		guards[id].hp = guard_max_hp(id)
		EventBus.guard_healed.emit(id, float(guards[id].hp))

func reset_destroyed_fences() -> void:
	for id in buildings:
		var b: Dictionary = buildings[id]
		if MapLayout.spot_kind(id) == "fence" and int(b.level) >= 1 and float(b.hp) <= 0.0:
			buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
			EventBus.building_changed.emit(StringName(id), 0, 0)

func advance_day() -> void:
	day += 1
	lane_plan = _plan_today()

# --- diner tier (E5) --------------------------------------------------------

func _plan_today() -> Array:
	var p := LanePlanner.plan(run_seed, day, Balance.data.wave, tier, tier_day, Balance.data.tiers)
	return LanePlanner.with_boss(p) if boss_pending else p

func pressure() -> int:
	return WaveMath.pressure(day, tier, tier_day, Balance.data.tiers)

func is_boss_night() -> bool:
	return not lane_plan.is_empty() and bool(lane_plan[lane_plan.size() - 1].get("boss", false))

## -1 when this build has no next tier. Also -1 before the first new_game (buildings is empty while the world warms up).
func tier_next_cost() -> int:
	if buildings.is_empty():
		return -1
	return TierEffects.tier_cost(tier, Balance.data.tiers)

## 0 once paid in full (boss pending), -1 at the top.
func tier_remaining_cost() -> int:
	var cost := tier_next_cost()
	if cost < 0:
		return -1
	return 0 if boss_pending else cost - tier_paid

## The tier sign's stand-still payment. Same rule as pads and spots (_pay_towards). Nothing while the boss is pending.
func pay_into_tier(amount: int) -> int:
	var cost := tier_next_cost()
	if cost < 0 or boss_pending:
		return 0
	var entry := {"paid": tier_paid}
	var pay := _pay_towards(entry, cost, amount)
	if pay <= 0:
		return 0
	tier_paid = int(entry.paid)
	if tier_paid >= cost:
		tier_paid = 0
		boss_pending = true
		lane_plan = LanePlanner.with_boss(lane_plan)  # the boss rides tonight's plan; with_boss copies and draws no RNG
		EventBus.tier_changed.emit(tier, tier_paid, boss_pending)
		EventBus.tier_paid_up.emit(tier + 1)
	else:
		EventBus.tier_changed.emit(tier, tier_paid, boss_pending)
	return pay

## Dawn after a won boss night (PhaseController, after advance_day). No-op at the top (a clamped save).
func complete_tier_up() -> void:
	assert(boss_pending, "complete_tier_up without a pending boss")
	boss_pending = false
	tier_paid = 0
	if tier >= TierEffects.top_tier(Balance.data.tiers):
		lane_plan = _plan_today()
		EventBus.tier_changed.emit(tier, 0, false)
		return
	tier += 1
	tier_day = day
	for id in MapLayout.TIER_SPOTS.get(tier, []):
		buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
		EventBus.building_changed.emit(StringName(id), 0, 0)
	lane_plan = _plan_today()
	EventBus.tier_changed.emit(tier, 0, false)
	EventBus.tier_reached.emit(tier)

## Tests, sims and fixtures only: jump to a tier as if it had been entered on `day_entered`.
func debug_set_tier(p_tier: int, day_entered: int) -> void:
	tier = clampi(p_tier, 1, TierEffects.top_tier(Balance.data.tiers))
	tier_day = 1 if tier == 1 else maxi(day_entered, 1)  # tier 1 always starts on day 1 (the lane RNG order depends on it)
	tier_paid = 0
	boss_pending = false
	for id in MapLayout.spots_for_tier(tier):
		if not buildings.has(id):
			buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	lane_plan = _plan_today()
	EventBus.tier_changed.emit(tier, 0, false)

# --- cards and guards (S2) ------------------------------------------------

func card_level(id: StringName) -> int:
	return int(cards.get(id, 0))

func carry_capacity() -> int:
	return CardEffects.carry_capacity(Balance.data.hero.carry_capacity, cards, Balance.data.cards) \
		+ StationEffects.carry_bonus(station_level(&"freezer"), Balance.data.stations)

func gold_per_steak() -> int:
	return CardEffects.gold_per_steak(Balance.data.economy.gold_per_steak, cards, Balance.data.cards)

func guard_max_hp(id: StringName) -> float:
	return float(CardEffects.guard_stats(id, maxi(card_level(id), 1), Balance.data.guards).max_hp)

func set_card_offer(offer: Array[StringName]) -> void:
	card_offer = offer.duplicate()
	EventBus.card_offered.emit(Array(card_offer.duplicate()))

## E5: the tier-up dawn stores the offer before the reveal so a save written during the reveal resumes at the card pick.
func stash_card_offer(offer: Array[StringName]) -> void:
	card_offer = offer.duplicate()

## Debug skip only (spec 5.1): no signal, so no overlay shows.
func clear_card_offer() -> void:
	card_offer = []

func pick_card(id: StringName) -> int:
	assert(id in card_offer, "pick_card: %s is not offered" % id)
	var level := card_level(id) + 1
	assert(level <= Balance.data.cards.max_level, "pick_card: %s is maxed" % id)
	cards[id] = level
	card_offer = []
	if CardCatalog.kind(id) == &"adventurer" and Balance.data.guards.stats(id).targetable:
		guards[id] = {"hp": guard_max_hp(id)}
	EventBus.card_picked.emit(id, level)
	return level

## Debug and test helper: picks exactly this card; an open dawn offer is kept.
func debug_grant_card(id: StringName) -> int:
	var prev := card_offer.duplicate()
	card_offer = [id]
	var lvl := pick_card(id)
	card_offer = prev.filter(func(c): return card_level(c) < Balance.data.cards.max_level)
	return lvl

func damage_guard(id: StringName, amount: float) -> void:
	if not guards.has(id) or float(guards[id].hp) <= 0.0:
		return
	var hp := maxf(float(guards[id].hp) - amount, 0.0)
	guards[id].hp = hp
	EventBus.guard_damaged.emit(id, hp)
	if hp <= 0.0:
		EventBus.guard_knocked_out.emit(id)

func revive_guard(id: StringName) -> void:
	if not guards.has(id):
		return
	guards[id].hp = guard_max_hp(id)
	EventBus.guard_revived.emit(id)

# --- failure and mercy (S3) ------------------------------------------------

func set_night_fails(n: int) -> void:
	night_fails = maxi(n, 0)

func clear_night_fails() -> void:
	night_fails = 0

## Enemy HP and damage multiplier (D-175).
func mercy_factor() -> float:
	var wb := Balance.data.wave
	return maxf(1.0 - wb.mercy_step * night_fails, wb.mercy_floor)

static func _string_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out

func _stations_out() -> Dictionary:
	var out := {}
	for id in stations:
		out[String(id)] = {"level": int(stations[id].level), "paid": int(stations[id].paid)}
	return out

func _guards_out() -> Dictionary:
	var out := {}
	for k in guards:
		out[String(k)] = {"hp": float(guards[k].hp)}
	return out
