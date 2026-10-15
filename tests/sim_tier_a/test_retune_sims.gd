extends GutTest
## E6 Task 19, spec 8.3: three sims (`Balance.reset()` in before_each and after_each; balance/ is never written) on fixtures recorded
## from real tier-bot play (`tests/sim/make_save.gd -- --fixture=retune --seed=3`: seed 3 is a tuning seed; its lane character is siege = sw, hare = west):
##  (a) retune_siege_night: the close-up of day 25 (tier_day 23), the threat-matched build as the bot had bought it. A wave's brutes have the siege lane (sw) as neither the drawn main nor side lane;
##      the plan step moves them to sw and the hares' share comes as an extra group on west. The night is held.
##  (b) retune_first_t3_night: the start of the first tier-3 day (day 23); the threat-matched bot plays the day and the night; the night is survived at or above 25% diner HP (D-281).
##  (c) retune_respawn: a CONSTRUCTED state (make_save.gd): the first tier-3 day's buildings (south-west spots unbuilt, the zone fills) with tier_day moved back two days (day 23, tier_day 21), resumed at NIGHT, so the night is at the cap pressure 12 with the brute ramp complete; sim 7 of test_tier3_sims.gd on the retuned game.
##      Why constructed: on the real first tier-3 night (pressure 10) the precondition that failed is the CROWD one: fewer than CROWD (6) enemies ever stood in the south-west zone while the tank was posted, so the knock-out was never forced (forced = -1.0) and the respawn was never watched.
## Every fixture carries a SAVED lane plan, so each sim asserts that the DECODED STORED plan equals the planner's plan for that day (raw LanePlanner.plan, then LaneCharacter.apply), and that the load
## path re-derives it: a stored plan replaced by the unapplied one comes back equal to the planner's after GameState.from_dict (spec 3.4).
## Wall-clock prints are information only, never asserted. Reads only signals and GameState (D-113), plus the pool `grew` signals.

## (a)'s lower bound on the minimum diner fraction during the night. Three recorded runs of this sim gave 0.96, 0.96 and 0.96 (the game is deterministic, so they agree).
## The same night with tower_sw and fence_sw unbranched in memory (held, but worse) ended at 0.8033, so 0.90 sits between the two measured values: the threat-matched
## build passes, the unbranched one fails. Not an exact float: a floor.
const BOUND_A := 0.90
## D-281: no first tier-3 night below 25% diner HP.
const FIRST_NIGHT_MIN := 0.25
## (b)'s recorded floor: the run gave 1.00; 1.00 - 0.15 = 0.85 (never above 0.85).
const FLOOR_B := 0.85
const SIEGE_STEM := "retune_siege_night"
const FIRST_STEM := "retune_first_t3_night"
const RESPAWN_STEM := "retune_respawn"
## Sim (c) forces the knockout once at least this many enemies stand in the south-west zone. The first tier-3 night's south-west enemies come one or two at a time at first
## (the zone is empty three seconds after a knockout at the first one), so the respawn must be into a crowd, not into the first arrival.
const CROWD := 6
## Sim (c) only: the diner's HP in memory. At the real 300 HP the constructed night (south-west spots unbuilt) is lost 119.2 s into the night, 0.12 s after the first respawn (119.1 s; knock-out forced at 116.1 s), so the 5 s after the respawn could not be watched. Re-measured: the whole test takes about 3 s of wall time (2.9 to 3.4 s, on a loaded machine).
const DINER_HP_C := 3000.0
## Sim (c): the planned brutes (brute_main + brute_side over the three waves) on the constructed night (tier_day 21: the brute ramp, brute_ramp_days[3] = 3, is complete).
const PLANNED_BRUTES_C := 3

var h: SimHarness
var _t0 := 0
var growth: Array = []
var _knock_times: Dictionary = {}
var _revive_times: Dictionary = {}
var _kills: Dictionary = {}  # lane -> {boar, hare, brute}: every enemy_killed of the night

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_t0 = Time.get_ticks_msec()
	growth = []
	_kills = {}

