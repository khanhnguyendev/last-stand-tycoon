extends GutTest
## E5 tier-3 spec 6.4 (D-272.3, D-273.0): the branch identity test on Balance, plus the data shape of tier 3.
## Real HP = base HP x WaveMath.hp_mult(pressure, wave): the multiplier also grows when a wave's raw size passes
## max_wave_size. Whole-hit math: a monster of HP h dies after ceil(h / d) hits (BranchMath).
## M1 (single-target DPS) and M3 (DPS against three targets) are RAW by definition: damage x projectiles on distinct
## targets / interval. Kill rates (M4, the brute check) use whole hits, so overkill counts against a tower.

const PRESSURES: Array[int] = [12, 15]
const ALL_PRESSURES: Array[int] = [12, 13, 14, 15]
const WAVES := 3

# Real hare HP per [pressure][wave], verified by hand: 15 x (1 + 0.15 x (p - 1)) x max(1, raw / 30).
# p12: raw 19, 29, 39 -> 15 x 2.65 = 39.75, 39.75, then 39/30 x 2.65 x 15 = 51.675.
# p15: raw 24, 35, 47 -> 15 x 3.1 = 46.5; 35/30 x 3.1 x 15 = 54.25; 47/30 x 3.1 x 15 = 72.85.
const HARE_HP := {12: [39.75, 39.75, 51.675], 15: [46.5, 54.25, 72.85]}
const BOAR_HP := {12: [79.5, 79.5, 103.35], 15: [93.0, 108.5, 145.7]}
const BRUTE_HP := {12: [636.0, 636.0, 826.8], 15: [744.0, 868.0, 1165.6]}

var bd: BalanceData
var bb: BranchBalance

func before_each() -> void:
	Balance.reset()
	bd = Balance.data
	bb = bd.branches

func _hp(base: float, pressure: int, w: int) -> float:
	return base * WaveMath.hp_mult(pressure, w, bd.wave)

func _towers() -> Dictionary:
	return {&"": bb.tower(&""), &"longbow": bb.tower(&"longbow"), &"volley": bb.tower(&"volley")}

func _fences() -> Dictionary:
	return {&"": bb.fence(&""), &"stone": bb.fence(&"stone"), &"spike": bb.fence(&"spike")}

## The id with the strictly highest value; &"tie" if the top is shared.
func _best(values: Dictionary) -> StringName:
	var top_id: StringName = &""
	var top := -INF
	var tied := false
	for id in values:
		if values[id] > top + 1e-9:
			top = values[id]
			top_id = id
			tied = false
		elif absf(values[id] - top) <= 1e-9:
			tied = true
	return &"tie" if tied else top_id

## Every id whose value equals the top value (a shared top counts for all of them).
func _top_set(values: Dictionary) -> Array:
	var top := -INF
	for id in values:
		top = maxf(top, values[id])
	var out := []
	for id in values:
		if absf(values[id] - top) <= 1e-9:
			out.append(id)
	return out

func _worst(values: Dictionary) -> StringName:
	var neg := {}
	for id in values:
		neg[id] = -values[id]
	return _best(neg)

# --- the real HP numbers -------------------------------------------------------------------------------

func test_real_hp_values_are_pinned() -> void:
	for p in PRESSURES:
		for w in WAVES:
			var hare := _hp(bd.monsters.stats(&"hare").hp, p, w)
			var boar := _hp(bd.monsters.stats(&"boar").hp, p, w)
			var brute := _hp(bd.monsters.stats(&"brute").hp, p, w)
			gut.p("p%d wave %d: hare %.3f boar %.3f brute %.3f" % [p, w + 1, hare, boar, brute])
			assert_almost_eq(hare, HARE_HP[p][w], 1e-3, "hare p%d w%d" % [p, w])
			assert_almost_eq(boar, BOAR_HP[p][w], 1e-3, "boar p%d w%d" % [p, w])
			assert_almost_eq(brute, BRUTE_HP[p][w], 1e-3, "brute p%d w%d" % [p, w])
	assert_almost_eq(_hp(15.0, 12, 0), 39.75, 1e-6, "spec 3.5: about 40 at pressure 12")
	assert_almost_eq(_hp(15.0, 15, 0), 46.5, 1e-6, "spec 3.5: 46 at pressure 15")

