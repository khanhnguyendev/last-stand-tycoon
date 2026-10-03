extends GutTest

var fp: FocusPause

func before_each() -> void:
	fp = FocusPause.new()
	add_child_autofree(fp)

func after_each() -> void:
	get_tree().paused = false

func test_focus_out_and_in_emit_changed_only() -> void:
	watch_signals(fp)
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(fp.focus_paused)
	assert_false(get_tree().paused, "FocusPause never writes get_tree().paused")
	assert_signal_emitted_with_parameters(fp, "changed", [true])
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(fp.focus_paused)
	assert_signal_emitted_with_parameters(fp, "changed", [false])

func test_window_focus_out_and_in() -> void:
	watch_signals(fp)
	fp.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_true(fp.focus_paused)
	fp.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert_false(fp.focus_paused)
	assert_signal_emit_count(fp, "changed", 2)
	assert_false(get_tree().paused)

func test_visibility_hidden_and_visible() -> void:
	watch_signals(fp)
	fp.on_visibility_changed(true)
	assert_true(fp.focus_paused)
	assert_signal_emitted_with_parameters(fp, "changed", [true])
	assert_false(get_tree().paused)
	fp.on_visibility_changed(false)
	assert_false(fp.focus_paused)
	assert_signal_emitted_with_parameters(fp, "changed", [false])

func test_two_focus_outs_emit_changed_once() -> void:
	watch_signals(fp)
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	fp.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_signal_emit_count(fp, "changed", 1)

func test_never_touches_a_foreign_pause() -> void:
	get_tree().paused = true
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(get_tree().paused)

func test_process_mode_always() -> void:
	assert_eq(fp.process_mode, Node.PROCESS_MODE_ALWAYS)

func test_main_wires_focus_pause_first() -> void:
	var m := Main.create()
	add_child_autofree(m)
	assert_not_null(m.focus_pause)
	assert_eq(m.focus_pause.get_parent(), m)
	assert_eq(m.focus_pause.process_mode, Node.PROCESS_MODE_ALWAYS)
	var kids := m.get_children()
	assert_lt(kids.find(m.focus_pause), kids.find(m.hero))

func test_changed_signal_follows_focus() -> void:
	watch_signals(fp)
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_signal_emitted_with_parameters(fp, "changed", [true])
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_signal_emitted_with_parameters(fp, "changed", [false])
	assert_signal_emit_count(fp, "changed", 2)

func test_changed_not_repeated_for_same_state() -> void:
	watch_signals(fp)
	fp.on_visibility_changed(true)
	fp.on_visibility_changed(true)
	assert_signal_emit_count(fp, "changed", 1)
	fp.on_visibility_changed(false)
