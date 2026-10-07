extends GutTest
## E5 tier 3 Task 9: production code reads lanes, zones, towers, fences, yards, queue slots, the exit and the sign only through
## MapLayout's accessors. The old dictionaries hold the tier-1/2 entries only: indexing one with "sw", "tower_sw", "fence_sw" or
## "front" is a key error that shows only at tier 3.

const BANNED := ["LANE_PATHS", "ZONE_RECTS", "ZONE_AXIS", "FENCE_LANE", "LANE_FENCE", "TOWER_SPOTS", "TOWER_LANES", "YARDS",
	"QUEUE_SLOTS", "TRAVELER_EXIT", "TIER_SIGN", "YARD_TIER"]
## Skipped wholesale: the layout itself, the tests, the headless tools, the vendored test framework.
const SKIP_PREFIXES := ["res://core/map_layout.gd", "res://tests/", "res://tools/", "res://addons/", "res://export/", "res://docs/", "res://.godot/"]
## file -> code substrings that may keep a direct tier-1 read. Every entry says why.
const ALLOW := {
	# Task 16 (the layout switch at dawn, live travelers, the tier-3 sign position) owns these sites; below tier 3 they are the only layout.
	"res://world/traveler_spawner.gd": ["MapLayout.QUEUE_SLOTS["],
	"res://actors/traveler/traveler.gd": ["MapLayout.TRAVELER_EXIT"],
	"res://core/station_effects.gd": ["MapLayout.TRAVELER_EXIT"],
	"res://world/stations/tier_sign.gd": ["MapLayout.TIER_SIGN"],
	"res://world/fx/reactions.gd": ["MapLayout.TIER_SIGN"],
	# The tier-2 graph node: the tier-2 sign. The tier-3 sign is its own node (tier_sign(3)) in _add_tier3.
	"res://core/waypoint_graph.gd": ["MapLayout.TIER_SIGN"],
}

func _files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_files(dir.path_join(d), out)

## The ONE pattern the scan and its self-test share.
static func _pattern() -> RegEx:
	var rx := RegEx.new()
	rx.compile("(MapLayout|layout)\\.(%s)(_T3)?\\b|\\bLanePlanner\\.LANES\\b|\\bLANES_TIER3\\b" % "|".join(BANNED))
	return rx

## The line without its trailing comment; a # inside a string literal does not start one.
func _code(line: String) -> String:
	var quote := ""
	for i in line.length():
		var c := line[i]
		if quote != "":
			if c == "\\":
				continue
			if c == quote and (i == 0 or line[i - 1] != "\\"):
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
	return line

func _is_allowed(path: String, code: String) -> bool:
	for pat in ALLOW.get(path, []):
		if pat in code:
			return true
	return false

## Every banned read outside the skipped paths as "path:line text"; `use_allow` false lists the allow-listed ones too. `visited` counts files.
func _scan(use_allow: bool, visited: Array) -> Array:
	var files := []
	_files("res://", files)
	var rx := _pattern()
	var out := []
	for path in files:
		var skip := false
		for p in SKIP_PREFIXES:
			if path.begins_with(p):
				skip = true
		if skip or path == "res://core/lane_planner.gd":
			continue
		visited.append(path)
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := _code(line)
			if rx.search(code) != null and not (use_allow and _is_allowed(path, code)):
				out.append("%s:%d" % [path, n])
	return out

func test_no_direct_read_of_the_tier_1_and_2_dictionaries() -> void:
	var visited := []
	assert_eq(_scan(true, visited), [])
	assert_gt(visited.size(), 100, "the scan really walked the project")

func test_with_the_allow_list_ignored_the_scan_finds_exactly_the_allow_listed_sites() -> void:
	var found := _scan(false, [])
	var by_file := {}
	for f in found:
		by_file[String(f).rsplit(":", true, 1)[0]] = true
	var want := ALLOW.keys()
	want.sort()
	var got := by_file.keys()
	got.sort()
	assert_eq(got, want, "the allow-list names exactly the files with direct reads")

func test_the_pattern_matches_direct_reads_and_nothing_else() -> void:
	var rx := _pattern()
	assert_not_null(rx.search("var p = MapLayout.LANE_PATHS[lane]"))
	assert_not_null(rx.search("var p = MapLayout.TOWER_SPOTS_T3.tower_sw"))
	assert_not_null(rx.search("MapLayout.YARD_TIER[id]"))
	assert_not_null(rx.search("for l in LanePlanner.LANES:"))
	assert_null(rx.search("var p = MapLayout.lane_path(lane)"))
	assert_null(rx.search("var p = MapLayout.TIER_SIGNS[3]"), "TIER_SIGNS is the per-tier table, not the banned TIER_SIGN")

func test_a_hash_inside_a_string_does_not_hide_a_read() -> void:
	assert_not_null(_pattern().search(_code('var s = "#" + str(MapLayout.YARDS)')))
	assert_null(_pattern().search(_code("var x = 1  # MapLayout.YARDS in a comment")))
	assert_null(_pattern().search(_code("## MapLayout.YARDS")))

func test_all_yards_lists_every_yard_in_yard_order() -> void:
	assert_eq(MapLayout.all_yards(), ["west", "east", "front"])

func test_the_allow_list_entries_are_still_needed() -> void:
	for path in ALLOW:
		var text := FileAccess.get_file_as_string(path)
		for pat in ALLOW[path]:
			assert_true(pat in text, "%s no longer contains %s: drop the allow-list entry" % [path, pat])

func test_the_lane_planner_and_the_layout_agree_on_the_lanes_of_every_tier() -> void:
	for t in range(1, 5):
		assert_eq(LanePlanner.lanes_for_tier(t), MapLayout.lanes_for_tier(t), "tier %d" % t)
