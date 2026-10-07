extends GutTest
## E5 tier 3 Task 11 (spec 3.3, 3.4, 6.3; D-267, D-274.2): Baron von Hop, the boss of the tier-2 boss night.
## Literals: Baron HP 500, speed 2.4, damage 12 per 1.0 s, reach 1.6, 150 steaks; diner HP 300; hero speed 5.0, attack range 4.0.
## Hold check by hand (slice 1, boss_min_hold_s 15): hits = ceil(300 / 12) = 25; the first hit lands one interval after the Baron
## arrives, the 25th 24 intervals later: 24.0 s from the first hit to the fall (mercy factor 1.0 on a first attempt).

const DT := 1.0 / 60.0
const LANES := ["west", "north", "east"]

var main: Main
var wd: WaveDirector

func before_each() -> void:
	Balance.reset()
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(20260930)
	await get_tree().process_frame
	wd = main.world.wave_director

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

func _to_tier2() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_tier(2, GameState.day)
	main.world.rebuild_for_tier()

## Pays the tier sign in full (the real call) and returns tonight's plan.
func _pay_sign() -> Array:
	var cost := GameState.tier_next_cost()
	GameState.add_gold(cost)
	assert_eq(GameState.pay_into_tier(cost), cost)
	return GameState.lane_plan

func _boss_wave_alive() -> Array:
	wd.start_night(GameState.lane_plan)
	wd._start_wave(GameState.lane_plan.size() - 1)
	await get_tree().physics_frame
	return wd.alive_enemies()

# --- the kind lookup ---

func test_boss_kind_per_tier_and_the_boss_set() -> void:
	var tb := Balance.data.tiers
	assert_eq(TierEffects.boss_kind_for(1, tb), &"boss", "leaving tier 1: the Boar King")
	assert_eq(TierEffects.boss_kind_for(2, tb), &"baron", "leaving tier 2: Baron von Hop")
	assert_eq(TierEffects.boss_kind_for(3, tb), &"", "the top tier has no boss")
	assert_eq(TierEffects.boss_kind_for(0, tb), &"", "below tier 1")
	assert_eq(TierEffects.boss_kind_for(9, tb), &"", "past the table")
	assert_true(TierEffects.is_boss_kind(&"boss", tb))
	assert_true(TierEffects.is_boss_kind(&"baron", tb))
	for k in [&"boar", &"hare", &"brute", &""]:
		assert_false(TierEffects.is_boss_kind(k, tb), "%s is not a boss" % k)

func test_the_top_tier_of_a_two_tier_build_has_no_boss() -> void:
	var tb: TierBalance = Balance.data.tiers.duplicate()
	tb.tier_costs = tb.tier_costs.slice(0, 2)
	assert_eq(TierEffects.boss_kind_for(1, tb), &"boss")
	assert_eq(TierEffects.boss_kind_for(2, tb), &"", "boss_kind[2] is the Baron, but nothing leaves the top tier")

# --- the schedule and the threat ---

func _wave(boss: bool) -> Dictionary:
	return {"main": "north", "side": "west", "main_count": 3, "side_count": 2, "hp_mult": 1.0, "fast_main": 0, "fast_side": 0, "boss": boss}

func test_a_boss_wave_leads_with_the_kind_of_the_tier() -> void:
	var tb := Balance.data.tiers
	var wb := Balance.data.wave
	for tier_kind in [[1, &"boss"], [2, &"baron"]]:
		var s := WaveSchedule.build(_wave(true), wb, tb, tier_kind[0])
		assert_eq(s[0].kind, tier_kind[1], "tier %d" % tier_kind[0])
		assert_eq(s[0].t, 0.0)
		assert_eq(s[0].lane, "north")
		var first_boar: Dictionary = s.filter(func(e): return e.kind == &"boar")[0]
		assert_eq(first_boar.t, tb.boss_lead, "the rest of the wave follows by boss_lead")
		assert_eq(s.filter(func(e): return TierEffects.is_boss_kind(e.kind, tb)).size(), 1, "exactly one boss")

