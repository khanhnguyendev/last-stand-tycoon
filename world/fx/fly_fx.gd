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

const STEAK_SCENE := preload("res://art/pickups/steak.tscn")
const COIN_SCENE := preload("res://art/pickups/coin.tscn")
var _pool: NodePool

static func make_item() -> Node3D:
	var n := FxItem.new()
	n.name = "Fx"
	# both kinds are built once per pooled item; fly() only toggles which one shows (no per-fly instancing)
	var steak: Node3D = STEAK_SCENE.instantiate()
	steak.name = "SteakArt"
	n.add_child(steak)
	var coin: Node3D = COIN_SCENE.instantiate()
	coin.name = "CoinArt"
	n.add_child(coin)
	return n

func setup(pool: NodePool) -> void:
	_pool = pool

func in_flight() -> int:
	return _pool.active().size()

func fly(kind: String, from: Vector3, to: Vector3) -> void:
	var n: Node3D = _pool.acquire()
	(n.get_node("SteakArt") as Node3D).visible = kind != "coin"
	(n.get_node("CoinArt") as Node3D).visible = kind == "coin"
	n.position = from
	var apex := Balance.ui.transfer_arc_apex
	var tw := n.create_tween()
	n.set_meta(&"tween", tw)
	tw.tween_method(func(t: float): n.position = from.lerp(to, t) + Vector3.UP * apex * 4.0 * t * (1.0 - t), 0.0, 1.0, Balance.ui.transfer_arc_time)
	tw.tween_callback(_pool.release.bind(n))