# --- the seven measures, one test each, every wave at both pressures ------------------------------------

func test_m1_single_target_dps_longbow_highest() -> void:
	var t := _towers()
	assert_almost_eq(BranchMath.single_dps(t[&"longbow"]), 120.0 / 3.0, 1e-6)
	assert_almost_eq(BranchMath.single_dps(t[&""]), 36.0, 1e-6)
	assert_almost_eq(BranchMath.single_dps(t[&"volley"]), 20.0, 1e-6)
	var v := {}
	for id in t:
		v[id] = BranchMath.single_dps(t[id])
	assert_eq(_best(v), &"longbow")
	gut.p("M1 single-target dps: unbranched %.2f longbow %.2f volley %.2f" % [v[&""], v[&"longbow"], v[&"volley"]])

func test_m2_range_longbow_longest() -> void:
	var t := _towers()
	assert_eq([t[&""].attack_range, t[&"longbow"].attack_range, t[&"volley"].attack_range], [8.0, 9.98, 8.0])
	gut.p("M2 range: unbranched 8.0 longbow 9.98 volley 8.0")
	var v := {}
	for id in t:
		v[id] = t[id].attack_range
	assert_eq(_best(v), &"longbow")

func test_m3_dps_against_three_targets_volley_highest() -> void:
	var t := _towers()
	assert_almost_eq(BranchMath.multi_dps(t[&"volley"], 3), 60.0, 1e-6)
	assert_almost_eq(BranchMath.multi_dps(t[&"volley"], 2), 40.0, 1e-6)
	assert_almost_eq(BranchMath.multi_dps(t[&"volley"], 9), 60.0, 1e-6, "never more than count projectiles")
	var v := {}
	for id in t:
		v[id] = BranchMath.multi_dps(t[id], 3)
	assert_eq(_best(v), &"volley")
	gut.p("M3 dps vs 3 targets: unbranched %.1f longbow %.1f volley %.1f" % [v[&""], v[&"longbow"], v[&"volley"]])

func test_m4_hares_per_second_volley_most_longbow_fewest() -> void:
	var t := _towers()
	for p in ALL_PRESSURES:
		for w in WAVES:
			var hare := _hp(bd.monsters.stats(&"hare").hp, p, w)
			for n in [3, 5, 8]:
				var v := {}
				for id in t:
					v[id] = BranchMath.kills_per_second(hare, t[id], n)
				gut.p("M4 p%d w%d n=%d hare %.2f kills/s: unbranched %.3f longbow %.3f volley %.3f" % [p, w + 1, n, hare, v[&""], v[&"longbow"], v[&"volley"]])
				assert_eq(_best(v), &"volley", "most: p%d w%d n%d" % [p, w + 1, n])
				assert_eq(_worst(v), &"longbow", "fewest: p%d w%d n%d" % [p, w + 1, n])

func test_m4_kill_rate_literals() -> void:
	var t := _towers()
	var hare := _hp(15.0, 15, 2)  # 72.85: unbranched 5 hits (2.5 s), Longbow one shot per 3 s, Volley 8 hits per target
	assert_almost_eq(BranchMath.kills_per_second(hare, t[&""], 5), 0.4, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(hare, t[&"longbow"], 5), 1.0 / 3.0, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(hare, t[&"volley"], 5), 0.75, 1e-9)
	var easy := _hp(15.0, 12, 0)  # 39.75: 3 hits, 1 shot, 4 hits
	assert_almost_eq(BranchMath.kills_per_second(easy, t[&""], 5), 2.0 / 3.0, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(easy, t[&"volley"], 5), 1.5, 1e-9)

