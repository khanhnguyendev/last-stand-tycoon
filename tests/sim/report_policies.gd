extends SceneTree
## E5 tier-3 policy ranking (Task 24, spec 9.2 and 9.4). NOT a CI test (the name does not start with test_); asserts nothing, changes no balance value.
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/report_policies.gd [-- --seeds=20260930,1,2 --days=32 --parallel=3 --reuse=1]
## For every seed x policy (the spec's four: all_a, all_b, mixed, threat; plus the report-only volley_stone: towers Volley, fences Stone wall) it starts the REAL
## tier sweep in its own Godot process (`sweep.gd -- --bot=tier --days=32 --seed=S --policy=P --out=policy_S_P.csv`, stdout in tests/sim/out/policy_S_P.log, whose first
## line records the git commit, seed, policy and days) and reads the `T3RUN` line that sweep prints: the day loop is the sweep's, not a copy. At most --parallel
## (1 to 3, default 3) processes run at once; one run takes about 220 s idle; 15 runs, 3 at a time, about 15 min.
## --reuse=1 skips a run whose log holds a T3RUN line AND whose first line matches the seed, policy, days and the current commit (a dirty tree never matches); other runs are redone.
## A run that ends without a T3RUN line, or with a hard break (a night lost after its retries), stops the report: the rows so far are printed, the verdict lines are
## skipped, the running children are killed and the exit code is 1. Everything is written under tests/sim/out/ (gitignored); the output is also saved as policies.txt there.
## Output: NOTE, COMMIT, RUN per run (tier-3 nights only; diner fractions are the lowest diner HP of the night's final attempt), POLICY per policy (mean over seeds of
## the mean diner fraction, in POINTS = percent of the diner's maximum HP; retry nights summed; fences lost per night and branch gold, means over seeds), RANKING, GAP,
## the 2 x 2 table (tower Longbow | Volley x fence Stone | Spike) with per-seed values and the main effects and the interaction, and the verdict lines for the review queue
## (thresholds are asserted nowhere):
##   DOMINANT_BRANCH: yes|no (gap <x> points, threshold 15)      -- over the spec's four policies: best minus worst above 15 points: "possible dominant branch"
##   DOMINANT_BRANCH_2x2: yes|no (...)                            -- the same over the four fixed combinations (all_a, all_b, mixed, volley_stone)
##   THREAT_BEST: yes|no|tie (...)                                -- threat against the best other of the four, per seed; tie under 2 points or with differing signs
## D-150: a `-s` script compiles before the autoloads exist; this one names none (SweepMath and ReportMath are pure).

const SPEC_POLICIES := ["all_a", "all_b", "mixed", "threat"]
const POLICY_IDS := ["all_a", "all_b", "mixed", "threat", "volley_stone"]
const RUN_FIELDS := ["nights", "retry_nights", "min", "median", "mean", "fences_lost_mean", "branches", "branch_gold", "unspent_last_day", "hard_break_day"]

