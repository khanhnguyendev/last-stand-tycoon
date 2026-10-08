extends Node
## Manual difficulty sweep (D-059, D-066, D-067): PlannerBot days 1-14 by default -> tests/sim/out/sweep.csv.
## `--bot=upgrader` runs the UpgraderBot and writes `sweep_upgrader.csv` with a `stations` column (E1).
## `--bot=tier` runs the TierBot -> `sweep_tier.csv` (+ tier,boss_night,boss_retries) and prints a TIER line (E5).
## `--policy=all_a|all_b|mixed|threat|volley_stone|unbranched` sets the tier bot's branch policy (default threat). `--tier3=off` removes the tier-3 cost entry in memory,
## and the run then asserts that no brute died, no wave came from the south-west and no branch was chosen (the Task 21 assertion, D-279):
## a TIER3_GATE line, exit code 1 on a violation. Tier rows end with brute_kills,sw_waves,branches (per day, appended after the old columns; sw_waves counts waves with a south-west lane, formerly named sw_spawns).
## After the SWEEP line it prints a RETRIES line (days, median, max_before_day8, max, target_ok) for the D-184 retries-per-night target.
## Tuning overrides (in memory only, after Balance.reset(); printed on the first output line; they apply to EVERY bot, not only the tier bot (not rejected for the
## planner and upgrader bots: a study may run those on a changed balance on purpose)): `--tier3-cap=<n>` (tier_cap[3]),
## `--brute-caps=<main>,<side>` (brute_cap_main[3], brute_cap_side[3]; both numbers are required), `--brute-hp=<n>`, `--fence-mult=<x>` (the brute's fence_damage_mult).
## `--out=<file name>` writes tests/sim/out/<file name> (a relative path such as policies/x.csv is allowed, no `..`) instead of the default (parallel runs). `--cols=extra` appends fences_lost (fences at 0 HP when the
## night ended, final attempt) and lane_load (enemies per lane in the night's plan, brutes included) to the tier rows; without it the CSV is byte-identical to before.
## The TIER3 line (tier bot): nights, retry_nights, retries, cap_nights (pressure at tier_cap[3] when the night began), cap_retry_nights, and the min and median
## diner fraction over the tier-3 nights that were held (the final attempt's lowest diner HP). NOTE: `kills` and `brute_kills` in the rows include the kills of failed attempts.
## Tier mode also prints, after TIER3_GATE (stdout only; the CSV is not touched):
##   T3RUN seed policy nights retry_nights min median mean fences_lost_mean branches branch_gold unspent_last_day hard_break_day: the tier-3 facts of this run
##   (SweepMath.tier3_stats; the night statistics count nights that STARTED at tier >= 3; branches and branch_gold count every row that CLOSED at tier >= 3, the
##   tier-3 dawn day's purchases included; branch_gold = the cost of every branch bought, re-buys included; read by tests/sim/report_policies.gd). A retried night counts its final (mercy) attempt.
##   LADDER plot_day=<d> ladder_done_day=<d> max_unspent_during_ladder=<g> fence_rebuild_gold_median_at_cap=<g> income_at_cap=<g> t3_days_to_done=<n> max_unspent_while_purchasable=<g>
##   (SweepMath.ladder_summary; run with --days=30 or more). ALL days are ROW numbers of the sweep CSV (row N = night N, then the day phase that follows it):
##     plot_day = the row whose day phase paid the tier-3 sign (the front lot) in full (-1 never). The Baron night is row plot_day + 1 (it closes at tier 3: the tier-3 dawn day);
##       the first tier-3 night is row plot_day + 2.
##     ladder_done_day = the first row whose close-up leaves nothing purchasable (tier 3, every spot of the tier at max level, every tower and fence branched, both stations at
##       max level) or -1; t3_days_to_done = the day phases that closed at tier 3, from the tier-3 dawn day to ladder_done_day inclusive (-1 when never).
##     max_unspent_during_ladder = the largest unspent gold at close-up over the rows that closed at tier 3, up to and including ladder_done_day (every such row when -1)
##       (spec section 8: "from the tier-3 dawn until the ladder completes"); max_unspent_while_purchasable = the same without the done row (its leftover is not unspent
##       while something is still to buy).
##     fence_rebuild_gold_median_at_cap = over the tier-3 cap nights (pressure = tier_cap[3] at the start) the median of the gold paid in the day phase that follows for
##       (a) levels of fences that fell that night, from the payment signals (building_changed on a fence that stood at the night's start and was rubble at its end) and
##       (b) the re-purchase of the branch such a fence had lost (branch_chosen on it, the branch's cost net of refunds). First-time fence branches are not counted.
##       A retried night's own day phases are excluded. income_at_cap = the median gold the same days' sales paid.
##   UNSPENT_TARGET: PASS|FAIL|N/A (spec section 8, limit 650 on max_unspent_during_ladder; N/A unless the ladder completed within the run) and
##   FENCE_TAX: yes|no (share of fence_rebuild_gold_median_at_cap in income_at_cap above 30%): both printed with LADDER, asserted nowhere in CI.
##     The figure UNDER-COUNTS when a rebuild is deferred to a later day (a fence that fell and was rebuilt after the next night is attributed to the day it was paid in, and a
##     night that follows a skipped rebuild shows no rebuild at all), so FENCE_TAX: no is a lower bound.
##   `--cols=extra` also appends fence_rebuild_gold (rebuild + rebranch of that row's day phase) at the END of the tier rows.
## Loaded at run time by tests/sim/sweep.gd, after the autoloads exist (D-150).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {"seed": "20260930", "days": "14", "bot": "planner", "policy": "threat", "tier3": "on", "tier3-cap": "", "brute-caps": "", "brute-hp": "", "fence-mult": "", "out": "", "cols": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if not String(args.bot) in ["planner", "upgrader", "tier"]:
		push_error("unknown --bot=%s (planner|upgrader|tier)" % args.bot)
		get_tree().quit(2)
		return
	if not (String(args.policy) in TierBot.POLICIES or String(args.policy) in TierBot.REPORT_POLICIES) or not String(args.tier3) in ["on", "off"]:
		push_error("bad --policy=%s (all_a|all_b|mixed|threat|volley_stone|unbranched) or --tier3=%s (on|off)" % [args.policy, args.tier3])
		get_tree().quit(2)
		return
	if not String(args.bot) == "tier" and (args.policy != "threat" or args.tier3 != "on"):
		print("WARNING: --policy and --tier3 only apply to --bot=tier; ignored for --bot=%s" % args.bot)
	Balance.reset()
	if String(args.tier3) == "off":
		Balance.data.tiers.tier_costs.resize(2)  # in memory only: no sign sells tier 3
	var tier_mode := String(args.bot) == "tier"
	var ov: Array = []
	if String(args["tier3-cap"]) != "":
		Balance.data.tiers.tier_cap[3] = int(args["tier3-cap"])
		ov.append("tier3-cap=%d" % int(args["tier3-cap"]))
	if String(args["brute-caps"]) != "":
		var bc := String(args["brute-caps"]).split(",")
		if bc.size() != 2 or not bc[0].is_valid_int() or not bc[1].is_valid_int():
			push_error("bad --brute-caps=%s (expected <main>,<side>, two integers)" % args["brute-caps"])
			get_tree().quit(2)
			return
		Balance.data.tiers.brute_cap_main[3] = int(bc[0])
		Balance.data.tiers.brute_cap_side[3] = int(bc[1])
		ov.append("brute-caps=%s" % args["brute-caps"])
	if String(args["brute-hp"]) != "":
		Balance.data.monsters.brute.hp = float(args["brute-hp"])
		ov.append("brute-hp=%s" % args["brute-hp"])
	if String(args["fence-mult"]) != "":
		Balance.data.monsters.brute.fence_damage_mult = float(args["fence-mult"])
		ov.append("fence-mult=%s" % args["fence-mult"])
	print("OVERRIDES %s" % (" ".join(ov) if not ov.is_empty() else "none"))
	var extra := String(args.cols) == "extra" and tier_mode
	var upgrader := String(args.bot) == "upgrader" or tier_mode
	var holder := Node.new()
	get_tree().root.add_child(holder)
	var h := SimHarness.new(holder)
	_h = h
	h.start(int(args.seed), TierBot if tier_mode else (UpgraderBot if upgrader else PlannerBot))
	if tier_mode:
		h.bot.policy = String(args.policy)
		EventBus.enemy_killed.connect(_on_enemy_killed)
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.branch_chosen.connect(_on_branch_chosen)
		EventBus.tier_paid_up.connect(_on_tier_paid_up)
		EventBus.building_changed.connect(_on_building_changed)
	EventBus.steak_sold.connect(_on_sold)
	EventBus.card_picked.connect(_on_picked)
	EventBus.guard_knocked_out.connect(_on_knockout)
	var rows := ["day,diner_frac,failed_retries,kills,steaks,gold_earned,builds_defending,enemy_count,night_seconds,day_seconds,unspent_gold_at_closeup,cards,guard_knockouts,picked" + (",stations" if upgrader else "") + (",tier,boss_night,boss_retries,brute_kills,sw_waves,branches" if tier_mode else "") + (",fences_lost,lane_load,fence_rebuild_gold" if extra else "")]
	var first_fail_day := -1
	var hard_break_day := -1
	var retries_per_day: Array = []
	var nights: Array = []
	var unspent_day14 := -1
	var tier3_events := 0
	var day_records: Array = []
	var last_unspent := 0
	for day in range(1, int(args.days) + 1):
		_row_day = day
		_rebuild_gold = 0
		_rebranch_gold = 0
		_tax_on = false
		var retries := 0
		_picked = ""
		_knockouts = 0
		_brute_kills = 0
		_sw_waves = 0
		_branches = 0
		_branch_gold = 0
		var enemy_count := SweepMath.enemy_count(GameState.lane_plan)  # the night's own plan (capped past day 7)
		var boss_night := GameState.is_boss_night()
		var start_tier := GameState.tier
		var at_cap := start_tier == 2 and GameState.pressure() == int(Balance.data.tiers.tier_cap[2])
		var at_cap3 := start_tier == 3 and GameState.pressure() == int(Balance.data.tiers.tier_cap[3])
		var lane_load := _lane_load()
		_fence_hp = {}
		_fence_branch = {}
		var defending := _builds()  # what stands when the night starts (spent during the day before)
		var stock0 := GameState.freezer_steaks + GameState.carried_steaks
		var t0 := h.elapsed
		var n := await h.run_night()
		if n.failed and first_fail_day < 0:
			first_fail_day = day
		# Retries run with mercy (S3, D-175): each retry of the same night is weaker, so a failed night can clear on a later retry.
		while n.failed and retries < 4:
			retries += 1
			var restored := await h.run_until(func(): return not h.main.phase_controller.failing, Balance.ui.banner_time + 1.0)
			if not restored:
				break
			if h.main.phase_controller.phase == Phase.DAY:
				await h.run_day()
			t0 = h.elapsed
			_knockouts = 0  # per attempt: the row reports the last attempt's knockouts
			n = await h.run_night()
		retries_per_day.append(retries)  # hard-break days count too
		var lost_now := 0
		for fid in _fence_hp:
			lost_now += 1 if float(_fence_hp[fid]) <= 0.0 else 0
		_capture_night_end()
		nights.append({"day": day, "tier": start_tier, "tier_close": start_tier, "boss_night": boss_night, "retries": retries, "at_cap": at_cap, "at_cap3": at_cap3, "frac": n.diner_frac, "failed": n.failed,
			"fences_lost": lost_now, "branches": _branches, "branch_gold": _branch_gold})
		var night_s := h.elapsed - t0
		if n.failed:
			hard_break_day = day
			var tcols := _tier_cols(tier_mode, start_tier, boss_night, retries) + (_extra_cols(lane_load) if extra else "")
			tier3_events += _brute_kills + _sw_waves + _branches
			rows.append("%d,%.3f,%d,%d,0,0,%s,%d,%.1f,,,%s,%d," % [day, n.diner_frac, retries, n.kills, defending, enemy_count, night_s, _cards(), _knockouts] + _stations(upgrader) + tcols)
			break
		# dawn moved the night's steaks to the freezer (freezer + carried, as test_night_sims counts); gold is what the day's sales pay out
		var steaks := GameState.freezer_steaks + GameState.carried_steaks - stock0
		_gold_sold = 0
		_snapshot_fence_paid()
		_tax_on = tier_mode
		var d := await h.run_day()
		_tax_on = false
		nights[nights.size() - 1].tier_close = GameState.tier
		nights[nights.size() - 1].branches = _branches  # the branches are bought by day
		nights[nights.size() - 1].branch_gold = _branch_gold
		var tcols := _tier_cols(tier_mode, start_tier, boss_night, retries) + (_extra_cols(lane_load) if extra else "")  # after the day: the branches are bought by day
		tier3_events += _brute_kills + _sw_waves + _branches
		if not d.closed:
			rows.append("%d,STALL" % day + _stations(upgrader) + tcols)
			break
		rows.append("%d,%.3f,%d,%d,%d,%d,%s,%d,%.1f,%.1f,%d,%s,%d,%s" % [day, n.diner_frac, retries, n.kills, steaks,
			_gold_sold, defending, enemy_count, night_s, d.seconds, int(h.main.phase_controller.snapshot.gold), _cards(), _knockouts, _picked] + _stations(upgrader) + tcols)
		last_unspent = int(h.main.phase_controller.snapshot.gold)
		if tier_mode:
			day_records.append({"day": day, "tier": GameState.tier, "at_cap3": at_cap3, "income": _gold_sold, "rebuild": _rebuild_gold, "rebranch": _rebranch_gold, "unspent": last_unspent, "done": _ladder_done()})
		if day == 14:
			unspent_day14 = int(h.main.phase_controller.snapshot.gold)
	if EventBus.steak_sold.is_connected(_on_sold):
		EventBus.steak_sold.disconnect(_on_sold)
	if EventBus.card_picked.is_connected(_on_picked):
		EventBus.card_picked.disconnect(_on_picked)
	if EventBus.guard_knocked_out.is_connected(_on_knockout):
		EventBus.guard_knocked_out.disconnect(_on_knockout)
	var out_dir := ProjectSettings.globalize_path("res://tests/sim/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gi := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)  # keep Godot from importing out/
	gi.close()
	var out_name := "sweep_tier.csv" if tier_mode else ("sweep_upgrader.csv" if upgrader else "sweep.csv")
	if String(args.out) != "":
		out_name = String(args.out)
		if out_name.begins_with("/") or ".." in out_name:
			push_error("bad --out=%s (a file name or a relative path under tests/sim/out/, no '..')" % out_name)
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(out_dir.path_join(out_name).get_base_dir())
	var f := FileAccess.open(out_dir.path_join(out_name), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	print("\n".join(rows))
	print("SWEEP first_fail_day=%d hard_break_day=%d unspent_day14=%d" % [first_fail_day, hard_break_day, unspent_day14])
	var sorted_r := retries_per_day.duplicate()
	sorted_r.sort()
	var median := 0.0
	var max_r := 0
	var max_early := 0
	if not sorted_r.is_empty():
		var mid := sorted_r.size() / 2
		median = float(sorted_r[mid]) if sorted_r.size() % 2 == 1 else (sorted_r[mid - 1] + sorted_r[mid]) / 2.0
		max_r = sorted_r.back()
	for i in range(mini(7, retries_per_day.size())):
		max_early = maxi(max_early, retries_per_day[i])
	print("RETRIES days=%d median=%s max_before_day8=%d max=%d target_ok=%s" % [retries_per_day.size(), median, max_early, max_r, str(median == 0.0 and max_early <= 2).to_lower()])
	if tier_mode:
		for pair in [[EventBus.enemy_killed, _on_enemy_killed], [EventBus.wave_started, _on_wave_started], [EventBus.branch_chosen, _on_branch_chosen], [EventBus.tier_paid_up, _on_tier_paid_up], [EventBus.building_changed, _on_building_changed]]:
			var sig: Signal = pair[0]
			if sig.is_connected(pair[1]):
				sig.disconnect(pair[1])
		var ts := SweepMath.tier_summary(nights)
		print("TIER first_tier2_day=%d boss_retries=%d cap_nights=%d cap_retries=%d" % [ts.first_tier2_day, ts.boss_retries, ts.cap_nights, ts.cap_retries])
		var t3n := 0
		var t3_retry_nights := 0
		var t3_retries := 0
		var t3_cap := 0
		var t3_cap_retry := 0
		var held_fracs: Array = []
		for nt in nights:
			if int(nt.tier) != 3:
				continue
			t3n += 1
			t3_retries += int(nt.retries)
			t3_retry_nights += 1 if int(nt.retries) > 0 else 0
			t3_cap += 1 if nt.at_cap3 else 0
			t3_cap_retry += 1 if (nt.at_cap3 and int(nt.retries) > 0) else 0
			if not nt.failed:
				held_fracs.append(float(nt.frac))
		print("TIER3 nights=%d retry_nights=%d retries=%d cap_nights=%d cap_retry_nights=%d min_frac_held=%.3f median_frac_held=%.3f" % [t3n, t3_retry_nights, t3_retries,
			t3_cap, t3_cap_retry, ReportMath.percentile(held_fracs, 0.0) if not held_fracs.is_empty() else -1.0, ReportMath.median(held_fracs) if not held_fracs.is_empty() else -1.0])
		print("TIER3_GATE tier3=%s policy=%s events=%d" % [args.tier3, args.policy, tier3_events])
		var rs := SweepMath.tier3_stats(nights)
		print("T3RUN seed=%s policy=%s nights=%d retry_nights=%d min=%.3f median=%.3f mean=%.4f fences_lost_mean=%.2f branches=%d branch_gold=%d unspent_last_day=%d hard_break_day=%d" % [
			args.seed, args.policy, rs.nights, rs.retry_nights, rs.min, rs.median, rs.mean, rs.fences_lost_mean, rs.branches, rs.branch_gold, last_unspent, hard_break_day])
		var ls := SweepMath.ladder_summary(_plot_day, day_records)
		print("LADDER plot_day=%d ladder_done_day=%d max_unspent_during_ladder=%d fence_rebuild_gold_median_at_cap=%d income_at_cap=%d t3_days_to_done=%d max_unspent_while_purchasable=%d" % [
			ls.plot_day, ls.ladder_done_day, ls.max_unspent_during_ladder, ls.fence_rebuild_gold_median_at_cap, ls.income_at_cap, ls.t3_days_to_done, ls.max_unspent_while_purchasable])
		print(SweepMath.unspent_target_line(ls))
		print(SweepMath.fence_tax_line(ls))
		if String(args.tier3) == "off" and tier3_events != 0:
			push_error("tier 3 is not for sale but %d brute kills, south-west spawns and branches were counted" % tier3_events)
			h.finish()
			get_tree().quit(1)
			return
	h.finish()
	get_tree().quit(0)

var _gold_sold := 0
var _fence_hp := {}

var _h: SimHarness

## Last night tick's fence HP (the dawn reset must not hide a fallen fence).
func _physics_process(_delta: float) -> void:
	if _h == null or _h.main == null or GameState.buildings.is_empty() or _h.main.phase_controller.phase != Phase.NIGHT:
		return
	for id in GameState.buildings:
		if MapLayout.spot_kind(id) == "fence" and int(GameState.buildings[id].level) > 0:
			_fence_hp[id] = float(GameState.buildings[id].hp)
			_fence_branch[id] = String(GameState.buildings[id].branch)

func _extra_cols(lane_load: String) -> String:
	var lost: Array = []
	for id in _fence_hp:
		if float(_fence_hp[id]) <= 0.0:
			lost.append(id)
	lost.sort()
	return ",%s,%s,%d" % ["|".join(lost), lane_load, _rebuild_gold + _rebranch_gold]

func _lane_load() -> String:
	var comp := LanePlanner.composition_by_lane(GameState.lane_plan, GameState.tier)
	var parts: Array = []
	for lane in LanePlanner.lanes_for_tier(GameState.tier):
		var c: Dictionary = comp.get(lane, {})
		parts.append("%s:%d" % [lane, int(c.get("boar", 0)) + int(c.get("hare", 0)) + int(c.get("brute", 0)) + int(c.get("boss", 0))])
	return "|".join(parts)
var _brute_kills := 0
var _sw_waves := 0
var _branches := 0

func _on_enemy_killed(_i: int, _lane: StringName, _p: Vector3, kind: StringName) -> void:
	if kind == &"brute":
		_brute_kills += 1

func _on_wave_started(_i: int, main_lane: StringName, side_lane: StringName) -> void:
	if main_lane == &"sw" or side_lane == &"sw":
		_sw_waves += 1

func _on_branch_chosen(spot: StringName, _branch: StringName) -> void:
	_branches += 1
	_branch_gold += GameState.branch_cost(String(spot))
	if _tax_on and String(spot) in _had_branch:
		_rebranch_gold += GameState.branch_cost(String(spot))
var _branch_gold := 0
var _plot_day := -1
var _row_day := 0
var _rebuild_gold := 0
var _rebranch_gold := 0
var _tax_on := false
var _fence_branch := {}    # fence id -> its branch while it stands at night (read every night tick)
var _rubble := []          # fences that fell in the night just ended
var _had_branch := []      # of those, the ones that had a branch
var _fence_paid := {}      # fence id -> cumulative gold put into its levels (+ the current level's payment) at the last building_changed

func _on_tier_paid_up(next_tier: int) -> void:
	if next_tier == 3 and _plot_day < 0:
		_plot_day = _row_day

## The night's end (before the day): which fences fell and which of those had lost a branch with them.
func _capture_night_end() -> void:
	_rubble = []
	_had_branch = []
	for id in _fence_hp:
		if float(_fence_hp[id]) <= 0.0:
			_rubble.append(id)
			if String(_fence_branch.get(id, "")) != "":
				_had_branch.append(id)

func _fence_paid_total(id: String) -> int:
	var b: Dictionary = GameState.buildings[id]
	var sum := int(b.paid)
	for lv in int(b.level):
		sum += maxi(Economy.level_cost(id, lv, Balance.data.build), 0)
	return sum

func _snapshot_fence_paid() -> void:
	_fence_paid = {}
	for id in GameState.buildings:
		if MapLayout.spot_kind(id) == "fence":
			_fence_paid[id] = _fence_paid_total(id)

## Gold put into a fence that fell last night (rebuilding its levels), read from the building's own signals.
func _on_building_changed(spot_id: StringName, _level: int, _paid: int) -> void:
	var id := String(spot_id)
	if not GameState.buildings.has(id) or MapLayout.spot_kind(id) != "fence":
		return
	var total := _fence_paid_total(id)
	if _tax_on and id in _rubble and total > int(_fence_paid.get(id, total)):
		_rebuild_gold += total - int(_fence_paid.get(id, total))
	_fence_paid[id] = total

func _ladder_done() -> bool:
	if GameState.tier < 3:
		return false
	var spots: Array = []
	for id in MapLayout.spots_for_tier(GameState.tier):
		if GameState.buildings.has(id):
			spots.append({"kind": MapLayout.spot_kind(id), "level": int(GameState.buildings[id].level), "branch": String(GameState.buildings[id].branch)})
	var stations: Array = []
	for sid in StationEffects.IDS:
		stations.append(GameState.station_level(sid))
	return SweepMath.ladder_done(spots, stations, int(Balance.data.build.max_level), int(Balance.data.stations.max_level))

var _picked := ""
var _knockouts := 0

func _on_picked(id: StringName, _level: int) -> void:
	_picked = "%s" % id

func _on_knockout(_guard_id: StringName) -> void:
	_knockouts += 1

func _cards() -> String:
	var parts: Array = []
	for id in CardCatalog.IDS:
		if GameState.card_level(id) > 0:
			parts.append("%s:%d" % [id, GameState.card_level(id)])
	return "|".join(parts)

func _on_sold(_count: int, gold: int) -> void:
	_gold_sold += gold

func _builds() -> String:
	var parts: Array = []
	for id in MapLayout.ALL_SPOT_IDS:
		if GameState.buildings.has(id):
			parts.append("%s:%d" % [id, int(GameState.buildings[id].level)])
	return "|".join(parts)

## "" for the planner (its CSV must stay byte-identical to the S4 baseline); the station levels for the upgrader.
func _stations(upgrader: bool) -> String:
	if not upgrader:
		return ""
	var parts: Array = []
	for id in StationEffects.IDS:
		parts.append("%s:%d" % [id, GameState.station_level(id)])
	return "," + "|".join(parts)

## "" unless the tier bot runs: the tier at the night's start, whether it was a boss night, and its retries then.
func _tier_cols(tier_mode: bool, start_tier: int, boss_night: bool, retries: int) -> String:
	if not tier_mode:
		return ""
	return ",%d,%d,%d,%d,%d,%d" % [start_tier, 1 if boss_night else 0, retries if boss_night else 0, _brute_kills, _sw_waves, _branches]
