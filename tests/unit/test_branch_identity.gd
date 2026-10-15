extends GutTest
## E5 tier-3 spec 6.4 (D-272.3, D-273.0): the branch identity test on Balance, plus the data shape of tier 3.
## Real HP = base HP x WaveMath.hp_mult(pressure, wave): the multiplier also grows when a wave's raw size passes
## max_wave_size. Whole-hit math: a monster of HP h dies after ceil(h / d) hits (BranchMath).
## M1 (single-target DPS) and M3 (DPS against three targets) are RAW by definition: damage x projectiles on distinct
## targets / interval. Kill rates (M4, the brute check) use whole hits, so overkill counts against a tower.

## Every case here runs on the LIVE pressures [10, 11, 12] (D-304: tier 3 starts at tier 2's cap 10 and ends at its own cap 12). The old cases at
## 13 to 15 (unreachable since D-280) were converted to this range in the debt sweep. PRESSURES is the explicit list; test_live_pressure_range_*
## derive the range from tier_base[3]..tier_cap[3] and fail if the two ever differ.
const PRESSURES: Array[int] = [10, 11, 12]
const WAVES := 3

# Real hare HP per [pressure][wave], verified by hand: 15 x (1 + 0.15 x (p - 1)) x max(1, raw / 30); boar 30 and brute 240 scale the same way.
# p10: hp_growth part 2.35; raw 33 on the last wave -> x 1.1: hare 35.25, 35.25, 38.775 (35.25 x 1.1); boar 70.5, 70.5, 77.55; brute 564, 564, 620.4.
# p11: 2.5; raw 36 on the last wave -> x 1.2: hare 37.5, 37.5, 45.0; boar 75, 75, 90; brute 600, 600, 720.
# p12: raw 19, 29, 39 -> 15 x 2.65 = 39.75, 39.75, then 39/30 x 2.65 x 15 = 51.675.
const HARE_HP := {10: [35.25, 35.25, 38.775], 11: [37.5, 37.5, 45.0], 12: [39.75, 39.75, 51.675]}
const BOAR_HP := {10: [70.5, 70.5, 77.55], 11: [75.0, 75.0, 90.0], 12: [79.5, 79.5, 103.35]}
const BRUTE_HP := {10: [564.0, 564.0, 620.4], 11: [600.0, 600.0, 720.0], 12: [636.0, 636.0, 826.8]}

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
	assert_almost_eq(_hp(15.0, 10, 0), 35.25, 1e-6, "35 at pressure 10, tier 3's first night")

# --- the live pressure range (D-280) --------------------------------------------------------------------

func _live_pressures() -> Array[int]:
	var out: Array[int] = []
	for p in range(bd.tiers.tier_base[3], bd.tiers.tier_cap[3] + 1):
		out.append(p)
	return out

func test_live_pressure_range_is_inside_the_covered_cases_and_nothing_above_the_cap_is_reached() -> void:
	var live := _live_pressures()
	assert_eq(live, [10, 11, 12] as Array[int], "tier 3 starts at tier 2's cap 10 and ends at its own cap 12 (D-304)")
	assert_eq(live, PRESSURES, "the explicit list and the balance's range are the same")
	for p in live:
		assert_true(p in PRESSURES and HARE_HP.has(p), "live pressure %d is covered by the identity cases" % p)
	for p in PRESSURES:
		assert_lte(p, bd.tiers.tier_cap[3], "no case runs above the tier-3 cap (D-280): %d" % p)
	for day in range(1, 80):
		assert_lte(WaveMath.pressure(day, 3, 17, bd.tiers), bd.tiers.tier_cap[3], "day %d never passes the cap" % day)

func test_live_pressure_range_real_hp_and_identity_hold() -> void:
	var t := _towers()
	for p in _live_pressures():
		for w in WAVES:
			assert_true(HARE_HP.has(p), "the pin table has live pressure %d" % p)  # was a silent skip
			assert_almost_eq(_hp(bd.monsters.stats(&"hare").hp, p, w), HARE_HP[p][w], 1e-3, "live hare p%d w%d" % [p, w])
			assert_almost_eq(_hp(bd.monsters.stats(&"brute").hp, p, w), BRUTE_HP[p][w], 1e-3, "live brute p%d w%d" % [p, w])
			var hare := _hp(bd.monsters.stats(&"hare").hp, p, w)
			for n in [3, 5, 8]:
				var v := {}
				for id in t:
					v[id] = BranchMath.kills_per_second(hare, t[id], n)
				assert_eq(_best(v), &"volley", "live most: p%d w%d n%d" % [p, w + 1, n])
				assert_eq(_worst(v), &"longbow", "live fewest: p%d w%d n%d" % [p, w + 1, n])
			var bh := _hp(bd.monsters.stats(&"brute").hp, p, w)
			assert_gte(BranchMath.kills_per_second(bh, t[&"longbow"], 1), BranchMath.kills_per_second(bh, t[&""], 1) - 1e-9, "live longbow vs brute p%d w%d" % [p, w])

