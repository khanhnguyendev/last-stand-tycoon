extends SceneTree
## Manual difficulty sweep launcher (D-059, D-066, D-067).
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd [-- --seed=N --days=10 --bot=upgrader]
## D-150: a `-s` script compiles before the autoloads exist, so it must not name them (or classes that
## use them). It only loads the typed runner at run time.

func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/sim/sweep_runner.gd").new())
