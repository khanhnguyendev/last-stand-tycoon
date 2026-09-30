class_name TargetPriority
extends Resource

## Ordered target kinds an enemy checks each tick (D-004, D-049). S2 inserts &"guard".
@export var kinds: Array[StringName] = [&"fence_on_lane", &"diner"]
