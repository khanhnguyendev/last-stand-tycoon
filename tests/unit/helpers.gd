class_name TestHelpers
extends RefCounted
## Walks the hero into a point from just outside, the way a player enters a station (D-121).

static func walk_in(hero: Hero, target: Vector2, from_offset := Vector2(0, 2.0)) -> void:
	hero.teleport(target + from_offset)
	var tree := hero.get_tree()
	await tree.physics_frame
	var step := Balance.data.hero.move_speed / float(Engine.physics_ticks_per_second)
	for i in 600:
		var d := target - hero.xz()
		if d.length() < 0.02:
			break
		hero.input.set_move((d / step).limit_length(1.0))
		await tree.physics_frame
	hero.input.set_move(Vector2.ZERO)
	assert((target - hero.xz()).length() < 0.05, "walk_in did not reach %s" % target)