func test_no_boss_entry_and_no_lead_at_the_top_tier() -> void:
	var tb := Balance.data.tiers
	var s := WaveSchedule.build(_wave(true), Balance.data.wave, tb, 3)
	assert_eq(s.filter(func(e): return TierEffects.is_boss_kind(e.kind, tb)).size(), 0, "a pending boss at the top tier spawns none")
	assert_eq(s[0].t, 0.0, "the wave starts at once: no lead for a boss that is not there")
	assert_eq(s.size(), 5)

func test_the_threat_on_the_boss_lane_uses_the_barons_hp_at_tier_2() -> void:
	var tb := Balance.data.tiers
	var wb := Balance.data.wave
	var hp: float = Balance.data.enemy.hp
	var plan := LanePlanner.plan(555, 12, wb, 2, 5, tb)
	var boss_plan := LanePlanner.with_boss(plan)
	var m := float(plan.back().hp_mult)
	var lane := String(plan.back().main)
	var t0 := LanePlanner.threat_by_lane(plan, hp, 2)
	var t1 := LanePlanner.threat_by_lane(boss_plan, hp, 2)
	assert_almost_eq(t1[lane] - t0[lane], 500.0 * m, 1e-3, "the Baron's 500 hp x the wave multiplier (the King's 800 fails)")
	for l in LANES:
		if l != lane:
			assert_eq(t1[l], t0[l])
	var k0 := LanePlanner.threat_by_lane(LanePlanner.plan(555, 7, wb, 1, 1, tb), hp, 1)
	var kp := LanePlanner.with_boss(LanePlanner.plan(555, 7, wb, 1, 1, tb))
	var k1 := LanePlanner.threat_by_lane(kp, hp, 1)
	var kl := String(kp.back().main)
	assert_almost_eq(k1[kl] - k0[kl], 800.0 * float(kp.back().hp_mult), 1e-3, "tier 1 still adds the King's 800")
	var t3 := LanePlanner.threat_by_lane(boss_plan, hp, 3)
	var t3_plain := LanePlanner.threat_by_lane(plan, hp, 3)
	assert_eq(t3, t3_plain, "no boss leaves the top tier: its threat adds nothing")

# --- the night ---

func test_a_paid_tier_2_sign_marks_the_plan_and_the_baron_spawns() -> void:
	_to_tier2()
	var plan := _pay_sign()
	assert_true(GameState.boss_pending)
	assert_true(GameState.is_boss_night())
	assert_eq(plan.map(func(w): return w.boss), [false, false, true])
	var alive := await _boss_wave_alive()
	assert_eq(alive.size(), 1, "only the boss at t = 0")
	var baron: Boar = alive[0]
	assert_eq(baron.kind, &"baron")
	assert_eq(baron.lane, String(plan.back().main), "on the wave's main lane")
	assert_almost_eq(baron.health.max_hp, 500.0 * float(plan.back().hp_mult), 1e-3)
	for i in int(ceil(Balance.data.tiers.boss_lead * 60.0)) + 2:
		await get_tree().physics_frame
	assert_gt(wd.alive_count(), 1, "the wave follows after boss_lead")

func test_a_tier_1_sign_still_spawns_the_boar_king() -> void:
	main.phase_controller.debug_skip_to_day()
	_pay_sign()
	var alive := await _boss_wave_alive()
	assert_eq((alive[0] as Boar).kind, &"boss")

func test_a_pending_boss_at_the_top_tier_spawns_none() -> void:
	main.phase_controller.debug_skip_to_day()
	var top := TierEffects.top_tier(Balance.data.tiers)
	GameState.debug_set_tier(top, GameState.day)
	main.world.rebuild_for_tier()
	GameState.boss_pending = true  # test-only: a clamped or hand-edited save
	GameState.lane_plan = LanePlanner.with_boss(GameState.lane_plan)  # test-only: the flag is on the plan
	assert_false(GameState.is_boss_night(), "no moon: the plan flag means nothing where no boss exists")
	var alive := await _boss_wave_alive()
	assert_gt(alive.size(), 0)
	for b in alive:
		assert_false((b as Boar).is_boss, "no boss entry")
	assert_false(wd.boss_alive())
	for i in 20:
		await get_tree().physics_frame
	for b in wd.alive_enemies():
		assert_false((b.get_node("BossBar") as BossBar).visible, "no bar")
	# the same through a save round trip: from_dict must not paint a boss onto the plan
	var d := GameState.to_dict()
	d.boss_pending = true
	for w in d.lane_plan:
		w.boss = false
	GameState.from_dict(d)
	assert_true(GameState.boss_pending)
	assert_false(bool(GameState.lane_plan.back().boss), "restored plan carries no boss")
	assert_false(GameState.is_boss_night())

