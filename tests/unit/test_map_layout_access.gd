extends GutTest
## E5 tier 3 Task 9: production code reads lanes, zones, towers, fences, yards, queue slots, the exit and the sign only through
## MapLayout's accessors. The old dictionaries hold the tier-1/2 entries only: indexing one with "sw", "tower_sw", "fence_sw" or
## "front" is a key error that shows only at tier 3.

const BANNED := ["LANE_PATHS", "ZONE_RECTS", "ZONE_AXIS", "FENCE_LANE", "LANE_FENCE", "TOWER_SPOTS", "TOWER_LANES", "YARDS",
	"QUEUE_SLOTS", "TRAVELER_EXIT", "TIER_SIGN"]
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

func _code(line: String) -> String:
	var i := line.find("#")
	return line if i < 0 else line.substr(0, i)

func _is_allowed(path: String, code: String) -> bool:
	for pat in ALLOW.get(path, []):
		if pat in code:
			return true
	return false

func _offences() -> Array:
	var files := []
	_files("res://", files)
	var rx := RegEx.new()
	rx.compile("(MapLayout|layout)\\.(%s)(_T3)?\\b|\\bLanePlanner\\.LANES\\b|\\bLANES_TIER3\\b" % "|".join(BANNED))
	var out := []
	for path in files:
		var skip := false
		for p in SKIP_PREFIXES:
			if path.begins_with(p):
				skip = true
		if skip or path == "res://core/lane_planner.gd":
			continue
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := _code(line)
			if rx.search(code) != null and not _is_allowed(path, code):
				out.append("%s:%d %s" % [path, n, line.strip_edges()])
	return out

func test_no_direct_read_of_the_tier_1_and_2_dictionaries() -> void:
	assert_eq(_offences(), [])

func test_the_scan_finds_a_planted_direct_read() -> void:
	var rx := RegEx.new()
	rx.compile("(MapLayout|layout)\\.(%s)(_T3)?\\b" % "|".join(BANNED))
	assert_not_null(rx.search("var p = MapLayout.LANE_PATHS[lane]"))
	assert_not_null(rx.search("var p = MapLayout.TOWER_SPOTS_T3.tower_sw"))
	assert_null(rx.search("var p = MapLayout.lane_path(lane)"))
	assert_null(rx.search("var p = MapLayout.TIER_SIGNS[3]"), "TIER_SIGNS is the per-tier table, not the banned TIER_SIGN")

func test_the_allow_list_entries_are_still_needed() -> void:
	for path in ALLOW:
		var text := FileAccess.get_file_as_string(path)
		for pat in ALLOW[path]:
			assert_true(pat in text, "%s no longer contains %s: drop the allow-list entry" % [path, pat])

func test_the_lane_planner_and_the_layout_agree_on_the_lanes_of_every_tier() -> void:
	for t in range(1, 5):
		assert_eq(LanePlanner.lanes_for_tier(t), MapLayout.lanes_for_tier(t), "tier %d" % t)
