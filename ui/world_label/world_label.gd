class_name WorldLabel
extends Label3D
## Billboard 3D label using Nunito (D-073, D-079). Label3D does not read the Theme.

const FONT_PATH := "res://ui/fonts/Nunito.ttf"

static func make(text_value: String, size: int = 48) -> WorldLabel:
	var l := WorldLabel.new()
	l.text = text_value
	l.font_size = size
	return l

func _init() -> void:
	font = load(FONT_PATH)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.01
	outline_size = 12
	no_depth_test = true
	modulate = Color.WHITE
