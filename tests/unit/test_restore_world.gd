extends GutTest
## Snapshot -> mutate everything -> restore -> world matches the snapshot, no pending transactions (spec 13.2,
## D-036, D-045). Every stateful node must rebuild from GameState on state_restored.

var main: Main
var pc: PhaseController
var _boars: Array = []  # the boars the mutation left alive and dying, to check their flash after the restore

func before_each() -> void:
	_boars = []
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
	# a build finishing right before the restore leaves its pop tween running. tower_ne is level 1 here and level 0
	# in the snapshot, so a surviving pop would end at the level-2 scale, not the restored scale 1.
	assert_eq(GameState.buildings.tower_ne.level, 1, "precondition: tower_ne is level 1")
	GameState.add_gold(5000)
	GameState.pay_into_spot("tower_ne", GameState.next_level_cost("tower_ne"))  # level 2, pop starts
	GameState.gold = 0
	EventBus.stocks_changed.emit()
	assert_eq(GameState.buildings.tower_ne.level, 2, "precondition: tower_ne is level 2")
	assert_gt(main.world.build_spots.tower_ne.visual.scale.x, 1.001, "precondition: the build pop is running")
	# visual-only leftovers: a transfer in flight, arrows on screen, hit flashes, a camera shake
	main.world.fly_fx.fly("coin", Vector3.ZERO, Vector3(2, 0, 2))
	assert_eq(main.world.fly_fx.in_flight(), 1, "precondition: a transfer is in flight")
	EventBus.wave_incoming.emit(0, &"west", &"north")
	assert_true(main.hud.arrows.main.visible, "precondition: an arrow is shown")
	boar.take_hit(1.0)
	assert_true(boar.flash_active(), "precondition: the boar flashes")
	_boars = [boar, dying]
	assert_true(dying.flash_active(), "precondition: the dying boar flashes")
	EventBus.diner_damaged.emit(1.0, GameState.diner_hp)
	assert_gt(main.camera_rig._shake_left, 0.0, "precondition: the camera shakes")
	_displace_camera()
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

## The camera is somewhere else when the restore hits (the hero is placed by the restore, the camera must follow).
func _displace_camera() -> void:
	main.camera_rig.snap_to(Vector2(12, -12))
	var far := main.camera_rig.camera.global_position
	var home := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), Balance.ui).origin
	assert_gt(far.distance_to(home), 1.0, "precondition: the camera is away from HOME")
	var start := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.NIGHT1_START), Balance.ui).origin
	assert_gt(far.distance_to(start), 1.0, "precondition: the camera is away from NIGHT1_START")

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
	_assert_hud_camera_fx(snap, true, MapLayout.HOME)

func _assert_hud_values(snap: Dictionary) -> void:
	var hud := main.hud
	assert_eq(hud.gold_label.text, str(snap.gold), "hud gold")
	# ProgressBar rounds its value to its step (0.01), so the exact HP lives in GameState, not in the bar
	assert_almost_eq(hud.diner_bar.value, float(snap.diner_hp), hud.diner_bar.step, "hud diner bar")
	assert_eq(hud.day_label.text, tr("Day %d") % int(snap.day), "hud day label")

## HUD, camera and visual-only FX after a restore. `day`: the restore resumed DAY (else the night-1 restart).
func _assert_hud_camera_fx(snap: Dictionary, day: bool, hero_pos: Vector2) -> void:
	var hud := main.hud
	_assert_hud_values(snap)
	if day:
		assert_false(hud.arrows.main.visible, "hud main arrow")
		assert_false(hud.arrows.side.visible, "hud side arrow")
		assert_true(hud.day_label.visible, "hud day label visible in DAY")
		for m in hud.moons:
			assert_false(m.visible, "moons are night-only")
	else:
		assert_eq(hud.moons.size(), GameState.lane_plan.size(), "one moon per planned wave")
		assert_eq(hud.filled_moons(), 0, "no moon filled at night 1 start")
		for m in hud.moons:
			assert_true(m.visible, "moons are shown at night")
		# night 1 restarts with its first wave announced (start_night -> wave_incoming)
		var first: Dictionary = GameState.lane_plan[0]
		assert_eq(hud._arrow_lane.main, String(first.main), "main arrow lane")
		assert_eq(hud.arrows.main.visible, String(first.main) != "")
		assert_eq(hud.arrows.side.visible, String(first.side) != "", "side arrow only when the wave has a side lane")
	var expect := CameraMath.camera_transform(CameraMath.focus_for(hero_pos), Balance.ui)
	var got := main.camera_rig.camera.global_transform
	assert_almost_eq(got.origin, expect.origin, Vector3.ONE * 0.001, "camera position (before any _process)")
	assert_true(got.basis.is_equal_approx(expect.basis), "camera basis")
	assert_lte(main.camera_rig._shake_left, 0.0, "camera shake cleared")
	assert_eq(main.world.fly_fx.in_flight(), 0, "no transfer in flight")
	for b in _boars:
		assert_false(b.flash_active(), "recalled boar does not flash")