func test_boss_alive_is_true_for_either_boss_and_false_for_the_rest() -> void:
	for kind in [&"boar", &"hare", &"brute"]:
		var b := wd.debug_spawn("north", 0.0, 1.0, kind)
		assert_false(wd.boss_alive(), "%s is no boss" % kind)
		b.set_physics_process(false)
		wd.debug_kill_all()
	wd.stop()
	var baron := wd.debug_spawn("north", 0.0, 1.0, &"baron")
	assert_true(wd.boss_alive(), "the Baron")
	assert_true(baron.is_boss)
	wd.stop()
	var king := wd.debug_spawn("north", 0.0, 1.0, &"boss")
	assert_true(wd.boss_alive(), "the Boar King")
	assert_true(king.is_boss)
	wd.stop()
	var boar := wd.debug_spawn("north", 0.0, 1.0, &"boar")
	assert_false(boar.is_boss, "a pooled node respawned as a Boar is no boss")

# --- the Baron in play ---

func _walker(kind: StringName, lane := "north") -> Boar:
	var b := wd.debug_spawn(lane, 0.0, 1.0, kind)
	b.set_physics_process(false)
	return b

func _step(b: Boar, ticks: int) -> void:
	for i in ticks:
		b._physics_process(DT)

func test_the_baron_ignores_a_standing_fence() -> void:
	GameState.gold = 100000
	GameState.pay_into_spot("fence_n", 100000)
	var fence0 := float(GameState.buildings.fence_n.hp)
	assert_gt(fence0, 0.0, "a fence stands on the north lane")
	var b := _walker(&"baron")
	_step(b, int(ceil(b.path_length() / 2.4 * 60.0)) + 5)
	assert_true(b.at_path_end(), "it walked past the fence to the diner")
	assert_eq(float(GameState.buildings.fence_n.hp), fence0, "the fence keeps its hp: the Baron never hit it")
	var hp0 := GameState.diner_hp
	_step(b, 60)
	assert_almost_eq(hp0 - GameState.diner_hp, 12.0, 1e-4, "it hits the diner for its own 12")
	assert_eq(float(GameState.buildings.fence_n.hp), fence0)

func test_the_baron_hits_a_guard_in_reach_before_the_diner() -> void:
	var b := _walker(&"baron")
	assert_eq(b.stats().priority, [&"guard", &"diner"] as Array[StringName], "the hare's list at boss scale")
	assert_almost_eq(b.stats().reach, 1.6, 1e-6)

func test_the_boss_bar_names_the_boss_and_the_kings_bar_is_unchanged() -> void:
	var baron := wd.debug_spawn("north", 0.0, 1.0, &"baron")
	var king := wd.debug_spawn("west", 0.0, 1.0, &"boss")
	var boar := wd.debug_spawn("east", 0.0, 1.0, &"boar")
	await get_tree().process_frame
	var bb: BossBar = baron.get_node("BossBar")
	var kb: BossBar = king.get_node("BossBar")
	assert_true(bb.visible)
	assert_eq(bb.name_text(), tr("Baron von Hop"))
	assert_eq(kb.name_text(), tr("Boar King"))
	assert_false((boar.get_node("BossBar") as BossBar).visible, "a Boar has no bar")
	assert_eq((boar.get_node("BossBar") as BossBar).name_text(), "", "and no name")
	# the King's bar keeps its geometry and colour
	assert_almost_eq(kb.position.y, 2.6, 1e-5)
	assert_eq(kb.fill_color(), Palette.color(&"enemy_red"))
	assert_eq(bb.fill_color(), Palette.color(&"enemy_red"), "one bar style for both bosses")
	assert_almost_eq(kb.fraction(), 1.0, 1e-6)
	baron.take_hit(baron.health.max_hp * 0.25)
	await get_tree().process_frame
	assert_almost_eq(bb.fraction(), 0.75, 1e-6)
	assert_almost_eq(kb.fraction(), 1.0, 1e-6, "the bars are per boss")
	# a recycled node: the name follows the kind
	king.spawn("west", 7, 0.0, 1.0, wd, &"baron")
	await get_tree().process_frame
	assert_eq(kb.name_text(), tr("Baron von Hop"))

