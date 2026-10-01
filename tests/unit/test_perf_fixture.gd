extends GutTest
## The perf fixture is a valid current-schema save (S4 spec 9.5).

var _events: Array = []
var _cb: Callable

func _record(p: int, d: int) -> void:
	_events.append([p, d])

func _start_recording() -> void:
	_events.clear()
	_cb = _record
	EventBus.phase_changed.connect(_cb)

func after_each() -> void:
	if _cb.is_valid() and EventBus.phase_changed.is_connected(_cb):
		EventBus.phase_changed.disconnect(_cb)

func _decode(stem: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
	return SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)

func test_fixtures_decode() -> void:
	for pair in [["night3_start", "NIGHT"], ["night3_closeup", "DAY"]]:
		var r := _decode(pair[0])
		assert_true(r.ok, "%s: %s" % [pair[0], r.reason])
		assert_eq(String(r.state.resume_phase), pair[1])
		assert_eq(int(r.state.day), 3, "the close-up before night 3")

func test_night_fixture_resumes_into_night() -> void:
	var main: Main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(1)
	assert_eq(GameState.day, 1, "a fresh game starts on day 1, so day 3 below comes from the fixture")
	_start_recording()
	main.phase_controller.resume_from(_decode("night3_start").state)
	assert_true(_events.has([Phase.NIGHT, 3]), "phase_changed(NIGHT, 3) emitted: %s" % [_events])
	for i in int(ceil((Balance.data.wave.first_wave_delay + 1.0) * 60.0)):
		await get_tree().physics_frame
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(GameState.day, 3, "night 3")
	assert_gt(main.phase_controller.wave_director.alive_count(), 0, "Boars are alive")

func test_closeup_fixture_resumes_into_day() -> void:
	var main: Main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(1)
	assert_eq(GameState.day, 1)
	_start_recording()
	main.phase_controller.resume_from(_decode("night3_closeup").state)
	assert_true(_events.has([Phase.DAY, 3]), "phase_changed(DAY, 3) emitted: %s" % [_events])
	assert_eq(GameState.day, 3)
