class_name BuildLabel
extends CanvasLayer
## Bottom-left build id inside the safe area (D-135). The pages workflow sets window.LST_BUILD = "<short hash> <branch>".

var _label: Label

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.text = build_id()
	_label.add_theme_font_size_override("font_size", 14)
	_label.modulate.a = 0.5
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	get_viewport().size_changed.connect(_place)
	_place()

func _place() -> void:
	var ins := SafeArea.insets(get_viewport().get_visible_rect().size)
	_label.offset_left = 8.0 + ins.left
	_label.offset_bottom = -(8.0 + ins.bottom)

static func build_id() -> String:
	if OS.has_feature("web"):
		var v := str(JavaScriptBridge.eval("window.LST_BUILD||''", true))
		return v if v != "" else "dev"
	return "dev"
