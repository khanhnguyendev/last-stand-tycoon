class_name FocusPause
extends Node
## Pause on focus loss / hidden tab so switching away never costs the diner (D-046).
## Resume rule: the latest focus-in or visible event resumes (iOS may never send focus-in).
## Only undoes a pause FocusPause itself set.

var _js_cb: JavaScriptObject
var _paused_by_focus := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(_on_visibility)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _js_cb)

func _exit_tree() -> void:
	if OS.has_feature("web") and _js_cb != null:
		JavaScriptBridge.get_interface("document").removeEventListener("visibilitychange", _js_cb)
		_js_cb = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		set_paused(false)

func set_paused(p: bool) -> void:
	if p:
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_focus = true
	elif _paused_by_focus:
		get_tree().paused = false
		_paused_by_focus = false

func on_visibility_changed(hidden: bool) -> void:
	set_paused(hidden)

func _on_visibility(_args: Array) -> void:
	on_visibility_changed(bool(JavaScriptBridge.eval("document.hidden", true)))
