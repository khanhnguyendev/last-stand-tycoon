class_name GuardStats
extends Resource
## One adventurer's level-1 stats and per-level growth (S2 spec 8). Stat at level L = base x (1 + growth x (L - 1)).

@export var max_hp := 0.0
@export var hp_growth := 0.0
@export var damage := 0.0
@export var damage_growth := 0.0
@export var interval := 1.0
@export var attack_range := 0.0
@export var projectile_speed := 16.0
@export var body_radius := 0.4
@export var walk_speed := 0.0
@export var respawn_s := 0.0
## Ground guards are enemy targets (D-164); the roof Archer is not.
@export var targetable := false
@export var on_roof := false
