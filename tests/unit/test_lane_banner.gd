extends GutTest
## E6 Task 11 (spec 5.4, D-289.4): the eight flavour lines, and the one-time banner of a save that was already at tier 3 when the
## retune switched on. The reveal's own step is tested in test_tier_reveal.gd. Every test names the wrong implementation it catches.

const V6_FIXTURE := "res://tests/fixtures/v6_tier3_cap_threat.save.json"
const LANES := ["west", "north", "east", "sw"]
## What each lane is called in its lines.
const LANE_WORD := {"west": "west", "north": "north", "east": "east", "sw": "south"}
## Hand-written from LaneCharacter.for_run(20260930) is not needed: the fixture's own seed is read at run time.

var main: Main
var banners: Array = []

func _on_banner(t) -> void:
	banners.append(t)

func before_each() -> void:
	Balance.reset()
	SaveCodec.MIGRATIONS.clear()
	banners.clear()

func after_each() -> void:
	if EventBus.banner_requested.is_connected(_on_banner):
		EventBus.banner_requested.disconnect(_on_banner)
	Balance.reset()
	GameState.new_game(1)

# --- the eight lines -------------------------------------------------------------------------------------

## Mutation: a line over six words; an empty line; two kinds or lanes sharing a text; a line naming the wrong lane.
func test_all_eight_lines_are_at_most_six_words_non_empty_distinct_and_name_their_lane() -> void:
	var seen := {}
	for lane in LANES:
		for kind in [LaneCharacter.SIEGE, LaneCharacter.HARE]:
			var line := LaneCharacter.flavour(lane, kind)
			var tag := "%s %s: '%s'" % [lane, kind, line]
			assert_ne(line, "", tag)
			assert_lte(line.split(" ", false).size(), 6, tag + " has more than 6 words")
			assert_true(line.contains(String(LANE_WORD[lane]) + " "), tag + " names its lane")
			for other in LANES:
				if other != lane:
					assert_false(line.contains(String(LANE_WORD[other]) + " "), tag + " names another lane")
			assert_false(seen.has(line), tag + " is a duplicate")
			seen[line] = true
	assert_eq(seen.size(), 8)
	assert_eq(LaneCharacter.FLAVOUR.size(), 4, "four lanes in the table")

func test_the_siege_lines_speak_of_tracks_and_the_hare_lines_of_paws() -> void:
	for lane in LANES:
		assert_true(LaneCharacter.flavour(lane, LaneCharacter.SIEGE).begins_with("Heavy tracks"), lane)
		assert_true(LaneCharacter.flavour(lane, LaneCharacter.HARE).begins_with("Quick paws"), lane)
	assert_eq(LaneCharacter.flavour("west", LaneCharacter.NEUTRAL), "", "no line for a neutral lane")
	assert_eq(LaneCharacter.flavour("nowhere", LaneCharacter.SIEGE), "")

## Mutation: the lines are taken from the wrong lane or kind of the character.
func test_the_lines_of_a_character_are_its_siege_line_then_its_hare_line() -> void:
	assert_eq(LaneCharacter.flavour_lines({}), [], "an empty character has none")
	var c := LaneCharacter.for_run(1)
	assert_eq(c, {"siege": "east", "hare": "west"}, "setup: pinned seed 1")
	assert_eq(LaneCharacter.flavour_lines(c), ["Heavy tracks on the east road...", "Quick paws in the west grass..."])
	assert_eq(LaneCharacter.flavour_lines({"siege": "sw", "hare": "north"}), ["Heavy tracks on the south road...", "Quick paws in the north grass..."])

# --- the save field --------------------------------------------------------------------------------------

