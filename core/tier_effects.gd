class_name TierEffects
extends RefCounted
## Tier ladder helpers (E5 spec 4.4). Pure: no scene access, no GameState.

## The highest tier this build can reach: tier_costs[t] is the cost of tier t + 1, so the last index is the last buy.
static func top_tier(tb: TierBalance) -> int:
	return tb.tier_costs.size()

## Gold from `tier` to `tier + 1`; -1 when there is no next tier in this build.
static func tier_cost(tier: int, tb: TierBalance) -> int:
	if tier < 1 or tier >= top_tier(tb):
		return -1
	return tb.tier_costs[tier]

## Share of a wave group that spawns as hares on `day` for a tier entered on `tier_day`.
static func fast_share_now(day: int, tier: int, tier_day: int, tb: TierBalance) -> float:
	var ramp := maxi(tb.fast_ramp_days[tier], 1)
	var k := clampf(float(day - tier_day) / float(ramp), 0.0, 1.0)
	return lerpf(tb.fast_share_start[tier], tb.fast_share[tier], k)

## How many of a wave's main and side groups are hares.
static func fast_counts(main: int, side: int, share: float) -> Dictionary:
	return {"fast_main": mini(main, int(round(main * share))), "fast_side": mini(side, int(round(side * share)))}
