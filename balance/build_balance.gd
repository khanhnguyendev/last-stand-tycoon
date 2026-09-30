class_name BuildBalance
extends Resource

@export var tower_cost := 40
@export var fence_cost := 20
@export var level_cost_mult := 2.0
@export var max_level := 3
@export var drain_divisor := 20
@export var tower_damage: Array[float] = [8.0, 12.0, 18.0]
@export var tower_range: Array[float] = [7.0, 7.5, 8.0]
@export var tower_interval := 0.5
@export var tower_projectile_speed := 16.0
@export var fence_hp: Array[float] = [120.0, 200.0, 320.0]
@export var diner_max_hp := 300.0
