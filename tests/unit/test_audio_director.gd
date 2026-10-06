extends GutTest

var d: AudioDirector

func before_each() -> void:
	Balance.reset()
	UrlFlags.set_for_tests("")
	d = AudioDirector.new()
	add_child_autofree(d)
	d.setup(null)
	d.set_unlocked()

func after_each() -> void:
	AudioServer.set_bus_mute(0, false)
	GameState.new_game(0)
	UrlFlags.set_for_tests("")
	get_tree().paused = false
	SettingsStore.with_dir("user://test_dir_audio").wipe_for_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_dir_audio"))

func test_bus_signals_map_to_ids() -> void:
	EventBus.steak_sold.emit(1, 3)
	EventBus.steak_picked.emit(1)
	EventBus.build_completed.emit(&"fence_n", 1)
	EventBus.card_offered.emit([&"archer"])
	EventBus.card_picked.emit(&"archer", 1)
	EventBus.wave_incoming.emit(0, &"north", &"")
	EventBus.diner_damaged.emit(5.0, 100.0)
	EventBus.night_failed.emit(1)
	EventBus.guard_knocked_out.emit(&"archer")
	EventBus.guard_revived.emit(&"archer")
	EventBus.sfx_requested.emit(&"throw")
	EventBus.enemy_killed.emit(0, &"north", Vector3.ZERO, &"boar")
	EventBus.phase_changed.emit(Phase.DAWN, 1)
	assert_eq(d.last_played, [&"coin", &"pickup", &"build_done", &"card_open", &"card_pick", &"horn", &"diner_hit", &"fail", &"guard_down", &"guard_up", &"throw", &"poof", &"dawn"])

func test_gold_delta_sign() -> void:
	EventBus.gold_changed.emit(10, 10)
	EventBus.gold_changed.emit(8, -2)
	assert_eq(d.last_played, [&"collect", &"build_tick"])

func test_building_changed_plays_nothing() -> void:
	EventBus.building_changed.emit(&"fence_n", 1, 0)
	assert_eq(d.last_played, [])

func test_last_wave_clear_is_silent() -> void:
	GameState.lane_plan = [{}, {}, {}]
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	EventBus.wave_cleared.emit(0)
	EventBus.wave_cleared.emit(2)
	assert_eq(d.last_played.count(&"wave_clear"), 1)

func test_min_gap_drops_repeats() -> void:
	d.play(&"hit")
	d.play(&"hit")
	assert_eq(d.last_played.count(&"hit"), 1)

func test_ring_is_trimmed() -> void:
	for i in AudioDirector.RING + 5:
		d.play(&"click")
		d.debug_clear_gaps()
	assert_eq(d.last_played.size(), AudioDirector.RING)

func test_pitch_cycles_the_table() -> void:
	var pitches := []
	for i in 5:
		d.play(&"pickup")
		pitches.append(d.last_pitch)
		d.debug_clear_gaps()
	var spread: float = AudioManifest.SFX[&"pickup"].pitch_spread
	assert_eq(pitches, [1.0 - spread, 1.0 + 0.5 * spread, 1.0 - 0.5 * spread, 1.0 + spread, 1.0])

func test_oldest_voice_reused() -> void:
	for i in AudioDirector.VOICES + 1:
		d.play(&"click")
		d.debug_clear_gaps()
	assert_eq(d.sfx_players().size(), AudioDirector.VOICES)
	assert_almost_eq(d.sfx_players()[0].pitch_scale, d.last_pitch, 0.0001, "the 11th play reused voice 0")

func test_nothing_before_unlock_then_music() -> void:
	var e := AudioDirector.new()
	add_child_autofree(e)
	e.setup(null, false)
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	EventBus.sfx_requested.emit(&"throw")
	assert_eq(e.last_played, [])
	assert_eq(e.music_id, &"")
	e.set_unlocked()
	assert_eq(e.music_id, &"night")

func test_music_follows_phase() -> void:
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	assert_eq(d.music_id, &"night")
	EventBus.phase_changed.emit(Phase.DAWN, 1)
	assert_eq(d.music_id, &"day")
	EventBus.phase_changed.emit(Phase.DAY, 2)
	assert_eq(d.music_id, &"day")

func test_mute_persists_and_sets_master() -> void:
	var s := SettingsStore.with_dir("user://test_dir_audio")
	s.wipe_for_tests()
	var e := AudioDirector.new()
	add_child_autofree(e)
	e.setup(s)
	e.set_muted(true)
	assert_true(AudioServer.is_bus_mute(0))
	var t := SettingsStore.with_dir("user://test_dir_audio")
	t.load_settings()
	assert_true(t.muted)
	s.wipe_for_tests()

func _assert_night_playing(e: AudioDirector) -> void:
	var playing := e.music_players().filter(func(m): return m.playing)
	assert_eq(playing.size(), 1)
	if playing.size() == 1:
		assert_eq(playing[0].stream, load(AudioManifest.MUSIC[&"night"].path))

