extends Node
## The body of tests/sim/report_margin.gd, loaded at run time after the autoloads exist (D-150).
## One night per seed by design: `retries=0` on every line (no retry loop). `failed` = the diner fell; a night that neither
## cleared nor failed (300 s timeout) or a stuck bot is BAD: it is printed and the script exits 1. Bad arguments exit 2.
## `diner_frac` = the lowest diner HP the night reached / max HP (0 for a fallen diner). Median and p25 are over diner_frac
## of all seeds (a fallen night counts as 0.0); percentile = linear interpolation between the closest ranks (ReportMath).
## `--tier-cap=<n>` overrides tier_cap[2] in memory only (every seed, after Balance.reset()); the CSV is margin_cap<n>.csv then.

const USAGE := "usage: -s res://tests/sim/report_margin.gd [-- --seeds=20260930,1,2 (non-zero integers) --fixture=tier2_full --tier-cap=<n>]"

func _ready() -> void:
	_run.call_deferred()

func _fail_args(msg: String) -> void:
	printerr("report_margin: %s\n%s" % [msg, USAGE])
	get_tree().quit(2)

func _run() -> void:
	var args := {"seeds": "20260930,1,2,3,4,5,6,7,8,9", "fixture": "tier2_full", "tier-cap": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() != 2 or not args.has(kv[0]):
			_fail_args("unknown argument %s" % a)
			return
		args[kv[0]] = kv[1]
	var seeds: Array[int] = []
	for s in String(args.seeds).split(",", true):
		if not s.is_valid_int() or int(s) == 0:
			_fail_args("bad seed '%s'" % s)
			return
		seeds.append(int(s))
	var fixture := String(args.fixture)
	if not FileAccess.file_exists("res://export/fixtures/%s.save.json" % fixture):
		_fail_args("no fixture export/fixtures/%s.save.json" % fixture)
		return
	var override := String(args["tier-cap"]) != ""
	if override and not String(args["tier-cap"]).is_valid_int():
		_fail_args("bad --tier-cap '%s'" % args["tier-cap"])
		return
	var cap_override := int(args["tier-cap"]) if override else 0
	if override:
		print("MARGIN tier_cap=%d (override)" % cap_override)
	var holder := Node.new()
	get_tree().root.add_child(holder)
	var rows := ["seed,cleared,failed,diner_frac,kills,stuck,retries"]
	var fracs: Array = []
	var cleared_n := 0
	var failed_n := 0
	var bad := 0
	for sd in seeds:
		Balance.reset()
		if override:
			Balance.data.tiers.tier_cap[2] = cap_override
		var expected_cap := int(Balance.data.tiers.tier_cap[2])
		var h := SimHarness.new(holder)
		h.start_from(fixture, NaiveBot, sd)
		if GameState.tier != 2 or GameState.pressure() != expected_cap or GameState.run_seed != sd:
			printerr("BAD seed %d: tier %d pressure %d (want 2, %d) run_seed %d" % [sd, GameState.tier, GameState.pressure(), expected_cap, GameState.run_seed])
			bad += 1
		var n := await h.run_night()
		var ok: bool = bool(n.cleared)
		var fell: bool = bool(n.failed)
		var stuck := int(h.bot.stuck_count)
		var frac := float(n.diner_frac)
		if not ok and not fell:
			printerr("BAD seed %d: the night neither cleared nor failed (timeout)" % sd)
			bad += 1
		if stuck > 0:
			printerr("BAD seed %d: the bot got stuck %d times" % [sd, stuck])
			bad += 1
		cleared_n += 1 if ok else 0
		failed_n += 1 if fell else 0
		fracs.append(0.0 if fell else frac)
		var line := "seed=%d cleared=%s failed=%s diner_frac=%.3f kills=%d stuck=%d retries=0" % [sd, str(ok).to_lower(), str(fell).to_lower(), frac, int(n.kills), stuck]
		print("MARGIN " + line)
		rows.append("%d,%s,%s,%.3f,%d,%d,0" % [sd, str(ok).to_lower(), str(fell).to_lower(), frac, int(n.kills), stuck])
		h.finish()
		await get_tree().process_frame
	print("MARGIN seeds=%d cleared=%d failed=%d median=%.3f min=%.3f max=%.3f p25=%.3f" % [
		seeds.size(), cleared_n, failed_n, ReportMath.median(fracs), ReportMath.percentile(fracs, 0.0),
		ReportMath.percentile(fracs, 100.0), ReportMath.percentile(fracs, 25.0)])
	var out_dir := ProjectSettings.globalize_path("res://tests/sim/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gi := FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)  # keep Godot from importing out/
	gi.close()
	var f := FileAccess.open(out_dir.path_join("margin_cap%d.csv" % cap_override if override else "margin.csv"), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	holder.queue_free()
	get_tree().quit(1 if bad > 0 else 0)
