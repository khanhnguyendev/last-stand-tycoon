extends Node
## The body of tests/sim/report_margin.gd, loaded at run time after the autoloads exist (D-150).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {"seeds": "20260930,1,2,3,4,5,6,7,8,9", "fixture": "tier2_full"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var seeds: Array[int] = []
	for s in String(args.seeds).split(",", false):
		seeds.append(int(s))
	var holder := Node.new()
	get_tree().root.add_child(holder)
	var rows := ["seed,cleared,diner_frac,kills"]
	var fracs: Array = []
	var cleared_n := 0
	var bad := 0
	for sd in seeds:
		Balance.reset()
		var h := SimHarness.new(holder)
		h.start_from(String(args.fixture), NaiveBot, sd)
		if GameState.tier != 2 or GameState.pressure() != int(Balance.data.tiers.tier_cap[2]):
			push_error("seed %d: tier %d pressure %d is not the tier-2 cap" % [sd, GameState.tier, GameState.pressure()])
			bad += 1
		var n := await h.run_night()
		var ok: bool = bool(n.cleared)
		var frac := float(n.diner_frac) if ok else 0.0
		cleared_n += 1 if ok else 0
		fracs.append(frac)
		print("MARGIN seed=%d cleared=%s diner_frac=%.3f kills=%d" % [sd, str(ok).to_lower(), frac, int(n.kills)])
		rows.append("%d,%s,%.3f,%d" % [sd, str(ok).to_lower(), frac, int(n.kills)])
		h.finish()
		await get_tree().process_frame
	print("MARGIN seeds=%d cleared=%d median=%.3f min=%.3f max=%.3f p25=%.3f" % [
		seeds.size(), cleared_n, ReportMath.median(fracs), ReportMath.percentile(fracs, 0.0),
		ReportMath.percentile(fracs, 100.0), ReportMath.percentile(fracs, 25.0)])
	var out_dir := ProjectSettings.globalize_path("res://tests/sim/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("margin.csv"), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	holder.queue_free()
	get_tree().quit(1 if bad > 0 else 0)
