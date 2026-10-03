class_name FocusPause
extends Node
## Focus loss / hidden tab detector (D-046). Signal-only since S5 (D-218): Main turns `changed` into the `focus` pause
## reason; FocusPause never writes get_tree().paused.
## Resume rule: the latest focus-in or visible event resumes (iOS may never send focus-in).

var _js_cb: JavaScriptObject
## FocusPause's own focus state (S5 Task 3b): true from focus-out/hidden to focus-in/visible.
var focus_paused := false

signal changed(paused: bool)

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
	if p != focus_paused:
		focus_paused = p
		changed.emit(p)

func on_visibility_changed(hidden: bool) -> void:
	set_paused(hidden)

func _on_visibility(_args: Array) -> void:
	on_visibility_changed(bool(JavaScriptBridge.eval("document.hidden", true)))
