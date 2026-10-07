extends GutTest

## A stand-in enemy for GuardRoster.guard_target: a position plus the monster stats it reads (E5).
class EnemyProbe:
	extends Node3D
	func stats() -> MonsterStats:
		return Balance.data.monsters.stats(&"boar")

var main: Main
var pc: PhaseController
var roster: GuardRoster

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(99)
	main.world.wave_director.stop()  # test setup: no scheduled waves; boars come from debug_spawn
	main.hero.teleport(Vector2(15, 8))  # hero out of every fight
	roster = main.world.guard_roster

func after_each() -> void:
	get_tree().paused = false
	Balance.reset()  # tier-3 tests append a tier cost; the next test starts clean
	GameState.new_game(1)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_hire_spawns_guards_at_posts() -> void:
	GameState.debug_grant_card(&"archer")
	var a: Guard = roster.guards[&"archer"]
	assert_eq(a.xz(), MapLayout.guard_post(&"archer"))
	assert_almost_eq(a.global_position.y, MapLayout.DINER_HEIGHT, 1e-4)
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.RETURNING, "a new Tank walks in from the door")
	await _ticks(60 * 8)
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(t.xz(), MapLayout.guard_post(&"tank"))

func test_upgrade_card_spawns_no_guard() -> void:
	GameState.debug_grant_card(&"move_speed")
	assert_eq(roster.guards.size(), 0)

func test_archer_is_never_targeted() -> void:
	GameState.debug_grant_card(&"archer")
	for lane in ["west", "north", "east"]:
		var b: Boar = main.world.wave_director.debug_spawn(lane)
		b.dist = b.path_length()
		b._update_position()
		assert_eq(roster.guard_target(b), {}, lane)
	var probe := EnemyProbe.new()
	add_child_autofree(probe)
	probe.global_position = roster.guards[&"archer"].global_position
	assert_eq(roster.guard_target(probe), {}, "in reach but never targeted")
	assert_false(roster.guards[&"archer"].is_targetable())

func test_archer_kills_a_north_boar() -> void:
	GameState.debug_grant_card(&"archer")
	var b: Boar = main.world.wave_director.debug_spawn("north")
	var killed := false
	for i in 60 * 20:
		await get_tree().physics_frame
		if not b.alive:
			killed = true
			break
	assert_true(killed, "the roof archer kills a north boar")

