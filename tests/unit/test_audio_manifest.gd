extends GutTest

func test_every_entry_meets_its_class_target() -> void:
	for id in AudioManifest.SFX:
		var e: Dictionary = AudioManifest.SFX[id]
		var target: float = AudioManifest.CLASS_TARGET_DB[e["class"]]
		assert_almost_eq(e.mean_db + e.volume_db, target, 3.0, "%s loudness" % id)
		assert_true(e.peak_db + e.volume_db <= -1.0, "%s clips" % id)
		var cap := 0.6 if e["class"] == &"repeated" else 1.5
		assert_true(e.duration_s < cap, "%s too long" % id)
	for id in AudioManifest.MUSIC:
		var m: Dictionary = AudioManifest.MUSIC[id]
		assert_almost_eq(m.mean_db + m.volume_db, AudioManifest.CLASS_TARGET_DB[&"music"], 3.0, "%s loudness" % id)

func test_every_id_the_spec_names_exists() -> void:
	for id in [&"throw", &"hit", &"poof", &"pickup", &"take", &"stock", &"coin", &"collect", &"build_tick", &"build_done",
			&"card_open", &"card_pick", &"horn", &"wave_clear", &"diner_hit", &"fail", &"dawn", &"guard_down", &"guard_up", &"click"]:
		assert_true(AudioManifest.SFX.has(id), String(id))
	assert_true(AudioManifest.MUSIC.has(&"day") and AudioManifest.MUSIC.has(&"night"))

func test_music_loops() -> void:
	for id in AudioManifest.MUSIC:
		var s: AudioStreamMP3 = load(AudioManifest.MUSIC[id].path)
		assert_true(s.loop, "%s loops" % id)
