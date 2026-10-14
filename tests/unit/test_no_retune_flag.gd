extends GutTest
## E6 cleanup (D-307): the retune flag is gone and cannot come back half-way. No .gd file anywhere outside docs/ (and the third-party addons/, the
## import cache .godot/ and this file) mentions `retune_enabled` or `retune_on`.

const SELF := "res://tests/unit/test_no_retune_flag.gd"
const SKIP_DIRS := ["res://docs", "res://addons", "res://.godot"]
const WORDS := ["retune_enabled", "retune_on"]

func _collect(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		var sub := dir_path.path_join(d)
		if not SKIP_DIRS.has(sub):
			_collect(sub, out)

## Mutation: a file brings the flag back (a declaration, a read, an assignment in a test or a tool). The scan reaches production, tests and tools.
func test_no_gd_file_outside_docs_mentions_the_flag() -> void:
	var files: Array = []
	_collect("res://", files)
	assert_true(files.has("res://autoload/GameState.gd"), "the scan reached autoload/")
	assert_true(files.has("res://balance/tier_balance.gd"), "and balance/")
	assert_true(files.has("res://tests/unit/test_wave_math.gd"), "and tests/")
	assert_true(files.has("res://tools/shot_pads.gd"), "and tools/")
	assert_gt(files.size(), 300, "a real tree, not an empty walk")
	var offenders: Array = []
	for path in files:
		if path == SELF:
			continue
		var text := FileAccess.get_file_as_string(path)
		for w in WORDS:
			if text.contains(w):
				offenders.append("%s: %s" % [path, w])
	assert_eq(offenders, [], "the retune flag must not come back")