func _v6_decoded() -> Dictionary:
	var r := SaveCodec.decode(FileAccess.get_file_as_string(V6_FIXTURE), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	return r.state

func _roundtrip(s: Dictionary) -> Dictionary:
	var r := SaveCodec.decode(SaveCodec.encode(s, "t", 0), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	return r.state

## Mutation: the migration does not add the field; it adds true.
func test_the_v6_migration_adds_the_field_false() -> void:
	var s := _v6_decoded()
	assert_true(s.has("lane_character_shown"))
	assert_false(s.lane_character_shown)

## Mutation: the key is required on read (a v7 save written before this task would be rejected).
func test_a_v7_save_without_the_key_loads_as_false() -> void:
	var s := _v6_decoded()
	s.erase("lane_character_shown")
	assert_eq(SaveCodec.validate(s, Balance.data), "")
	GameState.new_game(3)
	GameState.lane_character_shown = true
	GameState.from_dict(_roundtrip(s))
	assert_false(GameState.lane_character_shown, "a missing key is false, not the previous game's true")

## Mutation: from_dict or to_dict ignores the field.
func test_the_field_round_trips_true_and_false() -> void:
	for v in [true, false]:
		GameState.new_game(3)
		GameState.lane_character_shown = v
		var s := GameState.to_dict()
		assert_eq(s.lane_character_shown, v)
		GameState.new_game(4)
		GameState.lane_character_shown = not v
		GameState.from_dict(_roundtrip(s))
		assert_eq(GameState.lane_character_shown, v)

func test_a_non_bool_field_is_rejected_and_new_game_clears_it() -> void:
	var s := _v6_decoded()
	s.lane_character_shown = "yes"
	assert_eq(SaveCodec.validate(s, Balance.data), "type lane_character_shown")
	GameState.lane_character_shown = true
	GameState.new_game(5)
	assert_false(GameState.lane_character_shown)

# --- the one-time banner at the first dawn --------------------------------------------------------------

## Boots a game from the migrated v6 tier-3 fixture (flag as given), at night with the fixture's plan.
func _boot(state: Dictionary, flag: bool) -> void:
	Balance.data.tiers.retune_enabled = flag
	if main == null:
		main = Main.create()
		add_child_autofree(main)
		main.hero.input.player_control = false
		await get_tree().physics_frame
		EventBus.banner_requested.connect(_on_banner)
	state.resume_phase = "NIGHT"
	main.phase_controller.resume_from(state)
	await get_tree().physics_frame
	banners.clear()

## A won night: the real dawn, the real pick when one is offered, then `wait` physics seconds of the day.
func _dawn_and_pick(wait := 2.5) -> void:
	main.phase_controller._on_wave_cleared(GameState.lane_plan.size() - 1)
	if main.phase_controller.dawn_substate == "CARD_PICK":
		EventBus.card_chosen.emit(GameState.card_offer[0])
	assert_eq(main.phase_controller.phase, Phase.DAY, "setup: the dawn ended in the day")
	for i in int(wait * 60.0):
		await get_tree().physics_frame

func _lc_banners() -> Array:
	return banners.filter(func(b): return String(b).begins_with("Heavy tracks") or String(b).begins_with("Quick paws"))

## Mutations: the banner is never shown; shown twice; shown again after a reload (the field not saved or not loaded); the hare line
## missing; the field not set.
func test_a_tier3_save_with_the_field_false_shows_the_banner_once_and_never_again_after_a_reload() -> void:
	var state := _v6_decoded()
	await _boot(state, true)
	assert_eq(GameState.tier, 3)
	assert_false(GameState.lane_character_shown, "setup: the loaded save has not shown it")
	var lines := LaneCharacter.flavour_lines(GameState.lane_character())
	assert_eq(lines.size(), 2)
	await _dawn_and_pick()
	assert_eq(_lc_banners(), lines, "siege line then hare line, once each")
	assert_true(GameState.lane_character_shown)
	# save, reload, and the next dawn
	var saved := _roundtrip(GameState.to_dict())
	assert_true(saved.lane_character_shown, "the saved file holds it")
	GameState.lane_character_shown = false  # a fresh process: only the file can bring it back
	await _boot(saved, true)
	assert_true(GameState.lane_character_shown, "and a reload brings it back")
	await _dawn_and_pick()
	assert_eq(_lc_banners(), [], "the next dawn shows nothing")
	await _dawn_and_pick()
	assert_eq(_lc_banners(), [], "nor the one after")

## Mutation: the banner ignores the flag (shown with it off), or the field is set while nothing is shown.
func test_with_the_flag_off_the_banner_never_shows_and_the_field_stays_false() -> void:
	await _boot(_v6_decoded(), false)
	assert_eq(GameState.lane_character(), {})
	await _dawn_and_pick()
	assert_eq(_lc_banners(), [])
	assert_false(GameState.lane_character_shown)
	assert_false(GameState.to_dict().lane_character_shown)

## Mutation: a new game's own reveal and the one-time banner both fire. A run whose reveal marked the field has no second banner.
func test_a_save_whose_field_is_true_shows_no_banner() -> void:
	var state := _v6_decoded()
	state.lane_character_shown = true
	await _boot(state, true)
	await _dawn_and_pick()
	assert_eq(_lc_banners(), [])

## Mutation: both lines sent at once (the first is cut to banner_min_s and unreadable): the hare line comes banner_time after.
func test_the_hare_line_follows_the_siege_line_after_banner_time() -> void:
	await _boot(_v6_decoded(), true)
	var lines := LaneCharacter.flavour_lines(GameState.lane_character())
	await _dawn_and_pick(0.5)
	assert_eq(_lc_banners(), [lines[0]], "only the siege line at first")
	for i in int(Balance.ui.banner_time * 60.0):
		await get_tree().physics_frame
	assert_eq(_lc_banners(), lines)
