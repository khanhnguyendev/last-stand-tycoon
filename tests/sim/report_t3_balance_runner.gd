extends Node
## The body of tests/sim/report_t3_balance.gd. Output lines start with P1 / P2 / SUMMARY / TABLE / WALL.
## "min" = the lowest diner HP fraction the night reached (0 for a fallen diner).

const P1_VARIANTS := [[0, 16], [0, 17], [0, 18], [0, 19], [0, 20], [1, 16], [2, 16], [3, 16], [4, 16], [5, 16]]  # [seed (0 = the fixture's), day]
const P1_CONFIGS := [["hp500", 500.0, 2.4], ["hp450", 450.0, 2.4], ["hp400", 400.0, 2.4], ["hp350", 350.0, 2.4], ["hp500_speed2.0", 500.0, 2.0]]
const P2_SEEDS := [20260930, 1, 2]
const P2_CAPS := [15, 14, 13, 12]
const P2_DAY := 20  # tier_day 17: brutes and hares are fully ramped on day 20; the cap alone decides the pressure (min(15, cap))

var holder: Node
var _origin := {}      # projectile instance id -> source label, set when first seen
var _claimed := {}
var _dmg := {}         # source -> damage dealt to the Baron
var _hits := {}
var _tap := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var part := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.trim_prefix("--part=")
	holder = Node.new()
	get_tree().root.add_child(holder)
	var t0 := Time.get_ticks_msec()
	if part == "1" or part == "all":
		await _part1()
	if part == "2" or part == "all":
		await _part2()
	print("WALL part=%s %.0f s" % [part, (Time.get_ticks_msec() - t0) / 1000.0])
	holder.queue_free()
	get_tree().quit(0)

# --- one night ------------------------------------------------------------------------------------------------------

## Runs the night from the fixture and returns the facts. `watch_boss`: also the Baron's zone time, HP, lane and (with _tap) damage by source.
func _night(stem: String, p_seed: int, mutate: Callable, watch_boss: bool) -> Dictionary:
	var h := SimHarness.new(holder)
	h.start_from(stem, TierBot, p_seed, "", mutate)
	var wd: WaveDirector = h.main.world.wave_director
	h.diner_min = GameState.diner_hp
	h.failed = false
	h.kills = 0
	var total := 0
	for w in GameState.lane_plan:
		total += int(w.main_count) + int(w.side_count) + int(w.get("brute_main", 0)) + int(w.get("brute_side", 0)) + (1 if w.boss else 0)
	var lane: String = GameState.lane_plan[-1].main
	var zone := MapLayout.zone_rect(lane).grow(0.05)
	var t_start := h.elapsed
	var out := {"lane": lane, "total": total, "zone_t": -1.0, "boss_hp": -1.0, "boss_dead_t": -1.0, "fences": {}, "seen": false}
	var boss: Boar = null
	_origin = {}
	_claimed = {}
	_dmg = {}
	_hits = {}
	for i in 60 * 300:
		await h.tick()
		if h.failed or h.main.phase_controller.phase == Phase.DAY:
			break
		for id in GameState.buildings:
			if MapLayout.spot_kind(id) == "fence":
				out.fences[id] = float(GameState.buildings[id].hp)
		if not watch_boss:
			continue
		if boss == null and not out.seen:
			for b in wd.alive_enemies():
				if (b as Boar).is_boss:
					boss = b
					out.seen = true
		if boss != null:
			if boss.alive:
				out.boss_hp = float(boss.health.hp)
				if out.zone_t < 0.0 and zone.has_point(Vector2(boss.global_position.x, boss.global_position.z)):
					out.zone_t = h.elapsed - t_start
			elif out.boss_dead_t < 0.0:
				out.boss_dead_t = h.elapsed - t_start
				out.boss_hp = 0.0
		if _tap:
			_label_new_projectiles(h)
			if boss != null and boss.alive:
				_count_landing_hits(h, boss)
	out.held = (not h.failed) and h.main.phase_controller.phase == Phase.DAY
	out.fell = h.failed
	out.min_frac = (0.0 if h.failed else h.diner_min / float(Balance.data.build.diner_max_hp))
	out.kills = h.kills
	out.stuck = int(h.bot.stuck_count)
	out.t_end = h.elapsed - t_start
	h.finish()
	await get_tree().process_frame
	return out

## A pooled projectile node is reused: one launch = node + target + target generation + damage.
func _key(p: Object) -> String:
	return "%d_%d_%d_%.2f" % [p.get_instance_id(), int(p._target_index), int(p._target_generation), float(p._damage)]

