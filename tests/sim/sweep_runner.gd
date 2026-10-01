extends Node
## Manual difficulty sweep (D-059, D-066, D-067): PlannerBot days 1-14 by default -> tests/sim/out/sweep.csv.
## After the SWEEP line it prints a RETRIES line (days, median, max_before_day8, max, target_ok) for the D-184 retries-per-night target.
## Loaded at run time by tests/sim/sweep.gd, after the autoloads exist (D-150).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {"seed": "20260930", "days": "14"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	Balance.reset()
	var holder := Node.new()
	get_tree().root.add_child(holder)
	var h := SimHarness.new(holder)
	h.start(int(args.seed), PlannerBot)
	EventBus.steak_sold.connect(_on_sold)
	EventBus.card_picked.connect(_on_picked)
	EventBus.guard_knocked_out.connect(_on_knockout)
	var rows := ["day,diner_frac,failed_retries,kills,steaks,gold_earned,builds_defending,enemy_count,night_seconds,day_seconds,unspent_gold_at_closeup,cards,guard_knockouts,picked"]
	var first_fail_day := -1
	var hard_break_day := -1
	var retries_per_day: Array = []
	for day in range(1, int(args.days) + 1):
		var retries := 0
		_picked = ""
		_knockouts = 0
		var enemy_count := Economy.night_kills(GameState.day, Balance.data.wave)
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
		var night_s := h.elapsed - t0
		if n.failed:
			hard_break_day = day
			rows.append("%d,%.3f,%d,%d,0,0,%s,%d,%.1f,,,%s,%d," % [day, n.diner_frac, retries, n.kills, defending, enemy_count, night_s, _cards(), _knockouts])
			break
		# dawn moved the night's steaks to the freezer (freezer + carried, as test_night_sims counts); gold is what the day's sales pay out
		var steaks := GameState.freezer_steaks + GameState.carried_steaks - stock0
		_gold_sold = 0
		var d := await h.run_day()
		if not d.closed:
			rows.append("%d,STALL" % day)
			break
		rows.append("%d,%.3f,%d,%d,%d,%d,%s,%d,%.1f,%.1f,%d,%s,%d,%s" % [day, n.diner_frac, retries, n.kills, steaks,
			_gold_sold, defending, enemy_count, night_s, d.seconds, int(h.main.phase_controller.snapshot.gold), _cards(), _knockouts, _picked])
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
	var f := FileAccess.open(out_dir.path_join("sweep.csv"), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	print("\n".join(rows))
	print("SWEEP first_fail_day=%d hard_break_day=%d target=%d±%d" % [first_fail_day, hard_break_day, Balance.data.sim.break_day_target, Balance.data.sim.break_day_tolerance])
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
	h.finish()
	get_tree().quit(0)

var _gold_sold := 0
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
	for id in MapLayout.SPOT_IDS:
		parts.append("%s:%d" % [id, int(GameState.buildings[id].level)])
	return "|".join(parts)
