class_name CardStrip
extends Control
## Owned hero cards under the gold label (S4 Task 15, 16b): one 56 px icon per card on a cream backing, with a small level
## badge, in CardCatalog.IDS order. Listener only. One Control with a custom _draw (D-201): all backings, then all icons,
## then all badge discs (all three cells of one atlas texture, so they batch; draw_style_box and draw_circle are polygons
## and do not), then all level numbers: the strip costs 2 draws whatever the number of cards. `text` keeps the S2 glyph summary ("DM1  TK2", "" when empty) for tests and debug;
## `shown()` reads the list `_draw` uses, not GameState. Redraws only on card_picked / state_restored.

const ICON_PX := 56.0
const BADGE_PX := 24.0
const GAP := 8.0
const LEVEL_FONT_SIZE := 18

var text := ""
## [[id, level], ...] in catalog order: the single source of what is drawn.
var _cards: Array = []
## Cell pop on card_picked (S5 Task 5): the card id and its current scale; visual only.
var _pop_id: StringName = &""
var _pop_k := 1.0
var _pop_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	EventBus.card_picked.connect(func(_id: StringName, _level: int): refresh())
	EventBus.card_picked.connect(func(id: StringName, _level: int): _pop(id))
	EventBus.state_restored.connect(refresh)
	refresh()

## [[id, level], ...] for every card on display, in order.
func shown() -> Array:
	return _cards.duplicate(true)

## The cell of the i-th shown card, in this Control's local coordinates.
func cell_rect(i: int) -> Rect2:
	return Rect2(float(i) * (ICON_PX + GAP), 0.0, ICON_PX, ICON_PX)

func pop_scale(id: StringName) -> float:
	return _pop_k if id == _pop_id else 1.0

func _pop(id: StringName) -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_id = id
	_set_pop_k(Balance.ui.strip_pop_scale)
	_pop_tween = create_tween()
	_pop_tween.tween_method(_set_pop_k, Balance.ui.strip_pop_scale, 1.0, Balance.ui.strip_pop_time)

func _set_pop_k(k: float) -> void:
	_pop_k = k
	queue_redraw()

## The cell as drawn: scaled about its centre while its card pops.
func _drawn_rect(i: int) -> Rect2:
	var r := cell_rect(i)
	var k := pop_scale(_cards[i][0])
	return r if k == 1.0 else Rect2(r.get_center() - r.size * k * 0.5, r.size * k)

func refresh() -> void:
	_cards = []
	var parts: Array[String] = []
	for id in CardCatalog.IDS:
		var l := GameState.card_level(id)
		if l > 0:
			parts.append("%s%d" % [CardCatalog.GLYPHS[id], l])
			_cards.append([id, l])
	text = "  ".join(parts)
	var n := _cards.size()
	custom_minimum_size = Vector2(float(n) * ICON_PX + float(maxi(n - 1, 0)) * GAP if n > 0 else 0.0, ICON_PX if n > 0 else 0.0)
	size = custom_minimum_size
	queue_redraw()

func _badge_center(i: int) -> Vector2:
	return _drawn_rect(i).end + Vector2.ONE * (4.0 - BADGE_PX * 0.5)

func _draw() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var atlas := IconAtlas.texture()
	var backing := IconAtlas.region(&"backing")
	for i in n:
		draw_texture_rect_region(atlas, IconAtlas.shape_dest(_drawn_rect(i)), backing)
	for i in n:
		draw_texture_rect_region(atlas, _drawn_rect(i), IconAtlas.region(_icon_name(_cards[i][0])))
	var disc := IconAtlas.region(&"disc")
	for i in n:
		var c := _badge_center(i)
		draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(c - Vector2.ONE * BADGE_PX * 0.5, Vector2.ONE * BADGE_PX)), disc)
	var font := get_theme_default_font()
	var white := Palette.color(&"apron_white")
	var base := (font.get_ascent(LEVEL_FONT_SIZE) - font.get_descent(LEVEL_FONT_SIZE)) * 0.5
	for i in n:
		var c := _badge_center(i)
		draw_string(font, Vector2(c.x - BADGE_PX * 0.5, c.y + base), str(_cards[i][1]), HORIZONTAL_ALIGNMENT_CENTER, BADGE_PX, LEVEL_FONT_SIZE, white)

static func _icon_name(id: StringName) -> StringName:
	return StringName(String(CardCatalog.ICONS[id]).get_file().get_basename())
