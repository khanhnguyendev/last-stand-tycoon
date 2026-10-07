class_name FenceBranchStats
extends Resource
## One fence branch's numbers (E5 tier-3 spec 3.5). `BranchBalance.fence(id)`; `&""` = the unbranched level 3.

@export var hp := 320.0
## Damage taken x this, by the attacker's kind (an absent kind = 1.0).
@export var damage_taken_mult_by_kind: Dictionary[StringName, float] = {}
## Damage dealt back to the attacker on each hit the fence takes, at spike scale 1.0.
@export var thorn_damage := 0.0
## Damage dealt once to a monster of a `pass_kinds` kind crossing the fence's line, at spike scale 1.0.
@export var pass_damage := 0.0
@export var pass_kinds: Array[StringName] = []
