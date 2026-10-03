class_name BootFade
extends CanvasLayer
## S5 (D-215): a night-sky cover over the first frames (layer 90) while the warm-up draws every first-use visual;
## fade_out() dissolves it once the saved run is resumed. Visual only.

var _rect: ColorRect

func _init() -> void:
	name = "BootFade"
	layer = 90

func _ready() -> void:
	_rect = ColorRect.new()
	_rect.color = Palette.color(&"night_sky")
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func fade_out() -> void:
	var t := create_tween()
	t.tween_property(_rect, "color:a", 0.0, Balance.ui.boot_fade_out_s)
	t.tween_callback(queue_free)
