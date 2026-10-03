class_name SafeArea
extends RefCounted
## Safe-area insets in viewport pixels (D-077). Source per spike D-119: DisplayServer, CSS env() on web.

const CSS_JS := "(function(){var d=document.createElement('div');d.style.cssText='position:fixed;top:0;left:0;visibility:hidden;padding-top:env(safe-area-inset-top);padding-right:env(safe-area-inset-right);padding-bottom:env(safe-area-inset-bottom);padding-left:env(safe-area-inset-left)';document.body.appendChild(d);var s=getComputedStyle(d);var r=[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(parseFloat).concat([window.innerWidth,window.innerHeight]).join(',');d.remove();return r;})()"

## Tests and captures set the insets through this and nothing else (S5 Task 9); reset it to {} afterwards.
static var override_for_tests: Dictionary = {}

static func insets(viewport_size: Vector2) -> Dictionary:
	if not override_for_tests.is_empty():
		return override_for_tests.duplicate()
	var out := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if OS.has_feature("web"):
		var raw := str(JavaScriptBridge.eval(CSS_JS, true)).split(",")
		if raw.size() == 6 and float(raw[5]) > 0.0:
			var sx := viewport_size.x / float(raw[4])
			var sy := viewport_size.y / float(raw[5])
			out = {"top": float(raw[0]) * sy, "right": float(raw[1]) * sx, "bottom": float(raw[2]) * sy, "left": float(raw[3]) * sx}
		return _clamped(out)
	if not OS.has_feature("mobile"):
		return out
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0:
		return out
	var sx2 := viewport_size.x / win.x
	var sy2 := viewport_size.y / win.y
	var wpos := Vector2(DisplayServer.window_get_position())
	out.top = (safe.position.y - wpos.y) * sy2
	out.left = (safe.position.x - wpos.x) * sx2
	out.bottom = (wpos.y + win.y - safe.end.y) * sy2
	out.right = (wpos.x + win.x - safe.end.x) * sx2
	return _clamped(out)

static func _clamped(d: Dictionary) -> Dictionary:
	for k in d:
		d[k] = maxf(float(d[k]), 0.0)
	return d
