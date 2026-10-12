extends SceneTree
## E6 tier-3 retune report (Task 16, spec 8.1, D-285, D-290, D-292 to D-294). NOT a CI test (the name does not start with test_); asserts nothing, changes no balance value.
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/report_retune.gd [-- --set=tuning|1|2 --final --days=32 --parallel=3 --dry=1]
## Sets: `tuning` (default; 4 seeds, one per siege lane), `1` and `2` (hold-out sets #1 and #2, 8 seeds each, two per siege lane). The seeds are pinned in SweepMath (TUNING_SET,
## HOLDOUT_SET_1, HOLDOUT_SET_2); at the start the report scans seeds upward from 1 (the siege lane of a seed is `LaneCharacter.for_run(seed).siege`) and exits 2 if the scan
## does not give exactly the pinned literals. The hold-out sets run ONLY with `--final` (D-290): without it the report refuses and starts nothing; with it the output header
## carries the commit and the set number, the run is appended to tests/sim/out/retune_final.json (gitignored), and an earlier run of the same set is printed (FINAL_EARLIER),
## with FINAL_REPEAT when it is a second run (a different commit is spelled out). `--dry=1` prints the header (rule, seeds, gate) and runs nothing.
## Runs: for every seed x six policies (all_a = Longbow + Stone, mixed = Longbow + Spike, volley_stone = Volley + Stone, all_b = Volley + Spike, threat = the threat-matched build,
## unbranched = no branch) one REAL tier sweep in its own Godot process (`sweep.gd -- --bot=tier --days=32 --retune=on --seed=S --policy=P`), at most --parallel (1 to 3) at once;
## the runs' stdout is kept under tests/sim/out/retune/ (T3RUN, LADDER and RETUNE lines are read from it; a run takes about 220 s idle: the tuning set, 24 runs at 3 a time,
## is about 30 to 35 min; a hold-out set, 48 runs, about an hour). A missing or failed run (no result line, a hard break, no tier-3 night) prints NO verdict lines and exits 1.
## Verdict lines (SweepMath; each followed by its per-seed and per-siege-lane lines): THREAT_LEAD, THREAT_LEAD_BY_LANE, RETRY_NIGHTS, FIRST_T3_NIGHT, FENCE_TAX, FIXED_SPREAD,
## HARE_SHARE, LANE_CAP_GUARD. Targets that fail still exit 0 (the output is the verdict); the last line says how many passed.
## D-150: a `-s` script compiles before the autoloads exist; this one names only the pure helpers (SweepMath, ReportMath) and loads LaneCharacter at run time.

const RECORD_FILE := "retune_final.json"
const RUN_FIELDS := ["nights", "retry_nights", "min", "median", "mean", "fences_lost_mean", "branches", "branch_gold", "unspent_last_day", "hard_break_day"]

