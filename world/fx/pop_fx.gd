class_name PopFx
extends RefCounted
## Visual only: the model pops and settles back; the StaticBody3D and its shape are never scaled.

## Starts the pop on `target` from `base` scale; kills `prev` first. Returns the new tween.
static func pop(owner: Node, target: Node3D, base: Vector3, prev: Tween) -> Tween:
	kill(prev)
	target.scale = base * Balance.ui.build_pop_scale
	var t := owner.create_tween()
	t.tween_property(target, "scale", base, Balance.ui.build_pop_time)
	return t

static func kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