## Whole-shot check against the brute with ONE target in range: Longbow is never slower than the unbranched tower.
func test_longbow_kills_a_lone_brute_at_least_as_fast_as_unbranched() -> void:
	var t := _towers()
	var ties := 0
	var waves_checked := 0
	for p in ALL_PRESSURES:
		for w in WAVES:
			var hp := _hp(bd.monsters.stats(&"brute").hp, p, w)
			var u: TowerBranchStats = t[&""]
			var l: TowerBranchStats = t[&"longbow"]
			var uh := BranchMath.hits_to_kill(hp, u.damage)
			var lh := BranchMath.hits_to_kill(hp, l.damage)
			var ku := BranchMath.kills_per_second(hp, u, 1)
			var kl := BranchMath.kills_per_second(hp, l, 1)
			var tie := absf(ku - kl) <= 1e-9
			ties += 1 if tie else 0
			waves_checked += 1
			gut.p("BRUTE p%d w%d hp %.1f: unbranched %d hits %.1f s | longbow %d hits %.1f s%s" % [p, w + 1, hp, uh, uh * u.interval, lh, lh * l.interval, "  TIE" if tie else ""])
			assert_gte(kl, ku - 1e-9, "longbow >= unbranched vs a brute p%d w%d" % [p, w + 1])
	gut.p("BRUTE waves that tie: %d of %d" % [ties, waves_checked])

## Information only: against the Boar Longbow's overkill makes it SLOWER than the unbranched tower. By design.
func test_info_whole_shot_table_against_the_boar() -> void:
	var t := _towers()
	for p in ALL_PRESSURES:
		for w in WAVES:
			var hp := _hp(bd.monsters.stats(&"boar").hp, p, w)
			var u: TowerBranchStats = t[&""]
			var l: TowerBranchStats = t[&"longbow"]
			gut.p("BOAR p%d w%d hp %.1f: unbranched %d hits %.1f s | longbow %d hits %.1f s" % [p, w + 1, hp, BranchMath.hits_to_kill(hp, u.damage), BranchMath.hits_to_kill(hp, u.damage) * u.interval, BranchMath.hits_to_kill(hp, l.damage), BranchMath.hits_to_kill(hp, l.damage) * l.interval])
	pass_test("information only")

func test_m5_fence_holds_longest_against_one_brute_stone() -> void:
	var f := _fences()
	var brute := bd.monsters.stats(&"brute")
	var v := {}
	for id in f:
		v[id] = BranchMath.fence_hold_seconds(f[id].hp, brute, f[id], &"brute")
	# brute 8 x 4.0 = 32 per hit: 320 hp = 10 hits, Stone 640 hp at 16 per hit = 40 hits (thorns never shorten it).
	assert_eq([v[&""], v[&"stone"], v[&"spike"]], [10.0, 40.0, 10.0])
	assert_eq(_best(v), &"stone")
	gut.p("M5 fence hold vs one brute (s): unbranched %.1f stone %.1f spike %.1f" % [v[&""], v[&"stone"], v[&"spike"]])

func test_m6_only_spike_damages_a_passing_hare() -> void:
	var f := _fences()
	var base := BranchMath.spike_base_mult(bd.wave, bd.tiers)
	for p in PRESSURES:
		for w in WAVES:
			var scale := BranchMath.spike_scale(WaveMath.hp_mult(p, w, bd.wave), base)
			gut.p("M6 pass damage p%d w%d: unbranched 0 stone 0 spike %.2f (scale %.3f)" % [p, w + 1, BranchMath.pass_damage(f[&"spike"], &"hare", scale), scale])
			for kind in [&"hare", &"baron"]:
				assert_eq(BranchMath.pass_damage(f[&""], kind, scale), 0.0)
				assert_eq(BranchMath.pass_damage(f[&"stone"], kind, scale), 0.0)
				assert_gt(BranchMath.pass_damage(f[&"spike"], kind, scale), 0.0, "spike p%d w%d %s" % [p, w + 1, kind])
			for kind in [&"boar", &"brute", &"boss"]:
				assert_eq(BranchMath.pass_damage(f[&"spike"], kind, scale), 0.0, "%s is not a passing kind" % kind)
	for id in [&"longbow", &"volley"]:
		assert_eq(bb.tower(id).get("pass_damage"), null, "a tower has no pass damage")

