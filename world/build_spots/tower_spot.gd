class_name TowerSpot
extends BuildSpot
## Tower: never targeted, auto-attacks when level >= 1 (spec 7.5).

var attacker: Attacker

func _build_visual() -> void:
	# No physics body: the hero walks through towers (D-125).
	var m := Visuals.cylinder(MapLayout.TOWER_VISUAL_RADIUS, 2.0, Visuals.COLORS.tower)
	m.position.y = 1.0
	visual.add_child(m)
	attacker = Attacker.new()
	attacker.position.y = 1.5
	attacker.candidates = _world.wave_director.enemy_candidates
	attacker.projectile_pool = _world.projectile_pool
	attacker.enabled = false
	add_child(attacker)

func _apply_level(p_level: int, _b: Dictionary) -> void:
	var built := p_level >= 1
	visual.visible = built
	attacker.enabled = built
	if built:
		var bb := Balance.data.build
		assert(p_level <= bb.tower_damage.size() and p_level <= bb.tower_range.size(), "tower level out of range")
		attacker.configure(bb.tower_damage[p_level - 1], bb.tower_range[p_level - 1], bb.tower_interval,
			Balance.data.hero.retarget_interval, 1.0, bb.tower_projectile_speed)
