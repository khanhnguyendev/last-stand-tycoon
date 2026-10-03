class_name SettingsStore
extends RefCounted
## Device preferences, separate from the save (S5 D-210): {v, muted, guide_done}. Web: localStorage key
## lst:<pathname>:settings, through SaveStore's try/catch JS. Elsewhere: <dir>/settings.json. Missing or corrupt
## means defaults; SaveStore.wipe() and New game never touch it.

const KEY := "settings"
const VERSION := 1

var muted := false
var guide_done := false
var _web := false
var _key := ""
var _dir := ""

static func for_platform() -> SettingsStore:
	var s := SettingsStore.new()
	if OS.has_feature("web"):
		s._web = true
		s._key = SaveStore.key_prefix_for(SaveStore.normalize_path(str(JavaScriptBridge.eval("window.location.pathname", true)))) + KEY
	else:
		s._dir = "user://save"
	return s

static func with_dir(dir: String) -> SettingsStore:
	var s := SettingsStore.new()
	s._dir = dir
	return s

func load_settings() -> void:
	muted = false
	guide_done = false
	var j := JSON.new()
	if j.parse(_read()) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = j.data
	if typeof(d.get("muted")) == TYPE_BOOL:
		muted = d.muted
	if typeof(d.get("guide_done")) == TYPE_BOOL:
		guide_done = d.guide_done

func save_settings() -> bool:
	return _write(JSON.stringify({"v": VERSION, "muted": muted, "guide_done": guide_done}))

## Tests only: remove the stored value.
func wipe_for_tests() -> void:
	if _web:
		JavaScriptBridge.eval(SaveStore.js_call("remove", _key), true)
	elif FileAccess.file_exists(_dir.path_join(KEY + ".json")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir.path_join(KEY + ".json")))

func _read() -> String:
	if _web:
		var j := JSON.new()
		if j.parse(str(JavaScriptBridge.eval(SaveStore.js_call("get", _key), true))) != OK or typeof(j.data) != TYPE_DICTIONARY:
			return ""
		return String(j.data.value) if int(j.data.ok) == 1 else ""
	var p := _dir.path_join(KEY + ".json")
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""

func _write(text: String) -> bool:
	if _web:
		var raw = JavaScriptBridge.eval(SaveStore.js_call("set", _key, text), true)
		return typeof(raw) in [TYPE_INT, TYPE_FLOAT] and int(raw) == 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var f := FileAccess.open(_dir.path_join(KEY + ".json"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true
