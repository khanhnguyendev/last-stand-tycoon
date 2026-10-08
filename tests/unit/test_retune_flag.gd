extends GutTest
## E6 Task 1 (D-286): the one retune flag, its accessor, the debug toggle and the two source scans.

var DO = load("res://ui/debug/debug_overlay.gd")

const PROD_DIRS := ["res://autoload", "res://core", "res://components", "res://actors", "res://world", "res://ui", "res://art", "res://balance"]
const DECL_FILE := "res://balance/tier_balance.gd"
const DECL_LINE := "@export var retune_enabled := false"

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	Balance.reset()

## Mutation: the default changed to true in the declaration or in balance.tres.
func test_default_is_false_on_a_fresh_reset() -> void:
	assert_false(Balance.data.tiers.retune_enabled)
	assert_false(TierEffects.retune_on(Balance.data.tiers))

## Mutation: retune_on returns a constant, or reads another field.
func test_retune_on_follows_the_flag() -> void:
	Balance.data.tiers.retune_enabled = true
	assert_true(TierEffects.retune_on(Balance.data.tiers))
	Balance.data.tiers.retune_enabled = false
	assert_false(TierEffects.retune_on(Balance.data.tiers))

## Mutation: retune_on dereferences tb without the null check (script error) or returns true for null.
func test_retune_on_null_is_false() -> void:
	assert_false(TierEffects.retune_on(null))

## Mutation: retune_arg accepts "true", "0", "2", "" or an absent key, or ignores the value.
func test_debug_helper_true_only_for_retune_1() -> void:
	assert_true(DO.retune_arg(UrlFlags.parse("?retune=1")))
	assert_true(DO.retune_arg(UrlFlags.parse("?autoplay=1&retune=1")))
	assert_false(DO.retune_arg(UrlFlags.parse("?retune=0")))
	assert_false(DO.retune_arg(UrlFlags.parse("?retune=true")))
	assert_false(DO.retune_arg(UrlFlags.parse("?retune=")))
	assert_false(DO.retune_arg(UrlFlags.parse("?autoplay=1")))
	assert_false(DO.retune_arg({}))

## Mutation: a test leaks the flag and Balance.reset() no longer restores it (e.g. reset keeps tiers).
func test_reset_restores_false_after_a_test_set_it() -> void:
	Balance.data.tiers.retune_enabled = true
	assert_true(Balance.data.tiers.retune_enabled, "setup: the flag is on")
	Balance.reset()
	assert_false(Balance.data.tiers.retune_enabled)

# --- source scans ----------------------------------------------------------------------------------

func _collect(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_collect(dir_path.path_join(d), out)

## Production files (not ui/debug, tests, tools) as path -> comment-stripped, trimmed lines.
func _prod_lines() -> Dictionary:
	var files: Array = []
	for d in PROD_DIRS:
		_collect(d, files)
	var out := {}
	for path in files:
		if (path as String).begins_with("res://ui/debug/"):
			continue
		var lines: Array = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var cut: String = line
			if (path as String).ends_with(".gd"):
				var hash_at := cut.find("#")
				if hash_at >= 0:
					cut = cut.substr(0, hash_at)
			lines.append(cut.strip_edges())
		out[path] = lines
	return out

## Mutation: any production file (not ui/debug, tests, tools) assigns retune_enabled (=, +=, |=, set(), set_deferred());
## the only allowed hit is the declaration line, pinned exactly; a second declaration or a changed default fails.
func test_scan_a_nothing_in_production_assigns_the_flag() -> void:
	var prod := _prod_lines()
	assert_true(prod.has("res://autoload/GameState.gd"), "the scan reached autoload/")
	assert_true(prod.has(DECL_FILE), "and balance/")
	var assign_re := RegEx.new()
	assign_re.compile("retune_enabled\"?\\s*(:?=[^=]|\\+=|-=|\\|=|&=)|set(_deferred)?\\(\\s*[\"&]+retune_enabled")
	var offenders: Array = []
	var decl_hits := 0
	for path in prod:
		for line in prod[path]:
			if assign_re.search(line) == null:
				continue
			if path == DECL_FILE and line == DECL_LINE:
				decl_hits += 1
			else:
				offenders.append("%s: %s" % [path, line])
	assert_eq(offenders, [], "production code assigns retune_enabled")
	assert_eq(decl_hits, 1, "exactly the declaration line `%s`" % DECL_LINE)

## Mutation: any production file other than core/tier_effects.gd mentions retune_enabled (a direct read), except the
## declaration line in balance/tier_balance.gd; offenders are listed.
func test_scan_b_every_read_goes_through_the_accessor() -> void:
	var prod := _prod_lines()
	assert_true(prod.has("res://core/tier_effects.gd"), "the scan reached core/")
	var accessor_hits := 0
	var offenders: Array = []
	for path in prod:
		for line in prod[path]:
			if not (line as String).contains("retune_enabled"):
				continue
			if path == "res://core/tier_effects.gd":
				accessor_hits += 1
			elif path == DECL_FILE and line == DECL_LINE:
				pass
			else:
				offenders.append("%s: %s" % [path, line])
	assert_eq(offenders, [], "only TierEffects.retune_on may read retune_enabled; offenders: %s" % str(offenders))
	assert_gt(accessor_hits, 0, "the accessor itself reads the flag")
