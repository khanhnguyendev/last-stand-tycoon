class_name PayFx
extends RefCounted
## Visual feedback for one paid stand-still tick on a build spot or an upgrade pad. Returns the new paid-tick count.

static func paid_tick(at: Node3D, fx: FlyFx, ticks: int, level_done: bool, coin_y: float) -> int:
	# Visual-only counter (S5 Task 5): a dust puff on every build_dust_every-th paid tick.
	# A tick that completes a level restarts the count for the next level.
	ticks = 0 if level_done else ticks + 1
	if ticks > 0 and ticks % maxi(Balance.ui.build_dust_every, 1) == 0:
		EventBus.fx_requested.emit(&"dust", at.global_position)
	var hero := at.get_tree().get_first_node_in_group(&"hero") as Node3D
	if fx != null and hero != null:
		fx.fly("coin", hero.global_position + Vector3(0, 1.2, 0), at.global_position + Vector3(0, coin_y, 0))
	return ticks