func _initialize() -> void:
	var args := {"set": "tuning", "days": "32", "parallel": "3", "dry": "0", "final": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	if not String(args.days).is_valid_int() or int(args.days) < 1 or not String(args.parallel).is_valid_int():
		push_error("bad --days=%s or --parallel=%s (integers)" % [args.days, args.parallel])
		quit(2)
		return
	var set_id := String(args.set)
	var set: Dictionary = SweepMath.set_by_id(set_id)
	if set.is_empty():
		push_error("bad --set=%s (tuning|1|2)" % set_id)
		quit(2)
		return
	var lc = load("res://core/lane_character.gd")
	var scan: Dictionary = SweepMath.seed_scan(func(s): return String(lc.for_run(s).siege), SweepMath.SIEGE_LANES)
	if scan.tuning != SweepMath.TUNING_SET or scan.holdout1 != SweepMath.HOLDOUT_SET_1 or scan.holdout2 != SweepMath.HOLDOUT_SET_2:
		push_error("the seed scan no longer gives the pinned sets (LaneCharacter.for_run changed?): %s" % str(scan))
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
	var record := _read_record(out_dir.path_join(RECORD_FILE))
	var gate: Dictionary = SweepMath.final_gate(set_id, String(args.final) == "1", commit, record)
	var seeds: Array = SweepMath.set_seeds(set)
	var lines: Array = []
	if not gate.allowed:
		print("\n".join(gate.lines))
		quit(2)
		return
	lines.append("RETUNE_REPORT set=%s commit=%s days=%d" % ["tuning" if set_id == "tuning" else "#" + set_id, commit, days])
	lines.append_array(gate.lines)
	lines.append("SEED_RULE scan seeds upward from 1; a seed's siege lane is LaneCharacter.for_run(seed).siege; per lane the 1st seed is the tuning set, the next 2 hold-out set #1, the next 2 hold-out set #2")
	for l in SweepMath.SIEGE_LANES:
		lines.append("SEEDS %s %s: %s" % ["tuning" if set_id == "tuning" else "hold-out #" + set_id, l, str(set[l])])
	lines.append("NOTE a retried night counts its final (mercy) attempt; the night statistics count tier-3 nights only; hare share and the lane-cap guard are read from each run's own plan")
	if String(args.dry) == "1":
		lines.append("DRY RUN: nothing started")
		print("\n".join(lines))
		quit(0)
		return
	if String(args.final) == "1" and set_id != "tuning":
		_write_record(out_dir.path_join(RECORD_FILE), gate.record)  # recorded before the first run starts: a crash does not hide that the set was used
	var t0 := Time.get_ticks_msec()
	var jobs: Array = []
	for s in seeds:
		for p in SweepMath.RETUNE_POLICIES:
			jobs.append([s, p])
	for j in jobs:  # a stale run must not be read as this run's
		for ext in [".log", ".csv"]:
			var old: String = _log_path(out_dir, set_id, j[0], j[1]).get_basename() + ext
			DirAccess.make_dir_recursive_absolute(old.get_base_dir())
			if FileAccess.file_exists(old):
				DirAccess.remove_absolute(old)
	var total := jobs.size()
	var running: Array = []
	var failed := false
	while not failed and (not jobs.is_empty() or not running.is_empty()):
		var still: Array = []
		for r in running:
			if OS.is_process_running(int(r.pid)):
				still.append(r)
			else:
				var kv := _read_line(_log_path(out_dir, set_id, r.seed, r.policy), "T3RUN ")
				if kv.is_empty() or int(kv.get("hard_break_day", "-1")) >= 0 or _read_line(_log_path(out_dir, set_id, r.seed, r.policy), "RETUNE ").is_empty():
					failed = true
		running = still
		while not failed and running.size() < parallel and not jobs.is_empty():
			var j: Array = jobs.pop_front()
			var log := _log_path(out_dir, set_id, j[0], j[1])
			var first := "REPORT_RUN commit=%s set=%s seed=%d policy=%s days=%d" % [commit, set_id, j[0], j[1], days]
			var cmd := "echo %s > %s && exec %s --headless --path %s --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=tier --days=%d --retune=on --seed=%d --policy=%s --out=retune/retune_%s_%d_%s.csv >> %s 2>&1" % [
				_q(first), _q(log), _q(OS.get_executable_path()), _q(proj), days, j[0], j[1], set_id, j[0], j[1], _q(log)]
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
	var rows: Array = []
	var expected: Array = []
	lines.append("RUN seed policy | " + " ".join(RUN_FIELDS) + " | siege first_t3_frac hare_share_mean guard_hits")
	for s in seeds:
		for p in SweepMath.RETUNE_POLICIES:
			expected.append([s, p])
			var log: String = _log_path(out_dir, set_id, s, p)
			var kv := _read_line(log, "T3RUN ")
			var ld := _read_line(log, "LADDER ")
			var rt := _read_line(log, "RETUNE ")
			if kv.is_empty() or rt.is_empty():
				lines.append("RUN %d %s | MISSING (no T3RUN or RETUNE line in %s)" % [s, p, log])
				continue
			var cells: Array = []
			for f in RUN_FIELDS:
				cells.append(String(kv.get(f, "?")))
			lines.append("RUN %d %s | %s | %s %s %s %s" % [s, p, " ".join(cells), rt.get("siege", "?"), rt.get("first_t3_frac", "?"), rt.get("hare_share_mean", "?"), rt.get("guard_hits", "?")])
			var hard := int(kv.get("hard_break_day", "-1")) >= 0
			if hard:
				lines.append("RUN %d %s | HARD BREAK on day %s" % [s, p, kv.hard_break_day])
			rows.append({"seed": s, "lane": SweepMath.seed_lane(set, s), "policy": p, "mean_frac": float(kv.mean), "retry_nights": int(kv.retry_nights),
				"first_t3_frac": float(rt.get("first_t3_frac", "-1")), "fence_median": int(ld.get("fence_rebuild_gold_median_at_cap", "0")), "income_at_cap": int(ld.get("income_at_cap", "0")),
				"hare_share": float(rt.get("hare_share_mean", "-1")), "guard_hits": int(rt.get("guard_hits", "0")), "failed": hard})
	var res: Dictionary = SweepMath.retune_report(rows, expected)
	lines.append_array(res.lines)
	if int(res.exit) == 0:
		lines.append("TARGETS %s (HARE_SHARE flags are a warning, not a target; read every line, the per-seed and per-lane lines most of all)" % ("ALL PASS" if res.ok else "NOT ALL PASS"))
	lines.append("WALL %.0f s (parallel=%d, %d runs)" % [(Time.get_ticks_msec() - t0) / 1000.0, parallel, total])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open(out_dir.path_join("retune_%s.txt" % set_id), FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	quit(int(res.exit))

## Single-quoted for /bin/sh.
func _q(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"

func _log_path(out_dir: String, set_id: String, s: int, p: String) -> String:
	return out_dir.path_join("retune").path_join("retune_%s_%d_%s.log" % [set_id, s, p])

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

func _read_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}

func _write_record(path: String, record: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(record, "  ") + "\n")
	f.close()

## The key=value pairs of the log's line that starts with `prefix` ("T3RUN ", "LADDER ", "RETUNE "), {} when the log or the line is missing.
func _read_line(path: String, prefix: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with(prefix):
			var kv := {}
			for tok in line.trim_prefix(prefix).split(" ", false):
				var pair := tok.split("=", true, 1)
				if pair.size() == 2:
					kv[pair[0]] = pair[1]
			return kv
	return {}
