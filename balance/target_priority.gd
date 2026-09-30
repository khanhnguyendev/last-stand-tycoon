class_name TargetPriority
extends Resource

## Ordered target kinds an enemy checks each tick (D-004, D-049, D-164).
@export var kinds: Array[StringName] = [&"fence_on_lane", &"guard", &"diner"]
