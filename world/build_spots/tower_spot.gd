class_name TowerSpot
extends BuildSpot
## Tower: never targeted, auto-attacks when level >= 1 (spec 7.5).

## Level models (S4 Task 12, D-194): 2.2 / 2.8 / 3.4 m (ART_BIBLE scale table); the pips float 0.3 m above the top.
const MODELS: Array[PackedScene] = [
	preload("res://art/env/tower_l1.tscn"), preload("res://art/env/tower_l2.tscn"), preload("res://art/env/tower_l3.tscn"),
]
const MODEL_HEIGHTS: Array[float] = [2.2, 2.8, 3.4]

var attacker: Attacker

func _build_visual() -> void:
	# No physics body: the hero walks through towers (D-125); the model is swapped in by _apply_level.
	attacker = Attacker.new()
	attacker.position.y = 1.5
	attacker.candidates = _world.wave_director.enemy_candidates
	attacker.projectile_pool = _world.projectile_pool
	attacker.enabled = false
	add_child(attacker)

## The one source of a tower's combat stats: levels 1 to 3 from the build balance; the top level with a branch from
## the branch balance (E5 tier 3, spec 6.4). `branch` &"" = none. Unbranched levels return a fresh object; a branched call returns the shared balance resource (read only).
static func stats_for(p_level: int, branch: StringName) -> TowerBranchStats:
	var bb := Balance.data.build
	assert(p_level >= 1 and p_level <= bb.tower_damage.size() and p_level <= bb.tower_range.size(), "tower level out of range")
	if branch != &"" and p_level == bb.max_level:
		return Balance.data.branches.tower(branch)
	var s := TowerBranchStats.new()
	s.attack_range = bb.tower_range[p_level - 1]
	s.damage = bb.tower_damage[p_level - 1]
	s.interval = bb.tower_interval
	s.count = 1
	return s

func _apply_level(p_level: int, b: Dictionary) -> void:
	var built := p_level >= 1
	visual.visible = built
	_show_model(p_level, MODELS[mini(p_level, MODELS.size()) - 1] if built else null)
	attacker.enabled = built
	if built:
		# refresh() runs on building_changed (a branch purchase emits it), state_restored (load, new_game) and phase changes.
		var st := TowerSpot.stats_for(p_level, StringName(String(b.get("branch", ""))))
		attacker.configure(st.damage, st.attack_range, st.interval, Balance.data.hero.retarget_interval, 1.0,
			Balance.data.build.tower_projectile_speed, st.count)

func _pip_y(p_level: int) -> float:
	return MODEL_HEIGHTS[clampi(p_level, 1, MODEL_HEIGHTS.size()) - 1] + 0.3

func _label_y(p_level: int) -> float:
	return _pip_y(p_level) + 0.55 if p_level >= 1 else super(p_level)
