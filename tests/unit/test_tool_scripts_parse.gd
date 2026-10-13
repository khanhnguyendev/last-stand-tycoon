extends GutTest
## E6 (D-304): the report, study and fixture scripts under tests/sim/ are run by hand, so nothing else compiles them. A parse error in one of them
## (make_save.gd once had one) would only show on the next manual run. `load()` returns null for a script that does not parse.

const PATHS: Array[String] = [
	"res://tests/sim/make_save.gd",
	"res://tests/sim/report_retune.gd",
	"res://tests/sim/sweep_runner.gd",
	"res://tests/sim/study_first_t3_runner.gd",
	"res://tests/sim/sweep.gd",
	"res://tests/sim/study_first_t3.gd",
]

func test_the_tool_scripts_load_without_a_parse_error() -> void:
	for path in PATHS:
		assert_not_null(load(path), "%s must parse" % path)
