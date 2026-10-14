extends SceneTree
## E6 phase 4 study launcher (a study, NOT a CI test: the name does not start with test_; asserts nothing; changes no balance value and no production file).
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/study_first_t3.gd -- --seed=1 --policy=threat [--days=24] [--force=none|first|all] [--out=<name>.txt]
## Replays ONE real tier-bot run (retune flag on, in memory) with read-only logging of the first tier-3 nights: every branch purchase (day, spot, pad, branch, lanes, gold before and
## after), per wave and lane the enemies spawned / reaching the diner / killed by kind, the diner damage by lane and kind, fence falls, shots, hits and kills per shooter, and the bot's goal.
## There is no resume from a day-21 state: the run is played from day 1 (about 3 minutes for 24 days). With --force=first|all the threat policy is forced to buy Longbow on the tower(s)
## covering the siege lane first (Q6; in memory only, a subclass of the shipped bot overriding one method, see study_first_t3_runner.gd).
## What-if args (in memory, D-304 seed-14 diagnosis; they use the forced-bot subclass): `--hold=1` (keep the current lane while it has live monsters unless another lane has more breaching
## monsters than that), `--commit=1` (finish the walk before choosing again), `--far=1` (no walk to a zone more than 9 m away while the own lane has live monsters),
## `--base=<n>` (tier 3's first-night pressure, in memory: sets tier_base[3]).
## D-150: a `-s` script compiles before the autoloads exist; it only loads the typed runner at run time.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/sim/out/study"))
	root.add_child.call_deferred(load("res://tests/sim/study_first_t3_runner.gd").new())