## E6 (D-304): tier 3 starts at pressure 10 and ramps to the cap 12, so the live range is [10, 11, 12] (tables above).

## The live Longbow: the balance's Longbow (its 2.0 s interval) with its damage x its own multiplier for a monster of `kind` (an absent kind = 1.0).
func _longbow_on(kind: StringName = &"") -> TowerBranchStats:
	var lb: TowerBranchStats = bb.tower(&"longbow").duplicate()
	lb.damage = bb.longbow.damage * float(bb.longbow.kind_mults.get(kind, 1.0))
	return lb

func test_live_pressure_range_real_hp_is_pinned() -> void:
	for p in _live_pressures():  # derived from the balance, so a changed cap fails on a missing table row
		assert_true(HARE_HP.has(p) and BOAR_HP.has(p) and BRUTE_HP.has(p), "pin tables cover live pressure %d" % p)
		for w in WAVES:
			assert_almost_eq(_hp(bd.monsters.stats(&"hare").hp, p, w), HARE_HP[p][w], 1e-3, "hare p%d w%d" % [p, w])
			assert_almost_eq(_hp(bd.monsters.stats(&"boar").hp, p, w), BOAR_HP[p][w], 1e-3, "boar p%d w%d" % [p, w])
			assert_almost_eq(_hp(bd.monsters.stats(&"brute").hp, p, w), BRUTE_HP[p][w], 1e-3, "brute p%d w%d" % [p, w])

func test_live_pressure_range_identity_holds_with_the_live_longbow() -> void:
	var lb := _longbow_on()
	assert_eq([lb.interval, lb.damage], [2.0, 120.0], "Longbow: 2.0 s interval, damage 120 against a hare")
	assert_eq(_longbow_on(&"brute").damage, 240.0, "x the brute multiplier 2.0")
	var t := _towers()
	t[&"longbow"] = lb
	for p in _live_pressures():
		for w in WAVES:
			var hare := _hp(bd.monsters.stats(&"hare").hp, p, w)
			for n in [3, 5, 8]:
				var v := {}
				for id in t:
					v[id] = BranchMath.kills_per_second(hare, t[id], n)
				assert_eq(_best(v), &"volley", "most: p%d w%d n%d" % [p, w + 1, n])
				assert_eq(_worst(v), &"longbow", "fewest: p%d w%d n%d" % [p, w + 1, n])
			var bh := _hp(bd.monsters.stats(&"brute").hp, p, w)
			var kl := BranchMath.kills_per_second(bh, _longbow_on(&"brute"), 1)
			var ku := BranchMath.kills_per_second(bh, t[&""], 1)
			assert_gte(kl, ku - 1e-9, "longbow vs a brute p%d w%d (%.4f vs %.4f)" % [p, w + 1, kl, ku])

# --- the seven measures, one test each, every wave at both pressures ------------------------------------

func test_m1_single_target_dps_longbow_highest() -> void:
	var t := _towers()
	assert_almost_eq(BranchMath.single_dps(t[&"longbow"]), 120.0 / 2.0, 1e-6)
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
	# E6 (D-297): the Longbow's 2.0 s interval makes its raw damage per second (120 / 2.0 = 60, one target) EQUAL to Volley's three projectiles
	# (3 x 10 / 0.5 = 60): Volley is at the top, shared with the Longbow, and well above the unbranched tower (18 / 0.5 = 36).
	assert_eq(_top_set(v), [&"longbow", &"volley"], "the top is shared by exactly the Longbow and Volley")
	assert_true(&"volley" in _top_set(v), "Volley is at the top (alone or tied)")
	assert_almost_eq(float(v[&"longbow"]), 60.0, 1e-9)
	assert_almost_eq(float(v[&"volley"]), 60.0, 1e-9)
	assert_almost_eq(float(v[&""]), 36.0, 1e-9)
	gut.p("M3 dps vs 3 targets: unbranched %.1f longbow %.1f volley %.1f" % [v[&""], v[&"longbow"], v[&"volley"]])

