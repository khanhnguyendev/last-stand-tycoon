extends GutTest

class TickCounter:
	extends Node
	var ticks := 0
	func _physics_process(_d: float) -> void:
		ticks += 1

var fp: FocusPause
var counter: TickCounter

func before_each() -> void:
	fp = FocusPause.new()
	add_child_autofree(fp)
	counter = TickCounter.new()
	add_child_autofree(counter)

func after_each() -> void:
	get_tree().paused = false

func test_focus_out_pauses_and_in_resumes() -> void:
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused)
	var t0 := counter.ticks
	for i in 10:
		await get_tree().process_frame
	assert_eq(counter.ticks, t0)
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(get_tree().paused)
	for i in 5:
		await get_tree().physics_frame
	assert_gt(counter.ticks, t0)

func test_window_focus_out_and_in() -> void:
	fp.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_true(get_tree().paused)
	fp.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert_false(get_tree().paused)

func test_visibility_hidden_and_visible() -> void:
	fp.on_visibility_changed(true)
	assert_true(get_tree().paused)
	fp.on_visibility_changed(false)
	assert_false(get_tree().paused)

func test_focus_out_then_visible_resumes() -> void:
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused)
	fp.on_visibility_changed(false)
	assert_false(get_tree().paused)

func test_foreign_pause_not_cleared_by_focus_in() -> void:
	get_tree().paused = true
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(get_tree().paused)
	fp.on_visibility_changed(false)
	assert_true(get_tree().paused)

func test_process_mode_always() -> void:
	assert_eq(fp.process_mode, Node.PROCESS_MODE_ALWAYS)

func test_focus_out_on_already_paused_tree_keeps_foreign_pause() -> void:
	get_tree().paused = true
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(get_tree().paused)
	get_tree().paused = false
