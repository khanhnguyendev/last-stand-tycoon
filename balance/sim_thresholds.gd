class_name SimThresholds
extends Resource

@export var night1_win_min := 0.50
@export var night2_unaided_max := 0.30
@export var night2_comfort_min := 0.60
@export var first_combat_max_s := 30.0
@export var sim_suite_budget_s := 60.0
## S2 sweep target (D-170): the PlannerBot breaks at break_day_target +- break_day_tolerance. Reported, not asserted.
@export var break_day_target := 10
@export var break_day_tolerance := 1
## E5 sim 1 (spec 8.1): retries the tier bot may need on the boss night.
@export var boss_night_max_retries := 2
