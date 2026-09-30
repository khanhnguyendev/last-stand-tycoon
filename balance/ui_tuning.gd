class_name UiTuning
extends Resource
## Presentation tuning (D-078, D-090). Separate from gameplay BalanceData.

@export var joystick_radius_px := 64.0
@export var joystick_deadzone := 0.15
@export var edge_ignore_px := 16.0
@export var camera_fov_h := 42.0
@export var camera_pitch := -55.0
@export var camera_distance := 18.0
@export var camera_follow_rate := 8.0
@export var transfer_arc_time := 0.15
@export var transfer_arc_apex := 0.6
@export var gold_punch_scale := 1.25
@export var gold_punch_time := 0.12
@export var shake_amp := 0.12
@export var shake_time := 0.15
@export var shake_cooldown := 0.5
@export var build_pop_scale := 1.2
@export var build_pop_time := 0.2
@export var hit_flash_time := 0.08
@export var banner_time := 2.0
@export var telegraph_scale_min := 0.5
@export var telegraph_scale_max := 2.0
@export var pulse_scale := 1.15
@export var pulse_hz := 1.0
## Visual scale added per built level (spec 8.6).
@export var build_level_scale := 1.1
## D-151 occlusion fade: diner alpha while it hides an actor, fade time, AABB growth (m).
@export var occluder_alpha := 0.3
@export var occluder_fade_s := 0.15
@export var occluder_grow := 0.2
## HUD (spec 7.9, 9.4): diner bar shake, edge-arrow margin, hover lift, side-arrow scale.
@export var diner_bar_shake_px := 6.0
@export var diner_bar_shake_time := 0.04
@export var arrow_edge_margin := 48.0
@export var arrow_hover_px := 40.0
@export var arrow_side_scale := 0.6
