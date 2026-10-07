class_name BranchHintStore
extends RefCounted
## One device flag: has the onboarding pointer at a branch pad been shown (E5 tier 3 Task 17, D-273.5)? Same storage as
## SettingsStore (web: localStorage through SaveStore's try/catch JS, key lst:<pathname>:branch_hint; elsewhere
## <dir>/branch_hint.json) but its own key, so it never rewrites the settings file. Missing or corrupt means not shown yet.
## SaveStore.wipe() and New game never touch it.

const KEY := "branch_hint"

var done := false
var _web := false
var _key := ""
var _dir := ""

static func for_platform() -> BranchHintStore:
	var s := BranchHintStore.new()
	if OS.has_feature("web"):
		s._web = true
		s._key = SaveStore.key_prefix_for(SaveStore.normalize_path(str(JavaScriptBridge.eval("window.location.pathname", true)))) + KEY
	else:
		s._dir = "user://save"
	return s

static func with_dir(dir: String) -> BranchHintStore:
	var s := BranchHintStore.new()
	s._dir = dir
	return s

func load_store() -> void:
	done = false
	var j := JSON.new()
	if j.parse(_read()) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return
	if typeof(j.data.get("done")) == TYPE_BOOL:
		done = j.data.done

func save_store() -> bool:
	return _write(JSON.stringify({"v": 1, "done": done}))

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
