extends SceneTree
## E5 tier-3 policy ranking (Task 24, spec 9.2 and 9.4). NOT a CI test (the name does not start with test_); asserts nothing, changes no balance value.
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/report_policies.gd [-- --seeds=20260930,1,2 --days=32 --parallel=3 --reuse=1]
## For every seed x policy (all_a, all_b, mixed, threat) it starts the REAL tier sweep in its own Godot process
## (`sweep.gd -- --bot=tier --days=32 --seed=S --policy=P --out=policy_S_P.csv`, stdout in tests/sim/out/policy_S_P.log) and reads the `T3RUN` line
## that sweep prints: the day loop is the sweep's, not a copy. At most --parallel (1 to 3, default 3) processes run at once; one run takes about 220 s idle.
## --reuse=1 skips a run whose log already holds a T3RUN line. Everything is written under tests/sim/out/ (gitignored); the output is also saved as policies.txt there.
## Output: RUN per run (tier-3 nights only; diner fractions are the lowest diner HP of the night's final attempt, a failed night counts as played),
## POLICY per policy (mean over seeds of the mean diner fraction, in POINTS = percent of the diner's maximum HP; retry nights summed),
## RANKING, GAP and two verdict lines for the review queue (thresholds are asserted nowhere):
##   DOMINANT_BRANCH: yes|no (gap <x> points, threshold 15)   -- gap between the best and the worst policy above 15 points: "possible dominant branch"
##   THREAT_BEST: yes|no (threat <x>, best <policy> <y>)       -- threat not best: "branches don't reward reading the telegraph"
## D-150: a `-s` script compiles before the autoloads exist; this one names none (SweepMath and ReportMath are pure).

const POLICY_IDS := ["all_a", "all_b", "mixed", "threat"]
const RUN_FIELDS := ["nights", "retry_nights", "min", "median", "mean", "fences_lost_mean", "branches", "branch_gold", "unspent_last_day", "hard_break_day"]

func _initialize() -> void:
	var args := {"seeds": "20260930,1,2", "days": "32", "parallel": "3", "reuse": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var seeds: Array = []
	for s in String(args.seeds).split(","):
		seeds.append(int(s))
	var parallel := clampi(int(args.parallel), 1, 3)
	var out_dir := ProjectSettings.globalize_path("res://tests/sim/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gi := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	gi.close()
	var t0 := Time.get_ticks_msec()
	var jobs: Array = []
	for s in seeds:
		for p in POLICY_IDS:
			if String(args.reuse) == "1" and not _read_t3run(_log_path(out_dir, s, p)).is_empty():
				continue
			jobs.append([s, p])
	var started := jobs.size()
	var running: Array = []
	while not jobs.is_empty() or not running.is_empty():
		running = running.filter(func(pid): return OS.is_process_running(pid))
		while running.size() < parallel and not jobs.is_empty():
			var j: Array = jobs.pop_front()
			var cmd := "exec \"%s\" --headless --path \"%s\" --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=tier --days=%s --seed=%d --policy=%s --out=policy_%d_%s.csv > \"%s\" 2>&1" % [
				OS.get_executable_path(), ProjectSettings.globalize_path("res://").trim_suffix("/"), args.days, j[0], j[1], j[0], j[1], _log_path(out_dir, j[0], j[1])]
			var pid := OS.create_process("/bin/sh", ["-c", cmd])
			if pid < 0:
				push_error("could not start the run seed=%d policy=%s" % [j[0], j[1]])
				quit(2)
				return
			running.append(pid)
			print("STARTED seed=%d policy=%s" % [j[0], j[1]])
		OS.delay_msec(1000)
	var lines: Array = []
	var runs: Array = []
	lines.append("RUN seed policy | nights retry_nights min median mean fences_lost_mean branches branch_gold unspent_last_day hard_break_day")
	for s in seeds:
		for p in POLICY_IDS:
			var kv := _read_t3run(_log_path(out_dir, s, p))
			if kv.is_empty():
				lines.append("RUN %d %s | MISSING (no T3RUN line in %s)" % [s, p, _log_path(out_dir, s, p)])
				continue
			var cells: Array = []
			for f in RUN_FIELDS:
				cells.append(String(kv.get(f, "?")))
			lines.append("RUN %d %s | %s" % [s, p, " ".join(cells)])
			runs.append({"policy": p, "seed": s, "mean_frac": float(kv.mean), "retry_nights": int(kv.retry_nights)})
	var ranking := SweepMath.policy_ranking(runs)
	for r in ranking.rows:
		lines.append("POLICY %s mean_diner_points=%.1f retry_nights=%d (runs=%d)" % [r.policy, r.points, r.retry_nights, runs.filter(func(x): return x.policy == r.policy).size()])
	lines.append("RANKING " + " > ".join(ranking.rows.map(func(r): return "%s %.1f" % [r.policy, r.points])))
	lines.append("GAP %.1f points (best minus worst)" % ranking.gap)
	if not ranking.rows.is_empty():
		lines.append_array(SweepMath.policy_verdicts(ranking))
	lines.append("WALL %.0f s (parallel=%d, %d runs started)" % [(Time.get_ticks_msec() - t0) / 1000.0, parallel, started])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open(out_dir.path_join("policies.txt"), FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	quit(0)

func _log_path(out_dir: String, s: int, p: String) -> String:
	return out_dir.path_join("policy_%d_%s.log" % [s, p])

## The key=value pairs of the log's T3RUN line, {} when the log or the line is missing.
func _read_t3run(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("T3RUN "):
			var kv := {}
			for tok in line.trim_prefix("T3RUN ").split(" ", false):
				var pair := tok.split("=", true, 1)
				if pair.size() == 2:
					kv[pair[0]] = pair[1]
			return kv
	return {}
