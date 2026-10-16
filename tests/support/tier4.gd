class_name Tier4Support
extends RefCounted
## E8 phase 2 (B5): reaching tier 4 in tests before the price of tier 4 ships (Task 9). Test support, not shipped.

## Opens tier 4 in memory: `tier_costs` gains the price of tier 4. Callers undo it with `Balance.reset()` in `after_each`.
static func open_tier4() -> void:
	Balance.data.tiers.tier_costs = [0, 500, 1500, 3500]
