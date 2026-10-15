extends SceneTree
## E6 tier-3 retune report (Task 16, spec 8.1, D-285, D-290, D-292 to D-294). NOT a CI test (the name does not start with test_); asserts nothing, changes no balance value.
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/report_retune.gd [-- --set=tuning|3|4|5|6 --final --days=32 --parallel=3 --dry=1 --bot-rule=walk|far|old --bot-max-tier=<1-5> --deadline-min=20]
## Sets: `tuning` (default; 5 seeds: one per siege lane from the scan, plus the promoted north 14, D-304), `3` (E7 measurement set #3, 8 seeds, two per siege lane: scan positions 6 and 7), `4` (E7 measurement set #4, scan positions 8 and 9), `5` (E8 measurement set #5, scan positions 10 and 11; --final, walk bot, 32 days) and `6` (E8 measurement set #6, scan positions 12 and 13; --final, --days=45 is the only length it accepts, E8 spec 3.5).
## Hold-out set #2 is SPENT (D-307) and refused always like set #1 (message names D-307; results stay in the history). `--bot-rule=walk|far|old` (default walk) is passed to every child sweep, printed in the header and stored in the history entry
## (`bot_rule`); sets #3 to #6 may be run once per bot rule (walk, far, old; a history entry `new` is `far`) (a repeat with a rule already used by a COMPLETE entry is refused; an entry whose run printed no verdict has `complete: false` and does not block). Hold-out set #1 is
## RETIRED (D-304: seed 14 failed it, was diagnosed and moved to the tuning set): `--set=1` is refused always, with or without `--final`, exit 2, nothing started; its literal and its
## results stay for the history. The seeds are pinned in SweepMath (SCAN_TUNING_SET, PROMOTED_TO_TUNING, TUNING_SET, HOLDOUT_SET_1, HOLDOUT_SET_2, MEASURE_SET_3 to MEASURE_SET_6); at the start the report scans seeds upward from 1
## (the siege lane of a seed is `LaneCharacter.for_run(seed).siege`) and exits 2 if the scan does not give exactly the pinned literals (the scan's tuning seeds + the promotion = TUNING_SET). The hold-out sets run ONLY with `--final` (D-290): without it the report refuses and starts nothing; with it the output header
## carries the commit and the set number, the run is appended to the history in tests/sim/retune_final.json (COMMITTED, so earlier finals survive across worktrees; Task 20 commits it with the output), and every earlier entry is printed (FINAL_EARLIER),
## with FINAL_REPEAT when it is a second run (a different commit is spelled out). `--dry=1` prints the header (rule, seeds, gate) and runs nothing.
## Runs: for every seed x six policies (all_a = Longbow + Stone, mixed = Longbow + Spike, volley_stone = Volley + Stone, all_b = Volley + Spike, threat = the threat-matched build,
## unbranched = no branch) one REAL tier sweep in its own Godot process (`sweep.gd -- --bot=tier --days=32 --seed=S --policy=P`), at most --parallel (1 to 3) at once;
## the runs' stdout is kept under tests/sim/out/retune/ (T3RUN, LADDER and RETUNE lines are read from it; a run takes about 220 s idle: the tuning set, 30 runs at 3 a time,
## is about 40 to 45 min; a hold-out set, 48 runs, about an hour). A missing or failed run (no result line, a hard break, no tier-3 night) prints NO verdict lines and exits 1.
## D-298: `unbranched` is the floor reference: RETRY_NIGHTS prints its count but does not judge it; UNBRANCHED_RETRIES / UNBRANCHED_FLAG and UNSPENT_T3 / UNSPENT_AFTER_LADDER are report-only lines.
## Verdict lines (SweepMath; each followed by its per-seed and per-siege-lane lines): THREAT_LEAD, THREAT_LEAD_BY_LANE, RETRY_NIGHTS, FIRST_T3_NIGHT, FENCE_TAX, FIXED_SPREAD,
## HARE_SHARE, LANE_CAP_GUARD, plus FIRST_NIGHT_BAND (E8: the pooled median of the branch policies' first tier-3 night is 50 to 80 percent; counted). FIXED_SPREAD is information since E8 (spread >= 5 expected, not a must-hold). Targets that fail still exit 0 (the output is the verdict); the last line says how many passed.
## `--final` is refused with the tuning set, on a dirty tree and on an unknown commit (the recorded commit must identify the values); a record file that does not parse exits 2 and is
## never overwritten. Each entry: set, commit, the commit's date (from git), and at the end of the run `done` and `ok`. Unknown arguments exit 2.
## Child runs: each has a wall-time deadline (RUN_DEADLINE_MSEC, killed and counted as failed when exceeded), must exit 0 and must leave no `SCRIPT ERROR` line in its log (a plain
## `ERROR:` line is ignored: a benign one ends the log). STARTED lines carry the child's pid. A SceneTree script cannot trap signals: if you interrupt the report, stop its children
## with `pkill -f "sweep.gd.*--bot=tier --days=32"`.
## D-150: a `-s` script compiles before the autoloads exist; this one names only the pure helpers (SweepMath, ReportMath) and loads LaneCharacter at run time.

