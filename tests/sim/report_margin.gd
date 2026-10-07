extends SceneTree
## E5 tier-3 report (spec 9.1, D-269): how much diner HP is left after the tier-2 cap night with a full tier-2 build.
## Not a CI test (the name does not start with test_). Each seed runs the night ONCE, no retry loop.
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/report_margin.gd [-- --seeds=a,b,c --fixture=tier2_full --tier-cap=<n>]
## Prints `MARGIN seed=.. cleared=.. failed=.. diner_frac=.. kills=.. stuck=.. retries=0` per seed and a final `MARGIN seeds=..` summary;
## writes tests/sim/out/margin.csv (gitignored). Exits non-zero if a seed is not at tier 2 and the tier-2 pressure cap.
## D-150: a `-s` script compiles before the autoloads exist, so it only loads the typed runner at run time.

func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/sim/report_margin_runner.gd").new())
