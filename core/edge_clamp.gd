class_name EdgeClamp
extends RefCounted
## Where an edge arrow sits for a screen point (S5 D-213; was Hud._place_arrows). Pure.

static func clamp_to_rect(p: Vector2, rect: Rect2) -> Dictionary:
	if rect.has_point(p):
		return {"inside": true, "position": p, "rotation": 0.0}
	var c := rect.get_center()
	var dir := (p - c).normalized()
	var tx := INF if is_zero_approx(dir.x) else ((rect.end.x if dir.x > 0 else rect.position.x) - c.x) / dir.x
	var ty := INF if is_zero_approx(dir.y) else ((rect.end.y if dir.y > 0 else rect.position.y) - c.y) / dir.y
	return {"inside": false, "position": c + dir * minf(tx, ty), "rotation": dir.angle() - PI / 2.0}