func test_the_drop_is_150_steaks_and_dawn_sweeps_all_of_it() -> void:
	_to_tier2()
	_pay_sign()
	main.phase_controller.debug_skip_to_night()
	main.hero.teleport(MapLayout.HOME)
	var drop: int = Balance.data.monsters.stats(&"baron").steaks_per_kill
	assert_eq(drop, 150)
	var baron := wd.debug_spawn("north", 0.0, 1.0, &"baron")
	var freezer0 := GameState.freezer_steaks
	var before := freezer0 + GameState.carried_steaks
	var got: Array = []
	var cb := func(i, l, p, k): got.append(k)
	EventBus.enemy_killed.connect(cb)
	baron.take_hit(1e9)
	await get_tree().physics_frame
	EventBus.enemy_killed.disconnect(cb)
	assert_eq(got, [&"baron"])
	assert_eq(main.world.steak_pool.active().size(), drop, "exactly the drop is on the ground")
	for s in main.world.steak_pool.active():
		var d := Vector2((s as Node3D).position.x - baron.position.x, (s as Node3D).position.z - baron.position.z).length()
		assert_lte(d, Balance.data.monsters.stats(&"baron").drop_scatter + 1e-4, "inside the boss scatter")
	main.phase_controller.debug_skip_to_day()
	assert_eq(GameState.freezer_steaks + GameState.carried_steaks - before, drop, "all 150 reached the freezer or the hero")
	assert_eq(main.world.steak_pool.active().size(), 0, "none left on the ground")

# --- numbers by hand ---

func test_the_baron_alone_needs_24_s_to_fell_the_diner() -> void:
	var s := Balance.data.monsters.stats(&"baron")
	var diner: float = Balance.data.build.diner_max_hp
	assert_eq([s.damage, s.attack_interval, diner], [12.0, 1.0, 300.0])
	assert_eq(GameState.mercy_factor(), 1.0, "a first attempt")
	var hits := int(ceil(diner / (s.damage * GameState.mercy_factor())))
	assert_eq(hits, 25, "ceil(300 / 12)")
	var hold := (hits - 1) * s.attack_interval
	assert_eq(hold, 24.0, "from its first hit to the 25th, which fells the diner")
	assert_gte(hold, Balance.data.tiers.boss_min_hold_s, "at least the slice-1 floor of 15 s")

func test_the_hold_literal_is_what_the_actor_does() -> void:
	var b := _walker(&"baron")
	_step(b, int(ceil(b.path_length() / 2.4 * 60.0)) + 5)
	assert_true(b.at_path_end())
	var first := -1
	var ticks := 0
	var fell := -1
	var seen := 0
	while GameState.diner_hp > 0.0 and ticks < 60 * 40:
		var hp := GameState.diner_hp
		b._physics_process(DT)
		ticks += 1
		if GameState.diner_hp < hp:
			seen += 1
			if first < 0:
				first = ticks
	fell = ticks
	assert_eq(seen, 25)
	assert_almost_eq(float(fell - first) * DT, 24.0, 0.05)

## Hero at the lane's zone centre when the Baron spawns, running at the Baron's current position at 5.0 m/s; the Baron walks its
## lane at 2.4 m/s. Returns the hero's catch time (the Baron within the hero's attack range) and the Baron's time to enter the zone.
func _catch(lane: String, offset: float) -> Dictionary:
	var zone := MapLayout.zone_rect(lane)
	var hero := zone.get_center()
	var baron_speed: float = Balance.data.monsters.stats(&"baron").speed
	var hero_speed: float = Balance.data.hero.move_speed
	var reach: float = Balance.data.hero.attack_range
	var length := MapLayout.path_length(lane)
	var fade: float = Balance.data.enemy.offset_fade_distance
	var dist := 0.0
	var t := 0.0
	var caught := -1.0
	var zone_t := -1.0
	while t < 60.0 and zone_t < 0.0:
		var pos := EnemyPath.position_at(lane, dist, offset, fade)
		if caught < 0.0 and hero.distance_to(pos) <= reach:
			caught = t
		if zone.grow(0.05).has_point(pos):  # the lane ends on the zone's wall edge
			zone_t = t
		var to := pos - hero
		hero += to.normalized() * minf(hero_speed * DT, to.length())
		dist = minf(dist + baron_speed * DT, length)
		t += DT
	return {"caught": caught, "zone": zone_t}

