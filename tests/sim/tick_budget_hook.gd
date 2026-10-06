extends GutHookScript
## GUT pre-run hook (D-247): records physics ticks per sim test and checks them against the golden file.
## Used as `-gpre_run_script=res://tests/sim/tick_budget_hook.gd` by run_tests.sh sim / sim-tiers.
## Env: TICK_BUDGET_DIR (e.g. res://tests/sim), TICK_BUDGET_UPDATE=1 to rewrite this suite's golden entries.
## GUT keeps the pre-run hook instance in _pre_run_script_instance for the whole run, so signal
## connections to this object stay valid until end_run.

var _script_path := ""
var _start_ticks := 0
var _test_name := ""
var _actual := {}


func run() -> void:
	gut.start_script.connect(_on_start_script)
	gut.start_test.connect(_on_start_test)
	gut.end_test.connect(_on_end_test)
	gut.end_run.connect(_on_end_run)


func _on_start_script(script_obj) -> void:
	_script_path = str(script_obj.path)


func _on_start_test(test_name) -> void:
	_test_name = str(test_name)
	_start_ticks = Engine.get_physics_frames()


func _on_end_test() -> void:
	var key := "%s::%s" % [_script_path, _test_name]
	_actual[key] = Engine.get_physics_frames() - _start_ticks


func _on_end_run() -> void:
	var suite_dir := OS.get_environment("TICK_BUDGET_DIR")
	if suite_dir.is_empty():
		print("TICK BUDGET: FAIL TICK_BUDGET_DIR is not set")
		return
	var golden := TickBudget.load_golden()
	var keys: Array = _actual.keys()
	keys.sort()
	for k in keys:
		var exp: String = str(golden[k]) if golden.has(k) else "-"
		print("TICKS %s actual=%d expected=%s" % [k, _actual[k], exp])
	var seg := suite_dir.get_file()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/sim/out"))
	var f := FileAccess.open("res://tests/sim/out/ticks_%s.json" % seg, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_actual, "  ", true) + "\n")
		f.close()
	if OS.get_environment("TICK_BUDGET_UPDATE") == "1":
		var prefix := suite_dir + "/"
		var merged := {}
		for gk in golden:
			if not String(gk).begins_with(prefix):
				merged[gk] = golden[gk]
		for ak in _actual:
			if String(ak).begins_with(prefix):
				merged[ak] = _actual[ak]
		TickBudget.save_golden(merged)
		print("TICK BUDGET: UPDATED %d sims" % _actual.size())
		return
	var problems := TickBudget.check(_actual, golden, suite_dir)
	if problems.is_empty():
		print("TICK BUDGET: OK %d sims within +20%% of the expected ticks" % _actual.size())
	else:
		for p in problems:
			print("TICK BUDGET: FAIL %s" % p)
