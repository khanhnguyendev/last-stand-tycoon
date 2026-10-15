extends GutTest
## Debt sweep (E5_FOLLOWUPS "Policy names live in four places"): the branch policy names are written in tier_bot.gd (the source: POLICIES and
## REPORT_POLICIES), tests/sim/report_policies.gd, tests/sim/sweep_math.gd and tests/sim/sweep_runner.gd. The two report scripts cannot read TierBot
## (a `-s` script compiles before the autoloads exist, D-150, and TierBot reads Balance), so this file ties their copies to the source.

const REPORT_ONLY := "unbranched"

func _report_consts() -> Dictionary:
	return (load("res://tests/sim/report_policies.gd") as GDScript).get_script_constant_map()

func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

## The report-only policies other than the floor reference: the ones the 2 x 2 table adds.
func _extra_pairs() -> Array:
	return TierBot.REPORT_POLICIES.filter(func(p): return p != REPORT_ONLY)

func test_the_floor_reference_is_a_report_policy_of_the_bot() -> void:
	assert_eq(SweepMath.REFERENCE_POLICY, REPORT_ONLY)
	assert_true(SweepMath.REFERENCE_POLICY in TierBot.REPORT_POLICIES)
	assert_false(SweepMath.REFERENCE_POLICY in TierBot.POLICIES)

func test_report_policies_script_names_the_bots_policies() -> void:
	var c := _report_consts()
	assert_eq(c["SPEC_POLICIES"], TierBot.POLICIES, "the spec's four, in the bot's order")
	assert_eq(c["POLICY_IDS"], TierBot.POLICIES + _extra_pairs(), "the four plus the 2 x 2 table's extra pair, no floor reference")

func test_sweep_math_policy_lists_name_the_bots_policies() -> void:
	var fixed: Array = TierBot.POLICIES.filter(func(p): return p != "threat") + _extra_pairs()
	assert_eq(_sorted(SweepMath.FIXED_PAIRS), _sorted(fixed), "the four fixed combinations: every spec policy but threat, plus the extra pair")
	assert_eq(_sorted(SweepMath.RETUNE_POLICIES), _sorted(TierBot.POLICIES + TierBot.REPORT_POLICIES), "the retune report covers every policy the bot knows")
	assert_eq(_sorted(SweepMath.CELLS.values()), _sorted(SweepMath.FIXED_PAIRS), "each fixed pair fills exactly one cell of the 2 x 2 table")
	for p in SweepMath.LONGBOW_POLICIES:
		assert_true(p in TierBot.POLICIES, "%s is a spec policy" % p)

func test_every_policy_the_bot_knows_is_accepted_by_the_runner() -> void:
	var src := FileAccess.get_file_as_string("res://tests/sim/sweep_runner.gd")
	assert_true(src.contains("String(args.policy) in TierBot.POLICIES or String(args.policy) in TierBot.REPORT_POLICIES"), "the runner validates --policy against the bot's own lists")
	assert_true(src.contains("_policy != SweepMath.REFERENCE_POLICY"), "the runner names the floor reference through SweepMath")