func test_tank_stops_a_west_boar_and_takes_damage() -> void:
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var b: Boar = main.world.wave_director.debug_spawn("west")
	var engaged := false
	for i in 60 * 25:
		await get_tree().physics_frame
		if not b.alive:
			break
		if b.current_target.get("kind", &"") == &"guard":
			engaged = true
	assert_true(engaged, "the boar targeted the tank")
	assert_lt(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"), "the tank took hits")
	assert_lt(b.dist, b.path_length() - 1.0, "the boar never reached the diner")

func test_boar_walks_on_after_tank_knockout() -> void:
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var b: Boar = main.world.wave_director.debug_spawn("west")
	var engaged := false
	for i in 60 * 25:
		await get_tree().physics_frame
		if b.current_target.get("kind", &"") == &"guard":
			engaged = true
			if float(GameState.guards[&"tank"].hp) < GameState.guard_max_hp(&"tank"):
				break
	assert_true(b.alive)
	assert_true(engaged)
	var held := b.dist
	GameState.damage_guard(&"tank", 1e6)
	await _ticks(30)
	assert_gt(b.dist, held, "the boar walks on once the tank is down")

func test_knockout_respawn_at_door_then_return() -> void:
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var t: Guard = roster.guards[&"tank"]
	GameState.damage_guard(&"tank", 1e6)
	assert_eq(t.state, Guard.State.DOWN)
	assert_false(t.is_targetable())
	await _ticks(12)
	assert_false(t.visual.visible, "the knockout poof hides the guard")
	var b: Boar = main.world.wave_director.debug_spawn("west")
	b.dist = MapLayout.path_length("west") - MapLayout.TANK_POST_BACK - 1.0
	b._update_position()
	assert_eq(roster.guard_target(b), {}, "a downed tank is not a target")
	await _ticks(int(ceil(Balance.data.guards.tank.respawn_s * 60.0)) + 2 - 12)  # 12 ticks already waited above
	assert_eq(t.state, Guard.State.RETURNING)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_lt(t.xz().distance_to(MapLayout.DINER_DOOR), 0.2, "respawns at the door")
	await _ticks(60 * 8)
	assert_eq(t.state, Guard.State.POSTED)
	assert_true(t.visual.visible)
	assert_almost_eq(t.visual.scale.x, 1.0, 1e-3, "the respawned tank is full size")

func test_knockout_and_revive_restore_visual() -> void:
	# Review Focus 2: a Tank knocked out and revived repeatedly is never left invisible, half-scaled or stuck in Hit_A.
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var tank: Guard = roster.guards[&"tank"]
	var poof_ticks := int(ceil(0.15 * 60.0)) + 2  # poof(true) tweens the root from 0.01 over 0.15 s
	for cycle in 3:
		tank.visual.hit()
		GameState.damage_guard(&"tank", 1e6)
		assert_eq(tank.state, Guard.State.DOWN, "cycle %d" % cycle)
		await _ticks(poof_ticks)
		assert_false(tank.visual.visible, "cycle %d: the poof hid it" % cycle)
		await _ticks(int(ceil(Balance.data.guards.tank.respawn_s * 60.0)) + 2)  # revives, then arrive_from_door
		assert_eq(tank.state, Guard.State.RETURNING, "cycle %d" % cycle)
		tank.visual._last_hit_ms = -1000000000  # the throttle is wall-clock: clear it so this hit() really fires
		tank.visual.hit()  # a Hit_A in flight when the walk-in starts must be cut off by reset()
		await get_tree().physics_frame
		assert_true(tank.visual.anim_tree.get("parameters/react/active"), "cycle %d: Hit_A in flight" % cycle)
		tank.arrive_from_door()
		await _ticks(poof_ticks)
		assert_true(tank.visual.visible, "cycle %d" % cycle)
		assert_almost_eq(tank.visual.scale, Vector3.ONE, Vector3.ONE * 1e-3, "cycle %d root scale" % cycle)
		assert_eq(tank.visual.body.position, Vector3.ZERO)
		assert_eq(tank.visual.body.scale, Vector3.ONE)
		assert_false(tank.visual.anim_tree.get("parameters/react/active"), "cycle %d: not stuck in Hit_A" % cycle)
		tank.place_at_post()

func test_guard_bar_is_palette_boxes_outside_the_visual() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.visual.name, &"Visual")
	assert_true(t._bar.get_parent() == t and t._bar_back.get_parent() == t, "the bar is not under Visual")
	assert_true(t._bar.mesh is BoxMesh and t._bar_back.mesh is BoxMesh)
	assert_eq((t._bar.material_override as StandardMaterial3D).albedo_color, Palette.color(&"guard_green"))
	assert_eq((t._bar_back.material_override as StandardMaterial3D).albedo_color, Palette.color(&"ink"))
	t.place_at_post()
	GameState.damage_guard(&"tank", GameState.guard_max_hp(&"tank") * 0.5)
	assert_true(t._bar.visible and t._bar_back.visible)

func test_guard_visual_follows_motion_and_attacks() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.RETURNING)
	await _ticks(30)
	assert_gt(float(t.visual.anim_tree.get("parameters/loco/blend_position")), 0.9, "walking in: full motion blend")
	await _ticks(60 * 8)
	assert_eq(t.state, Guard.State.POSTED)
	assert_almost_eq(float(t.visual.anim_tree.get("parameters/loco/blend_position")), 0.0, 1e-4, "posted: idle")
	var b: Boar = main.world.wave_director.debug_spawn("west")
	var attacked := false
	for i in 60 * 20:
		await get_tree().physics_frame
		if t.visual.anim_tree.get("parameters/action/active"):
			attacked = true
			break
	assert_true(attacked, "the tank swings when its attacker fires")
	assert_not_null(b)

func test_hp_bar_follows_signals() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	assert_false(t._bar.visible)
	var mx := GameState.guard_max_hp(&"tank")
	GameState.damage_guard(&"tank", mx * 0.25)
	assert_true(t._bar.visible)
	assert_almost_eq(t._bar.scale.x, 0.75, 1e-3)
	GameState.damage_guard(&"tank", 1e6)
	assert_false(t._bar.visible, "a knockout hides the bar")
	EventBus.wave_cleared.emit(2)  # dawn
	assert_eq(t.state, Guard.State.POSTED)
	assert_false(t._bar.visible, "full HP at dawn: no bar")

