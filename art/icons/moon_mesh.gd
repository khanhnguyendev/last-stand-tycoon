class_name MoonMesh
extends RefCounted
## The HUD moon (S4 Task 15): a chamfered crescent solid, about 2 units tall, centred. Rendered in Palette
## warm_white by tools/render_icons.gd; the HUD tints it lit/unlit.

static func _circle(c: Vector2, r: float, steps := 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(t), sin(t)) * r)
	return pts

static func outline() -> PackedVector2Array:
	var cut := Geometry2D.clip_polygons(_circle(Vector2.ZERO, 1.0), _circle(Vector2(0.55, 0.28), 0.82))
	var best := PackedVector2Array()
	for p in cut:
		if p.size() > best.size():
			best = p
	for i in best.size():
		best[i] -= Vector2(-0.12, 0.0)
	return IconExtrude.rounded(best, 0.05)

static func build() -> ArrayMesh:
	return IconExtrude.build(outline(), 0.6, 0.12)
