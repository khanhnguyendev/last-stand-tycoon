class_name SaveStore
extends RefCounted
## One local save plus a backup (S3 spec 5.1, D-171, D-172). Web: localStorage under a per-path key prefix,
## every call wrapped in a JS try/catch (JavaScriptBridge.eval swallows exceptions). Elsewhere: files.

const NAMES := ["save", "save_bak", "save_corrupt"]

var writable := true
var key_prefix := ""
var _dir := ""
var _web := false
var _last_good_text := ""
var _warned := false

static func for_platform() -> SaveStore:
	var s := SaveStore.new()
	if OS.has_feature("web"):
		s._web = true
		s.key_prefix = key_prefix_for(normalize_path(str(JavaScriptBridge.eval("window.location.pathname", true))))
	else:
		s._dir = "user://save"
	return s

static func with_dir(dir: String) -> SaveStore:
	var s := SaveStore.new()
	s._dir = dir
	return s

static func normalize_path(p: String) -> String:
	return p.trim_suffix("index.html")

static func key_prefix_for(path: String) -> String:
	return "lst:%s:" % path

## JS source for one localStorage call; key and value go through JSON.stringify (escaping).
static func js_call(op: String, key: String, value := "") -> String:
	var k := JSON.stringify(key)
	match op:
		"get":
			return "(function(){try{var v=localStorage.getItem(%s);return JSON.stringify({ok:1,value:(v===null?'':v)})}catch(e){return JSON.stringify({ok:0,value:''})}})()" % k
		"set":
			return "(function(){try{localStorage.setItem(%s,%s);return 1}catch(e){return 0}})()" % [k, JSON.stringify(value)]
	return "(function(){try{localStorage.removeItem(%s);return 1}catch(e){return 0}})()" % k

func read() -> Dictionary:
	for name in ["save", "save_bak"]:
		var text := _read_key(name)
		if text == "":
			continue
		var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
		if r.ok:
			_last_good_text = text
			return {"ok": true, "state": r.state, "source": "primary" if name == "save" else "backup", "newer": false}
		if r.newer:
			writable = false
			_warn("a newer build's save was found; autosave is off for this session")
			return {"ok": false, "state": {}, "source": "primary" if name == "save" else "backup", "newer": true}
		if name == "save":
			_write_key("save_corrupt", text)
	return {"ok": false, "state": {}, "source": "none", "newer": false}

func write(text: String) -> bool:
	if not writable:
		return false
	if _last_good_text != "":
		if not _write_key("save_bak", _last_good_text):
			_warn("backup write failed")
	var ok := _write_key("save", text)
	if ok:
		_last_good_text = text
	else:
		_warn("save write failed (storage unavailable or full)")
	return ok

func wipe() -> void:
	for name in NAMES:
		_remove_key(name)
	_last_good_text = ""
	writable = true

func _warn(msg: String) -> void:
	if not _warned:
		_warned = true
		push_warning("SaveStore: " + msg)

## Named _read_key/_write_key/_remove_key: _get/_set would override Object's property virtuals.
func _read_key(name: String) -> String:
	if _web:
		var raw = JavaScriptBridge.eval(js_call("get", key_prefix + name), true)
		var j := JSON.new()
		var res = j.data if j.parse(str(raw)) == OK else null
		return String(res.value) if typeof(res) == TYPE_DICTIONARY and int(res.ok) == 1 else ""
	var path := _dir.path_join(name + ".json")
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _write_key(name: String, text: String) -> bool:
	if _web:
		var raw = JavaScriptBridge.eval(js_call("set", key_prefix + name, text), true)
		return typeof(raw) in [TYPE_INT, TYPE_FLOAT] and int(raw) == 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var tmp := _dir.path_join(name + ".json.tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	var final := _dir.path_join(name + ".json")
	# rename_absolute replaces an existing file (macOS/Linux; desktop is tests only): never a moment without a primary.
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(final)) == OK

func _remove_key(name: String) -> void:
	if _web:
		JavaScriptBridge.eval(js_call("remove", key_prefix + name), true)
		return
	var path := _dir.path_join(name + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