func test_a_hero_from_the_zone_centre_catches_the_baron_on_every_tier_2_lane() -> void:
	for lane in LANES:
		for offset in [-1.0, 0.0, 1.0]:
			var r := _catch(lane, offset)
			assert_gte(r.caught, 0.0, "%s offset %.0f: caught at all" % [lane, offset])
			assert_gt(r.zone, 0.0, "%s: the Baron reached the zone" % lane)
			assert_lt(r.caught, r.zone, "%s offset %.0f: caught at %.2f s, the Baron enters the zone at %.2f s" % [lane, offset, r.caught, r.zone])
			assert_gt(r.zone - r.caught, 2.0, "%s offset %.0f: at least 2 s of margin" % [lane, offset])
		var r0 := _catch(lane, 0.0)
		gut.p("%s: caught %.2f s, zone at %.2f s, margin %.2f s" % [lane, r0.caught, r0.zone, r0.zone - r0.caught])

# --- the mesh ---

func test_the_barons_mesh_is_a_big_hare_with_a_crown() -> void:
	var boar := BoarMesh.get_mesh(&"boar").get_aabb()
	var hare := BoarMesh.get_mesh(&"hare").get_aabb()
	var king := BoarMesh.get_mesh(&"boss").get_aabb()
	var baron := BoarMesh.get_mesh(&"baron").get_aabb()
	assert_gte(baron.size.y, boar.size.y * 1.8, "at least 1.8x the Boar's height")
	assert_gte(baron.size.z, boar.size.z * 1.8, "at least 1.8x the Boar's length")
	assert_gte(baron.size.y, hare.size.y * 2.5, "at least 2.5x a hare's height")
	assert_gte(baron.size.z, hare.size.z * 2.5, "at least 2.5x a hare's length")
	assert_lte(baron.size.y, king.size.y, "no taller than the Boar King, who stays the biggest")
	assert_lte(baron.size.z, king.size.z * 1.05)
	var p := BoarMesh.params(&"baron")
	assert_gt(int(p.crown), 0, "a crown")
	assert_eq(BoarMesh.params(&"hare").get("crown", 0), 0)
	assert_gt(float(p.ear_len), 0.0, "a hare's ears")
	assert_eq(int(p.tusks), 0, "a hare, not a boar")
	assert_ne(p.upper, BoarMesh.params(&"hare").upper, "its own coat")
	var tris: int = BoarMesh.get_mesh(&"baron").surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	assert_lte(tris, ArtBudgets.budget_for("res://art/boar/x"))
	gut.p("baron %s vs boar %s, hare %s, king %s, %d tris" % [baron.size, boar.size, hare.size, king.size, tris])

## Hare and Boar King hashes captured from main; the brute from its Task 10 review state.
func test_the_other_kinds_meshes_are_unchanged() -> void:
	var want := {
		&"hare": "398149e8feb96260d82a63b91478ceb559b2f3c147e3050d6c53f1715ff8bdc5",
		&"boss": "b9ed4d4349b9e33e17defdf8df20b9c3fc6af58872974384282f49b04a8ef589",
		&"brute": "2a489997ce5f32669fc0973b44a11b5a91f42c0521090ec9cd712fae0e81972a",
	}
	for kind in want:
		var a := BoarMesh.get_mesh(kind).surface_get_arrays(0)
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
		ctx.update((a[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
		ctx.update((a[Mesh.ARRAY_COLOR] as PackedColorArray).to_byte_array())
		ctx.update((a[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
		assert_eq(ctx.finish().hex_encode(), want[kind], "%s mesh" % kind)