const RECORD_PATH := "res://tests/sim/retune_final.json"
const DEFAULT_DEADLINE_MIN := 20  # per child run (a run takes about 220 s idle); --deadline-min=<5..240>
const KNOWN_ARGS := ["set", "days", "parallel", "dry", "final", "bot-rule", "bot-max-tier", "deadline-min"]
const RUN_FIELDS := ["nights", "retry_nights", "min", "median", "mean", "fences_lost_mean", "branches", "branch_gold", "unspent_last_day", "hard_break_day"]

func _initialize() -> void:
	var args := {"set": "tuning", "days": "32", "parallel": "3", "dry": "0", "final": "0", "bot-rule": "walk", "bot-max-tier": "", "deadline-min": str(DEFAULT_DEADLINE_MIN)}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if not kv[0] in KNOWN_ARGS:
			push_error("unknown argument %s (known: %s)" % [a, ", ".join(KNOWN_ARGS.map(func(k): return "--" + k))])
			quit(2)
			return
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	if not String(args.days).is_valid_int() or int(args.days) < 1 or not String(args.parallel).is_valid_int():
		push_error("bad --days=%s or --parallel=%s (integers)" % [args.days, args.parallel])
		quit(2)
		return
	if not String(args["deadline-min"]).is_valid_int() or int(args["deadline-min"]) < 5 or int(args["deadline-min"]) > 240:
		push_error("bad --deadline-min=%s (integer 5 to 240)" % args["deadline-min"])
		quit(2)
		return
	var deadline_min := int(args["deadline-min"])
	var run_deadline_msec := deadline_min * 60 * 1000
	var bot_rule := String(args["bot-rule"])
	var max_tier_arg := ""  # E8 (D-314.12): passed to every child sweep when given
	if String(args["bot-max-tier"]) != "":
		if not String(args["bot-max-tier"]).is_valid_int() or int(args["bot-max-tier"]) < 1 or int(args["bot-max-tier"]) > Balance.data.tiers.max_tier:
			push_error("bad --bot-max-tier=%s (integer 1 to %d)" % [args["bot-max-tier"], Balance.data.tiers.max_tier])
			quit(2)
			return
		max_tier_arg = " --bot-max-tier=%d" % int(args["bot-max-tier"])
	if not bot_rule in SweepMath.BOT_RULES:
		push_error("bad --bot-rule=%s (walk|far|old)" % bot_rule)
		quit(2)
		return
	var set_id := String(args.set)
	var tag := set_id + "_" + bot_rule  # file names: a run with another bot rule never overwrites another rule's logs
	var seed_set: Dictionary = SweepMath.set_by_id(set_id)
	if seed_set.is_empty():
		push_error("bad --set=%s (tuning|3|4|5|6; 1 is retired, 2 is spent)" % set_id)
		quit(2)
		return
	var lc = load("res://core/lane_character.gd")
	var scan: Dictionary = SweepMath.seed_scan(func(s): return String(lc.for_run(s).siege), SweepMath.SIEGE_LANES)
	if scan.tuning != SweepMath.SCAN_TUNING_SET or scan.holdout1 != SweepMath.HOLDOUT_SET_1 or scan.holdout2 != SweepMath.HOLDOUT_SET_2 or scan.set3 != SweepMath.MEASURE_SET_3 or scan.set4 != SweepMath.MEASURE_SET_4 \
			or scan.set5 != SweepMath.MEASURE_SET_5 or scan.set6 != SweepMath.MEASURE_SET_6 \
			or SweepMath.with_promotion(scan.tuning, SweepMath.PROMOTED_TO_TUNING) != SweepMath.TUNING_SET:
		push_error("the seed scan no longer gives the pinned sets (LaneCharacter.for_run changed?): %s" % str(scan))
		quit(2)
		return
	var retired: Dictionary = SweepMath.retired_gate(set_id)
	if retired.refused:
		print("SEED_PROMOTED north 14 (D-304): failed hold-out #1, diagnosed, now tuning data")
		print("HOLDOUT_1 retired (D-304), HOLDOUT_2 spent (D-307): results stay in the history")
		print("\n".join(retired.lines))
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
	var record_path := ProjectSettings.globalize_path(RECORD_PATH)
	var parsed: Dictionary = SweepMath.parse_record(FileAccess.get_file_as_string(record_path) if FileAccess.file_exists(record_path) else "")
	if not parsed.valid:
		push_error("%s exists but does not parse as a record ({\"history\": [...]}); fix or restore it by hand: the report never overwrites it" % record_path)
		quit(2)
		return
	var gate: Dictionary = SweepMath.final_gate(set_id, String(args.final) == "1", commit, parsed.record, _commit_date(proj), days, bot_rule)
	var seeds: Array = SweepMath.set_seeds(seed_set)
	var lines: Array = []
	if not gate.allowed:
		print("\n".join(gate.lines))
		quit(2)
		return
	lines.append("RETUNE_REPORT set=%s commit=%s days=%d" % ["tuning" if set_id == "tuning" else "#" + set_id, commit, days])
	lines.append("DEADLINE %d min per child run (--deadline-min)" % deadline_min)
	lines.append("BOT_RULE %s (passed to every child sweep as --bot-rule=%s)" % [bot_rule, bot_rule])
	lines.append_array(gate.lines)
	lines.append("SEED_PROMOTED north 14 (D-304): failed hold-out #1, diagnosed, now tuning data")
	lines.append("HOLDOUT_1 retired (D-304), HOLDOUT_2 spent (D-307): results stay in the history")
	lines.append("SEED_RULE scan seeds upward from 1; a seed's siege lane is LaneCharacter.for_run(seed).siege; per lane the 1st seed is the scan's tuning seed, the next 2 hold-out set #1 (RETIRED), the next 2 hold-out set #2 (SPENT), the next 2 measurement set #3, the next 2 measurement set #4, the next 2 measurement set #5 (E8), the next 2 measurement set #6 (E8); the tuning set run = the scan's tuning seeds + the promoted north 14 (D-304)")
	for l in SweepMath.SIEGE_LANES:
		lines.append("SEEDS %s %s: %s" % ["tuning" if set_id == "tuning" else "set #" + set_id, l, str(seed_set[l])])
	lines.append("NOTE a retried night counts its final (mercy) attempt, EXCEPT the first tier-3 night (FIRST_T3_NIGHT): a retried first night counts as lost, 0%; the night statistics count tier-3 nights only; hare share and the lane-cap guard are read from each run's own plan; with the retune flag on the first two tier-3 nights are below the cap (pressure 10, 11, then 12, D-304/D-305), so the at-cap columns (cap_nights, fence_rebuild_gold_median_at_cap, income_at_cap, hence FENCE_TAX) count from the third tier-3 night and are not like for like with runs before D-305")
	if String(args.dry) == "1":
		lines.append("DRY RUN: nothing started")
		print("\n".join(lines))
		quit(0)
		return
	var is_final := String(args.final) == "1" and set_id != "tuning"
	if is_final:
		_write_record(record_path, gate.record)  # recorded before the first run starts: a crash does not hide that the set was used
	var t0 := Time.get_ticks_msec()
	var jobs: Array = []
	for s in seeds:
		for p in SweepMath.RETUNE_POLICIES:
			jobs.append([s, p])
	for j in jobs:  # a stale run must not be read as this run's
		for ext in [".log", ".csv"]:
			var old: String = _log_path(out_dir, tag, j[0], j[1]).get_basename() + ext
			DirAccess.make_dir_recursive_absolute(old.get_base_dir())
			if FileAccess.file_exists(old):
				DirAccess.remove_absolute(old)
	var total := jobs.size()
	var running: Array = []
	var bad := {}  # "seed:policy" -> why the child run failed
	var failed := false
	while not failed and (not jobs.is_empty() or not running.is_empty()):
		var still: Array = []
		for r in running:
			var rlog: String = _log_path(out_dir, tag, r.seed, r.policy)
			if OS.is_process_running(int(r.pid)):
				if Time.get_ticks_msec() - int(r.t0) > run_deadline_msec:
					OS.kill(int(r.pid))
					bad["%d:%s" % [r.seed, r.policy]] = "killed after the %d s deadline" % (run_deadline_msec / 1000)
					failed = true
				else:
					still.append(r)
			else:
				var code := OS.get_process_exit_code(int(r.pid))
				var text := FileAccess.get_file_as_string(rlog) if FileAccess.file_exists(rlog) else ""
				var kv := _read_line(rlog, "T3RUN ")
				if SweepMath.child_failed(code, text):
					bad["%d:%s" % [r.seed, r.policy]] = "exit code %d or a SCRIPT ERROR line in the log" % code
					failed = true
				elif kv.is_empty() or int(kv.get("hard_break_day", "-1")) >= 0 or _read_line(rlog, "RETUNE ").is_empty():
					failed = true
		running = still
		while not failed and running.size() < parallel and not jobs.is_empty():
			var j: Array = jobs.pop_front()
			var log := _log_path(out_dir, tag, j[0], j[1])
			var first := "REPORT_RUN commit=%s set=%s seed=%d policy=%s days=%d bot_rule=%s" % [commit, tag, j[0], j[1], days, bot_rule]
			var cmd := "echo %s > %s && exec %s --headless --path %s --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=tier --days=%d --seed=%d --policy=%s --bot-rule=%s%s --out=retune/retune_%s_%d_%s.csv >> %s 2>&1" % [
				_q(first), _q(log), _q(OS.get_executable_path()), _q(proj), days, j[0], j[1], bot_rule, max_tier_arg, tag, j[0], j[1], _q(log)]
			var pid := OS.create_process("/bin/sh", ["-c", cmd])
			if pid < 0:
				push_error("could not start the run seed=%d policy=%s" % [j[0], j[1]])
				failed = true
				break
			running.append({"pid": pid, "seed": j[0], "policy": j[1], "t0": Time.get_ticks_msec()})
			print("STARTED seed=%d policy=%s pid=%d" % [j[0], j[1], pid])
		if not failed:
			OS.delay_msec(1000)
	for r in running:
		OS.kill(int(r.pid))  # a failed report leaves no child behind
	var rows: Array = []
	var expected: Array = []
	lines.append("RUN seed policy | " + " ".join(RUN_FIELDS) + " | siege first_t3_frac hare_share_mean guard_hits max_retries first_t3_retries")
	for s in seeds:
		for p in SweepMath.RETUNE_POLICIES:
			expected.append([s, p])
			var log: String = _log_path(out_dir, tag, s, p)
			var kv := _read_line(log, "T3RUN ")
			var ld := _read_line(log, "LADDER ")
			var rt := _read_line(log, "RETUNE ")
			if bad.has("%d:%s" % [s, p]):
				lines.append("RUN %d %s | FAILED (%s)" % [s, p, bad["%d:%s" % [s, p]]])
				rows.append({"seed": s, "lane": SweepMath.seed_lane(seed_set, s), "policy": p, "failed": true, "first_t3_frac": -1.0})
				continue
			if kv.is_empty() or rt.is_empty():
				lines.append("RUN %d %s | MISSING (no T3RUN or RETUNE line in %s)" % [s, p, log])
				continue
			var cells: Array = []
			for f in RUN_FIELDS:
				cells.append(String(kv.get(f, "?")))
			lines.append("RUN %d %s | %s | %s %s %s %s %s %s" % [s, p, " ".join(cells), rt.get("siege", "?"), rt.get("first_t3_frac", "?"), rt.get("hare_share_mean", "?"), rt.get("guard_hits", "?"), rt.get("max_retries", "?"), rt.get("first_t3_retries", "?")])
			var row: Dictionary = SweepMath.run_row(s, SweepMath.seed_lane(seed_set, s), p, kv, ld, rt)
			if row.failed:
				lines.append("RUN %d %s | FAILED (%s)" % [s, p, row.failed_reason])
			rows.append(row)
	var res: Dictionary = SweepMath.retune_report(rows, expected, set_id != "tuning")
	lines.append_array(res.lines)
	if int(res.exit) == 0:
		lines.append("TARGETS %s%s (counted: THREAT_LEAD, THREAT_LEAD_BY_LANE, RETRY_NIGHTS, FIRST_T3_NIGHT, FIRST_NIGHT_BAND, FENCE_TAX, LANE_CAP_GUARD; FIXED_SPREAD (spread >= 5), HARE_SHARE flags, UNBRANCHED_* and UNSPENT_* are information; read every line, the per-seed and per-lane lines most of all)" % [
			"ALL PASS" if res.ok else "NOT ALL PASS", "" if res.ok else " (failing: " + ", ".join(res.failed) + ")"])
	if is_final and _commit(proj) != commit:
		lines.append("FINAL_COMMIT_CHANGED: the commit was %s at the start and is %s now: HEAD or the tree changed during the run; the record says ok=false" % [commit, _commit(proj)])
	if is_final:
		_write_record(record_path, SweepMath.final_finish(gate.record, int(res.exit) == 0 and bool(res.ok), _commit(proj), int(res.exit) == 0))
	lines.append("WALL %.0f s (parallel=%d, %d runs)" % [(Time.get_ticks_msec() - t0) / 1000.0, parallel, total])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open(out_dir.path_join("retune_%s_%s.txt" % [tag, commit]), FileAccess.WRITE)
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
	if OS.execute("git", ["-C", proj, "status", "--porcelain", "--untracked-files=no", "--", ".", ":(exclude)tests/sim/retune_final.json"], st) == 0 and not st.is_empty() and String(st[0]).strip_edges() != "":
		h += "-dirty"
	return h

## The HEAD commit's committer date (ISO 8601) from git; "" if unavailable. Passed to the maths, which reads no clock.
func _commit_date(proj: String) -> String:
	var out: Array = []
	if OS.execute("git", ["-C", proj, "log", "-1", "--format=%cI"], out) != 0 or out.is_empty():
		return ""
	return String(out[0]).strip_edges()

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