func test_m7_unbranched_level_3_is_best_at_none() -> void:
	var t := _towers()
	var f := _fences()
	var brute := bd.monsters.stats(&"brute")
	var tops := {}  # measure -> the ids at the top value (a shared top counts)
	var tv := {}
	tv = {}
	for id in t: tv[id] = BranchMath.single_dps(t[id])
	tops["single dps"] = _top_set(tv)
	tv = {}
	for id in t: tv[id] = t[id].attack_range
	tops["range"] = _top_set(tv)
	tv = {}
	for id in t: tv[id] = BranchMath.multi_dps(t[id], 3)
	tops["dps x3"] = _top_set(tv)
	tv = {}
	for id in f: tv[id] = BranchMath.fence_hold_seconds(f[id].hp, brute, f[id], &"brute")
	tops["fence hold"] = _top_set(tv)
	tv = {}
	for id in f: tv[id] = BranchMath.pass_damage(f[id], &"hare", 1.0)
	tops["pass damage"] = _top_set(tv)
	for p in ALL_PRESSURES:
		for w in WAVES:
			var hare := _hp(bd.monsters.stats(&"hare").hp, p, w)
			for n in [3, 5, 8]:
				tv = {}
				for id in t: tv[id] = BranchMath.kills_per_second(hare, t[id], n)
				tops["hares/s p%d w%d n%d" % [p, w + 1, n]] = _top_set(tv)
	for m in tops:
		assert_false(&"" in tops[m], "the unbranched building is at the top (alone or tied) of: %s" % m)
	assert_eq(tops["single dps"], [&"longbow"])
	assert_eq(tops["fence hold"], [&"stone"])
	assert_eq(tops["pass damage"], [&"spike"])

func test_top_set_counts_a_shared_top() -> void:
	assert_eq(_top_set({&"": 1.0, &"a": 1.0, &"b": 0.5}), [&"", &"a"])
	assert_eq(_top_set({&"": 1.0, &"a": 2.0}), [&"a"])

# --- BranchMath arithmetic ---------------------------------------------------------------------------------

func test_branch_math_whole_hits() -> void:
	assert_eq(BranchMath.hits_to_kill(39.75, 18.0), 3)
	assert_eq(BranchMath.hits_to_kill(36.0, 18.0), 2, "an exact fit needs no extra hit")
	assert_eq(BranchMath.hits_to_kill(36.01, 18.0), 3)
	assert_almost_eq(BranchMath.kills_per_second(39.75, bb.tower(&"volley"), 3), 3.0 / 0.5 / 4.0, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(39.75, bb.tower(&"volley"), 1), 1.0 / 0.5 / 4.0, 1e-9, "one target: one projectile")

func test_spike_scale_is_now_over_base() -> void:
	assert_almost_eq(BranchMath.spike_scale(4.0, 2.0), 2.0, 1e-9)
	var base := BranchMath.spike_base_mult(bd.wave, bd.tiers)
	assert_almost_eq(base, 2.65, 1e-9, "first wave at pressure 12")
	assert_almost_eq(BranchMath.spike_scale(base, base), 1.0, 1e-9)
	var s := BranchMath.spike_scale(WaveMath.hp_mult(15, 2, bd.wave), base)
	assert_almost_eq(s, 4.8567 / 2.65, 1e-3)
	assert_almost_eq(BranchMath.pass_damage(bb.fence(&"spike"), &"hare", s), 10.0 * s, 1e-9)

# --- data shape ---------------------------------------------------------------------------------------------

func test_unbranched_level_3_is_read_from_build_balance() -> void:
	assert_eq(bd.build.tower_damage[2], 18.0)
	var t := bb.tower(&"")
	assert_eq([t.attack_range, t.damage, t.interval, t.count], [8.0, 18.0, 0.5, 1])
	assert_eq(bb.fence(&"").hp, 320.0)
	bd.build.tower_damage[2] = 19.0
	bd.build.fence_hp[2] = 330.0
	assert_eq(bb.tower(&"").damage, 19.0, "a mutation is seen at once")
	assert_eq(bb.fence(&"").hp, 330.0)

func test_branch_spec_values() -> void:
	assert_eq([bb.tower_branch_cost, bb.fence_branch_cost], [500, 300])
	assert_eq(Array(BranchBalance.TOWER_BRANCHES), [&"longbow", &"volley"])
	assert_eq(Array(BranchBalance.FENCE_BRANCHES), [&"stone", &"spike"])
	var lb := bb.tower(&"longbow")
	assert_eq([lb.attack_range, lb.damage, lb.interval, lb.count], [9.98, 120.0, 3.0, 1])
	var vo := bb.tower(&"volley")
	assert_eq([vo.attack_range, vo.damage, vo.interval, vo.count], [8.0, 10.0, 0.5, 3])
	var st := bb.fence(&"stone")
	assert_eq([st.hp, st.thorn_damage, st.pass_damage], [640.0, 0.0, 0.0])
	assert_eq(st.damage_taken_mult_by_kind, {&"brute": 0.5})
	var sp := bb.fence(&"spike")
	assert_eq([sp.hp, sp.thorn_damage, sp.pass_damage], [320.0, 6.0, 10.0])
	assert_eq(Array(sp.pass_kinds), [&"hare", &"baron"])
	assert_eq(sp.damage_taken_mult_by_kind, {})