func test_mute_before_unlock_review_focus_2() -> void:
	var s := SettingsStore.with_dir("user://test_dir_audio")
	s.muted = true
	s.save_settings()
	var e := AudioDirector.new()
	add_child_autofree(e)
	s.load_settings()
	e.setup(s, false)
	assert_true(AudioServer.is_bus_mute(0))
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	e.set_unlocked()
	assert_eq(e.music_id, &"night")
	_assert_night_playing(e)
	assert_true(AudioServer.is_bus_mute(0))
	e.set_muted(false)
	assert_false(AudioServer.is_bus_mute(0))
	_assert_night_playing(e)
	s.wipe_for_tests()

func test_suspend_across_phase_change_review_focus_3() -> void:
	EventBus.phase_changed.emit(Phase.DAY, 2)
	d.set_suspended(true)
	EventBus.phase_changed.emit(Phase.NIGHT, 2)
	assert_eq(d.music_id, &"night")
	d.set_suspended(false)
	for p in d.all_players():
		assert_false(p.stream_paused)
	var playing := d.music_players().filter(func(m): return m.playing)
	assert_eq(playing.size(), 1)
	assert_eq(playing[0].stream, load(AudioManifest.MUSIC[&"night"].path))
	assert_almost_eq(playing[0].volume_db, float(AudioManifest.MUSIC[&"night"].volume_db), 0.01)

func test_audio_flag_disables() -> void:
	UrlFlags.set_for_tests("?audio=0")
	var e := AudioDirector.new()
	add_child_autofree(e)
	e.setup(null)
	e.set_unlocked()
	e.register_streams()
	assert_true(e._streams.is_empty(), "register_streams is a no-op under ?audio=0")
	EventBus.sfx_requested.emit(&"throw")
	assert_eq(e.last_played, [])
	assert_eq(e.music_id, &"")

func test_suspended_plays_no_sfx() -> void:
	d.set_suspended(true)
	EventBus.sfx_requested.emit(&"throw")
	assert_eq(d.last_played, [])
	d.set_suspended(false)
	EventBus.sfx_requested.emit(&"throw")
	assert_eq(d.last_played, [&"throw"])

func test_focus_pause_changed_suspends() -> void:
	var m := Main.create()
	add_child_autofree(m)
	m.focus_pause.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(m.audio_director.suspended)
	m.focus_pause.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(m.audio_director.suspended)
	get_tree().paused = false

# --- local hooks: they only emit sfx_requested ---

func test_hero_fire_requests_throw() -> void:
	var m := Main.create()
	add_child_autofree(m)
	watch_signals(EventBus)
	m.hero.attacker.fired.emit(null)
	assert_signal_emitted_with_parameters(EventBus, "sfx_requested", [&"throw"])

func test_boar_take_hit_requests_hit() -> void:
	var b := Boar.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(b)
	var dir := RefCounted.new()
	b.spawn("north", 0, 0.0, 1.0, dir)
	watch_signals(EventBus)
	b.take_hit(0.1)
	assert_signal_emitted_with_parameters(EventBus, "sfx_requested", [&"hit"])

func test_freezer_tick_requests_take() -> void:
	var m := Main.create()
	add_child_autofree(m)
	GameState.new_game(5)
	GameState.add_freezer(5)
	watch_signals(EventBus)
	m.world.freezer._on_tick()
	assert_signal_emitted_with_parameters(EventBus, "sfx_requested", [&"take"])

func test_counter_tick_requests_stock() -> void:
	var m := Main.create()
	add_child_autofree(m)
	GameState.new_game(5)
	GameState.carried_steaks = 2
	watch_signals(EventBus)
	m.world.counter._on_tick()
	assert_signal_emitted_with_parameters(EventBus, "sfx_requested", [&"stock"])

func test_empty_ticks_are_silent() -> void:
	var m := Main.create()
	add_child_autofree(m)
	GameState.new_game(5)
	watch_signals(EventBus)
	m.world.freezer._on_tick()
	m.world.counter._on_tick()
	assert_signal_not_emitted(EventBus, "sfx_requested")

func test_music_streams_stay_referenced_and_are_not_reloaded() -> void:
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	var night_stream: AudioStream = d._streams[AudioManifest.MUSIC[&"night"].path]
	EventBus.phase_changed.emit(Phase.DAWN, 1)
	var day_stream: AudioStream = d._streams[AudioManifest.MUSIC[&"day"].path]
	EventBus.phase_changed.emit(Phase.NIGHT, 2)
	assert_true(d._streams.has(AudioManifest.MUSIC[&"day"].path), "the day stream is still referenced")
	assert_same(d._streams[AudioManifest.MUSIC[&"night"].path], night_stream, "night is the same object after switching back")
	EventBus.phase_changed.emit(Phase.DAWN, 2)
	assert_same(d._streams[AudioManifest.MUSIC[&"day"].path], day_stream)
	assert_eq(AudioManifest.MUSIC_MODE, &"lazy")

func test_preload_music_caches_the_stream_and_registers_nothing_off_web() -> void:
	d.preload_music(&"night")
	var path: String = AudioManifest.MUSIC[&"night"].path
	assert_true(d._streams.has(path))
	var s: AudioStream = d._streams[path]
	d.preload_music(&"night")
	assert_same(d._streams[path], s)
	assert_false(AudioServer.is_stream_registered_as_sample(s), "off web nothing is registered")
	d.preload_music(&"nope")  # unknown id: ignored
