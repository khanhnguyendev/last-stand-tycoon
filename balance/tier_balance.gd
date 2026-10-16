class_name TierBalance
extends Resource
## E5 spec 4.4: the diner tier ladder. Index = tier; index 0 is unused (tiers count from 1). Every array has
## at least tier_costs.size() + 1 entries so the top tier (tier_costs.size()) has its own cap. The tier-3 entries (index 3)
## are live: tier_costs has four entries (the tier-3 switch, E5 tier-3 spec section 2; tier 4's price, E8 Task 9).

## Gold to reach tier index + 1: tier_costs[1] is the cost of tier 2. The highest reachable tier is tier_costs.size().
@export var tier_costs: Array[int] = [0, 500, 1500, 3500]
## Pressure (the "day" every wave formula sees) at the tier's first night, and where it stops growing. E6 (D-304): tier 3 starts at 10
## (tier 2's cap) and reaches its cap 12 on its third night, so the first night, when one branch is owned, is softer.
@export var tier_base: Array[int] = [0, 1, 8, 10, 12]
## Tier 3's cap is 12: its escalation is the brute ramp and the fourth lane, then the last two steps of pressure
## (real-play tuning: 15 needed retries on about half of all cap nights; 12 with no side-lane brutes had 0 in 40).
## Tier 4's cap is 14 (E8 phase-2 tuning round 2; round 1 was 15: the Volley builds retried 3 tier-4 cap nights each).
@export var tier_cap: Array[int] = [0, 7, 10, 12, 14]
## Share of each wave group that spawns as hares: on the tier's first night, at the cap, and the days between.
@export var fast_share_start: Array[float] = [0.0, 0.0, 0.15, 0.35, 0.35]
@export var fast_share: Array[float] = [0.0, 0.0, 0.35, 0.35, 0.35]
@export var fast_ramp_days: Array[int] = [0, 1, 3, 1, 1]
## E5 tier 3 (spec 3.3): siege brutes per wave (main lane, side lane) at the cap, and the days the count takes to ramp.
## The first tier-3 night has one brute on the last wave's main lane. Tiers 1 and 2 carry 0.
@export var brute_cap_main: Array[int] = [0, 0, 0, 1, 1]
@export var brute_cap_side: Array[int] = [0, 0, 0, 0, 0]
@export var brute_ramp_days: Array[int] = [0, 1, 1, 3, 1]
## The boss fought to LEAVE the tier at that index (index 0 unused): tier 1 -> the Boar King, tier 2 -> Baron von Hop, tier 3 -> the Wrecker (E8; it fights only once tier 3 is not the top).
## One entry per tier including the top; the top tier's entry is empty (no boss leaves the top).
@export var boss_kind: Array[StringName] = [&"", &"boss", &"baron", &"wrecker", &""]
## Seconds between the boss (first spawn of wave 3) and the rest of that wave.
@export var boss_lead := 3.0
## Sim 2 (spec 8.1): the boss alone must need at least this long to fell the diner from its first hit.
@export var boss_min_hold_s := 15.0
## Dawn after a won boss night: seconds before the card pick opens (the reveal plays meanwhile).
@export var tier_reveal_time := 3.0
## The ladder's length (D-236). A save above the top this build knows is clamped (spec 6.3).
@export var max_tier := 5

## E6 (D-282, D-287): the share of a tier-3 wave's hares that walk the run's hare lane (LaneCharacter.apply).
@export var hare_lane_share := 0.7
