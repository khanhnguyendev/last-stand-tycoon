class_name TargetProviders
extends RefCounted
## Target kinds by name (D-004, D-049). Enemies ask kinds in their own stats().priority order (E5).
## S2 registers &"guard" here (GuardRoster); Boar gained one match arm for it (S2 spec 7).

var _providers := {}

func register(kind: StringName, fn: Callable) -> void:
	_providers[kind] = fn

## True when a provider is registered for the kind AND the kind is in this enemy's priority list (E5: per kind).
func has_kind(kind: StringName, enemy) -> bool:
	return _providers.has(kind) and (enemy.stats().priority as Array).has(kind)

func find_target(enemy) -> Dictionary:
	for kind in enemy.stats().priority:
		if _providers.has(kind):
			var t: Dictionary = _providers[kind].call(enemy)
			if not t.is_empty():
				return t
	return {}

## Distance along the path where a boar stops for its lane's fence; INF when no fence stands.
static func fence_stop_dist(enemy) -> float:
	var b: Dictionary = GameState.buildings[MapLayout.lane_fence(enemy.lane)]
	if int(b.level) < 1 or float(b.hp) <= 0.0:
		return INF
	return enemy.path_length() - MapLayout.FENCE_OFFSET_FROM_END - enemy.stats().reach

static func fence_on_lane(enemy) -> Dictionary:
	if enemy.dist >= fence_stop_dist(enemy) - 1e-4:
		return {"kind": &"fence_on_lane", "spot_id": MapLayout.lane_fence(enemy.lane)}
	return {}

static func diner(enemy) -> Dictionary:
	return {"kind": &"diner"} if enemy.at_path_end() else {}
