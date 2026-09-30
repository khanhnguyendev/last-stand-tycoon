class_name Targetable
extends Node
## Marks a node as a target of a kind (&"enemy", &"fence", &"diner"); spawn_index breaks ties.

@export var kind: StringName = &"enemy"
var spawn_index := -1
