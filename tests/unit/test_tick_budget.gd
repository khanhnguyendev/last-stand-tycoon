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
	re.compile("(?m)^func (test_\\w+)")
	var checked := 0
	for dir in [S, T]:
		for fname in DirAccess.get_files_at(dir):
			if not (fname.begins_with("test_") and fname.ends_with(".gd")):
				continue
			var src := FileAccess.get_file_as_string(dir + "/" + fname)
			for m in re.search_all(src):
				var key: String = "%s/%s::%s" % [dir, fname, m.get_string(1)]
				assert_true(golden.has(key), "sim without a tick budget: %s" % key)
				checked += 1
	assert_gt(checked, 0, "scanned at least one sim test")
