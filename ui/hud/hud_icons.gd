class_name HudIcons
extends Control
## The HUD's icons in one custom _draw (S4 Task 16b, D-201): the moon discs first, then the icons (coin, heart, moons),
## all cells of one atlas texture, so they batch into one draw. It holds no layout of its own: the coin sits at a fixed spot, the heart
## and the moons follow Controls the Hud lays out (`heart_anchor`, `moon_cells`), and it redraws when those move or when
## the Hud changes the moon state. Full-rect child of the HUD root; ignores the mouse.

const ICON_PX := 48.0
const ICON_GAP := 8.0
const MOON_PX := 26.0
const MOON_CELL_PX := 32.0
const COIN_POS := Vector2(24, 22)
## Lit moons show the icon as rendered (warm_white); unlit ones are tinted ink_soft, on an ink disc.
const MOON_LIT := Color.WHITE

## The diner-bar slot; the heart sits left of it, centred on its height.
var heart_anchor: Control
## One layout cell per planned wave (MOON_CELL_PX square), in order.
var moon_cells: Array = []
var night := false
var filled := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func moon_lit(i: int) -> bool:
	return i < filled

func moon_color(i: int) -> Color:
	return MOON_LIT if moon_lit(i) else Palette.color(&"ink_soft")

func coin_rect() -> Rect2:
	return Rect2(global_position + COIN_POS, Vector2(ICON_PX, ICON_PX))

func heart_rect() -> Rect2:
	if heart_anchor == null:
		return Rect2()
	var a := heart_anchor.get_global_rect()
	return Rect2(Vector2(a.position.x - (ICON_PX + ICON_GAP), a.position.y + (a.size.y - ICON_PX) * 0.5), Vector2(ICON_PX, ICON_PX))

func moon_rect(i: int) -> Rect2:
	var c: Control = moon_cells[i]
	return Rect2(c.get_global_rect().position + Vector2.ONE * ((MOON_CELL_PX - MOON_PX) * 0.5), Vector2(MOON_PX, MOON_PX))

func _local(r: Rect2) -> Rect2:
	return Rect2(r.position - global_position, r.size)

func _draw() -> void:
	var atlas := IconAtlas.texture()
	if night:
		var disc := IconAtlas.region(&"disc")
		for c in moon_cells:
			draw_texture_rect_region(atlas, IconAtlas.shape_dest(_local(c.get_global_rect())), disc)
	draw_texture_rect_region(atlas, _local(coin_rect()), IconAtlas.region(&"coin"))
	draw_texture_rect_region(atlas, _local(heart_rect()), IconAtlas.region(&"heart"))
	if night:
		for i in moon_cells.size():
			draw_texture_rect_region(atlas, _local(moon_rect(i)), IconAtlas.region(&"moon"), moon_color(i))
