class_name TowerBranchStats
extends Resource
## One tower branch's numbers (E5 tier-3 spec 3.5). `BranchBalance.tower(id)`; `&""` = the unbranched level 3.

@export var attack_range := 8.0
## Damage of ONE projectile.
@export var damage := 18.0
@export var interval := 0.5
## Projectiles per attack, each at a different target (the first `count` of Targeting.select's order).
@export var count := 1