func test_m4_hares_per_second_volley_most_longbow_fewest() -> void:
	var t := _towers()
	for p in _live_pressures():
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
	var hare := _hp(15.0, 11, 2)  # 45.0 (live): unbranched 3 hits (1.5 s), Longbow one shot per 2.0 s, Volley 5 hits per target (3 projectiles)
	assert_almost_eq(BranchMath.kills_per_second(hare, t[&""], 5), 1.0 / 1.5, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(hare, t[&"longbow"], 5), 1.0 / 2.0, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(hare, t[&"volley"], 5), 3.0 / 2.5, 1e-9)
	var first := _hp(15.0, 10, 0)  # 35.25 (tier 3's first night): 2 hits, 1 shot, 4 hits
	assert_almost_eq(BranchMath.kills_per_second(first, t[&""], 5), 1.0, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(first, t[&"longbow"], 5), 0.5, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(first, t[&"volley"], 5), 1.5, 1e-9)
	var easy := _hp(15.0, 12, 0)  # 39.75: 3 hits, 1 shot, 4 hits
	assert_almost_eq(BranchMath.kills_per_second(easy, t[&""], 5), 2.0 / 3.0, 1e-9)
	assert_almost_eq(BranchMath.kills_per_second(easy, t[&"volley"], 5), 1.5, 1e-9)

## Whole-shot check against the brute with ONE target in range: Longbow is never slower than the unbranched tower.
func test_longbow_kills_a_lone_brute_at_least_as_fast_as_unbranched() -> void:
	var t := _towers()
	var ties := 0
	var waves_checked := 0
	for p in PRESSURES:
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
	for p in PRESSURES:
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
	var base := BranchMath.spike_base_mult(bd.wave, bd.branches)
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
	for p in PRESSURES:
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
	var base := BranchMath.spike_base_mult(bd.wave, bd.branches)
	assert_almost_eq(base, 2.65, 1e-9, "first wave at pressure 12 (the tier's cap, not its first night's 10)")
	assert_almost_eq(BranchMath.spike_scale(base, base), 1.0, 1e-9)
	var s := BranchMath.spike_scale(WaveMath.hp_mult(12, 2, bd.wave), base)
	assert_almost_eq(s, 1.3, 1e-9, "last wave at pressure 12: raw 39 / 30 = 1.3 times the first wave's multiplier")
	assert_almost_eq(BranchMath.pass_damage(bb.fence(&"spike"), &"hare", s), 24.0 * s, 1e-9)

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
	assert_eq([lb.attack_range, lb.damage, lb.interval, lb.count], [9.98, 120.0, 2.0, 1])
	var vo := bb.tower(&"volley")
	assert_eq([vo.attack_range, vo.damage, vo.interval, vo.count], [8.0, 10.0, 0.5, 3])
	var st := bb.fence(&"stone")
	assert_eq([st.hp, st.thorn_damage, st.pass_damage], [640.0, 0.0, 0.0])
	assert_eq(st.damage_taken_mult_by_kind, {&"brute": 0.5})
	var sp := bb.fence(&"spike")
	assert_eq([sp.hp, sp.thorn_damage, sp.pass_damage], [320.0, 6.0, 24.0])
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

func test_tier_3_arrays_are_live_and_the_top_tier_is_3() -> void:
	var tb := bd.tiers
	assert_eq(Array(tb.tier_costs), [0, 500, 1500])
	assert_eq(TierEffects.top_tier(tb), 3)
	assert_eq(TierEffects.tier_cost(2, tb), 1500, "tier 3 is reachable (the switch)")
	assert_eq(TierEffects.tier_cost(3, tb), -1, "nothing is sold beyond tier 3")
	var n := tb.tier_costs.size() + 1
	for arr in [tb.tier_base, tb.tier_cap, tb.fast_share_start, tb.fast_share, tb.fast_ramp_days, tb.brute_cap_main, tb.brute_cap_side, tb.brute_ramp_days, tb.boss_kind]:
		assert_gte((arr as Array).size(), n)
	assert_eq([tb.tier_base[3], tb.tier_cap[3]], [10, 12], "tier 3 starts at tier 2's cap and reaches its own on its third night (D-304)")
	assert_eq([tb.fast_share_start[3], tb.fast_share[3], tb.fast_ramp_days[3]], [0.35, 0.35, 1])
	assert_eq([tb.brute_cap_main[3], tb.brute_cap_side[3], tb.brute_ramp_days[3]], [1, 0, 3], "main-lane brutes only (the ruling)")
	assert_eq([tb.brute_cap_main[2], tb.brute_cap_side[2]], [0, 0], "tier 2 carries no brutes")
	assert_eq(tb.boss_kind[1], &"boss")
	assert_eq(tb.boss_kind[2], &"baron")
	assert_eq(Array(tb.boss_kind), [&"", &"boss", &"baron", &""])
	var last := tb.boss_kind.size() - 1
	for t in range(1, last):
		assert_ne(tb.boss_kind[t], &"", "boss_kind[%d] must name the boss that leaves tier %d (a new tier must add its boss)" % [t, t])
	assert_eq(tb.boss_kind[last], &"", "no boss leaves the top tier: the last boss_kind entry is empty")
	assert_eq(bd.guards.respawn_protect_s, 1.5)