func test_respawn_timer_pauses_with_the_tree() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	GameState.damage_guard(&"tank", 1e6)
	var frames := int(ceil(Balance.data.guards.tank.respawn_s * 60.0))
	get_tree().paused = true
	for i in frames + 30:
		await get_tree().process_frame
	var state_paused := t.state
	get_tree().paused = false
	await _ticks(frames + 2)
	var state_after := t.state
	assert_eq(state_paused, Guard.State.DOWN, "no respawn while paused")
	assert_eq(state_after, Guard.State.RETURNING)

func test_dawn_restores_a_downed_tank() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.damage_guard(&"tank", 1e6)
	EventBus.wave_cleared.emit(2)  # dawn
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(t.xz(), MapLayout.guard_post(&"tank"))
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	await _ticks(int(ceil(Balance.data.guards.tank.respawn_s * 60.0)) + 2)
	assert_eq(t.state, Guard.State.POSTED, "no respawn timer carried into the day")

func test_level_up_reconfigures() -> void:
	var ts := Balance.data.guards.tank
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_almost_eq(t.attacker.damage, ts.damage, 1e-5)
	GameState.debug_grant_card(&"tank")
	assert_almost_eq(t.attacker.damage, ts.damage * (1.0 + ts.damage_growth), 1e-5)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_eq(roster.guards.size(), 1, "a duplicate levels up; no second tank")

func test_occluder_points_include_visible_guards() -> void:
	GameState.debug_grant_card(&"archer")
	assert_eq(roster.occluder_points().size(), 1)
	GameState.debug_grant_card(&"tank")
	roster.guards[&"tank"].place_at_post()
	assert_eq(roster.occluder_points().size(), 2)
	GameState.damage_guard(&"tank", 1e6)
	await _ticks(12)
	assert_eq(roster.occluder_points().size(), 1)

func test_priority_fence_then_guard_then_diner() -> void:
	assert_eq(Array(Balance.data.wave.target_priority.kinds), [&"fence_on_lane", &"guard", &"diner"])
	GameState.debug_grant_card(&"tank")
	main.world.guard_roster.guards[&"tank"].place_at_post()  # skip the walk in from the door
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	var b: Boar = main.world.wave_director.debug_spawn("west")
	b.dist = TargetProviders.fence_stop_dist(b)
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"fence_on_lane")
	GameState.damage_fence("fence_w", 1e6)
	b.dist = b.path_length() - MapLayout.TANK_POST_BACK - 1.0
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"guard")
	GameState.damage_guard(&"tank", 1e6)
	b.dist = b.path_length()
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"diner")

# --- E5 tier 3 Task 13: respawn protection (D-271, spec 6.6) ---

## Knocks the tank out through GameState and ticks until the guard revives (state RETURNING). Returns the ticks used.
func _knock_out_and_wait_for_revive() -> int:
	GameState.damage_guard(&"tank", 1e6)
	var n := 0
	while roster.guards[&"tank"].state != Guard.State.RETURNING and n < 60 * 40:
		await get_tree().physics_frame
		n += 1
	return n

func _tier3_with_tank_at_post(tank_max_hp := -1.0) -> Guard:
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)  # test-only: the build knows tier 3
	GameState.debug_set_tier(3, 5)
	if tank_max_hp > 0.0:
		Balance.data.guards.tank.max_hp = tank_max_hp
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	return t

func _probe_near(g: Guard) -> EnemyProbe:
	var e := EnemyProbe.new()
	add_child_autofree(e)
	e.global_position = Vector3(g.xz().x, 0.0, g.xz().y)
	return e

