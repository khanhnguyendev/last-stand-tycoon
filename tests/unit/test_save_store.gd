extends GutTest

var dir := ""

func before_each() -> void:
	Balance.reset()
	GameState.new_game(5)
	dir = "user://test_saves/%d" % Time.get_ticks_usec()

func after_each() -> void:
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))  # only succeeds when empty

func _text(gold: int) -> String:
	GameState.gold = gold  # test-only setup write
	var s := GameState.to_dict()
	s.resume_phase = "DAY"
	return SaveCodec.encode(s, "t", 1)

func test_write_then_read() -> void:
	var st := SaveStore.with_dir(dir)
	assert_true(st.write(_text(7)))
	var r := SaveStore.with_dir(dir).read()
	assert_eq([r.ok, r.source, int(r.state.gold)], [true, "primary", 7])

func test_backup_rotation_and_corrupt_primary() -> void:
	var st := SaveStore.with_dir(dir)
	st.write(_text(1))
	st.write(_text(2))  # backup now holds gold 1
	var f := FileAccess.open(dir.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var st2 := SaveStore.with_dir(dir)
	var r := st2.read()
	assert_eq([r.ok, r.source, int(r.state.gold)], [true, "backup", 1])
	assert_true(FileAccess.file_exists(dir.path_join("save_corrupt.json")), "the corrupt primary is kept aside")

func test_both_corrupt_is_none() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for n in ["save.json", "save_bak.json"]:
		var f := FileAccess.open(dir.path_join(n), FileAccess.WRITE)
		f.store_string("nope")
		f.close()
	var r := SaveStore.with_dir(dir).read()
	assert_eq([r.ok, r.source], [false, "none"])

func test_newer_save_is_never_overwritten() -> void:
	var s := GameState.to_dict()
	s.resume_phase = "DAY"
	s.v = GameState.SCHEMA_VERSION + 1
	var newer := SaveCodec.encode(s, "future", 1)
	SaveStore.with_dir(dir).write(newer)
	var st := SaveStore.with_dir(dir)
	var r := st.read()
	assert_eq([r.ok, r.newer, st.writable], [false, true, false])
	assert_false(st.write(_text(3)))
	assert_eq(FileAccess.get_file_as_string(dir.path_join("save.json")), newer, "untouched")

func test_wipe_clears_everything_and_resets() -> void:
	var st := SaveStore.with_dir(dir)
	st.write(_text(1))
	st.write(_text(2))
	st.wipe()
	assert_false(st.read().ok)
	st.write(_text(4))
	assert_false(FileAccess.file_exists(dir.path_join("save_bak.json")), "a wiped run never reaches the backup")

func test_keys_are_prefixed_by_path() -> void:
	assert_eq(SaveStore.normalize_path("/last-stand-tycoon/preview/x/debug/index.html"), "/last-stand-tycoon/preview/x/debug/")
	assert_eq(SaveStore.normalize_path("/last-stand-tycoon/"), "/last-stand-tycoon/")
	var a := SaveStore.key_prefix_for("/a/")
	var b := SaveStore.key_prefix_for("/a/debug/")
	assert_ne(a, b)
	assert_eq(a, "lst:/a/:")

func test_js_call_escapes_keys_and_values() -> void:
	var js := SaveStore.js_call("set", "lst:/a/:save", "line1\n\"q\" \\ đêm")
	assert_false(js.contains("\n"), "no raw newline in the JS source")
	assert_true(js.contains(JSON.stringify("lst:/a/:save")))
	assert_true(js.contains(JSON.stringify("line1\n\"q\" \\ đêm")))
	assert_true(js.begins_with("(function(){try{"))
	assert_true(SaveStore.js_call("get", "k").contains("localStorage.getItem("))
	assert_true(SaveStore.js_call("remove", "k").contains("localStorage.removeItem("))
