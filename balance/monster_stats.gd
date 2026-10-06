class_name MonsterStats
extends Resource
## One monster kind's numbers (E5 spec 4.3). The boar's are a view of EnemyBalance (MonsterBalance.stats).

@export var hp := 30.0
@export var speed := 2.0
@export var damage := 5.0
@export var attack_interval := 1.0
@export var reach := 1.2
@export var steaks_per_kill := 2
@export var drop_scatter := 0.6
## Ordered target kinds this monster checks each tick (D-004, D-049, D-148). No &"fence_on_lane" = walks past fences.
@export var priority: Array[StringName] = [&"fence_on_lane", &"guard", &"diner"]