## D-197: the level scale is 1.0, so a surviving pop tween no longer shows as a wrong scale. Assert it is dead, right
## after the restore (a finished tween is not valid either, so this must run before any waiting).
func _assert_pops_killed() -> void:
	for id in MapLayout.SPOT_IDS:
		var spot: BuildSpot = main.world.build_spots[id]
		assert_false(spot._pop != null and spot._pop.is_valid(), "%s: pop tween killed by restore" % id)

## Visual tweens that outlive the restore would show up a little later: wait them out.
func _assert_no_late_visuals(snap: Dictionary) -> void:
	await _ticks(int(ceil(maxf(Balance.ui.transfer_arc_time, Balance.ui.build_pop_time) * Engine.physics_ticks_per_second)) + 2)
	# Only checks the recall: an abandoned transfer is gone. Killing the FlyFx tween on release is test_fx.gd's job.
	assert_eq(main.world.fly_fx.in_flight(), 0, "still no transfer in flight")
	for id in MapLayout.SPOT_IDS:
		var lvl := int(snap.buildings[id].level)
		var expect_scale := Vector3.ONE * pow(Balance.ui.build_level_scale, maxi(lvl - 1, 0))
		assert_almost_eq(main.world.build_spots[id].visual.scale, expect_scale, Vector3.ONE * 0.0001, "%s scale after the pop time" % id)
	for b in _boars:
		assert_false(b.flash_active())

## The nodes that must rebuild from GameState on state_restored alone (no phase change, no recall).
func _assert_views_match(snap: Dictionary) -> void:
	var w := main.world
	_assert_hud_values(snap)
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
	assert_true(spots.fence_n.label.visible, "cost labels are shown in DAY")
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
	_assert_pops_killed()
	assert_eq(GameState.to_dict(), snap)
	assert_eq(GameState.diner_hp, float(snap.diner_hp), "exact diner HP")
	_assert_world_matches(snap)
	await _ticks(15)  # the dying boar's tween must not release or drop anything
	assert_eq(main.world.enemy_pool.active().size(), 0, "enemy pool after the death tween")
	assert_eq(main.world.steak_pool.active().size(), 0, "no steaks dropped after the restore")
	await _assert_no_pending_transactions(snap)
	await _assert_no_late_visuals(snap)

func test_from_dict_alone_rebuilds_every_view() -> void:
	# state_restored is the only trigger here: no recall, no phase change
	var snap := _make_snapshot()
	await _mutate_everything(snap)
	GameState.from_dict(snap)
	_assert_pops_killed()
	assert_eq(GameState.to_dict(), snap)
	_assert_views_match(snap)

func test_restore_piles_show_exact_counts() -> void:
	GameState.freezer_steaks = 5  # test-only setup write
	EventBus.stocks_changed.emit()
	assert_eq(main.world.freezer.stack_count(), 5)
	var snap := GameState.to_dict()
	snap.counter_steaks = Balance.data.economy.counter_capacity
	snap.freezer_steaks = 0
	snap.carried_steaks = 3
	GameState.from_dict(snap)
	assert_eq(main.world.counter.stack_count(), Balance.data.economy.counter_capacity)
	assert_eq(main.world.freezer.stack_count(), 0)
	assert_eq(main.hero.carry_stack.visible_count(), 3)

