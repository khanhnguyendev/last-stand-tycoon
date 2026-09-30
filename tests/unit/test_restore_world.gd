extends GutTest
## Snapshot -> mutate everything -> restore -> world matches the snapshot, no pending transactions (spec 13.2,
## D-036, D-045). Every stateful node must rebuild from GameState on state_restored.

var main: Main
var pc: PhaseController

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	pc.start_new_game(61)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ring_progress(spot: BuildSpot) -> float:
	return float((spot.zone.ring.material_override as ShaderMaterial).get_shader_parameter("progress"))

func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

func _expected_scales(plan: Array) -> Dictionary:
	var threat := LanePlanner.threat_by_lane(plan, Balance.data.enemy.hp)
	var mx: float = threat.values().max()
	var out := {}
	for lane in threat:
		out[lane] = LanePlanner.marker_scale(threat[lane], mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
	return out

## Day 2, close-up snapshot (resume DAY). Awkward values on purpose: a partly paid fence, a level-1 tower, a level-2
## fence, a diner HP with no exact decimal form (D-146), stocks everywhere. The gold pile is patched into the dict
## because close_up() collects it.
func _make_snapshot() -> Dictionary:
	pc.debug_skip_to_day()
	GameState.add_gold(2000)
	GameState.pay_into_spot("tower_nw", GameState.next_level_cost("tower_nw"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))  # level 2
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n") - 5)  # leaves 5 to pay
	GameState.damage_fence("fence_w", 7.0)
	GameState.damage_diner(1.0 / 3.0)
	GameState.add_freezer(6)
	GameState.move_freezer_to_carry(2)
	GameState.move_carry_to_counter(1)
	pc.close_up()  # snapshot (resume DAY), now NIGHT
	var snap: Dictionary = pc.snapshot.duplicate(true)
	snap.gold_pile = 9
	pc.snapshot = snap.duplicate(true)
	return snap

## Waits (in DAY) until the front traveler is being served, then leaves no steaks so the service stays frozen.
func _wait_for_service() -> void:
	var sp := main.world.traveler_spawner
	var guard := 0
	while (sp.queue.is_empty() or sp.queue[0].service_timer <= 0.0) and guard < 60 * 30:
		await get_tree().physics_frame
		guard += 1

func _mutate_everything(snap: Dictionary) -> void:
	pc.debug_skip_to_day()
	GameState.add_gold(2000)
	GameState.pay_into_spot("tower_nw", GameState.next_level_cost("tower_nw"))  # level 2
	GameState.pay_into_spot("tower_ne", GameState.next_level_cost("tower_ne"))
	GameState.pay_into_spot("fence_n", 5)
	GameState.damage_fence("fence_w", 1e6)  # rubble
	GameState.damage_diner(40.0)
	GameState.add_freezer(9)
	GameState.move_freezer_to_carry(3)
	GameState.counter_steaks = 7
	GameState.gold_pile = 12
	GameState.advance_day()
	EventBus.stocks_changed.emit()
	main.hero.teleport(Vector2(15, 8))  # away from every station zone while we wait
	await _ticks(60 * 12)  # travelers arrive
	await _wait_for_service()
	assert_gt(main.world.traveler_spawner.queue.size(), 0, "precondition: a traveler is queued")
	assert_gt(main.world.traveler_spawner.queue[0].service_timer, 0.0, "precondition: a traveler is mid-service")
	# leave nothing to do, so the sign is pulsing when the restore hits
	GameState.freezer_steaks = 0
	GameState.carried_steaks = 0
	GameState.counter_steaks = 0
	GameState.gold_pile = 0
	GameState.gold = 0
	EventBus.stocks_changed.emit()
	# a real stand and hold on the sign (hold < closeup_hold, or the close-up would fire)
	await TestHelpers.walk_in(main.hero, MapLayout.SIGN)
	await _ticks(int(ceil((Balance.data.economy.stand_still_time + 0.3) * Engine.physics_ticks_per_second)))
	var sign: CloseUpSign = main.world.closeup_sign
	assert_true(sign.zone.standing, "precondition: standing on the sign")
	assert_gt(sign.hold, 0.0, "precondition: the sign hold has progress")
	assert_lt(sign.hold, Balance.data.economy.closeup_hold, "precondition: the close-up has not fired")
	assert_true(sign.pulsing, "precondition: the sign pulses before the restore")
	assert_ne(sign._visual.scale, Vector3.ONE, "precondition: the sign is mid-pulse")
	main.world.freezer.zone.armed = true  # as if the hero were also standing in it
	# world objects last, so nothing kills them while we wait
	for i in 5:
		main.world.steak_pool.acquire().place(Vector3(15, 0, 0))
	var boar := main.world.wave_director.debug_spawn("west")
	var dying := main.world.wave_director.debug_spawn("north")
	main.world.projectile_pool.acquire()
	var flying: Projectile = main.world.projectile_pool.acquire()
	flying.launch(Vector3(15, 1, 0), boar, boar.spawn_index, 1.0, 14.0, main.world.projectile_pool)
	dying.take_hit(1e9)  # mid-death tween, and drops steaks
	assert_eq(main.world.wave_director.alive_count(), 1, "precondition: a boar is alive")
	assert_eq(main.world.enemy_pool.active().size(), 2, "precondition: a boar is mid-death")
	# hidden attacker state
	var target := {"ref": boar, "spawn_index": boar.spawn_index}
	for a in [main.hero.attacker, main.world.build_spots.tower_nw.attacker, main.world.build_spots.tower_ne.attacker]:
		a._target = target
		a._cooldown = 1.0
		a._retarget = 1.0
	# the restore must have something to fix in the derived views
	assert_ne(GameState.lane_plan, snap.lane_plan, "precondition: the lane plan changed")
	var now_scales := _expected_scales(GameState.lane_plan)
	var snap_scales := _expected_scales(snap.lane_plan)
	var differs := false
	for lane in snap_scales:
		if absf(float(snap_scales[lane]) - float(now_scales[lane])) > 0.001:
			differs = true
	assert_true(differs, "precondition: some telegraph scale differs from the restored one")

## Everything the world shows must match `snap` (the state that was restored), DAY resumed.
func _assert_world_matches(snap: Dictionary) -> void:
	var w := main.world
	for pool in main.find_children("*", "NodePool", true, false):
		assert_eq(pool.active().size(), 0, "pool %s not empty" % pool.name)
	assert_eq(w.traveler_spawner.queue.size(), 0, "traveler queue")
	assert_eq(w.traveler_spawner.leaving.size(), 0, "travelers leaving")
	assert_eq(w.wave_director.alive_count(), 0, "alive boars in the director")
	assert_eq(w.wave_director.state, WaveDirector.State.IDLE, "no night is running")
	assert_true(w.traveler_spawner.active, "travelers resume in DAY")
	assert_eq(main.hero.xz(), MapLayout.HOME)
	assert_eq(pc.phase, Phase.DAY)
	assert_false(pc.failing)
	_assert_views_match(snap)

## The nodes that must rebuild from GameState on state_restored alone (no phase change, no recall).
func _assert_views_match(snap: Dictionary) -> void:
	var w := main.world
	var spots: Dictionary = w.build_spots
	for id in MapLayout.SPOT_IDS:
		var lvl := int(snap.buildings[id].level)
		var spot: BuildSpot = spots[id]
		assert_eq(spot.level, lvl, "%s level" % id)
		var pips := spot._pips.filter(func(p): return p.visible).size()
		assert_eq(pips, lvl, "%s visible pips" % id)
		var expect_scale := Vector3.ONE * pow(Balance.ui.build_level_scale, maxi(lvl - 1, 0))
		assert_almost_eq(spot.visual.scale, expect_scale, Vector3.ONE * 0.0001)
		assert_eq(spot.visual.visible, lvl >= 1, "%s visual" % id)
	assert_true(spots.tower_nw.attacker.enabled)
	assert_eq(spots.tower_nw.attacker.damage, Balance.data.build.tower_damage[0])
	assert_eq(spots.tower_nw.attacker.attack_range, Balance.data.build.tower_range[0])
	assert_false(spots.tower_ne.attacker.enabled)
	assert_eq(spots.tower_ne.label.text, str(GameState.next_level_cost("tower_ne")))
	assert_eq(spots.fence_n.label.text, "5")
	assert_true(spots.fence_n.zone.ring.visible)
	assert_almost_eq(_ring_progress(spots.fence_n), 15.0 / GameState.next_level_cost("fence_n"), 0.0001)
	assert_false(spots.tower_ne.zone.ring.visible)
	assert_false(spots.fence_w.is_rubble(), "fence rubble rebuilt from hp")
	assert_eq(GameState.buildings.fence_w.hp, snap.buildings.fence_w.hp)
	# attackers forget their targets and cooldowns
	for a in [main.hero.attacker, spots.tower_nw.attacker, spots.tower_ne.attacker]:
		assert_true(a._target.is_empty(), "attacker target cleared")
		assert_eq(a._cooldown, 0.0, "attacker cooldown")
	# stations
	assert_eq(w.freezer.label.text, str(snap.freezer_steaks))
	assert_eq(w.freezer.stack_count(), mini(int(snap.freezer_steaks), 10))
	assert_eq(w.counter.label.text, str(snap.counter_steaks))
	assert_eq(w.counter.stack_count(), int(snap.counter_steaks))
	assert_eq(w.gold_pile.coin_count(), int(snap.gold_pile))
	assert_eq(w.gold_pile.label.text, str(int(snap.gold_pile)) if int(snap.gold_pile) > 0 else "")
	assert_eq(main.hero.carry_stack.visible_count(), int(snap.carried_steaks))
	# sign: no pulse, no hold, not standing
	assert_false(w.closeup_sign.pulsing)
	assert_eq(w.closeup_sign._visual.scale, Vector3.ONE)
	assert_eq(w.closeup_sign.hold, 0.0, "sign hold")
	assert_false(w.closeup_sign.zone.standing, "sign standing")
	for zone in main.find_children("*", "StationZone", true, false):
		assert_false(zone.armed, "zone %s armed" % zone.get_parent().name)
		assert_false(zone.standing, "zone %s standing" % zone.get_parent().name)
	# telegraph markers
	var expected := _expected_scales(GameState.lane_plan)
	for lane in w.telegraph_markers:
		var m: TelegraphMarker = w.telegraph_markers[lane]
		assert_almost_eq(m.target_scale, float(expected[lane]), 0.0001)
		assert_eq(m.visible, float(expected[lane]) > 0.0, "marker %s visibility (DAY)" % lane)
		if float(expected[lane]) > 0.0:
			assert_almost_eq(m.scale.x, float(expected[lane]), 0.0001)

## After a restore nothing is pending: the state stays exactly the snapshot while the world runs (D-045).
func _assert_no_pending_transactions(snap: Dictionary) -> void:
	await _ticks(30)
	assert_eq(GameState.to_dict(), snap, "state drifted after the restore")

func test_restore_rebuilds_world_from_snapshot() -> void:
	var snap := _make_snapshot()
	await _mutate_everything(snap)
	pc.snapshot = snap.duplicate(true)
	pc._restore_snapshot()
	assert_eq(GameState.to_dict(), snap)
	assert_eq(GameState.diner_hp, float(snap.diner_hp), "exact diner HP")
	_assert_world_matches(snap)
	await _ticks(15)  # the dying boar's tween must not release or drop anything
	assert_eq(main.world.enemy_pool.active().size(), 0, "enemy pool after the death tween")
	assert_eq(main.world.steak_pool.active().size(), 0, "no steaks dropped after the restore")
	await _assert_no_pending_transactions(snap)

func test_from_dict_alone_rebuilds_every_view() -> void:
	# state_restored is the only trigger here: no recall, no phase change
	var snap := _make_snapshot()
	await _mutate_everything(snap)
	GameState.from_dict(snap)
	assert_eq(GameState.to_dict(), snap)
	_assert_views_match(snap)

func test_restore_from_json_round_trip_at_full_precision() -> void:
	var snap := _make_snapshot()
	assert_ne(float(JSON.parse_string(JSON.stringify(snap)).diner_hp), float(snap.diner_hp), "default precision must lose digits")
	await _mutate_everything(snap)
	var text := JSON.stringify(snap, "", true, true)  # D-146
	var parsed: Dictionary = JSON.parse_string(text)
	pc.snapshot = parsed
	pc._restore_snapshot()
	# ints come back as floats from JSON; from_dict casts them, so the state is exactly the original
	assert_eq(GameState.to_dict(), snap)
	assert_eq(GameState.diner_hp, float(snap.diner_hp), "exact diner HP after JSON")
	assert_eq(JSON.parse_string(JSON.stringify(GameState.to_dict(), "", true, true)), parsed)
	_assert_world_matches(snap)
	await _assert_no_pending_transactions(snap)

func test_fail_flow_restore_rebuilds_world() -> void:
	var snap := _make_snapshot()  # NIGHT now, resume DAY
	var wd := main.world.wave_director
	var a := wd.debug_spawn("west")
	wd.debug_spawn("east")
	GameState.damage_fence("fence_w", 1e6)
	for i in 3:
		main.world.steak_pool.acquire().place(Vector3(15, 0, 0))
	var flying: Projectile = main.world.projectile_pool.acquire()
	flying.launch(Vector3(15, 1, 0), a, a.spawn_index, 1.0, 14.0, main.world.projectile_pool)
	GameState.add_freezer(3)
	GameState.damage_diner(1e6)
	assert_true(pc.failing, "precondition: the diner fell")
	await _ticks(_fail_ticks())
	assert_false(pc.failing)
	assert_eq(GameState.to_dict(), snap)
	_assert_world_matches(snap)
	await _assert_no_pending_transactions(snap)

func test_night_restart_restore_rebuilds_world() -> void:
	# the new-game snapshot (resume NIGHT, D-043): restoring it after a played night puts the world at night 1 start
	var snap: Dictionary = pc.snapshot.duplicate(true)
	pc.debug_skip_to_day()
	GameState.add_gold(300)
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	GameState.add_freezer(5)
	GameState.gold_pile = 4
	EventBus.stocks_changed.emit()
	main.world.wave_director.debug_spawn("north")
	main.world.steak_pool.acquire().place(Vector3(15, 0, 0))
	await _ticks(60 * 5)
	pc.snapshot = snap.duplicate(true)
	pc._restore_snapshot()
	var wd := main.world.wave_director
	assert_eq(GameState.to_dict(), snap)
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(main.hero.xz(), MapLayout.NIGHT1_START)
	assert_eq(wd.alive_count(), 0)
	assert_eq(wd.state, WaveDirector.State.WAITING, "night 1 waits for its first spawn")
	assert_eq(wd.wave_index, -1)
	assert_false(main.world.traveler_spawner.active)
	assert_eq(main.world.build_spots.fence_n.level, 0)
	assert_false(main.world.build_spots.fence_n.visual.visible)
	assert_eq(main.world.freezer.label.text, "0")
	assert_eq(main.hero.carry_stack.visible_count(), int(snap.carried_steaks))
	assert_eq(main.world.gold_pile.coin_count(), int(snap.gold_pile))
	assert_false(main.world.closeup_sign.pulsing)
	for pool in main.find_children("*", "NodePool", true, false):
		assert_eq(pool.active().size(), 0, "pool %s not empty" % pool.name)
	for lane in main.world.telegraph_markers:
		assert_false(main.world.telegraph_markers[lane].visible, "telegraphs are day-only")
