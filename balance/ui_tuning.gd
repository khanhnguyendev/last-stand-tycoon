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
## Ground steaks only (the PickupField) are drawn at this scale so they read at phone size; piles stay at 1.0.
@export var ground_steak_scale := 1.6
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
@export var build_level_scale := 1.0
## D-151 occlusion fade: diner alpha while it hides an actor, fade time, AABB growth (m).
@export var occluder_alpha := 0.45
@export var occluder_fade_s := 0.15
@export var occluder_grow := 0.2
## HUD (spec 7.9, 9.4): diner bar shake, edge-arrow margin, hover lift, side-arrow scale.
@export var diner_bar_shake_px := 6.0
@export var diner_bar_shake_time := 0.04
@export var arrow_edge_margin := 48.0
@export var arrow_hover_px := 40.0
@export var arrow_side_scale := 0.6
## Banner backing panel alpha (CP1 review: banners must stay readable over world labels). Baked into ui/theme/game_theme.tres; re-run tools/build_theme.gd after changing.
@export var banner_panel_alpha := 0.85
## Gap between the top HUD block and an edge arrow (CP1 review).
@export var arrow_hud_gap := 8.0
## S2 card pick overlay (D-162): early taps are ignored for card_input_guard_s; panel size, gap, and the
## smallest height panels may shrink to on short (landscape) windows.
@export var card_input_guard_s := 0.5
@export var card_panel_size := Vector2(560, 220)
@export var card_panel_gap := 24.0
@export var card_panel_min_h := 120.0
## S3: a new banner shortens the one on screen to at most banner_min_s (D-175); autosave throttle (D-173).
@export var banner_min_s := 0.6
@export var autosave_interval_s := 3.0
## S4 Task 6: ActorVisual (D-190). Turn rate of the model toward its facing (rad/s), AnimationTree blend and
## one-shot fade (s), and the minimum gap between Hit_A reactions (s).
@export var visual_turn_speed := 14.0
@export var anim_blend_s := 0.12
@export var hit_react_cooldown := 1.0
## S4 Task 9: Boar tweens (ART_BIBLE §6, D-192): idle bob (m, s), run hop (m, Hz), attack lunge (m), hit and death squash on y.
@export var boar_idle_bob := 0.03
@export var boar_idle_period := 0.8
@export var boar_hop_height := 0.08
@export var boar_hop_hz := 4.0
@export var boar_lunge := 0.3
@export var boar_squash := 0.92
@export var boar_death_squash := 0.6
## S4 Task 7 (D-191): the hero's knife roll about its local X (deg/s) and the hero ring's alpha.
@export var knife_spin_deg_s := 720.0
@export var hero_ring_alpha := 0.6
## S4 Task 13 (D-194): day and night lighting, tweened over lighting_tween_s on phase_changed. The night is a blue
## moonlight, not dark: the hero, the Boar and the steaks keep R1-R5 (R6).
@export var lighting_tween_s := 1.5
@export var day_sun_color := Color("fff3c4")
@export var day_sun_energy := 0.85
@export var day_ambient := Color(0.55, 0.55, 0.55)
@export var day_bg := Color("7fbf5a")
@export var night_sun_color := Color("d8e2ff")
@export var night_sun_energy := 0.55
@export var night_ambient := Color(0.36, 0.40, 0.58)
@export var night_bg := Color("2a4a35")