func test_restore_from_json_round_trip_at_full_precision() -> void:
	var snap := _make_snapshot()
	assert_ne(float(JSON.parse_string(JSON.stringify(snap)).diner_hp), float(snap.diner_hp), "default precision must lose digits")
	await _mutate_everything(snap)
	var text := JSON.stringify(snap, "", true, true)  # D-146
	var parsed: Dictionary = JSON.parse_string(text)
	pc.snapshot = parsed
	pc._restore_snapshot()
	_assert_pops_killed()
	# ints come back as floats from JSON; from_dict casts them, so the state is exactly the original
	assert_eq(GameState.to_dict(), snap)
	assert_eq(GameState.diner_hp, float(snap.diner_hp), "exact diner HP after JSON")
	assert_eq(JSON.parse_string(JSON.stringify(GameState.to_dict(), "", true, true)), parsed)
	_assert_world_matches(snap)
	await _assert_no_pending_transactions(snap)
	await _assert_no_late_visuals(snap)

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
	snap.night_fails = 1  # a failed night carries one mercy step (S3 spec 6)
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
	main.world.fly_fx.fly("coin", Vector3.ZERO, Vector3(2, 0, 2))
	EventBus.wave_cleared.emit(0)
	assert_eq(main.hud.filled_moons(), 1, "precondition: a moon is filled")
	_displace_camera()
	pc.snapshot = snap.duplicate(true)
	pc._restore_snapshot()
	_assert_hud_camera_fx(snap, false, MapLayout.NIGHT1_START)
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
	assert_false(main.world.build_spots.fence_n.label.visible, "cost labels are hidden at night")
	assert_eq(main.world.freezer.label.text, "0")
	assert_eq(main.hero.carry_stack.visible_count(), int(snap.carried_steaks))
	assert_eq(main.world.gold_pile.coin_count(), int(snap.gold_pile))
	assert_false(main.world.closeup_sign.pulsing)
	for pool in main.find_children("*", "NodePool", true, false):
		assert_eq(pool.active().size(), 0, "pool %s not empty" % pool.name)
	for lane in main.world.telegraph_markers:
		assert_false(main.world.telegraph_markers[lane].visible, "telegraphs are day-only")

func test_restore_cancels_a_camera_shake_in_progress() -> void:
	var snap := _make_snapshot()
	EventBus.diner_damaged.emit(1.0, GameState.diner_hp)
	assert_gt(main.camera_rig._shake_left, 0.0, "precondition: shaking")
	pc.snapshot = snap.duplicate(true)
	pc._restore_snapshot()
	assert_lte(main.camera_rig._shake_left, 0.0)
	var n: int = main.camera_rig.shake_count
	EventBus.diner_damaged.emit(1.0, GameState.diner_hp)
	assert_eq(main.camera_rig.shake_count, n + 1, "first hit after a restore shakes")

func test_restore_unfades_the_diner() -> void:
	var snap := _make_snapshot()  # NIGHT now, resume DAY
	var fade: OccluderFade = main.world.occluder_fade
	main.hero.teleport(MapLayout.HOME)
	main.camera_rig.snap()
	var b := main.world.wave_director.debug_spawn("north")
	b.set_physics_process(false)
	var d := 0.0
	while EnemyPath.position_at("north", d, 0.0, Balance.data.enemy.offset_fade_distance).y < -9.0:
		d += 0.05
	b.dist = d
	b._update_position()
	var frames := int(ceil(Balance.ui.occluder_fade_s * 60.0)) + 2
	for i in frames + 30:
		await get_tree().process_frame
	assert_true(fade.is_faded(), "precondition: the boar behind the diner fades it")
	pc.snapshot = snap.duplicate(true)
	pc._restore_snapshot()
	for i in frames + 30:
		await get_tree().process_frame
	assert_false(fade.is_faded(), "opaque again after the restore recalled the boar")

func test_restore_brings_back_cards_and_guards() -> void:
	var step: float = Balance.data.cards.damage_step
	var base: float = Balance.data.hero.attack_damage
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	pc.close_up()  # snapshot: tank 1, hero_damage 1
	await get_tree().physics_frame
	GameState.debug_grant_card(&"hero_damage")  # level 2 after the snapshot
	assert_almost_eq(main.hero.attacker.damage, base * (1.0 + step * 2.0), 1e-5)
	var t: Guard = main.world.guard_roster.guards[&"tank"]
	GameState.damage_guard(&"tank", 1e6)  # knocked out at night
	assert_eq(t.state, Guard.State.DOWN)
	assert_gt(Balance.data.guards.tank.respawn_s, Balance.ui.banner_time + 0.1, "restore must beat the respawn")
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(t.xz(), MapLayout.guard_post(&"tank"))
	assert_true(t.visual.visible)
	assert_almost_eq(t.visual.scale.x, 1.0, 1e-3)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_eq(GameState.card_level(&"hero_damage"), 1)
	assert_almost_eq(main.hero.attacker.damage, base * (1.0 + step), 1e-5)
	assert_false(main.hero.input.blocked)
	assert_false(main.card_overlay.visible)

func test_new_game_from_the_open_card_pick() -> void:
	EventBus.wave_cleared.emit(2)
	assert_true(main.card_overlay.visible)
	assert_true(main.hero.input.blocked)
	pc.start_new_game(5)
	assert_false(main.card_overlay.visible)
	assert_false(main.hero.input.blocked)

func test_new_game_removes_guards() -> void:
	GameState.debug_grant_card(&"archer")
	GameState.debug_grant_card(&"tank")
	pc.start_new_game(5)
	await get_tree().process_frame
	assert_eq(main.world.guard_roster.guards.size(), 0)
	assert_eq(main.hud.card_strip.text, "")