func test_branch_data_survives_a_balance_reset_as_a_deep_copy() -> void:
	bb.longbow.damage = 1.0
	Balance.reset()
	assert_eq(Balance.data.branches.longbow.damage, 120.0)

func test_monster_spec_values_tier_3() -> void:
	var b := bd.monsters.stats(&"brute")
	assert_eq([b.hp, b.speed, b.damage, b.attack_interval, b.reach, b.steaks_per_kill, b.drop_scatter, b.fence_damage_mult], [240.0, 1.2, 8.0, 1.0, 1.2, 8, 0.8, 4.0])
	var z := bd.monsters.stats(&"baron")
	assert_eq([z.hp, z.speed, z.damage, z.attack_interval, z.reach, z.steaks_per_kill, z.drop_scatter, z.fence_damage_mult], [500.0, 2.4, 12.0, 1.0, 1.6, 150, 2.5, 1.0])
	assert_eq(Array(z.priority), [&"guard", &"diner"], "walks past fences, the hare's order")
	assert_eq(Array(bd.monsters.hare.priority), Array(z.priority))
	assert_eq(bd.monsters.stats(&"boar").fence_damage_mult, 1.0)
	assert_eq(bd.monsters.stats(&"hare").fence_damage_mult, 1.0)
	assert_eq(bd.monsters.stats(&"boss").fence_damage_mult, 1.0)

func test_brute_keeps_the_boars_reach_and_target_order() -> void:
	var boar := bd.monsters.stats(&"boar")
	var b := bd.monsters.stats(&"brute")
	assert_eq(b.reach, boar.reach, "stop points and test A' stay valid (D-265)")
	assert_eq(Array(b.priority), Array(boar.priority))
	assert_eq(b.attack_interval, boar.attack_interval)

func test_tier_3_arrays_are_data_only_and_the_top_tier_is_still_2() -> void:
	var tb := bd.tiers
	assert_eq(Array(tb.tier_costs), [0, 500])
	assert_eq(TierEffects.top_tier(tb), 2)
	assert_eq(TierEffects.tier_cost(2, tb), -1, "nothing of tier 3 is reachable")
	var n := tb.tier_costs.size() + 1
	for arr in [tb.tier_base, tb.tier_cap, tb.fast_share_start, tb.fast_share, tb.fast_ramp_days, tb.brute_cap_main, tb.brute_cap_side, tb.brute_ramp_days, tb.boss_kind]:
		assert_gte((arr as Array).size(), n)
	assert_eq([tb.tier_base[3], tb.tier_cap[3]], [12, 15])
	assert_eq([tb.fast_share_start[3], tb.fast_share[3], tb.fast_ramp_days[3]], [0.35, 0.35, 1])
	assert_eq([tb.brute_cap_main[3], tb.brute_cap_side[3], tb.brute_ramp_days[3]], [1, 1, 3])
	assert_eq([tb.brute_cap_main[2], tb.brute_cap_side[2]], [0, 0], "tier 2 carries no brutes")
	assert_eq(tb.boss_kind[1], &"boss")
	assert_eq(tb.boss_kind[2], &"baron")
	assert_eq(Array(tb.boss_kind), [&"", &"boss", &"baron", &""])
	var last := tb.boss_kind.size() - 1
	for t in range(1, last):
		assert_ne(tb.boss_kind[t], &"", "boss_kind[%d] must name the boss that leaves tier %d (a new tier must add its boss)" % [t, t])
	assert_eq(tb.boss_kind[last], &"", "no boss leaves the top tier: the last boss_kind entry is empty")
	assert_eq(bd.guards.respawn_protect_s, 1.5)
