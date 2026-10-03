extends GutTest
## S5 Task 8a (D-218): Main owns the tree pause through a set of reasons; FocusPause only signals.

var main: Main

func before_each() -> void:
	main = Main.create()
	add_child_autofree(main)

func after_each() -> void:
	get_tree().paused = false

func _focus(out: bool) -> void:
	main.focus_pause.set_paused(out)

func test_focus_out_pauses_and_in_resumes() -> void:
	_focus(true)
	assert_true(get_tree().paused)
	_focus(false)
	assert_false(get_tree().paused)

func test_settings_held_across_focus_in() -> void:
	_focus(true)
	main.add_pause_reason(&"settings")
	assert_true(get_tree().paused)
	_focus(false)
	assert_true(get_tree().paused, "settings still holds the pause")
	main.remove_pause_reason(&"settings")
	assert_false(get_tree().paused)

func test_settings_held_across_focus_out() -> void:
	main.add_pause_reason(&"settings")
	assert_true(get_tree().paused)
	_focus(true)
	assert_true(get_tree().paused)
	main.remove_pause_reason(&"settings")
	assert_true(get_tree().paused, "focus still holds the pause")
	_focus(false)
	assert_false(get_tree().paused)

func test_freeing_focus_pause_clears_the_focus_reason() -> void:
	_focus(true)
	assert_true(get_tree().paused)
	main.focus_pause.free()
	assert_false(get_tree().paused)
	assert_false(main.pause_reasons.has(&"focus"))

func test_direct_pause_is_not_overwritten() -> void:
	get_tree().paused = true
	assert_true(main.pause_reasons.is_empty())
	main.remove_pause_reason(&"settings")
	assert_true(get_tree().paused)
	_focus(false)
	assert_true(get_tree().paused)

func test_focus_out_with_settings_held_still_suspends_audio() -> void:
	main.add_pause_reason(&"settings")
	_focus(true)
	assert_true(main.audio_director.suspended)
	_focus(false)
	assert_false(main.audio_director.suspended)
	main.remove_pause_reason(&"settings")

func test_freeing_main_while_a_reason_is_held_unpauses() -> void:
	main.add_pause_reason(&"settings")
	assert_true(get_tree().paused)
	remove_child(main)
	main.free()
	assert_false(get_tree().paused)
