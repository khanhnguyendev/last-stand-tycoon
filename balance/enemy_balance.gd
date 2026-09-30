class_name EnemyBalance
extends Resource

@export var hp := 30.0
@export var speed := 2.0
@export var damage := 5.0
@export var attack_interval := 1.0
@export var reach := 1.2
@export var lateral_spread := 1.0
@export var drop_scatter := 0.6
## Over the last N meters the lateral offset blends onto the zone's width axis (spec 6.3 test D).
@export var offset_fade_distance := 3.0
