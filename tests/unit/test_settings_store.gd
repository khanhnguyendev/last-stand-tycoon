extends GutTest

const DIR := "user://test_settings"

func before_each() -> void:
	var s := SettingsStore.with_dir(DIR)
	s.wipe_for_tests()

func after_each() -> void:
	SettingsStore.with_dir(DIR).wipe_for_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))

func test_defaults_when_missing() -> void:
	var s := SettingsStore.with_dir(DIR)
	s.load_settings()
	assert_false(s.muted)
	assert_false(s.guide_done)

func test_round_trip() -> void:
	var s := SettingsStore.with_dir(DIR)
	s.muted = true
	s.guide_done = true
	assert_true(s.save_settings())
	var t := SettingsStore.with_dir(DIR)
	t.load_settings()
	assert_true(t.muted)
	assert_true(t.guide_done)

func test_corrupt_value_gives_defaults() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(DIR.path_join("settings.json"), FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s := SettingsStore.with_dir(DIR)
	s.load_settings()
	assert_false(s.muted)
	assert_false(s.guide_done)

func test_wrong_types_give_defaults_per_field() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(DIR.path_join("settings.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "muted": "yes", "guide_done": true}))
	f.close()
	var s := SettingsStore.with_dir(DIR)
	s.load_settings()
	assert_false(s.muted)
	assert_true(s.guide_done)

func test_save_wipe_leaves_settings() -> void:
	var s := SettingsStore.with_dir(DIR)
	s.muted = true
	s.save_settings()
	SaveStore.with_dir(DIR).wipe()
	var t := SettingsStore.with_dir(DIR)
	t.load_settings()
	assert_true(t.muted)

func test_web_key_is_separate_from_save_keys() -> void:
	assert_false(SettingsStore.KEY in SaveStore.NAMES)
