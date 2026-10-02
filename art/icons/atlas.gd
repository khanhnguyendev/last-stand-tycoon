class_name IconAtlas
extends RefCounted
## The icon atlas (S4 Task 16b, D-201 applied to the HUD): all 11 icons at 128 px in one 4x3 grid, so a Control that draws
## several icons issues one batched draw. Written by tools/render_icons.gd (`--atlas-only` rebuilds it from the committed
## per-icon PNGs, which stay the checked source and what the card overlay shows). NAMES is the grid order, row-major,
## followed by SHAPES: two solid UI shapes baked as cells (the card backing, an ink disc), so a Control that draws
## icons, backings and badges stays one texture and batches (polygons from draw_circle / draw_style_box do not).

const CELL := 128
const COLS := 4
const NAMES: Array[StringName] = [
	&"card_hero_damage", &"card_attack_speed", &"card_move_speed", &"card_carry_capacity",
	&"card_gold_per_steak", &"card_archer", &"card_tank", &"coin",
	&"steak", &"heart", &"moon",
]
## Baked shapes: the card backing (the theme's Panel look: cream at 0.95, 4 px ink border, 20 px radius on a 56 px cell,
## scaled to the cell) and an ink disc. Both are inset PAD px inside their cell so mip filtering never reads a neighbour.
const SHAPES: Array[StringName] = [&"backing", &"disc"]
const PAD := 2
const PATH := "res://art/icons/atlas.png"

## The cell of icon `name` (a file name without ".png", e.g. &"coin", &"card_tank") in atlas pixels.
static func region(name: StringName) -> Rect2:
	var i := NAMES.find(name)
	if i < 0:
		i = SHAPES.find(name)
		assert(i >= 0, "no atlas cell %s" % name)
		i += NAMES.size()
	return Rect2(float(i % COLS) * CELL, float(i / COLS) * CELL, CELL, CELL)

static func rows() -> int:
	return (NAMES.size() + SHAPES.size() + COLS - 1) / COLS

## The destination rect to draw a baked shape's whole cell into so the shape itself (inset PAD) fills `shape`.
static func shape_dest(shape: Rect2) -> Rect2:
	return shape.grow(shape.size.x * float(PAD) / float(CELL - 2 * PAD))

## Preloaded: a texture first loaded inside a _draw call renders white (and a Control that redraws rarely keeps it).
const _TEXTURE: Texture2D = preload("res://art/icons/atlas.png")

static func texture() -> Texture2D:
	return _TEXTURE
