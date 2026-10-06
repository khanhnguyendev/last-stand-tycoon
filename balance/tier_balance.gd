class_name TierBalance
extends Resource
## E5 spec 4.4: the diner tier ladder. Index = tier; index 0 is unused (tiers count from 1). Every array has
## tier_costs.size() + 1 entries so the top tier (tier_costs.size()) has its own cap.

## Gold to reach tier index + 1: tier_costs[1] is the cost of tier 2. The highest reachable tier is tier_costs.size().
@export var tier_costs: Array[int] = [0, 500]
## Pressure (the "day" every wave formula sees) at the tier's first night, and where it stops growing.
@export var tier_base: Array[int] = [0, 1, 8]
@export var tier_cap: Array[int] = [0, 7, 11]
## Share of each wave group that spawns as hares: on the tier's first night, at the cap, and the days between.
@export var fast_share_start: Array[float] = [0.0, 0.0, 0.15]
@export var fast_share: Array[float] = [0.0, 0.0, 0.35]
@export var fast_ramp_days: Array[int] = [0, 1, 3]
## Seconds between the boss (first spawn of wave 3) and the rest of that wave.
@export var boss_lead := 3.0
## Sim 2 (spec 8.1): the boss alone must need at least this long to fell the diner from its first hit.
@export var boss_min_hold_s := 15.0
## Dawn after a won boss night: seconds before the card pick opens (the reveal plays meanwhile).
@export var tier_reveal_time := 3.0
## The ladder's length (D-236). A save above the top this build knows is clamped (spec 6.3).
@export var max_tier := 5
