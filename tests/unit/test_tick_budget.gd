extends GutTest

const S := "res://tests/sim"
const T := "res://tests/sim_tier"


func test_exactly_plus_20_percent_passes() -> void:
	var p := TickBudget.check({S + "/a.gd::test_x": 120}, {S + "/a.gd::test_x": 100}, S)
	assert_eq(p.size(), 0)


func test_over_limit_fails_with_percentage() -> void:
	var p := TickBudget.check({S + "/a.gd::test_x": 121}, {S + "/a.gd::test_x": 100}, S)
	assert_eq(p.size(), 1)
	assert_string_contains(p[0], "121 ticks, expected 100 (+21.0%, limit +20%)")


func test_fewer_ticks_passes() -> void:
	var p := TickBudget.check({S + "/a.gd::test_x": 10}, {S + "/a.gd::test_x": 100}, S)
	assert_eq(p.size(), 0)


func test_unknown_test_fails() -> void:
	var p := TickBudget.check({S + "/a.gd::test_new": 5}, {}, S)
	assert_eq(p.size(), 1)
	assert_string_contains(p[0], "no expected tick count; add it to the golden file deliberately")


func test_golden_entry_that_did_not_run_fails() -> void:
	var p := TickBudget.check({}, {S + "/a.gd::test_gone": 5}, S)
	assert_eq(p.size(), 1)
	assert_string_contains(p[0], "in the golden file but did not run")


func test_other_suite_dir_is_ignored_on_both_sides() -> void:
	var actual := {S + "/a.gd::test_x": 100, T + "/b.gd::test_y": 999999}
	var golden := {S + "/a.gd::test_x": 100, T + "/b.gd::test_z": 1}
	assert_eq(TickBudget.check(actual, golden, S).size(), 0)
	var p := TickBudget.check(actual, golden, T)
	assert_eq(p.size(), 2)


func test_empty_actual_fails_once_per_golden_key() -> void:
	var golden := {S + "/a.gd::test_x": 1, S + "/a.gd::test_y": 2, T + "/b.gd::test_z": 3}
	assert_eq(TickBudget.check({}, golden, S).size(), 2)


func test_committed_golden_covers_every_sim_test() -> void:
	assert_true(FileAccess.file_exists(TickBudget.GOLDEN_PATH), "golden file exists")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TickBudget.GOLDEN_PATH))
	assert_true(parsed is Dictionary, "golden parses to a dictionary")
	if not (parsed is Dictionary):
		return
	var golden: Dictionary = parsed
	assert_gt(golden.size(), 0, "golden is non-empty")
	for k in golden:
		var v: Variant = golden[k]
		assert_true(v is int or (v is float and v == floorf(v)), "%s is an int" % k)
		assert_gt(int(v), 0, "%s > 0" % k)
	var re := RegEx.new()
	re.compile("(?m)^\\s*func\\s+(test_\\w+)")
	var found := {}
	for dir in [S, T]:
		for path in _scripts_under(dir):
			for m in re.search_all(FileAccess.get_file_as_string(path)):
				found["%s::%s" % [path, m.get_string(1)]] = true
	for key in found:
		assert_true(golden.has(key), "sim without a tick budget: %s" % key)
	for k in golden:
		assert_true(found.has(k), "golden key without a sim test: %s" % k)
	assert_gt(found.size(), 0, "scanned at least one sim test")


func test_tick_budget_hook_loads_and_is_a_gut_hook() -> void:
	var scr: Variant = load("res://tests/sim/tick_budget_hook.gd")
	assert_not_null(scr, "hook script loads")
	if scr == null:
		return
	var inst: Variant = scr.new()
	assert_not_null(inst, "hook instantiates")
	assert_true(inst is GutHookScript, "hook extends GutHookScript")
	if inst is Object and not (inst is RefCounted):
		inst.free()


func _scripts_under(dir: String) -> Array:
	var out := []
	for fname in DirAccess.get_files_at(dir):
		if fname.begins_with("test_") and fname.ends_with(".gd"):
			out.append(dir + "/" + fname)
	for sub in DirAccess.get_directories_at(dir):
		if sub != "out" and sub != "baseline":
			out.append_array(_scripts_under(dir + "/" + sub))
	return out
