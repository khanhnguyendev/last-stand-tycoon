class_name WorldLabel
extends Label3D
## Billboard 3D label using Nunito (D-073, D-079). Label3D does not read the Theme.

const FONT_PATH := "res://ui/fonts/Nunito.ttf"
## Nunito at weight 800 (wght axis 2003265652, range 200..1000): the thin default drowned in outlines (Task 14 follow-up).
const BOLD_PATH := "res://ui/fonts/nunito_bold.tres"

static func make(text_value: String, size: int = 48) -> WorldLabel:
	var l := WorldLabel.new()
	l.text = text_value
	l.font_size = size
	return l

func _init() -> void:
	font = load(BOLD_PATH)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.01
	outline_size = 8
	outline_modulate = Palette.color(&"ink")
	no_depth_test = true
	modulate = Palette.color(&"apron_white")
