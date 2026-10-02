extends SceneTree
## Writes ui/theme/game_theme.tres from the palette (S4 Task 14, D-195). The only theme builder: run it, commit the .tres.
## "$GODOT" --headless --path . -s res://tools/build_theme.gd
## Deterministic: the same palette and tuning give a byte-identical file. Only palette colours are used (test_theme).
## The banner alpha is read from balance/ui_tuning.tres (banner_panel_alpha), so every number stays in balance/.

const OUT := "res://ui/theme/game_theme.tres"
const FONT := "res://ui/fonts/Nunito.ttf"

var _pal: GDScript

func _c(n: StringName, a: float = 1.0) -> Color:
	var c: Color = _pal.color(n)
	return Color(c.r, c.g, c.b, a)

func _box(bg: Color, border: Color, border_w: int, radius: int, margin: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

func _card(band: Color) -> StyleBoxFlat:
	var s := _box(_c(&"diner_cream", 0.95), band, 0, 20)
	s.border_width_left = 16
	return s

func _variation(t: Theme, name: StringName, base: StringName) -> void:
	t.set_type_variation(name, base)

func _label_look(t: Theme, type: StringName, font: Color, outline: Color, outline_size: int) -> void:
	t.set_color("font_color", type, font)
	t.set_color("font_outline_color", type, outline)
	t.set_constant("outline_size", type, outline_size)

func build() -> Theme:
	_pal = load("res://art/palette/palette.gd")
	var ui = load("res://balance/ui_tuning.tres")
	var t := Theme.new()
	t.default_font = load(FONT)
	var panel := _box(_c(&"diner_cream", 0.95), _c(&"ink"), 4, 20)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel.duplicate())
	# Banner: night sky backing, light text (BannerLabel).
	_variation(t, &"BannerPanel", &"PanelContainer")
	t.set_stylebox("panel", &"BannerPanel", _box(_c(&"night_sky", ui.banner_panel_alpha), _c(&"night_sky", 0.0), 0, 24, 20))
	# Card overlay panels: cream with a 16 px left band (adventurer gold, upgrade teal).
	_variation(t, &"CardPanelAdventurer", &"Panel")
	t.set_stylebox("panel", &"CardPanelAdventurer", _card(_c(&"gold")))
	_variation(t, &"CardPanelUpgrade", &"Panel")
	t.set_stylebox("panel", &"CardPanelUpgrade", _card(_c(&"diner_teal")))
	# ProgressBar: ink track, guard-green fill.
	t.set_stylebox("background", "ProgressBar", _box(_c(&"ink"), _c(&"ink"), 2, 8))
	t.set_stylebox("fill", "ProgressBar", _box(_c(&"guard_green"), _c(&"ink"), 2, 8))
	# Button: cream, ink outline; gold when pressed.
	t.set_stylebox("normal", "Button", _box(_c(&"diner_cream"), _c(&"ink"), 4, 16, 12))
	t.set_stylebox("hover", "Button", _box(_c(&"warm_white"), _c(&"ink"), 4, 16, 12))
	t.set_stylebox("pressed", "Button", _box(_c(&"gold"), _c(&"ink"), 4, 16, 12))
	t.set_stylebox("disabled", "Button", _box(_c(&"traveler_beige"), _c(&"ink_soft"), 4, 16, 12))
	t.set_stylebox("focus", "Button", _box(_c(&"diner_cream", 0.0), _c(&"gold"), 4, 16))
	t.set_color("font_color", "Button", _c(&"ink"))
	t.set_color("font_pressed_color", "Button", _c(&"ink"))
	t.set_color("font_hover_color", "Button", _c(&"ink"))
	t.set_color("font_disabled_color", "Button", _c(&"ink_soft"))
	# Labels: ink text by default (on cream panels).
	t.set_color("font_color", "Label", _c(&"ink"))
	# HudLabel: ink text with a light outline, readable over any world colour (card strip, build id).
	_variation(t, &"HudLabel", &"Label")
	_label_look(t, &"HudLabel", _c(&"ink"), _c(&"apron_white"), 6)
	# HudCounter: gold and day counters, light text with a heavy ink outline.
	_variation(t, &"HudCounter", &"Label")
	_label_look(t, &"HudCounter", _c(&"apron_white"), _c(&"ink"), 8)
	# BannerLabel: light text on the night-sky banner.
	_variation(t, &"BannerLabel", &"Label")
	_label_look(t, &"BannerLabel", _c(&"apron_white"), _c(&"ink"), 8)
	return t

func _init() -> void:
	var t := build()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	var err := ResourceSaver.save(t, OUT)
	if err != OK:
		push_error("theme save failed: %s" % error_string(err))
		quit(1)
		return
	print("saved ", OUT)
	quit(0)
