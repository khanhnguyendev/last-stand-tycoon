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

## Siege brutes of one wave (E5 tier-3 spec 6.1), added on top of the group counts. Pure and deterministic: no RNG.
## Below tier 3: zeros. With d = max(day - tier_day, 0) and R = max(brute_ramp_days[tier], 1):
##  - d < R: the LAST d + 1 waves (capped at wave_count) carry brute_cap_main brutes on their main lane; the first
##    tier-3 night (d = 0) is exactly one brute, on the last wave's main lane. No side-lane brutes yet.
##  - d >= R: every wave carries brute_cap_main on its main lane and, when it has a side lane, brute_cap_side there.
## So the total never decreases from one day to the next.
static func brute_counts(day: int, tier: int, tier_day: int, wave_index: int, wave_count: int, has_side: bool, tb: TierBalance) -> Dictionary:
	if tier < 3:
		return {"main": 0, "side": 0}
	var d := maxi(day - tier_day, 0)
	var ramp := maxi(tb.brute_ramp_days[tier], 1)
	if d >= ramp:
		return {"main": tb.brute_cap_main[tier], "side": tb.brute_cap_side[tier] if has_side else 0}
	var carrying := mini(d + 1, wave_count)
	return {"main": tb.brute_cap_main[tier] if wave_index >= wave_count - carrying else 0, "side": 0}
