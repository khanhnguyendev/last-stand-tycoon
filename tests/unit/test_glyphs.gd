extends GutTest
## D-079: the font must cover Vietnamese diacritics.

const SAMPLE := "Quán ăn mở cửa — Đêm thứ 3 » 4"

func test_nunito_has_all_glyphs() -> void:
	var font: FontFile = load(WorldLabel.FONT_PATH)
	assert_not_null(font)
	var missing := ""
	for i in SAMPLE.length():
		var cp := SAMPLE.unicode_at(i)
		if cp != 32 and not font.has_char(cp):
			missing += SAMPLE[i]
	assert_eq(missing, "", "missing glyphs")

func test_world_label_uses_nunito() -> void:
	var l := WorldLabel.make("x")
	assert_eq(l.font.resource_path, WorldLabel.BOLD_PATH)
	assert_eq((l.font as FontVariation).base_font.resource_path, WorldLabel.FONT_PATH)
	assert_eq(l.outline_size, 8)
	l.free()

func test_theme_font_wired() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom_font", ""), WorldLabel.FONT_PATH)
