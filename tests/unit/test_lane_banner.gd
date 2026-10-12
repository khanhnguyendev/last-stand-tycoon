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

var banner_frames: Array = []

func _on_banner(t) -> void:
	banners.append(t)
	banner_frames.append(Engine.get_physics_frames())

func before_each() -> void:
	Balance.reset()
	SaveCodec.MIGRATIONS.clear()
	banners.clear()
	banner_frames.clear()

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
	banner_frames.clear()

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
	await _dawn_and_pick(7.0)
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

func _frame_of(text: String) -> int:
	var i := banners.find(text)
	return banner_frames[i] if i >= 0 else -1

## Physics frames each text has been ON the HUD's banner label (the test reads the HUD, not the controller's clock).
var hud_frames := {}

func _sample_hud() -> void:
	if main != null and main.hud.banner.visible:
		var t: String = main.hud.banner.text
		hud_frames[t] = int(hud_frames.get(t, 0)) + 1

func _wait_s(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame
		_sample_hud()

## Waits until `text` has been emitted `n` times (at most 12 s).
func _wait_emitted(text: String, n: int) -> void:
	var guard := 0
	while banners.count(text) < n and guard < 720:
		await get_tree().physics_frame
		_sample_hud()
		guard += 1
	assert_eq(banners.count(text), n, "setup: %s emitted %d times" % [text, n])

## The pick of a tier-3 fixture dawn after the boot's own banners are gone. Returns the pair.
func _start_pick() -> Array:
	var lines := LaneCharacter.flavour_lines(GameState.lane_character())
	await _wait_s(3.0)
	main.phase_controller._on_wave_cleared(GameState.lane_plan.size() - 1)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK", "setup: the fixture offers cards")
	banners.clear()
	banner_frames.clear()
	hud_frames.clear()
	EventBus.card_chosen.emit(GameState.card_offer[0])
	return lines

## E6 fix round (D-294.5): the order is the pick banner, the siege line, the hare line, each for its full banner_time ON THE HUD.
## Mutation: both lines sent at once with the pick; the hare line sent early; a line sent while the one before still shows.
func test_pick_banner_then_siege_then_hare_each_gets_its_full_two_seconds() -> void:
	await _boot(_v6_decoded(), true)
	var lines: Array = await _start_pick()
	var pick: String = banners[0]
	var t_pick: int = banner_frames[0]
	assert_eq(banners.size(), 1, "only the pick banner at the pick")
	assert_false(GameState.lane_character_shown)
	await _wait_s(1.9)
	assert_eq(_lc_banners(), [], "no lane line while the pick banner shows")
	await _wait_s(0.3)
	assert_eq(_lc_banners(), [lines[0]], "the siege line once the pick banner had its 2.0 s")
	var t_siege := _frame_of(lines[0])
	assert_gte(t_siege - t_pick, 120, "pick banner full time")
	assert_lte(t_siege - t_pick, 126)
	assert_false(GameState.lane_character_shown, "false until the hare line has had its time")
	await _wait_s(1.8)
	assert_eq(_lc_banners(), [lines[0]], "the hare line waits for the siege line's 2.0 s")
	await _wait_s(0.4)
	assert_eq(_lc_banners(), lines)
	assert_gte(_frame_of(lines[1]) - t_siege, 120)
	assert_lte(_frame_of(lines[1]) - t_siege, 126)
	assert_false(GameState.lane_character_shown, "the hare line has not had its 2.0 s yet")
	await _wait_s(2.0)
	assert_true(GameState.lane_character_shown, "true once the hare line's full time has ended")
	assert_eq(banners.filter(func(b): return b == pick).size(), 1)
	for t in [pick, lines[0], lines[1]]:
		assert_between(int(hud_frames.get(t, 0)), 117, 124, "frames '%s' was on the HUD's label" % t)

## Mutation: a foreign banner is cut by a lane line, or the lane line is dropped.
func test_a_foreign_banner_while_the_lines_wait_is_not_cut_and_the_lines_follow_it() -> void:
	await _boot(_v6_decoded(), true)
	var lines: Array = await _start_pick()
	await _wait_s(0.5)
	EventBus.banner_requested.emit("Foreign event")
	var t_f := _frame_of("Foreign event")
	await _wait_s(2.5)  # the pick banner was cut to 0.6 s by the foreign one (HUD rule), which then shows 2.0 s
	assert_eq(_lc_banners(), [], "no lane line while the foreign banner shows")
	await _wait_s(0.6)
	assert_eq(_lc_banners(), [lines[0]], "the siege line follows the foreign banner")
	assert_gte(_frame_of(lines[0]) - t_f, 155, "after the foreign banner's full time (0.6 s cut + 2.0 s)")
	assert_between(int(hud_frames.get("Foreign event", 0)), 117, 124, "the foreign banner was not cut")
	await _wait_s(4.5)
	assert_eq(_lc_banners(), lines)
	assert_true(GameState.lane_character_shown)

## E6 review 2: a cut line is not a shown line. A foreign banner 0.5 s into the siege line cuts it; it is shown again in full after the
## foreign banner, then the hare line; the flag is true only at the end. Mutation: the cut line dropped, or the flag set at the cut.
func test_a_foreign_banner_half_a_second_into_the_siege_line_gets_the_siege_line_again_in_full() -> void:
	await _boot(_v6_decoded(), true)
	var lines: Array = await _start_pick()
	await _wait_emitted(lines[0], 1)
	await _wait_s(0.5)
	hud_frames.clear()
	EventBus.banner_requested.emit("Boss")
	await _wait_s(0.4)
	assert_false(GameState.lane_character_shown)
	await _wait_s(1.9)  # the siege line's cut remainder (0.6 s), then the boss banner 2.0 s: 2.6 s in all
	assert_eq(banners.filter(func(b): return b in lines or b == "Boss"), [lines[0], "Boss"], "the siege line waits behind the foreign banner")
	await _wait_emitted(lines[0], 2)
	hud_frames.clear()
	await _wait_s(2.3)
	assert_between(int(hud_frames.get(lines[0], 0)), 117, 124, "the second showing is in full")
	assert_eq(banners.filter(func(b): return b in lines or b == "Boss"), [lines[0], "Boss", lines[0], lines[1]], "order holds")
	assert_false(GameState.lane_character_shown, "the hare line is still on screen")
	await _wait_s(2.2)
	assert_true(GameState.lane_character_shown)
	assert_eq(banners.count(lines[1]), 1)

## Same, 0.5 s into the hare line. Mutation: a cut hare line marks the flag.
func test_a_foreign_banner_half_a_second_into_the_hare_line_gets_the_hare_line_again_in_full() -> void:
	await _boot(_v6_decoded(), true)
	var lines: Array = await _start_pick()
	await _wait_emitted(lines[1], 1)
	await _wait_s(0.5)
	EventBus.banner_requested.emit("Boss")
	await _wait_s(0.7 + 1.0)
	assert_false(GameState.lane_character_shown, "a cut hare line is not a shown one")
	await _wait_emitted(lines[1], 2)
	hud_frames.clear()
	assert_false(GameState.lane_character_shown, "just sent again")
	await _wait_s(1.9)
	assert_false(GameState.lane_character_shown, "not before its full time")
	await _wait_s(0.4)
	assert_true(GameState.lane_character_shown)
	assert_eq(banners.filter(func(b): return b in lines or b == "Boss"), [lines[0], lines[1], "Boss", lines[1]])
	assert_between(int(hud_frames.get(lines[1], 0)), 117, 124, "the second showing is in full")

## Mutation: lines shown at night; the flag set although the hare line never finished; the pair not repeated at the next dawn.
func test_night_before_the_pair_completes_shows_nothing_keeps_the_flag_false_and_the_pair_comes_at_the_next_dawn() -> void:
	await _boot(_v6_decoded(), true)
	var lines: Array = await _start_pick()
	await _wait_s(2.3)
	assert_eq(_lc_banners(), [lines[0]], "setup: the siege line is out, the hare line is not")
	main.phase_controller.close_up()
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	await _wait_s(5.0)
	assert_eq(_lc_banners(), [lines[0]], "nothing more at night")
	assert_false(GameState.lane_character_shown)
	banners.clear()
	banner_frames.clear()
	await _dawn_and_pick(7.0)
	assert_eq(_lc_banners(), lines, "the whole pair at the next dawn")
	assert_true(GameState.lane_character_shown)

## Parity: the HUD and the controller's clock agree on a scripted sequence (pick banner, the two lane lines, a foreign banner in the middle),
## each physics frame, within one frame. Mutation: the controller's clock follows another rule than the HUD's.
func test_the_controllers_clock_and_the_hud_agree_every_frame() -> void:
	await _boot(_v6_decoded(), true)
	await _start_pick()
	var pc := main.phase_controller
	var hud_show: Array = []
	var ctl_show: Array = []
	var hud_q: Array = []
	var ctl_q: Array = []
	for i in int(14.0 * 60.0):
		if i == 200:
			EventBus.banner_requested.emit("Foreign event")
		await get_tree().physics_frame
		hud_show.append(main.hud._banner_left > 0.0)
		ctl_show.append(pc._clock.left > 0.0)
		hud_q.append(main.hud._banner_queue.size())
		ctl_q.append(pc._clock.queue.size())
	for i in hud_show.size():
		var lo := maxi(i - 1, 0)
		var hi := mini(i + 1, hud_show.size() - 1)
		assert_true(hud_show[i] == ctl_show[i] or hud_show[i] == ctl_show[lo] or hud_show[i] == ctl_show[hi], "showing at frame %d" % i)
		assert_true(hud_q[i] == ctl_q[i] or hud_q[i] == ctl_q[lo] or hud_q[i] == ctl_q[hi], "queue size at frame %d" % i)
	assert_true(ctl_show.has(true) and ctl_show[ctl_show.size() - 1] == false, "setup: the sequence shows banners and ends idle")

## Mutation: _cancel_reveal leaves pending or in-flight lines.
func test_cancel_reveal_clears_the_pending_and_in_flight_lines() -> void:
	await _boot(_v6_decoded(), true)
	var pc := main.phase_controller
	pc._lane_lines = ["a", "b"]
	pc._lane_inflight = "c"
	pc._cancel_reveal()
	assert_eq(pc._lane_lines, [])
	assert_eq(pc._lane_inflight, "")

## E6 review 2: the flag is saved when it is set. RED until the wiring note of the Task 11 fix round is applied (a bus signal emitted by
## GameState.mark_lane_character_shown, and Autosave writing on it): today nothing writes after the hare line.
func test_the_shown_flag_is_written_to_the_store_when_it_is_set() -> void:
	var dir := "user://test_saves/lb_%d" % Time.get_ticks_usec()
	await _boot(_v6_decoded(), true)
	var store := SaveStore.with_dir(dir)
	main.autosave.store = store
	await _start_pick()
	await _wait_s(7.5)
	assert_true(GameState.lane_character_shown, "setup: the pair went out")
	var saved: Dictionary = SaveStore.with_dir(dir).read().state
	assert_true(bool(saved.get("lane_character_shown", false)), "the store holds the flag the moment it is set")
	assert_eq(str(saved.get("resume_phase", "")), "DAY", "the restore point is the day")
	store.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