func _initialize() -> void:
	var args := {"seeds": "20260930,1,2", "days": "32", "parallel": "3", "reuse": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var seeds: Array = []
	for s in String(args.seeds).split(","):
		if not s.is_valid_int():
			push_error("bad --seeds=%s (comma-separated integers)" % args.seeds)
			quit(2)
			return
		seeds.append(int(s))
	if not String(args.days).is_valid_int() or int(args.days) < 1 or not String(args.parallel).is_valid_int():
		push_error("bad --days=%s or --parallel=%s (integers)" % [args.days, args.parallel])
		quit(2)
		return
	var days := int(args.days)
	var parallel := clampi(int(args.parallel), 1, 3)
	var out_dir := ProjectSettings.globalize_path("res://tests/sim/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gi := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	gi.close()
	var proj := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var commit := _commit(proj)
	var t0 := Time.get_ticks_msec()
	var jobs: Array = []
	var notes: Array = []
	for s in seeds:
		for p in POLICY_IDS:
			if String(args.reuse) == "1":
				var why := _reuse_refusal(_log_path(out_dir, s, p), commit, s, p, days)
				if why == "":
					continue
				notes.append("REUSE refused seed=%d policy=%s: %s (run again)" % [s, p, why])
			jobs.append([s, p])
	var started := jobs.size()
	var running: Array = []  # {pid, seed, policy}
	var failed := false
	while not failed and (not jobs.is_empty() or not running.is_empty()):
		var still: Array = []
		for r in running:
			if OS.is_process_running(int(r.pid)):
				still.append(r)
			else:
				var kv := _read_t3run(_log_path(out_dir, r.seed, r.policy))
				if kv.is_empty() or int(kv.get("hard_break_day", "-1")) >= 0:
					failed = true
		running = still
		while not failed and running.size() < parallel and not jobs.is_empty():
			var j: Array = jobs.pop_front()
			var log := _log_path(out_dir, j[0], j[1])
			var first := "REPORT_RUN commit=%s seed=%d policy=%s days=%d" % [commit, j[0], j[1], days]
			var cmd := "echo %s > %s && exec %s --headless --path %s --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=tier --days=%d --seed=%d --policy=%s --out=policy_%d_%s.csv >> %s 2>&1" % [
				_q(first), _q(log), _q(OS.get_executable_path()), _q(proj), days, j[0], j[1], j[0], j[1], _q(log)]
			var pid := OS.create_process("/bin/sh", ["-c", cmd])
			if pid < 0:
				push_error("could not start the run seed=%d policy=%s" % [j[0], j[1]])
				failed = true
				break
			running.append({"pid": pid, "seed": j[0], "policy": j[1]})
			print("STARTED seed=%d policy=%s" % [j[0], j[1]])
		if not failed:
			OS.delay_msec(1000)
	for r in running:
		OS.kill(int(r.pid))  # a failed report leaves no child behind
	var lines: Array = ["NOTE a retried night counts its final (mercy) attempt; the night statistics count tier-3 nights only", "COMMIT %s" % commit]
	lines.append_array(notes)
	var runs: Array = []
	lines.append("RUN seed policy | nights retry_nights min median mean fences_lost_mean branches branch_gold unspent_last_day hard_break_day")
	for s in seeds:
		for p in POLICY_IDS:
			var kv := _read_t3run(_log_path(out_dir, s, p))
			if kv.is_empty():
				lines.append("RUN %d %s | MISSING (no T3RUN line in %s)" % [s, p, _log_path(out_dir, s, p)])
				failed = true
				continue
			var cells: Array = []
			for f in RUN_FIELDS:
				cells.append(String(kv.get(f, "?")))
			lines.append("RUN %d %s | %s" % [s, p, " ".join(cells)])
			if int(kv.get("hard_break_day", "-1")) >= 0:
				lines.append("RUN %d %s | HARD BREAK on day %s" % [s, p, kv.hard_break_day])
				failed = true
			runs.append({"policy": p, "seed": s, "mean_frac": float(kv.mean), "retry_nights": int(kv.retry_nights), "fences_lost_mean": float(kv.fences_lost_mean), "branch_gold": float(kv.branch_gold)})
	if failed:
		lines.append("FAILED: a run is missing or hit a hard break; no verdict lines")
	else:
		var ranking := SweepMath.policy_ranking(runs)
		for r in ranking.rows:
			lines.append("POLICY %s mean_diner_points=%.1f retry_nights=%d fences_lost_per_night=%.2f branch_gold=%.0f (runs=%d)" % [r.policy, r.points, r.retry_nights, r.fences_lost, r.branch_gold,
				runs.filter(func(x): return x.policy == r.policy).size()])
		lines.append("RANKING " + " > ".join(ranking.rows.map(func(r): return "%s %.1f" % [r.policy, r.points])))
		lines.append("GAP %.1f points (best minus worst, five policies)" % ranking.gap)
		var t := SweepMath.two_by_two(runs)
		if not t.is_empty():
			lines.append("TABLE2X2 mean points (per seed: %s)" % ", ".join(seeds.map(func(s): return str(s))))
			lines.append("TABLE2X2 %-14s | %-26s | %-26s" % ["tower \\ fence", "Stone", "Spike"])
			for row in [["Longbow", "longbow_stone", "longbow_spike"], ["Volley", "volley_stone", "volley_spike"]]:
				lines.append("TABLE2X2 %-14s | %-26s | %-26s" % [row[0], _cell(t.cells[row[1]]), _cell(t.cells[row[2]])])
			lines.append("EFFECT tower (Volley minus Longbow, averaged over fences) %+.1f points" % t.tower_effect)
			lines.append("EFFECT fence (Stone minus Spike, averaged over towers) %+.1f points" % t.fence_effect)
			lines.append("EFFECT interaction ((Volley minus Longbow with Spike) minus (the same with Stone)) %+.1f points" % t.interaction)
			lines.append(SweepMath.dominant_line("DOMINANT_BRANCH_2x2", SweepMath.policy_ranking(runs, ["all_a", "all_b", "mixed", "volley_stone"])))
		lines.append(SweepMath.dominant_line("DOMINANT_BRANCH", SweepMath.policy_ranking(runs, SPEC_POLICIES)))
		lines.append(SweepMath.threat_verdict(runs, SPEC_POLICIES))
	lines.append("WALL %.0f s (parallel=%d, %d runs started)" % [(Time.get_ticks_msec() - t0) / 1000.0, parallel, started])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open(out_dir.path_join("policies.txt"), FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	quit(1 if failed else 0)

func _cell(c: Dictionary) -> String:
	return "%.1f (%s)" % [c.points, " ".join(c.per_seed.map(func(x): return "%.0f" % x[1]))]

## Single-quoted for /bin/sh.
func _q(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"

func _log_path(out_dir: String, s: int, p: String) -> String:
	return out_dir.path_join("policy_%d_%s.log" % [s, p])

## The HEAD hash, "-dirty" appended when a tracked file differs (untracked files are ignored: the results are copied into the repo after a run).
func _commit(proj: String) -> String:
	var out: Array = []
	if OS.execute("git", ["-C", proj, "rev-parse", "--short", "HEAD"], out) != 0 or out.is_empty():
		return "unknown"
	var h := String(out[0]).strip_edges()
	var st: Array = []
	if OS.execute("git", ["-C", proj, "status", "--porcelain", "--untracked-files=no"], st) == 0 and not st.is_empty() and String(st[0]).strip_edges() != "":
		h += "-dirty"
	return h

## "" when the log can be reused, else the reason.
func _reuse_refusal(path: String, commit: String, s: int, p: String, days: int) -> String:
	if _read_t3run(path).is_empty():
		return "no T3RUN line"
	var first := ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		first = line
		break
	if first != "REPORT_RUN commit=%s seed=%d policy=%s days=%d" % [commit, s, p, days]:
		return "the log's first line is '%s'" % first
	if commit.ends_with("-dirty") or commit == "unknown":
		return "the tree is dirty or the commit unknown"
	return ""

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