# ---- E6 Task 9 (spec 4.3, D-294.6, D-294.7): the identity restated on the lane-type bench's measures ----------------------
## Uses the bench's FAST subset (tests/unit/test_branch_bench.gd computes it; BranchBench.fast_results() caches it per process, so this adds
## no runs when that file ran first): pressure 12, the LAST wave of each mix only, an invulnerable diner. A shorter night than the full
## bench (tests/bench/test_branch_bench_full.gd runs the same rules over three waves). The assertions above (Balance only) are
## untouched. The fast file's old combined identity test moved here, with the stands-longest and fewest-hares rules added.

func _fast() -> Dictionary:
	return await BranchBench.fast_results()

## A run the identity rules read must have cleared the night.
func _ok_runs(lane_results: Dictionary, lane: StringName) -> void:
	for name in lane_results:
		assert_false(lane_results[name].timed_out, "%s %s did not clear before MAX_TICKS (timed out)" % [lane, name])

func test_e6_identity_longbow_is_the_best_tower_state_against_the_siege_mix() -> void:
	var f := await _fast()
	_ok_runs(f[&"siege"], &"siege")
	var v := BranchBench.identity_longbow_siege(f[&"siege"])
	assert_true(v.ok, "%s | fails when: %s" % [v.why, BranchBench.IDENTITY_FAILS_WHEN["longbow_siege"]])

func test_e6_identity_volley_is_the_best_tower_state_against_the_hare_mix() -> void:
	var f := await _fast()
	_ok_runs(f[&"hare"], &"hare")
	var v := BranchBench.identity_volley_hare(f[&"hare"])
	assert_true(v.ok, "%s | fails when: %s" % [v.why, BranchBench.IDENTITY_FAILS_WHEN["volley_hare"]])

func test_e6_identity_stone_wall_fence_stands_longest_against_brutes() -> void:
	var f := await _fast()
	_ok_runs(f[&"siege"], &"siege")
	var v := BranchBench.identity_stone_stands_longest(f[&"siege"])
	assert_true(v.ok, "%s | fails when: %s" % [v.why, BranchBench.IDENTITY_FAILS_WHEN["stone_stands"]])

func test_e6_identity_spike_fence_lets_the_fewest_hares_reach_the_zone_on_the_hare_lane() -> void:
	var f := await _fast()
	_ok_runs(f[&"hare"], &"hare")
	var v := BranchBench.identity_spike_fewest_hares(f[&"hare"])
	assert_true(v.ok, "%s | fails when: %s" % [v.why, BranchBench.IDENTITY_FAILS_WHEN["spike_hares"]])

func test_e6_identity_unbranched_is_never_the_best_at_any_named_measure_on_any_lane_type() -> void:
	var f := await _fast()
	for lane in BranchBench.LANES:
		var l: Dictionary = f[lane]
		_ok_runs(l, lane)
		var base: Dictionary = l["-/-"]
		var towers := minf(float(l["longbow/-"].diner_lost), float(l["volley/-"].diner_lost))
		var fences := minf(float(l["-/stone"].diner_lost), float(l["-/spike"].diner_lost))
		assert_lt(towers, float(base.diner_lost) - BranchBench.SAME, "%s: the unbranched tower is never best on diner HP lost (best branch %.1f vs %.1f)" % [lane, towers, base.diner_lost])
		assert_lt(fences, float(base.diner_lost) - BranchBench.SAME, "%s: the unbranched fence is never best on diner HP lost (best branch %.1f vs %.1f)" % [lane, fences, base.diner_lost])
	var s: Dictionary = f[&"siege"]
	assert_gt(maxf(float(s["-/stone"].fence_stands_s), float(s["-/spike"].fence_stands_s)), float(s["-/-"].fence_stands_s), "siege: a branched fence stands longer than the unbranched one")
	var h: Dictionary = f[&"hare"]
	assert_lt(mini(int(h["-/stone"].hares_in_zone), int(h["-/spike"].hares_in_zone)), int(h["-/-"].hares_in_zone), "hare: a branched fence lets fewer hares in than the unbranched one")
