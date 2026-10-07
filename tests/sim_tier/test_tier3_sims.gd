extends GutTest
## E5 tier 3, Task 23: spec 9.2 sims 2 to 8 (sim 1 and sim 6's multi-seed ranking are report scripts, D-274.4). Slice 1's sims are in
## test_tier_sims.gd; this file is separate so the job can be split into sim-tiers-a / sim-tiers-b by moving one file.
## Every state starts from a schema-6 fixture written by `tests/sim/make_save.gd -- --fixture=tier3` (constructed, deterministic).
## Wall-clock prints are information only, never asserted. Reads only signals and GameState (D-113), plus the pool `grew` signals.

## Sim 8: slice 1's tier2_night1 played by the tier bot, measured before this task's code existed on this branch's base (7484180):
## 5889 physics ticks from the start of the night to dawn (the same number slice 1's golden entry records for its sim 3), diner HP 119 of 300.
const PINNED_TIER2_NIGHT := {"diner_hp": 119.0, "ticks": 5889}

var h: SimHarness
var _t0 := 0
var bosses_killed := 0
var growth: Array = []
var hp_last := -1.0

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_t0 = Time.get_ticks_msec()
	bosses_killed = 0
	growth = []
	hp_last = -1.0

func after_each() -> void:
	for pair in [[EventBus.enemy_killed, _count_kill], [EventBus.diner_damaged, _track_hp]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	h.finish()
	gut.p("  wall time %.1f s" % ((Time.get_ticks_msec() - _t0) / 1000.0))

func _count_kill(_i: int, _lane: StringName, _p: Vector3, kind: StringName) -> void:
	if TierEffects.is_boss_kind(kind, Balance.data.tiers):
		bosses_killed += 1

func _track_hp(_amount: float, hp_left: float) -> void:
	hp_last = hp_left

## Counts runtime growth of the enemy, steak and projectile pools (each grow also warns: D-270.6).
func _watch_pools() -> void:
	var w: World = h.main.world
	for p in [w.enemy_pool, w.steak_pool, w.projectile_pool]:
		var pool: NodePool = p
		pool.grew.connect(func(n: int): growth.append("%s -> %d" % [pool.name, n]))

func _start(stem: String, bot_script: GDScript, p_seed := 0, mutate := Callable(), phase := "") -> void:
	h.start_from(stem, bot_script, p_seed, phase, mutate)
	_watch_pools()
	if not EventBus.enemy_killed.is_connected(_count_kill):
		EventBus.enemy_killed.connect(_count_kill)

func _spot_levels(ids: Array) -> Array:
	return ids.map(func(id): return int(GameState.buildings[id].level) if GameState.buildings.has(id) else -1)

# ---- sim 2: the Baron night, full tier-2 build ----------------------------------------------------------------------

func test_2_the_baron_night_with_the_full_tier2_build_is_held_with_0_retries() -> void:
	_start("tier3_baron_full", TierBot)
	assert_eq(GameState.tier, 2)
	assert_true(GameState.is_boss_night(), "tonight is the Baron night")
	assert_eq(GameState.night_fails, 0, "a first attempt")
	assert_eq(_spot_levels(MapLayout.spots_for_tier(2)), [3, 3, 3, 3, 3, 3, 3], "the full tier-2 build (precondition)")
	var n := await h.run_night()
	gut.p("Baron night, full build: %s; diner HP left %.1f" % [n, GameState.diner_hp])
	assert_false(n.failed, "no loss, so no retry")
	assert_true(n.cleared, "the Baron night is held on the first attempt")
	assert_eq(GameState.night_fails, 0)
	assert_eq(bosses_killed, 1, "the Baron died exactly once")
	assert_eq(GameState.tier, 3, "the dawn tiered up")
	assert_eq(h.bot.stuck_count, 0, "the bot never got stuck")

# ---- sim 3: the Baron night without the yard towers -----------------------------------------------------------------

func test_3_the_baron_night_without_the_yard_towers_is_lost() -> void:
	_start("tier3_baron_no_yard", TierBot)
	assert_true(GameState.is_boss_night())
	assert_eq(_spot_levels(["tower_w", "tower_e"]), [0, 0], "the fixture has no yard towers (precondition: the sim is vacuous with them)")
	assert_eq(_spot_levels(["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"]), [3, 3, 3, 3, 3], "everything else is built")
	var n := await h.run_night()
	gut.p("Baron night, no yard towers: %s; diner HP left %.1f; boss kills %d" % [n, GameState.diner_hp, bosses_killed])
	assert_true(n.failed, "without the yard towers the first attempt is lost (a retry would need mercy, D-267.3)")
	assert_eq(bosses_killed, 0, "the Baron was never felled")

# ---- sim 4: the Baron alone is catchable ------------------------------------------------------------------------------

## Holds the hero at the Baron lane's zone centre until the Baron spawns, then runs at it (hero speed, straight line).
class ChaseBot extends BotBase:
	var zone_center := Vector2.ZERO
	func _steer() -> void:
		var boss: Boar = null
		for b in main.world.wave_director.alive_enemies():
			if (b as Boar).is_boss:
				boss = b
		if boss == null:
			hero.input.set_move(Vector2.ZERO)
			return
		var d: Vector2 = Vector2(boss.global_position.x, boss.global_position.z) - hero.xz()
		hero.input.set_move(d.normalized() if d.length() > 0.01 else Vector2.ZERO)

## Reading of "first" (D-267.1, spec 6.3): the hero starts at the centre of the Baron lane's attack zone when the Baron spawns and runs at it;
## "reaches melee range" = the Baron within Balance.data.hero.attack_range of the hero; "the Baron reaches the zone" = the Baron inside the
## zone rectangle (grown by the 5 cm the unit test also uses). The catch must come strictly before the Baron enters the zone.
func test_4_the_hero_at_the_zone_reaches_the_baron_before_it_reaches_the_zone() -> void:
	_start("tier3_baron_alone", ChaseBot)
	assert_true(GameState.is_boss_night())
	assert_eq(GameState.guards.size(), 0, "no guard (precondition)")
	assert_eq(_spot_levels(MapLayout.spots_for_tier(2)), [0, 0, 0, 0, 0, 0, 0], "no building (precondition)")
	var lane: String = GameState.lane_plan[-1].main
	var zone := MapLayout.zone_rect(lane)
	var reach: float = Balance.data.hero.attack_range
	var caught := -1.0
	var zone_t := -1.0
	var spawned := -1.0
	var t := 0.0
	for i in 60 * 120:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var boss: Boar = null
		for b in h.main.world.wave_director.alive_enemies():
			if (b as Boar).is_boss:
				boss = b
		if boss == null:
			if spawned < 0.0 and h.main.phase_controller.phase == Phase.NIGHT:
				EventBus.hero_place_requested.emit(zone.get_center())  # still waiting for the Baron: stand at the zone centre
			if spawned >= 0.0:
				break  # it died or left
			continue
		var p := Vector2(boss.global_position.x, boss.global_position.z)
		if spawned < 0.0:
			spawned = t
			assert_lt(h.main.hero.xz().distance_to(zone.get_center()), 0.5, "the hero stands at the zone centre when the Baron spawns")
		if caught < 0.0 and h.main.hero.xz().distance_to(p) <= reach:
			caught = t
		if zone_t < 0.0 and zone.grow(0.05).has_point(p):
			zone_t = t
		if caught >= 0.0 and zone_t >= 0.0:
			break
	gut.p("lane %s: Baron spawned at %.1f s, caught at %.2f s, in the zone at %.2f s (margin %.2f s)" % [lane, spawned, caught, zone_t, zone_t - caught])
	assert_gte(spawned, 0.0, "the Baron spawned")
	assert_gte(caught, 0.0, "the hero reached melee range")
	assert_gte(zone_t, 0.0, "the Baron reached the zone")
	assert_lt(caught, zone_t, "melee range comes before the Baron reaches the zone")
	assert_gt(zone_t - caught, 5.0, "at least 5 s of margin (the same bar as test_baron's unit test; a Baron at 12 m/s leaves 0.85 s)")

# ---- sim 5: the first tier-3 night ----------------------------------------------------------------------------------

func test_5_the_tier_bot_holds_the_first_tier3_night_with_0_retries() -> void:
	_start("tier3_night1", TierBot)
	assert_eq(GameState.tier, 3)
	assert_eq(GameState.tier_day, GameState.day, "the first night of the tier")
	assert_eq(_spot_levels(["tower_sw", "fence_sw"]), [0, 0], "the new spots are unbuilt (precondition)")
	var plan_brutes := 0
	for w in GameState.lane_plan:
		plan_brutes += int(w.get("brute_main", 0)) + int(w.get("brute_side", 0))
	assert_gt(plan_brutes, 0, "the night has a brute (precondition)")
	assert_eq(h.main.phase_controller.phase, Phase.DAY, "the fixture starts at the dawn: the bot plays the day")
	var d := await h.run_day()
	assert_true(d.closed, "the bot closes up")
	var new_levels := _spot_levels(["tower_sw", "fence_sw"])
	var n := await h.run_night()
	gut.p("first tier-3 night: new spots built to %s in a %.0f s day; %s; diner HP left %.1f; pool growth %s" % [new_levels, d.seconds, n, GameState.diner_hp, growth])
	assert_false(n.failed)
	assert_true(n.cleared, "held on the first attempt")
	assert_eq(GameState.night_fails, 0, "0 retries")
	assert_eq(growth, [], "the enemy, steak and projectile pools never grew at runtime")
	assert_eq(h.bot.stuck_count, 0, "the bot never got stuck")
	assert_eq(h.bot.skipped_goals, 0, "the bot skipped no goal")

# ---- sim 6: the tier-3 cap, full build, every policy ----------------------------------------------------------------

func test_6_every_branch_policy_holds_the_tier3_cap_and_threat_ends_with_the_most_diner_hp() -> void:
	var hp := {}
	var lines: Array = []
	var comp_line := ""
	for policy in TierBot.POLICIES:
		h.finish()
		await get_tree().process_frame
		Balance.reset()
		h = SimHarness.new(self)
		growth = []
		hp_last = -1.0
		_start("tier3_cap_" + policy, TierBot)
		(h.bot as TierBot).policy = policy
		assert_eq(GameState.tier, 3)
		assert_eq(GameState.pressure(), Balance.data.tiers.tier_cap[3], "%s: at the tier-3 cap" % policy)
		var branched := 0
		for id in MapLayout.spots_for_tier(3):
			assert_eq(int(GameState.buildings[id].level), 3, "%s: %s is at max level" % [policy, id])
			if String(GameState.buildings[id].branch) != "":
				branched += 1
		assert_eq(branched, 9, "%s: every branchable building carries a branch (precondition)" % policy)
		if comp_line == "":
			comp_line = str(LanePlanner.composition_by_lane(GameState.lane_plan, 3))
		hp_last = GameState.diner_hp
		EventBus.diner_damaged.connect(_track_hp)
		var n := await h.run_night()
		EventBus.diner_damaged.disconnect(_track_hp)
		hp[policy] = hp_last
		lines.append("%s: %s dawn HP %.1f of %.0f" % [policy, n, hp_last, Balance.data.build.diner_max_hp])
		assert_false(n.failed, "%s: no loss" % policy)
		assert_true(n.cleared, "%s holds the cap with 0 retries" % policy)
		assert_eq(GameState.night_fails, 0, "%s: 0 retries" % policy)
		assert_eq(growth, [], "%s: no pool grew" % policy)
		assert_eq(h.bot.stuck_count, 0, "%s: never stuck" % policy)
		assert_eq(h.bot.skipped_goals, 0, "%s: no skipped goal" % policy)
	gut.p("tier-3 cap, dawn diner HP: " + " | ".join(lines))
	gut.p("plan composition (lane -> kinds): " + comp_line)
	for p in TierBot.POLICIES:
		if p != "threat":
			assert_gte(hp["threat"], hp[p], "threat's dawn HP %.1f >= %s's %.1f" % [hp["threat"], p, hp[p]])

# ---- sim 7: respawn -------------------------------------------------------------------------------------------------

var _knock_times: Dictionary = {}  # guard id -> Array of elapsed seconds
var _revive_times: Dictionary = {}

func _on_ko(id: StringName) -> void:
	_knock_times[id] = _knock_times.get(id, []) + [h.elapsed]

func _on_revive(id: StringName) -> void:
	_revive_times[id] = _revive_times.get(id, []) + [h.elapsed]

func _enemies_in_zone(lane: String) -> int:
	var zone := MapLayout.zone_rect(lane).grow(0.3)  # a lane ends on the zone's far edge, which Rect2.has_point excludes
	var n := 0
	for e in h.main.world.wave_director.alive_enemies():
		if zone.has_point(Vector2(e.global_position.x, e.global_position.z)):
			n += 1
	return n

## Instrumented through the public signals guard_knocked_out and guard_revived (the hero has no HP, spec 6.6, so the guards are the actors
## that can be knocked out). The first tier-3 night is played by the tier bot from its start (the fixture's resume phase overridden to NIGHT: tower_sw and fence_sw unbuilt, the worst case for the zone); the moment the tank is posted and enemies stand in the
## south-west zone, the sim knocks the tank out through GameState.damage_guard (the same call an enemy's hit makes), so a guard really
## respawns into an occupied zone.
func test_7_a_guard_respawning_into_an_occupied_sw_zone_is_not_knocked_out_again_within_5_s() -> void:
	_knock_times = {}
	_revive_times = {}
	_start("tier3_night1", TierBot, 0, Callable(), "NIGHT")  # the night at once: the south-west spots are unbuilt, the zone fills
	EventBus.guard_knocked_out.connect(_on_ko)
	EventBus.guard_revived.connect(_on_revive)
	var forced := -1.0
	var occupied_at_revive := -1
	var seen_revive := 0
	for i in 60 * 150:
		await h.tick()
		if h.failed or h.main.phase_controller.phase == Phase.DAY:
			break
		var tank: Guard = h.main.world.guard_roster.guards.get(&"tank")
		if forced < 0.0 and tank != null and tank.state == Guard.State.POSTED and _enemies_in_zone("sw") > 0:
			forced = h.elapsed
			GameState.damage_guard(&"tank", 1e6)
		if _revive_times.get(&"tank", []).size() > seen_revive:
			seen_revive = _revive_times[&"tank"].size()
			if occupied_at_revive < 0:
				occupied_at_revive = _enemies_in_zone("sw")
		if forced >= 0.0 and seen_revive > 0 and h.elapsed > _revive_times[&"tank"][0] + 20.0:
			break
	EventBus.guard_knocked_out.disconnect(_on_ko)
	EventBus.guard_revived.disconnect(_on_revive)
	gut.p("forced knockout at %.1f s; knockouts %s; revives %s; enemies in the SW zone at the first revive: %d" % [forced, _knock_times, _revive_times, occupied_at_revive])
	assert_gte(forced, 0.0, "enemies reached the south-west zone and the tank was knocked out (not vacuous)")
	assert_gt(_revive_times.get(&"tank", []).size(), 0, "the tank respawned")
	assert_gt(occupied_at_revive, 0, "the south-west zone was occupied when the tank respawned")
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

# ---- sim 8: identity ------------------------------------------------------------------------------------------------

## Planner-level identity (the full sweep rows 1 to 7 are three planner sweeps of several minutes each: too slow for CI; `tools/baseline_rows.sh 7`
## runs them once per wave). Here: tier-1 and tier-2 plans equal the pinned file for every seed, and the tier-1 plans of days 1 to 7 carry exactly the
## enemy_count of the baseline sweep's rows 1 to 7 (tests/sim/baseline), so the row inputs are unchanged.
func test_8a_tier1_and_tier2_plans_and_the_sweep_row_inputs_are_unchanged() -> void:
	await get_tree().physics_frame  # one tick: a golden entry must be above 0 (a unit test pins it)
	var f := FileAccess.open("res://tests/fixtures/plans_tier12.json", FileAccess.READ)
	var fx: Dictionary = JSON.parse_string(f.get_as_text())["plans"]
	var tb := Balance.data.tiers
	var wb := Balance.data.wave
	assert_eq(fx.size(), 84)
	for key in fx:
		var parts: PackedStringArray = String(key).split(":")
		var tier := int(parts[1])
		var p := LanePlanner.plan(int(parts[0]), int(parts[2]), wb, tier, 1 if tier == 1 else 8, tb)
		var want: Array = fx[key]
		assert_eq(p.size(), want.size(), key)
		for w in want.size():
			for k in ["main", "side", "boss"]:
				assert_eq(p[w][k], want[w][k], "%s wave %d %s" % [key, w, k])
			for k in ["main_count", "side_count", "fast_main", "fast_side"]:
				assert_eq(int(p[w][k]), int(want[w][k]), "%s wave %d %s" % [key, w, k])
			assert_almost_eq(float(p[w].hp_mult), float(want[w].hp_mult), 1e-9, "%s wave %d hp_mult" % [key, w])
			assert_false(p[w].has("brute_main") or p[w].has("brute_side"), "%s: no brute keys below tier 3" % key)
	for sd in [20260930, 11, 777]:
		var rows := FileAccess.get_file_as_string("res://tests/sim/baseline/s4_sweep_%d.csv" % sd).split("\n", false)
		for day in range(1, 8):
			var cols := rows[day].split(",")
			assert_eq(int(cols[0]), day)
			var total := 0
			for w in LanePlanner.plan(sd, day, wb, 1, 1, tb):
				total += int(w.main_count) + int(w.side_count)
			assert_eq(total, int(cols[7]), "seed %d day %d: the plan's enemies equal the baseline row's enemy_count" % [sd, day])

## One tier-2 fixture night (slice 1's tier2_night1, played by the tier bot) ends with the diner HP and tick count recorded before this task.
## Mutation check: change the hare or Boar HP or a tower's damage and one of the two moves.
func test_8b_the_tier2_fixture_night_ends_as_recorded() -> void:
	_start("tier2_night1", TierBot)
	var f0 := Engine.get_physics_frames()
	hp_last = GameState.diner_hp
	EventBus.diner_damaged.connect(_track_hp)
	var n := await h.run_night()
	var ticks := Engine.get_physics_frames() - f0
	gut.p("tier-2 night 1: %s; ticks %d; diner HP %.4f" % [n, ticks, hp_last])
	assert_true(n.cleared)
	assert_eq(ticks, PINNED_TIER2_NIGHT.ticks, "the night's tick count is the recorded one")
	assert_almost_eq(hp_last, PINNED_TIER2_NIGHT.diner_hp, 1e-3, "the diner's HP at dawn is the recorded one")