## Names the shooter of every projectile the first tick it exists: the nearest Attacker node (a launch starts 1 m above the attacker).
func _label_new_projectiles(h: SimHarness) -> void:
	var atts: Array = h.main.find_children("*", "Attacker", true, false)
	var live := {}
	for p in h.main.world.projectile_pool.active():
		live[_key(p)] = true
	for k in _origin.keys():
		if not live.has(k):
			_origin.erase(k)  # the pooled projectile was released: a new launch of the same node must be labelled afresh
	for p in h.main.world.projectile_pool.active():
		var pid = _key(p)
		if _origin.has(pid):
			continue
		var best := ""
		var bd := INF
		for a in atts:
			var d: float = (Vector3(p.global_position) - ((a as Node3D).global_position + Vector3(0, 1.0, 0))).length()
			if d < bd:
				bd = d
				best = String((a as Node).get_parent().name)
		_origin[pid] = best

## Read at the tick boundary (physics_frame fires before the nodes' _physics_process, D-118): a projectile aimed at the live Baron whose
## remaining distance is within one step lands in this tick. Its damage goes to its shooter's label. Hits that spike fences and the like deal
## are not counted (the total is checked against the Baron's HP in the output).
func _count_landing_hits(h: SimHarness, boss: Boar) -> void:
	for p in h.main.world.projectile_pool.active():
		if p._target != boss or p._pool == null or int(p._target_index) != boss.spawn_index:
			continue
		var to: Vector3 = boss.global_position + Vector3(0, 0.5, 0) - p.global_position
		if to.length() <= float(p._speed) / 60.0:
			var label := String(_origin.get(_key(p), "unlabelled"))
			var key := "%s @%.1f" % [label, float(p._damage)]
			_dmg[key] = float(_dmg.get(key, 0.0)) + float(p._damage)
			_hits[key] = int(_hits.get(key, 0)) + 1

# --- part 1 ---------------------------------------------------------------------------------------------------------

func _part1() -> void:
	var rows := {}
	for cfg in P1_CONFIGS:
		var held := 0
		var fr: Array = []
		var fr_held: Array = []
		for v in P1_VARIANTS:
			Balance.reset()
			Balance.data.monsters.baron.hp = cfg[1]
			Balance.data.monsters.baron.speed = cfg[2]
			_tap = cfg[0] == "hp500" and int(v[0]) == 0 and int(v[1]) == 16
			var day: int = v[1]
			var mut := func(st: Dictionary) -> void:
				st.day = day
				st.lane_plan = LanePlanner.with_boss(LanePlanner.plan(int(st.run_seed), day, Balance.data.wave, int(st.tier), int(st.tier_day), Balance.data.tiers))
			var n := await _night("tier3_baron_full", int(v[0]), mut, true)
			var seed_s := "20260930" if int(v[0]) == 0 else str(v[0])
			held += 1 if n.held else 0
			fr.append(n.min_frac)
			if n.held:
				fr_held.append(n.min_frac)
			var end_s := ("died at %.1fs" % n.boss_dead_t) if n.boss_dead_t >= 0.0 else ("hp %.0f left" % n.boss_hp)
			print("P1 cfg=%s seed=%s day=%d lane=%s held=%s min=%.3f baron_in_zone=%s baron=%s night_end=%.1fs kills=%d/%d stuck=%d" % [cfg[0], seed_s, day, n.lane,
				str(n.held).to_lower(), n.min_frac, ("%.1fs" % n.zone_t) if n.zone_t >= 0.0 else "never", end_s, n.t_end, n.kills, n.total, n.stuck])
			if _tap:
				var keys: Array = _dmg.keys()
				keys.sort()
				var sum := 0.0
				for k in keys:
					sum += _dmg[k]
				var parts := []
				for k in keys:
					parts.append("%s=%.0f (%d hits)" % [k, _dmg[k], _hits[k]])
				print("DAMAGE_TO_BARON (cfg hp500, seed 20260930 day 16; Baron HP 500 x wave multiplier; landing-hit damage counted %.0f, includes overkill): %s" % [sum, ", ".join(parts)])
		rows[cfg[0]] = [held, ReportMath.median(fr), ReportMath.percentile(fr, 0.0), (ReportMath.percentile(fr_held, 0.0) if not fr_held.is_empty() else -1.0)]
		print("SUMMARY P1 %s: holds %d/10 median_min=%.3f min_min=%.3f (lowest min among the held nights %.3f)" % [cfg[0], held, rows[cfg[0]][1], rows[cfg[0]][2], rows[cfg[0]][3]])
	print("TABLE P1 (config: holds of 10, median and min diner fraction)")
	for k in rows:
		print("  %-16s %2d/10  median %.3f  min %.3f  (held nights' lowest %.3f)" % [k, rows[k][0], rows[k][1], rows[k][2], rows[k][3]])
	var full := ""
	for k in rows:
		if rows[k][0] == 10 and full == "":
			full = k
	print("PART3 Baron: first tested configuration holding 10 of 10 (order hp500, hp450, hp400, hp350, hp500_speed2.0): %s" % (full if full != "" else "NONE of the five configurations"))

