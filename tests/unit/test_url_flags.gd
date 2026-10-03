extends GutTest

func after_each() -> void:
	UrlFlags.set_for_tests("")

func test_parse_flags() -> void:
	assert_eq(UrlFlags.parse("?audio=0&guide"), {"audio": "0", "guide": "1"})

func test_parse_empty() -> void:
	assert_eq(UrlFlags.parse(""), {})
	assert_eq(UrlFlags.parse("?"), {})

func test_parse_decodes() -> void:
	assert_eq(UrlFlags.parse("?a=b%20c&d=e=f"), {"a": "b c", "d": "e=f"})

func test_get_flag_after_set_for_tests() -> void:
	UrlFlags.set_for_tests("?mute=1&warmup=0")
	assert_eq(UrlFlags.get_flag("mute"), "1")
	assert_eq(UrlFlags.get_flag("warmup"), "0")
	assert_eq(UrlFlags.get_flag("audio"), "")

func test_reset_clears_flags() -> void:
	UrlFlags.set_for_tests("?mute=1")
	UrlFlags.set_for_tests("")
	assert_eq(UrlFlags.get_flag("mute"), "")
