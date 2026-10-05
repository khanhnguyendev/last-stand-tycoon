class_name StationBalance
extends Resource
## Station upgrade tuning (E1 spec 4, D-223 to D-225, D-230). Index = level; index 0 is the S5 game (D-228).

@export var max_level := 5
@export var cost_mult := 2.0
@export var counter_cost := 30
@export var freezer_cost := 25
## Sim 6.1: each counter level must serve at least this much more than the level below (D-230).
@export var min_level_gain := 0.08
@export var queue_max: Array[int] = [4, 5, 6, 7, 8, 9]
@export var traveler_interval: Array[float] = [2.5, 2.1, 1.8, 1.5, 1.25, 1.0]
@export var service_time: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
@export var counter_capacity: Array[int] = [12, 18, 24, 30, 36, 42]
@export var carry_bonus: Array[int] = [0, 2, 4, 6, 8, 10]
@export var load_per_tick: Array[int] = [1, 1, 2, 2, 3, 3]