# --- part 2 ---------------------------------------------------------------------------------------------------------

func _part2() -> void:
	var table := {}
	var all_hold_caps := []
	var threat_lines := []
	for cap in P2_CAPS:
		var by_policy := {}
		for sd in P2_SEEDS:
			for policy in TierBot.POLICIES:
				Balance.reset()
				Balance.data.tiers.tier_cap[3] = cap
				_tap = false
				var pol: String = policy
				var mut := func(st: Dictionary) -> void:
					var bd = Balance.data
					st.day = P2_DAY
					var plan := LanePlanner.plan(int(st.run_seed), P2_DAY, bd.wave, 3, int(st.tier_day), bd.tiers)
					st.lane_plan = plan
					var ch := TierBot.branch_choices(pol, MapLayout.spots_for_tier(3), plan, 3)
					for id in ch:
						st.buildings[id].branch = String(ch[id])
						if MapLayout.spot_kind(id) == "fence":
							st.buildings[id].hp = GameState.fence_max_hp(int(bd.build.max_level), ch[id])
				var n := await _night("tier3_cap_" + policy, sd, mut, false)
				var pr: int = GameState.pressure()
				if not by_policy.has(policy):
					by_policy[policy] = []
				by_policy[policy].append(n)
				var fences := []
				for id in ["fence_w", "fence_n", "fence_e", "fence_sw"]:
					fences.append("%s:%.0f" % [id, n.fences.get(id, -1.0)])
				print("P2 cap=%d pressure=%d seed=%d policy=%s held=%s min=%.3f kills=%d/%d stuck=%d fell_at=%s fences=%s" % [cap, pr, sd, policy, str(n.held).to_lower(),
					n.min_frac, n.kills, n.total, n.stuck, ("%.1fs" % n.t_end) if n.fell else "-", " ".join(fences)])
		var parts := []
		var mins := []
		for policy in TierBot.POLICIES:
			var hold := 0
			var mn := 1.0
			var sm := 0.0
			for n in by_policy[policy]:
				hold += 1 if n.held else 0
				mn = minf(mn, n.min_frac)
				sm += n.min_frac
			mins.append(sm / 3.0)
			table["%d/%s" % [cap, policy]] = [hold, mn]
			parts.append("%s %d/3 (min %.3f)" % [policy, hold, mn])
		var cap_all := true
		for policy in TierBot.POLICIES:
			if int(table["%d/%s" % [cap, policy]][0]) != 3:
				cap_all = false
		if cap_all:
			all_hold_caps.append(cap)
		for i in P2_SEEDS.size():
			var every := true
			for policy in TierBot.POLICIES:
				every = every and by_policy[policy][i].held
			if every:
				var th: float = by_policy["threat"][i].min_frac
				var worse := []
				for policy in TierBot.POLICIES:
					if policy != "threat" and by_policy[policy][i].min_frac > th + 1e-9:
						worse.append("%s %.3f" % [policy, by_policy[policy][i].min_frac])
				threat_lines.append("cap %d seed %d: all four hold; threat %.3f; policies above threat: %s" % [cap, P2_SEEDS[i], th, ", ".join(worse) if not worse.is_empty() else "none"])
		var gap: float = (mins.max() - mins.min()) * float(Balance.data.build.diner_max_hp)
		print("SUMMARY P2 cap=%d: %s; best-worst gap in mean diner HP %.1f points of %.0f" % [cap, "; ".join(parts), gap, Balance.data.build.diner_max_hp])
	print("PART3 tier-3 cap: highest tested cap where all four policies hold on all three seeds (tested 15, 14, 13, 12): %s" % (str(all_hold_caps[0]) if not all_hold_caps.is_empty() else "NONE"))
	print("PART3 threat vs the others at every (cap, seed) where all four policies hold: %s" % ("none such" if threat_lines.is_empty() else ""))
	for l in threat_lines:
		print("PART3   " + l)
	print("TABLE P2 (cap x policy: holds of 3, min diner fraction)")
	for k in table:
		print("  %-10s %d/3  min %.3f" % [k, table[k][0], table[k][1]])
