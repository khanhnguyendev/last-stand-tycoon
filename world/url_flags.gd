class_name UrlFlags
extends RefCounted
## Query-string flags for debug and profile web builds (S5): audio=0, warmup=0, perfwarm=<seconds> (perf overlay warm-up length), mute=1, guide=0|1, autoplay=1 (the hero plays itself, recordings), nooverlay=1 (hide the debug readout and button, recordings). Release ignores them.

static var _cache: Dictionary = {}
static var _loaded := false

static func get_flag(name: String) -> String:
	if not _loaded:
		_loaded = true
		if OS.has_feature("web") and (OS.is_debug_build() or OS.has_feature("profile_overlay")):
			_cache = parse(str(JavaScriptBridge.eval("window.location.search", true)))
	return String(_cache.get(name, ""))

static func parse(query: String) -> Dictionary:
	var out := {}
	for part in query.trim_prefix("?").split("&", false):
		var kv := part.split("=", true, 1)
		out[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else "1"
	return out

static func set_for_tests(query: String) -> void:
	_cache = parse(query)
	_loaded = true