func test_revived_guard_is_untargetable_for_respawn_protect_s_then_targetable() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	var ticks := await _knock_out_and_wait_for_revive()
	assert_lt(ticks, 60 * 40, "the guard revived")
	# We are on the revive frame (the guard revived this tick; its timer has not run yet).
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"), "revived at full HP")
	var probe := _probe_near(t)
	assert_eq(roster.guard_target(probe), {}, "protected on the revive frame")
	# ceil(1.5 * 60) = 90: the read after the 89th tick still shows protection, the read after the 90th shows targetable.
	var frames := 0
	while frames < 200:
		await get_tree().physics_frame
		frames += 1
		probe.global_position = Vector3(t.xz().x, 0.0, t.xz().y)
		if not roster.guard_target(probe).is_empty():
			break
	assert_eq(frames, 90, "targetable on the first physics frame after 1.5 s (frame 90)")
	assert_true(t.is_targetable())

func test_protected_guard_walks_to_its_post() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	await _knock_out_and_wait_for_revive()
	var post := MapLayout.guard_post(&"tank")
	var d_prev := t.xz().distance_to(post)
	for i in 89:  # every tick the read still shows protection
		await get_tree().physics_frame
		var d := t.xz().distance_to(post)
		assert_lt(d, d_prev, "tick %d: closer to the post" % (i + 1))
		assert_eq(t.state, Guard.State.RETURNING, "tick %d: still walking" % (i + 1))
		assert_false(t.is_targetable(), "tick %d: still protected" % (i + 1))
		d_prev = d

func test_protection_ends_at_the_post_whatever_the_tuning() -> void:
	Balance.data.guards.respawn_protect_s = 10.0
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	await _knock_out_and_wait_for_revive()
	var n := 0
	while t.state != Guard.State.POSTED and n < 60 * 20:
		assert_false(t.is_targetable(), "protected while walking")
		await get_tree().physics_frame
		n += 1
	assert_eq(t.state, Guard.State.POSTED)
	assert_true(t.is_targetable(), "targetable on the first frame after it is posted, 10 s protection or not")

func test_protected_state_is_set_before_guard_revived_is_emitted() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	var seen := [null]
	var on_revived := func(g: StringName): seen[0] = t._protect_left > 0.0
	EventBus.guard_revived.connect(on_revived)
	await _knock_out_and_wait_for_revive()
	EventBus.guard_revived.disconnect(on_revived)
	assert_eq(seen[0], true, "a guard_revived listener already sees the protection")

func test_knockout_during_protection_clears_it() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	await _knock_out_and_wait_for_revive()
	await _ticks(5)
	assert_gt(t._protect_left, 0.0)
	GameState.damage_guard(&"tank", 1e6)
	assert_eq(t.state, Guard.State.DOWN)
	assert_eq(t._protect_left, 0.0, "no protection carried through the knockout")

func test_guard_never_knocked_out_is_targetable() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	assert_true(t.is_targetable())
	assert_false(roster.guard_target(_probe_near(t)).is_empty(), "the rule does not leak to a guard that was never down")
	await _ticks(5)
	assert_true(t.is_targetable())

func test_fresh_hire_walking_from_the_door_is_targetable() -> void:
	# A hire is not a respawn: no monster exists in the day, and the rule is about respawns (D-271).
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.RETURNING)
	assert_true(t.is_targetable())

func test_zero_protection_restores_todays_behaviour() -> void:
	Balance.data.guards.respawn_protect_s = 0.0
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	await _knock_out_and_wait_for_revive()
	assert_true(t.is_targetable(), "targetable on the frame it revives")
	assert_false(roster.guard_target(_probe_near(t)).is_empty())

func test_save_restore_mid_protection_places_the_guard_at_its_post_unprotected() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	t.place_at_post()
	await _knock_out_and_wait_for_revive()
	assert_false(t.is_targetable())
	EventBus.state_restored.emit()
	assert_eq(t.state, Guard.State.POSTED)
	assert_true(t.is_targetable(), "protection is not saved: a restored guard stands at its post")

## Three boars standing at the end of the south-west lane (inside the zone that contains the diner door).
func _three_sw_boars() -> Array:
	var out: Array = []
	for i in 3:
		var b: Boar = main.world.wave_director.debug_spawn("sw", float(i - 1) * 0.5, 200.0)
		b.dist = b.path_length()
		b._update_position()
		out.append(b)
	return out

