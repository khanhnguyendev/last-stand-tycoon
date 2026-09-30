class_name WaveBalance
extends Resource

@export var base_counts: Array[int] = [4, 6, 8]
@export var count_growth := 0.35
@export var hp_growth := 0.15
@export var max_wave_size := 30
@export var spawn_interval := 0.8
@export var first_wave_delay := 5.0
@export var breather := 10.0
@export var side_share_base := 0.20
@export var side_share_step := 0.05
@export var side_share_cap := 0.45
@export var side_group_delay := 4.0
@export var target_priority: TargetPriority = TargetPriority.new()
## Mercy (S3, D-175): enemy HP and damage x max(1 - mercy_step x night_fails, mercy_floor).
@export var mercy_step := 0.15
@export var mercy_floor := 0.40
