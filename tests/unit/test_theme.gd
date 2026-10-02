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

func _sorted(a: PackedStringArray) -> Array:
	var l := Array(a)
	l.sort()
	return l

func _styleboxes() -> Array:
	var out: Array = []
	for t in theme.get_stylebox_type_list():
		for n in theme.get_stylebox_list(t):
			out.append([t, n, theme.get_stylebox(n, t)])
	return out

func test_theme_loads_with_nunito_default_font() -> void:
	assert_not_null(theme)
	var f := theme.default_font as FontVariation
	assert_not_null(f)
	assert_eq(f.resource_path, WorldLabel.BOLD_PATH)
	assert_eq(f.base_font.resource_path, WorldLabel.FONT_PATH)

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

func test_default_font_is_nunito_at_weight_800() -> void:
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	var f := theme.default_font as FontVariation
	assert_eq(int(f.variation_opentype.get(tag, -1)), 800)
	var axes: Dictionary = (f.base_font as FontFile).get_supported_variation_list()
	assert_true(axes.has(tag), "the base font supports wght")
	assert_between(800, axes[tag].x, axes[tag].y)

func test_every_theme_colour_is_a_palette_colour() -> void:
	var pal := _palette_rgb()
	var n := 0
	for t in theme.get_color_type_list():
		for name in theme.get_color_list(t):
			var c := theme.get_color(name, t)
			assert_true(pal.has(Color(c.r, c.g, c.b, 1.0).to_html(false)), "%s/%s" % [t, name])
			n += 1
	assert_gt(n, 10)

func test_committed_theme_matches_the_builder() -> void:
	var built: Theme = load(BUILDER).build()
	assert_eq(_sorted(built.get_stylebox_type_list()), _sorted(theme.get_stylebox_type_list()))
	assert_eq(_sorted(built.get_color_type_list()), _sorted(theme.get_color_type_list()))
	assert_eq(_sorted(built.get_constant_type_list()), _sorted(theme.get_constant_type_list()))
	assert_eq(built.default_font.resource_path, theme.default_font.resource_path)
	for t in built.get_stylebox_type_list():
		assert_eq(_sorted(built.get_stylebox_list(t)), _sorted(theme.get_stylebox_list(t)), t)
		for n in built.get_stylebox_list(t):
			var a := built.get_stylebox(n, t) as StyleBoxFlat
			var b := theme.get_stylebox(n, t) as StyleBoxFlat
			var id := "%s/%s" % [t, n]
			assert_eq(a.bg_color, b.bg_color, id)
			assert_eq(a.border_color, b.border_color, id)
			assert_eq(a.border_width_left, b.border_width_left, id)
			assert_eq(a.get_corner_radius(CORNER_TOP_LEFT), b.get_corner_radius(CORNER_TOP_LEFT), id)
			assert_eq(a.content_margin_left, b.content_margin_left, id)
	for t in built.get_color_type_list():
		for n in built.get_color_list(t):
			assert_eq(built.get_color(n, t), theme.get_color(n, t), "%s/%s" % [t, n])
	for t in built.get_constant_type_list():
		for n in built.get_constant_list(t):
			assert_eq(built.get_constant(n, t), theme.get_constant(n, t), "%s/%s" % [t, n])
	for v in [&"BannerPanel", &"CardPanelAdventurer", &"CardPanelUpgrade", &"HudLabel", &"HudCounter", &"BannerLabel"]:
		assert_eq(built.get_type_variation_base(v), theme.get_type_variation_base(v), str(v))