## Runs the three-boar scene: the tank (tank_max_hp, so one volley of 3 x 5 is lethal) is knocked out, respawns at the
## door inside the SW zone. Right after the revive the boars' attack timers are set to 0.95 (a strike within 3 ticks;
## without it the 1 s cadence is phase-locked to miss the 0.5 s the guard spends in reach). Over the first 90 ticks
## it counts the boars in reach and the boars whose current target is the guard, and the knockouts over 5 s.
func _respawn_into_three_boars(tank_max_hp: float) -> Dictionary:
	_tier3_with_tank_at_post(tank_max_hp)
	var boars := _three_sw_boars()
	await _ticks(10)
	var ticks := await _knock_out_and_wait_for_revive()
	assert_lt(ticks, 60 * 40, "the guard revived")
	for b in boars:
		b._attack_timer = 0.95
	var g: Guard = roster.guards[&"tank"]
	var downs := [0]
	var on_ko := func(_g: StringName): downs[0] += 1
	EventBus.guard_knocked_out.connect(on_ko)
	var out := {"in_reach": 0, "targeted": 0, "knockouts_5s": 0, "knockouts_1_5s": 0}
	for i in 60 * 5:
		await get_tree().physics_frame
		if i < 90:
			for b in boars:
				var reach: float = b.stats().reach + float(g.stats.body_radius)
				if Vector2(b.global_position.x, b.global_position.z).distance_to(g.xz()) <= reach:
					out.in_reach += 1
				if b.current_target.get("kind", &"") == &"guard":
					out.targeted += 1
			if i == 89:
				out.knockouts_1_5s = downs[0]
	EventBus.guard_knocked_out.disconnect(on_ko)
	out.knockouts_5s = downs[0]
	return out

func test_respawned_guard_is_not_targeted_or_knocked_out_in_the_sw_zone_with_three_boars() -> void:
	var r: Dictionary = await _respawn_into_three_boars(10.0)
	gut.p("T13 info: protected, 10 hp tank: %s" % [r])
	assert_gt(r.in_reach, 0, "boars were within reach of the guard (the scene is live)")
	assert_eq(r.targeted, 0, "no boar targeted the protected guard in the first 90 ticks")
	assert_eq(r.knockouts_5s, 0, "not knocked out again within 5 s of reviving")

func test_control_without_protection_the_same_scene_knocks_the_guard_out() -> void:
	Balance.data.guards.respawn_protect_s = 0.0
	var r: Dictionary = await _respawn_into_three_boars(10.0)
	gut.p("T13 info: NO protection, 10 hp tank: %s" % [r])
	assert_gt(r.targeted, 0, "unprotected, the boars target the respawned guard")
	assert_gte(r.knockouts_5s, 1, "unprotected, one volley knocks the guard out again")

## The diner's HP after 10 s with three boars at the SW end. delay = ticks between the spawn and the knockout.
func _diner_hp_after_10_s(with_guard: bool, protect_s: float, delay: int) -> float:
	Balance.data.guards.respawn_protect_s = protect_s
	GameState.new_game(1)
	main.hero.teleport(Vector2(15, 8))
	if with_guard:
		_tier3_with_tank_at_post()
	else:
		if Balance.data.tiers.tier_costs.size() < 3:
			Balance.data.tiers.tier_costs.append(1500)
		GameState.debug_set_tier(3, 5)
	await _ticks(5)
	var boars := _three_sw_boars()
	await _ticks(delay)
	if with_guard:
		GameState.damage_guard(&"tank", 1e6)
	await _ticks(60 * 10 - delay)
	var hp := GameState.diner_hp
	main.world.wave_director.debug_kill_all()
	return hp

func test_diner_pressure_with_and_without_a_respawning_guard() -> void:
	var none := await _diner_hp_after_10_s(false, 1.5, 0)
	var prot := await _diner_hp_after_10_s(true, 1.5, 0)
	var lo := INF
	var hi := -INF
	for delay in [0, 10, 20, 30, 40, 50]:
		var hp := await _diner_hp_after_10_s(true, 0.0, delay)
		lo = minf(lo, hp)
		hi = maxf(hi, hp)
	gut.p("T13 info: diner HP after 10 s (max %.0f): no guard %.1f; protected respawn %.1f; unprotected respawn min %.1f max %.1f" % [
		Balance.data.build.diner_max_hp, none, prot, lo, hi])
	assert_eq(prot, none, "a protected guard diverts nothing from the diner")
	assert_gt(hi, none, "unprotected, the respawned guard absorbs at least one strike in some phase")
