class_name CardStrip
extends HBoxContainer
## Owned hero cards under the gold label (S4 Task 15): one 56 px icon per card on a cream backing, with a small level
## badge, in CardCatalog.IDS order. Listener only. `text` keeps the S2 glyph summary ("DM1  TK2", "" when empty) for
## tests and debug; `shown()` reads what is on display (the cells), not GameState.

const ICON_PX := 56.0
const BADGE_PX := 24.0

var text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	EventBus.card_picked.connect(func(_id: StringName, _level: int): refresh())
	EventBus.state_restored.connect(refresh)
	refresh()

## [[id, level], ...] for every cell on display (the cell's name and its badge text), in order.
func shown() -> Array:
	var out := []
	for cell in get_children():
		out.append([StringName(cell.name), int(cell.get_node("Badge/Level").text)])
	return out

func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var parts: Array[String] = []
	for id in CardCatalog.IDS:
		var l := GameState.card_level(id)
		if l > 0:
			parts.append("%s%d" % [CardCatalog.GLYPHS[id], l])
			add_child(_entry(id, l))
	text = "  ".join(parts)

func _entry(id: StringName, level: int) -> Control:
	var cell := Control.new()
	cell.name = String(id)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	var backing := Panel.new()  # the theme's default Panel: diner_cream with an ink border
	backing.name = "Backing"
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cell.add_child(backing)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load(CardCatalog.ICONS[id])
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cell.add_child(icon)
	var badge := Panel.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.color(&"ink")
	sb.set_corner_radius_all(int(BADGE_PX / 2.0))
	badge.add_theme_stylebox_override("panel", sb)
	badge.size = Vector2(BADGE_PX, BADGE_PX)
	badge.position = Vector2(ICON_PX - BADGE_PX + 4.0, ICON_PX - BADGE_PX + 4.0)
	cell.add_child(badge)
	var l := Label.new()
	l.name = "Level"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = str(level)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Palette.color(&"apron_white"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(l)
	return cell
