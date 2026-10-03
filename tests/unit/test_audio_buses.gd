extends GutTest

func test_sfx_and_music_buses_exist() -> void:
	assert_true(AudioServer.get_bus_index("SFX") >= 0, "SFX bus")
	assert_true(AudioServer.get_bus_index("Music") >= 0, "Music bus")

func test_buses_send_to_master() -> void:
	for n in ["SFX", "Music"]:
		var i := AudioServer.get_bus_index(n)
		assert_eq(AudioServer.get_bus_send(i), &"Master", "%s send" % n)
