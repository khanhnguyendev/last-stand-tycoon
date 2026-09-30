class_name FlyFx
extends Node
## Visual-only transfer arcs (D-078). Never reads or writes GameState.
## Owners get it injected (World.fly_fx) and call fly() if they hold one.

class FxItem:
	extends Node3D
	func on_release() -> void:
		if has_meta(&"tween"):
			var tw: Tween = get_meta(&"tween")
			if tw != null and tw.is_valid():
				tw.kill()
			remove_meta(&"tween")

var _pool: NodePool

static func make_item() -> Node3D:
	var n := FxItem.new()
	n.name = "Fx"
	n.add_child(Visuals.box(Vector3(0.25, 0.12, 0.2), Visuals.COLORS.coin))
	return n

func setup(pool: NodePool) -> void:
	_pool = pool

func in_flight() -> int:
	return _pool.active().size()

func fly(kind: String, from: Vector3, to: Vector3) -> void:
	var n: Node3D = _pool.acquire()
	var mesh: MeshInstance3D = n.get_child(0)
	mesh.material_override = Visuals.material(Visuals.COLORS.coin if kind == "coin" else Visuals.COLORS.steak)
	n.position = from
	var apex := Balance.ui.transfer_arc_apex
	var tw := n.create_tween()
	n.set_meta(&"tween", tw)
	tw.tween_method(func(t: float): n.position = from.lerp(to, t) + Vector3.UP * apex * 4.0 * t * (1.0 - t), 0.0, 1.0, Balance.ui.transfer_arc_time)
	tw.tween_callback(_pool.release.bind(n))
