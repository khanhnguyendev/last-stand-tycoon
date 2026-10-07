extends SceneTree
## E5 tier-3 balance study (Task 23 follow-up). NOT a CI test (the name does not start with test_); writes no file and no balance value:
## every override is in memory, after Balance.reset(). Nights run ONE AT A TIME.
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/report_t3_balance.gd [-- --part=1|2|all]
## Part 1: the Baron night with the full tier-2 build (fixture tier3_baron_full) over Baron HP 500/450/400/350 and (HP 500, speed 2.0),
##   ten nights each (CI seed days 16 to 20, seeds 1 to 5 on day 16); for the first night, the damage dealt to the Baron per source.
## Part 2: the tier-3 cap with the full tier-3 build (fixtures tier3_cap_<policy>), seeds 20260930, 1, 2 x four policies x tier_cap[3] 15/14/13/12.
## D-150: a `-s` script compiles before the autoloads exist, so it only loads the typed runner at run time.

func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/sim/report_t3_balance_runner.gd").new())