func _on_kill(_i: int, lane: StringName, _p: Vector3, kind: StringName) -> void:
	var row: Dictionary = _kills.get(String(lane), {"boar": 0, "hare": 0, "brute": 0})
	row[String(kind)] = int(row.get(String(kind), 0)) + 1
	_kills[String(lane)] = row

## The night's planned enemies per lane ({boar, hare, brute}) from the plan AFTER the lane-character step; the kill tally must equal it
## (a cleared night kills every enemy), so brutes off the siege lane or a dropped extra group fail.
func _planned() -> Dictionary:
	var out := {}
	var comp := LanePlanner.composition_by_lane(GameState.lane_plan, 3)
	for lane in comp:
		out[String(lane)] = {"boar": int(comp[lane].boar), "hare": int(comp[lane].hare), "brute": int(comp[lane].brute)}
	return out

func _killed() -> Dictionary:
	var out := {}
	for lane in ["west", "north", "east", "sw"]:
		var row: Dictionary = _kills.get(lane, {})
		out[lane] = {"boar": int(row.get("boar", 0)), "hare": int(row.get("hare", 0)), "brute": int(row.get("brute", 0))}
	return out

func after_each() -> void:
	if EventBus.enemy_killed.is_connected(_on_kill):
		EventBus.enemy_killed.disconnect(_on_kill)
	for pair in [[EventBus.guard_knocked_out, _on_ko], [EventBus.guard_revived, _on_revive]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	h.finish()
	Balance.reset()  # back to the shipped balance for every later test
	gut.p("  wall time %.1f s" % ((Time.get_ticks_msec() - _t0) / 1000.0))

func _watch_pools() -> void:
	var w: World = h.main.world
	for p in [w.enemy_pool, w.steak_pool, w.projectile_pool]:
		var pool: NodePool = p
		pool.grew.connect(func(n: int): growth.append("%s -> %d" % [pool.name, n]))

func _start(stem: String, phase := "") -> void:
	h.start_from(stem, TierBot, 0, phase)
	(h.bot as TierBot).max_tier = 3  # E8 (D-314.12): these are the tier-3 sims; the bot never pays for tier 4
	_watch_pools()
	EventBus.enemy_killed.connect(_on_kill)

func _spot_levels(ids: Array) -> Array:
	return ids.map(func(id): return int(GameState.buildings[id].level) if GameState.buildings.has(id) else -1)

func _decode(stem: String) -> Dictionary:
	var r: Dictionary = SaveCodec.decode(FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, "%s: %s" % [stem, r.get("reason", "")])
	return r.state

## The planner's plan for the state's run and day, as the game makes it: LanePlanner.plan, then the lane character's step (tier 3).
func _planner_plan(s: Dictionary) -> Array:
	var raw := LanePlanner.plan(int(s.run_seed), int(s.day), Balance.data.wave, int(s.tier), int(s.tier_day), Balance.data.tiers)
	return LaneCharacter.apply(raw, LaneCharacter.for_run(int(s.run_seed)), Balance.data.tiers)

## A plan reduced to strings, so an int 5 and a float 5.0 cannot hide a difference (or make a false one) between a decoded save and the planner's output.
func _canon(plan: Array) -> Array:
	return plan.map(func(w): return JSON.stringify(_norm(w), "", true))

## Whole-number floats become ints, recursively (a JSON number is a float after decoding; the planner makes ints).
func _norm(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _norm(v[k])
		return d
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(roundf(v))
	return v

## Stale-fixture guard, in three parts. 1: the plan STORED in the fixture file (decoded, never touched by GameState) equals the planner's plan for that day. 2: the load path re-derives
## the plan: the stored plan replaced by the planner's plan WITHOUT the lane character comes back as the one with it (GameState.from_dict). 3: the running game has it.
## Mutations: a fixture made before a planner change (1); the lane character ignored on load (2 and 3).
## Call it BEFORE the game starts (it loads a state into GameState). Returns the planner's plan for `_assert_loaded_plan` after the start.
func _assert_fresh_plan(stem: String, boss_night := false) -> Array:
	var stored := _decode(stem)
	var want := _planner_plan(stored)
	if boss_night:
		want = LanePlanner.with_boss(want)
	assert_eq(_canon(stored.lane_plan), _canon(want), "%s: the stored plan is the planner's (stale fixture: re-run make_save.gd -- --fixture=retune --seed=3)" % stem)
	var tampered := stored.duplicate(true)
	tampered.lane_plan = LanePlanner.plan(int(stored.run_seed), int(stored.day), Balance.data.wave, int(stored.tier), int(stored.tier_day), Balance.data.tiers)
	assert_ne(_canon(tampered.lane_plan), _canon(want), "%s: the unapplied plan differs from the planner's (precondition: the lane character changes this night)" % stem)
	GameState.from_dict(tampered)
	assert_eq(_canon(GameState.lane_plan), _canon(want), "%s: loading re-derives the plan under the lane character" % stem)
	return want

func _assert_loaded_plan(stem: String, want: Array) -> void:
	assert_eq(_canon(GameState.lane_plan), _canon(want), "%s: the game started from the fixture plays the planner's plan" % stem)

# ---- (a) the siege lane is neither the night's main nor its side lane in a wave -------------------------------------

func test_a_the_night_whose_siege_lane_is_neither_main_nor_side_is_held() -> void:
	var want := _assert_fresh_plan(SIEGE_STEM)
	_start(SIEGE_STEM)
	_assert_loaded_plan(SIEGE_STEM, want)
	assert_eq(h.main.phase_controller.phase, Phase.NIGHT, "the close-up resumed at NIGHT (precondition)")
	assert_eq(GameState.tier, 3)
	assert_eq(GameState.night_fails, 0, "a first attempt")
	var character := GameState.lane_character()
	assert_eq(character, {"siege": "sw", "hare": "west"}, "seed 3's lane character (precondition)")
	assert_eq([GameState.run_seed, GameState.day, GameState.tier_day], [3, 25, 23], "tuning seed 3, day 25 (hold-out seeds are never used)")
	# The raw plan (before the lane character): a wave with brutes whose siege lane is neither its main nor its side lane.
	var raw := LanePlanner.plan(GameState.run_seed, GameState.day, Balance.data.wave, GameState.tier, GameState.tier_day, Balance.data.tiers)
	var siege_neither := 0
	for w in raw:
		if int(w.brute_main) + int(w.brute_side) > 0 and w.main != character.siege and w.side != character.siege:
			siege_neither += 1
	assert_gte(siege_neither, 1, "a wave's brutes have the siege lane as neither main nor side (precondition: the night is not vacuous)")
	# After the step: every brute walks the siege lane, with the brutes of the night unchanged.
	var brutes_raw := 0
	var brutes_now := 0
	for i in raw.size():
		brutes_raw += int(raw[i].brute_main) + int(raw[i].brute_side)
		var w: Dictionary = GameState.lane_plan[i]
		brutes_now += int(w.brute_main) + int(w.brute_side)
		if int(w.brute_main) > 0:
			assert_eq(w.main, "sw", "wave %d: the main group's brutes are on the siege lane" % i)
		if int(w.brute_side) > 0:
			assert_eq(w.side, "sw", "wave %d: the side group's brutes are on the siege lane" % i)
	assert_eq(brutes_now, brutes_raw, "the night's brute count is unchanged by the step")
	assert_gt(brutes_now, 0, "the night has brutes")
	# The extra group and the third arrow's data. A wave with an extra group has three distinct lanes (main, side, extra); the lane's
	# telegraph rows and threat read the extra group.
	var extra_waves := 0
	var west_hares_in_groups := 0
	for w in GameState.lane_plan:
		var ex: Array = w.get("extra", [])
		if ex.is_empty():
			continue
		extra_waves += 1
		assert_eq(ex.size(), 1, "one extra group")
		assert_eq(String(ex[0].lane), "west", "the extra group is on the hare lane")
		assert_false(ex[0].lane == w.main or ex[0].lane == w.side, "the extra group's lane is a third lane")
		assert_gt(int(ex[0].count), 0, "the extra group has boars (hares)")
	assert_gte(extra_waves, 1, "the plan carries an extra group (the hare lane is neither main nor side in a wave)")
	for w in GameState.lane_plan:
		if String(w.main) == "west":
			west_hares_in_groups += int(w.fast_main)
		if String(w.side) == "west":
			west_hares_in_groups += int(w.fast_side)
		for e in w.get("extra", []):
			west_hares_in_groups += int(e.fast)
	var comp := LanePlanner.composition_by_lane(GameState.lane_plan, 3)
	assert_eq(int(comp.west.hare), west_hares_in_groups, "the telegraph counts the extra group's hares on the hare lane")
	var stripped: Array = GameState.lane_plan.duplicate(true)
	for w in stripped:
		w.erase("extra")
	var with_extra := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp, 3)
	var without := LanePlanner.threat_by_lane(stripped, Balance.data.enemy.hp, 3)
	assert_gt(float(with_extra.west), float(without.west), "the hare lane's threat (the third arrow's size) includes the extra group")
	assert_eq(float(with_extra.sw), float(without.sw), "the siege lane's threat has no extra group")
	var d := _spot_levels(["tower_sw", "fence_sw"])
	assert_eq(d, [3, 3], "the threat-matched build stands on the siege lane (precondition)")
	assert_eq(String(GameState.buildings.tower_sw.branch), "longbow", "Longbow on the siege lane's tower (the threat-matched purchase)")
	assert_eq(String(GameState.buildings.fence_sw.branch), "stone", "Stone wall on the siege lane's fence")
	var planned := _planned()
	var n := await h.run_night()
	gut.p("RECORD sim a: planned %s killed %s" % [planned, _killed()])
	gut.p("RECORD sim a: %s; minimum diner fraction %.4f; pool growth %s" % [n, n.diner_frac, growth])
	assert_false(n.failed, "the siege night is held without a retry")
	assert_true(n.cleared, "the siege night is cleared on the first attempt")
	assert_eq(GameState.night_fails, 0, "0 retries")
	assert_eq(_killed(), planned, "the night killed exactly the planned enemies per lane and kind: every brute on sw, the extra group's hares on west")
	assert_eq(int(planned.sw.brute), brutes_now, "all of the night's brutes are planned on the siege lane")
	assert_gte(n.diner_frac, BOUND_A, "the diner stays at or above the bound taken from the recorded runs minus a margin (never an exact float)")
	assert_eq(growth, [], "the enemy, steak and projectile pools never grew at runtime")

# ---- (b) the first tier-3 night --------------------------------------------------------------------------------------

func test_b_the_first_tier3_night_is_survived_at_or_above_25_percent_by_the_threat_matched_build() -> void:
	var want := _assert_fresh_plan(FIRST_STEM)
	_start(FIRST_STEM)
	_assert_loaded_plan(FIRST_STEM, want)
	assert_eq(h.main.phase_controller.phase, Phase.DAY, "the fixture loads at the start of the day (precondition)")
	assert_eq(GameState.tier, 3)
	assert_eq(GameState.tier_day, GameState.day, "the first night of the tier")
	assert_eq((h.bot as TierBot).policy, "threat", "the threat-matched bot")
	assert_false(GameState.lane_character().is_empty(), "the run has a lane character")
	assert_eq(_spot_levels(["tower_sw", "fence_sw"]), [0, 0], "the new spots are unbuilt (precondition)")
	var dday := await h.run_day()
	assert_true(dday.closed, "the bot closes up")
	assert_eq(_spot_levels(["tower_sw", "fence_sw"]), [3, 3], "the bot built the two new spots to level 3 in the day")
	var planned := _planned()
	var n := await h.run_night()
	gut.p("RECORD sim b: planned %s killed %s" % [planned, _killed()])
	gut.p("RECORD sim b: first tier-3 night, new spots %s; %s; minimum diner fraction %.4f; pool growth %s" % [_spot_levels(["tower_sw", "fence_sw"]), n, n.diner_frac, growth])
	assert_false(n.failed, "no loss")
	assert_true(n.cleared, "held on the first attempt")
	assert_eq(GameState.night_fails, 0, "0 retries")
	assert_eq(_killed(), planned, "the night killed exactly the planned enemies per lane and kind")
	assert_gte(n.diner_frac, FIRST_NIGHT_MIN, "D-281: the first tier-3 night is survived at or above 25% diner HP")
	assert_gte(n.diner_frac, FLOOR_B, "and at or above the recorded floor (measured minus 0.15)")
	assert_eq(h.bot.stuck_count, 0, "the bot never got stuck")
	assert_eq(h.bot.skipped_goals, 0, "the bot skipped no goal")
	assert_eq(growth, [], "the enemy, steak and projectile pools never grew at runtime")

# ---- (c) respawn ---------------------------------------------------------------------------------------------

func _on_ko(id: StringName) -> void:
	_knock_times[id] = _knock_times.get(id, []) + [h.elapsed]

func _on_revive(id: StringName) -> void:
	_revive_times[id] = _revive_times.get(id, []) + [h.elapsed]

func _enemies_in_zone(lane: String) -> int:
	var zone := MapLayout.zone_rect(lane).grow(0.3)
	var n := 0
	for e in h.main.world.wave_director.alive_enemies():
		if zone.has_point(Vector2(e.global_position.x, e.global_position.z)):
			n += 1
	return n

## Sim (c): sim 7 of test_tier3_sims.gd on the retuned game. WHAT IS RECORDED: the first tier-3 day's start of seed 3 from real bot play (its plan, cards, tank guard and
## buildings; tower_sw and fence_sw unbuilt); retune_respawn is that state CONSTRUCTED with tier_day = day - 2 (day 23, tier_day 21: pressure 12, the full brute ramp, 3 planned brutes), because the real first night (pressure 10) never fills the zone to CROWD. WHAT IS INSTRUMENTED (this is an instrumented scene, as sim 7 always was): the phase is overridden to NIGHT (the fixture resumes at
## once, no day is played); the tank's max HP is 1 in memory (any hit kills it, so only the respawn protection can keep it alive); the knock-out is scripted through
## GameState.damage_guard once >= CROWD enemies stand in the south-west zone; the diner has DINER_HP_C HP in memory. WHAT IT PROVES: in a crowded siege-lane zone (the south-west lane is this
## run's siege lane) a respawned guard is not knocked out again within 5 s while an enemy stands within its reach (respawn_protect_s = 0 makes it fail: the tank falls 0.13 s after the respawn).
## WHAT IT DOES NOT: the full 5 s window at the real 300 HP diner (that night is lost 119.2 s in with the south-west spots unbuilt, 0.12 s after the respawn at 119.1 s, before 5 s have been watched),
## nor a held night: on the held night (retune_siege_night, real 300 HP, tower_sw and fence_sw built) the south-west zone never holds a crowd long enough to observe a respawn into it (tried at CROWD 1 to 4: the zone is empty 3 s after
## the knock-out, or never reaches 3).
func test_c_a_guard_respawning_into_an_occupied_sw_zone_is_not_knocked_out_again_within_5_s_with_the_flag_on() -> void:
	_knock_times = {}
	_revive_times = {}
	Balance.data.guards.tank.max_hp = 1.0
	Balance.data.guards.tank.hp_growth = 0.0
	var want := _assert_fresh_plan(RESPAWN_STEM)
	Balance.data.build.diner_max_hp = DINER_HP_C  # in memory: with the south-west spots unbuilt the night is lost 119.2 s in at 300 HP, and the respawn must be watched 5 s
	_start(RESPAWN_STEM)
	GameState.diner_hp = DINER_HP_C
	_assert_loaded_plan(RESPAWN_STEM, want)
	assert_eq(h.main.phase_controller.phase, Phase.NIGHT, "the night at once (precondition)")
	assert_eq(GameState.tier, 3)
	# The CONSTRUCTED state (make_save.gd): the first tier-3 day's buildings with tier_day moved back two days, so the night is at the cap pressure with the brute ramp complete.
	assert_eq([GameState.day, GameState.tier_day], [23, 21], "the constructed respawn state: day 23, tier_day 21 (third tier-3 night)")
	assert_eq(GameState.pressure(), 12, "the night is at the tier-3 cap pressure (tier 3 starts at 10 and ramps to 12)")
	var planned_brutes := 0
	for w in GameState.lane_plan:
		planned_brutes += int(w.get("brute_main", 0)) + int(w.get("brute_side", 0))
	gut.p("planned brutes on the night: %d" % planned_brutes)
	assert_eq(planned_brutes, PLANNED_BRUTES_C, "the brute ramp is complete on this night: the planned brutes over its waves")
	assert_eq(GameState.lane_character().siege, "sw", "the south-west lane is the siege lane (precondition)")
	assert_eq(_spot_levels(["tower_sw", "fence_sw"]), [0, 0], "the south-west spots are unbuilt (precondition)")
	EventBus.guard_knocked_out.connect(_on_ko)
	EventBus.guard_revived.connect(_on_revive)
	var forced := -1.0
	var occupied_at_revive := -1
	var seen_revive := 0
	var attackers_in_reach_ticks := 0  # ticks in the 5 s after the first respawn with an enemy inside its reach of the tank (geometry only, protection ignored)
	var first_revive_t := -1.0
	for i in 60 * 150:
		await h.tick()
		if h.failed or h.main.phase_controller.phase == Phase.DAY:
			break
		var tank: Guard = h.main.world.guard_roster.guards.get(&"tank")
		if forced < 0.0 and tank != null and tank.state == Guard.State.POSTED and _enemies_in_zone("sw") >= CROWD:
			forced = h.elapsed
			GameState.damage_guard(&"tank", 1e6)
		if tank != null and first_revive_t >= 0.0 and h.elapsed <= first_revive_t + 5.0:
			for e in h.main.world.wave_director.alive_enemies():
				if Vector2(e.global_position.x, e.global_position.z).distance_to(tank.xz()) <= float(e.stats().reach) + float(tank.stats.body_radius) + 1e-4:
					attackers_in_reach_ticks += 1
					break
		if _revive_times.get(&"tank", []).size() > seen_revive:
			seen_revive = _revive_times[&"tank"].size()
			if occupied_at_revive < 0:
				occupied_at_revive = _enemies_in_zone("sw")
				first_revive_t = h.elapsed
	gut.p("forced knockout at %.1f s; knockouts %s; revives %s; enemies in the SW zone at the first revive: %d" % [forced, _knock_times, _revive_times, occupied_at_revive])
	var first_revive: float = _revive_times.get(&"tank", [0.0])[0]
	gut.p("MARGIN sim c: watched %.2f s after the first revive (bar 5 s); %d enemies in the SW zone at the revive" % [h.elapsed - first_revive, occupied_at_revive])
	assert_gte(forced, 0.0, "enemies reached the south-west zone and the tank was knocked out (not vacuous)")
	assert_gt(_revive_times.get(&"tank", []).size(), 0, "the tank respawned")
	assert_gt(occupied_at_revive, 0, "the south-west zone was occupied when the tank respawned")
	gut.p("attackers within reach of the respawned tank during the 5 s after the first respawn: %d ticks" % attackers_in_reach_ticks)
	assert_gt(attackers_in_reach_ticks, 0, "an enemy stood within its reach of the respawned tank during the 5 s (protection, not distance, is what saved it)")
	assert_gte(h.elapsed, _revive_times.get(&"tank", [0.0])[0] + 5.0, "the night was watched for at least 5 s after the respawn")
	for id in _revive_times:
		for t in _revive_times[id]:
			for k in _knock_times.get(id, []):
				assert_false(k > t and k <= t + 5.0, "%s respawned at %.2f s and was knocked out again at %.2f s (within 5 s)" % [id, t, k])
	for id in _knock_times:
		var ks: Array = _knock_times[id]
		for i in ks.size():
			var in_window := 0
			for k in ks:
				if k >= ks[i] and k < ks[i] + 15.0:
					in_window += 1
			assert_lte(in_window, 2, "%s: at most 2 knockouts in any 15 s window (from %.2f s)" % [id, ks[i]])
