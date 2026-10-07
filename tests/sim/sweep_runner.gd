extends Node
## Manual difficulty sweep (D-059, D-066, D-067): PlannerBot days 1-14 by default -> tests/sim/out/sweep.csv.
## `--bot=upgrader` runs the UpgraderBot and writes `sweep_upgrader.csv` with a `stations` column (E1).
## `--bot=tier` runs the TierBot -> `sweep_tier.csv` (+ tier,boss_night,boss_retries) and prints a TIER line (E5).
## `--policy=all_a|all_b|mixed|threat` sets the tier bot's branch policy (default threat). `--tier3=off` removes the tier-3 cost entry in memory,
## and the run then asserts that no brute died, no wave came from the south-west and no branch was chosen (the Task 21 assertion, D-279):
## a TIER3_GATE line, exit code 1 on a violation. Tier rows end with brute_kills,sw_waves,branches (per day, appended after the old columns; sw_waves counts waves with a south-west lane, formerly named sw_spawns).
## After the SWEEP line it prints a RETRIES line (days, median, max_before_day8, max, target_ok) for the D-184 retries-per-night target.
## Loaded at run time by tests/sim/sweep.gd, after the autoloads exist (D-150).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {"seed": "20260930", "days": "14", "bot": "planner", "policy": "threat", "tier3": "on"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if not String(args.bot) in ["planner", "upgrader", "tier"]:
		push_error("unknown --bot=%s (planner|upgrader|tier)" % args.bot)
		get_tree().quit(2)
		return
	if not String(args.policy) in TierBot.POLICIES or not String(args.tier3) in ["on", "off"]:
		push_error("bad --policy=%s (all_a|all_b|mixed|threat) or --tier3=%s (on|off)" % [args.policy, args.tier3])
		get_tree().quit(2)
		return
	if not String(args.bot) == "tier" and (args.policy != "threat" or args.tier3 != "on"):
		print("WARNING: --policy and --tier3 only apply to --bot=tier; ignored for --bot=%s" % args.bot)
	Balance.reset()
	if String(args.tier3) == "off":
		Balance.data.tiers.tier_costs.resize(2)  # in memory only: no sign sells tier 3
	var tier_mode := String(args.bot) == "tier"
	var upgrader := String(args.bot) == "upgrader" or tier_mode
	var holder := Node.new()
	get_tree().root.add_child(holder)
	var h := SimHarness.new(holder)
	h.start(int(args.seed), TierBot if tier_mode else (UpgraderBot if upgrader else PlannerBot))
	if tier_mode:
		h.bot.policy = String(args.policy)
		EventBus.enemy_killed.connect(_on_enemy_killed)
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.branch_chosen.connect(_on_branch_chosen)
	EventBus.steak_sold.connect(_on_sold)
	EventBus.card_picked.connect(_on_picked)
	EventBus.guard_knocked_out.connect(_on_knockout)
	var rows := ["day,diner_frac,failed_retries,kills,steaks,gold_earned,builds_defending,enemy_count,night_seconds,day_seconds,unspent_gold_at_closeup,cards,guard_knockouts,picked" + (",stations" if upgrader else "") + (",tier,boss_night,boss_retries,brute_kills,sw_waves,branches" if tier_mode else "")]
	var first_fail_day := -1
	var hard_break_day := -1
	var retries_per_day: Array = []
	var nights: Array = []
	var unspent_day14 := -1
	var tier3_events := 0
	for day in range(1, int(args.days) + 1):
		var retries := 0
		_picked = ""
		_knockouts = 0
		_brute_kills = 0
		_sw_waves = 0
		_branches = 0
		var enemy_count := SweepMath.enemy_count(GameState.lane_plan)  # the night's own plan (capped past day 7)
		var boss_night := GameState.is_boss_night()
		var start_tier := GameState.tier
		var at_cap := start_tier == 2 and GameState.pressure() == int(Balance.data.tiers.tier_cap[2])
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
		nights.append({"day": day, "tier": start_tier, "boss_night": boss_night, "retries": retries, "at_cap": at_cap})
		var night_s := h.elapsed - t0
		if n.failed:
			hard_break_day = day
			var tcols := _tier_cols(tier_mode, start_tier, boss_night, retries)
			tier3_events += _brute_kills + _sw_waves + _branches
			rows.append("%d,%.3f,%d,%d,0,0,%s,%d,%.1f,,,%s,%d," % [day, n.diner_frac, retries, n.kills, defending, enemy_count, night_s, _cards(), _knockouts] + _stations(upgrader) + tcols)
			break
		# dawn moved the night's steaks to the freezer (freezer + carried, as test_night_sims counts); gold is what the day's sales pay out
		var steaks := GameState.freezer_steaks + GameState.carried_steaks - stock0
		_gold_sold = 0
		var d := await h.run_day()
		var tcols := _tier_cols(tier_mode, start_tier, boss_night, retries)  # after the day: the branches are bought by day
		tier3_events += _brute_kills + _sw_waves + _branches
		if not d.closed:
			rows.append("%d,STALL" % day + _stations(upgrader) + tcols)
			break
		rows.append("%d,%.3f,%d,%d,%d,%d,%s,%d,%.1f,%.1f,%d,%s,%d,%s" % [day, n.diner_frac, retries, n.kills, steaks,
			_gold_sold, defending, enemy_count, night_s, d.seconds, int(h.main.phase_controller.snapshot.gold), _cards(), _knockouts, _picked] + _stations(upgrader) + tcols)
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
	var f := FileAccess.open(out_dir.path_join("sweep_tier.csv" if tier_mode else ("sweep_upgrader.csv" if upgrader else "sweep.csv")), FileAccess.WRITE)
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
		for pair in [[EventBus.enemy_killed, _on_enemy_killed], [EventBus.wave_started, _on_wave_started], [EventBus.branch_chosen, _on_branch_chosen]]:
			var sig: Signal = pair[0]
			if sig.is_connected(pair[1]):
				sig.disconnect(pair[1])
		var ts := SweepMath.tier_summary(nights)
		print("TIER first_tier2_day=%d boss_retries=%d cap_nights=%d cap_retries=%d" % [ts.first_tier2_day, ts.boss_retries, ts.cap_nights, ts.cap_retries])
		print("TIER3_GATE tier3=%s policy=%s events=%d" % [args.tier3, args.policy, tier3_events])
		if String(args.tier3) == "off" and tier3_events != 0:
			push_error("tier 3 is not for sale but %d brute kills, south-west spawns and branches were counted" % tier3_events)
			h.finish()
			get_tree().quit(1)
			return
	h.finish()
	get_tree().quit(0)

var _gold_sold := 0
var _brute_kills := 0
var _sw_waves := 0
var _branches := 0

func _on_enemy_killed(_i: int, _lane: StringName, _p: Vector3, kind: StringName) -> void:
	if kind == &"brute":
		_brute_kills += 1

func _on_wave_started(_i: int, main_lane: StringName, side_lane: StringName) -> void:
	if main_lane == &"sw" or side_lane == &"sw":
		_sw_waves += 1

func _on_branch_chosen(_spot: StringName, _branch: StringName) -> void:
	_branches += 1
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
