class_name HeartMesh
extends RefCounted
## The HUD heart (S4 Task 15): a rounded, chamfered heart solid, about 2 units wide, centred. Rendered in
## Palette enemy_red by tools/render_icons.gd (the allowed danger/health exception to ART_BIBLE R4).

static func outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 72
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y + 1.0) / 17.0)
	return IconExtrude.rounded(pts, 0.1)

static func build() -> ArrayMesh:
	return IconExtrude.build(outline(), 0.5, 0.11)
