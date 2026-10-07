class_name HudArrow
extends Node2D
## One lane edge arrow (S5 Task 9): plain data the HUD places (visible, position, rotation, scale); it draws nothing.
## HudIcons draws it from the `guide_arrow` atlas cell tinted enemy_red, which replaced a Polygon2D (WebGL warnings,
## docs/review/WEBGL_WARNINGS.md).

## E5 tier 3 Task 14 (D-264): the lane has a brute tonight; HudIcons draws the heavy mark (the brute glyph) on the arrow.
var heavy := false
