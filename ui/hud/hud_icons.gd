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
## The lane edge arrows (S5 Task 9): the guide_arrow cell, tinted enemy_red, in a square of Balance.ui.arrow_px centred 2 px below the
## holder's origin (the old polygon spanned -16..20), tip down at rotation 0.
const ARROW_CENTER := Vector2(0, 2)

## The diner-bar slot; the heart sits left of it, centred on its height.
var heart_anchor: Control
## One layout cell per planned wave (MOON_CELL_PX square), in order.
var moon_cells: Array = []
var night := false
var filled := 0
## HudArrow holders drawn last, over the icons; each is drawn only while visible.
var arrow_nodes: Array = []
## E5 spec 7.4: the boss moon's index (-1 = none) and whether the boss still lives (its moon breathes while it does).
var boss_moon := -1
var boss_alive := false
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func moon_lit(i: int) -> bool:
	return i < filled

func moon_color(i: int) -> Color:
	if i == boss_moon and not moon_lit(i):
		return Palette.color(&"enemy_red")
	return MOON_LIT if moon_lit(i) else Palette.color(&"ink_soft")

func moon_scale(i: int) -> float:
	if i != boss_moon:
		return 1.0
	var s: float = Balance.ui.boss_moon_scale
	if boss_alive and not moon_lit(i):
		s *= 1.0 + 0.06 * sin(_t * TAU * Balance.ui.pulse_hz)
	return s

func _process(delta: float) -> void:
	if night and boss_moon >= 0 and boss_alive:
		_t += delta
		queue_redraw()

func coin_rect() -> Rect2:
	return Rect2(global_position + COIN_POS, Vector2(ICON_PX, ICON_PX))

func heart_rect() -> Rect2:
	if heart_anchor == null:
		return Rect2()
	var a := heart_anchor.get_global_rect()
	return Rect2(Vector2(a.position.x - (ICON_PX + ICON_GAP), a.position.y + (a.size.y - ICON_PX) * 0.5), Vector2(ICON_PX, ICON_PX))

func moon_rect(i: int) -> Rect2:
	var c: Control = moon_cells[i]
	var px := MOON_PX * moon_scale(i)
	return Rect2(c.get_global_rect().position + Vector2.ONE * ((MOON_CELL_PX - px) * 0.5), Vector2(px, px))

## The ink disc behind moon i: the cell, grown for the boss moon so its larger icon stays inside (static, no breath).
func disc_rect(i: int) -> Rect2:
	var r: Rect2 = moon_cells[i].get_global_rect()
	if i == boss_moon:
		r = r.grow(MOON_CELL_PX * (Balance.ui.boss_moon_scale - 1.0) * 0.5)
	return r

func _local(r: Rect2) -> Rect2:
	return Rect2(r.position - global_position, r.size)

func _draw() -> void:
	var atlas := IconAtlas.texture()
	if night:
		var disc := IconAtlas.region(&"disc")
		for i in moon_cells.size():
			draw_texture_rect_region(atlas, IconAtlas.shape_dest(_local(disc_rect(i))), disc)
	draw_texture_rect_region(atlas, _local(coin_rect()), IconAtlas.region(&"coin"))
	draw_texture_rect_region(atlas, _local(heart_rect()), IconAtlas.region(&"heart"))
	if night:
		for i in moon_cells.size():
			draw_texture_rect_region(atlas, _local(moon_rect(i)), IconAtlas.region(&"moon"), moon_color(i))
	var red := Palette.color(&"enemy_red")
	var cell := IconAtlas.region(&"guide_arrow")
	var px := Balance.ui.arrow_px
	for a in arrow_nodes:
		if not a.visible:
			continue
		draw_set_transform(a.position, a.rotation, a.scale)
		draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(ARROW_CENTER - Vector2.ONE * px * 0.5, Vector2.ONE * px)), cell, red)
	draw_set_transform_matrix(Transform2D.IDENTITY)
