class_name CardStrip
extends Label
## Owned hero cards under the gold label (S2 spec 5.5): "DM1  TK2" in CardCatalog.IDS order. Listener only.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 28)
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_outline_color", Color.BLACK)
	EventBus.card_picked.connect(func(_id: StringName, _level: int): refresh())
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	var parts: Array[String] = []
	for id in CardCatalog.IDS:
		var l := GameState.card_level(id)
		if l > 0:
			parts.append("%s%d" % [CardCatalog.GLYPHS[id], l])
	text = "  ".join(parts)
