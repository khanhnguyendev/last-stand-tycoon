extends GutTest
## S4 Task 14: the palette UI theme (tools/build_theme.gd writes it; this test pins its contents).

const THEME_PATH := "res://ui/theme/game_theme.tres"
const BUILDER := "res://tools/build_theme.gd"

var theme: Theme

func before_each() -> void:
	theme = load(THEME_PATH) as Theme

func _palette_rgb() -> Dictionary:
	var d := {}
	for n in Palette.NAMES:
		var c := Palette.color(n)
		d[Color(c.r, c.g, c.b, 1.0).to_html(false)] = true
	return d

func _styleboxes() -> Array:
	var out: Array = []
	for t in theme.get_stylebox_type_list():
		for n in theme.get_stylebox_list(t):
			out.append([t, n, theme.get_stylebox(n, t)])
	return out

func test_theme_loads_with_nunito_default_font() -> void:
	assert_not_null(theme)
	var f := theme.default_font as FontFile
	assert_not_null(f)
	assert_eq(f.resource_path, WorldLabel.FONT_PATH)

func test_every_stylebox_uses_only_palette_colours() -> void:
	var pal := _palette_rgb()
	var seen := 0
	for e in _styleboxes():
		var sb := e[2] as StyleBoxFlat
		assert_not_null(sb, "%s/%s is a StyleBoxFlat" % [e[0], e[1]])
		if sb == null:
			continue
		seen += 1
		var bg := Color(sb.bg_color.r, sb.bg_color.g, sb.bg_color.b, 1.0).to_html(false)
		var bd := Color(sb.border_color.r, sb.border_color.g, sb.border_color.b, 1.0).to_html(false)
		assert_true(pal.has(bg), "%s/%s bg %s is a palette colour" % [e[0], e[1], bg])
		assert_true(pal.has(bd), "%s/%s border %s is a palette colour" % [e[0], e[1], bd])
	assert_gt(seen, 6)

func test_base_styles_exist() -> void:
	for pair in [["Panel", "panel"], ["PanelContainer", "panel"], ["Button", "normal"], ["Button", "pressed"],
			["ProgressBar", "background"], ["ProgressBar", "fill"]]:
		assert_true(theme.has_stylebox(pair[1], pair[0]), "%s/%s" % pair)
	assert_true(theme.has_color("font_color", "Label"))
	assert_eq(theme.get_color("font_color", "Label"), Palette.color(&"ink"))

func test_progress_bar_colours() -> void:
	assert_eq((theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat).bg_color, Palette.color(&"guard_green"))
	assert_eq((theme.get_stylebox("background", "ProgressBar") as StyleBoxFlat).bg_color, Palette.color(&"ink"))

func test_card_panel_variations_have_a_left_band() -> void:
	for pair in [[&"CardPanelAdventurer", &"gold"], [&"CardPanelUpgrade", &"diner_teal"]]:
		assert_true(theme.get_type_variation_base(pair[0]) == &"Panel", "%s extends Panel" % pair[0])
		var sb := theme.get_stylebox("panel", pair[0]) as StyleBoxFlat
		assert_not_null(sb)
		assert_gt(sb.border_width_left, 0)
		assert_eq(sb.border_color, Palette.color(pair[1]))
		assert_eq(sb.bg_color.r, Palette.color(&"diner_cream").r)

func test_banner_and_label_variations() -> void:
	assert_eq(theme.get_type_variation_base(&"BannerPanel"), &"PanelContainer")
	var sb := theme.get_stylebox("panel", &"BannerPanel") as StyleBoxFlat
	assert_eq(Color(sb.bg_color, 1.0), Palette.color(&"night_sky"))
	for v in [&"HudLabel", &"HudCounter", &"BannerLabel"]:
		assert_eq(theme.get_type_variation_base(v), &"Label", str(v))
	assert_eq(theme.get_color("font_outline_color", &"HudCounter"), Palette.color(&"ink"))
	assert_eq(theme.get_constant("outline_size", &"HudCounter"), 8)
	assert_eq(theme.get_color("font_outline_color", &"HudLabel"), Palette.color(&"apron_white"))
	assert_eq(theme.get_constant("outline_size", &"HudLabel"), 6)

func test_project_applies_the_theme_and_keeps_the_font() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH)
	assert_eq(ProjectSettings.get_setting("gui/theme/custom_font", ""), WorldLabel.FONT_PATH)
