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
@export var shake_time := 0.12
@export var shake_cooldown := 0.5
## S5 Task 5 (spec 5.2): reactions. Screen shake per kind; carry squash; traveler hop; bar flash; arrow punch; strip pop;
## hero dust interval; build dust every Nth paid tick.
@export var shake_enabled := true
@export var shake_fell_amp := 0.3
@export var shake_fell_time := 0.4
@export var carry_squash := 1.06
@export var carry_squash_time := 0.12
@export var traveler_hop_m := 0.25
@export var traveler_hop_time := 0.2
@export var bar_flash_time := 0.15
@export var arrow_punch_scale := 1.3
@export var arrow_punch_time := 0.2
@export var strip_pop_scale := 1.25
@export var strip_pop_time := 0.15
@export var hero_dust_interval_s := 0.35
@export var build_dust_every := 4
@export var build_pop_scale := 1.2
@export var build_pop_time := 0.2
## E5 spec 7.5: the tier-up reveal (camera pull-back and the pacing of the pops).
@export var tier_reveal_zoom := 2.25
@export var tier_reveal_in_s := 0.6
@export var tier_reveal_out_s := 0.8
@export var tier_reveal_step_s := 0.35
## E5 tier 3 Task 20: a tap during the reveal sends the camera back to the hero over this long; the tier-3 camera frames this much of the
## south-west lane's last stretch (m, along the lane from its end)
## (the tier-3 reveal only).
@export var tier_reveal_skip_ease_s := 0.25
@export var tier_reveal_lane_stretch_m := 8.0
## A press in the first this-many seconds of a reveal (physics time since the dawn started) does not skip it: step 1 is always seen.
@export var tier_reveal_skip_guard_s := 0.6
## The tier-3 camera fits its subject points inside this fraction of the half-screen (1.0 = the very edge, as tier 2): air for the HUD's
## top bar and for the finger.
@export var tier_reveal_fit_t3 := 0.8
## E5 tier 3 Task 20: the HUD's top bar (gold counter, day label, moons) in BASE pixels from the top of the safe area down: a telegraph
## count row whose screen rect touches it is hidden (it would draw under the bar).
@export var hud_top_bar_px := 90.0
@export var hit_flash_time := 0.08
@export var banner_time := 2.0
@export var telegraph_scale_min := 0.5
@export var telegraph_scale_max := 2.0
## E5 tier 3 Task 14 (D-264): the telegraph's composition row. Icon and number sizes in world metres (the glyph's 1 m
## square, the number's em), the gap between pairs, the lift above the flag; and the readability floors in BASE pixels
## (the 720x1280 canvas_items base), which the tests check at every aspect and focus.
@export var telegraph_icon_m := 1.1
@export var telegraph_number_em_m := 1.0
@export var telegraph_row_gap_m := 0.2
## The row sits at the fixed height `telegraph_row_height_m` (the icons' centre); where, is TelegraphMarker.ROW_ANCHORS.
@export var telegraph_row_height_m := 1.0
## Floors in base px. The number minimum is the EM height of the font (a digit is about 0.7 of it, so 28 is about 20 px of digit).
@export var telegraph_icon_min_px := 28.0
@export var telegraph_number_min_px := 28.0
## The brute mark beside a heavy edge arrow (Task 14): drawn this many base px square (never below the minimum).
@export var arrow_heavy_px := 24.0
@export var arrow_heavy_min_px := 22.0
@export var arrow_heavy_gap_px := 3.0
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
## S5 UI motion (spec 5.3): banner slide/fade-in, card rise and stagger (the last card lands inside card_input_guard_s),
## button press scale (Task 8).
@export var banner_slide_px := 24.0
@export var banner_in_s := 0.15
@export var card_rise_px := 40.0
@export var card_rise_s := 0.18
@export var card_stagger_s := 0.06
@export var button_press_scale := 0.94
## S5 Task 8b settings (D-216, D-217): gear size and margin to the safe edge, panel and button size, and how long the New game
## confirm stays armed.
@export var gear_px := 72.0
@export var gear_margin := 16.0
@export var settings_panel_size := Vector2(520, 420)
@export var settings_button_h := 96.0
@export var new_game_confirm_s := 3.0
@export var settings_font_px := 40
@export var button_press_in_s := 0.05
@export var button_press_out_s := 0.08
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
## E5 monster kinds (spec 7.1): the hare hops quick and low, the Boar King slow and heavy and lunges further.
@export var hare_hop_height := 0.05
@export var hare_hop_hz := 6.0
@export var boss_hop_height := 0.12
@export var boss_hop_hz := 2.0
@export var boss_lunge := 0.5
## The boss's moon in the night HUD is drawn this much bigger (spec 7.4).
@export var boss_moon_scale := 1.3
## The boss moon's breath: its scale swings by this fraction while the boss is alive.
@export var boss_moon_breath := 0.06
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

## S5 Task 7 (D-215): the boot fade-out time (s).
@export var boot_fade_out_s := 0.3

## S5 Task 7 (D-215 amendment): after the phase starts the boot fade stays opaque until this many consecutive frames are each
## under boot_fade_stable_ms, or boot_fade_max_s seconds after fade_out() was called; then it fades over boot_fade_out_s.
@export var boot_fade_stable_frames := 10
@export var boot_fade_stable_ms := 50.0
@export var boot_fade_max_s := 4.0

## S5 Task 9 (spec 7): gap between the coin row / diner bar and the card strip; world labels under a HUD block dim to
## label_dim_alpha when their screen point is within label_dim_grow_px of it, checked label_dim_hz times a second.
@export var strip_gap_px := 12.0
@export var label_dim_alpha := 0.15
@export var label_dim_grow_px := 8.0
@export var label_dim_hz := 4.0
## The lane edge arrows are drawn arrow_px square (S5 Task 9); Hud.arrow_extent() derives from it.
@export var arrow_px := 44.0

## S5 Task 10 (spec 6): the Guide. Evaluation period, extra inset of its edge rect, world pointer height and bounce,
## the walk that clears `move`, the ghost stick's swipe loop.
@export var guide_eval_s := 0.25
## 62 = lane arrow extent + half the 64 px Guide arrow + 2, so the two arrows never stack.
@export var guide_rect_inset_px := 62.0
@export var guide_pointer_h := 2.2
@export var guide_bounce_m := 0.25
@export var guide_bounce_hz := 1.5
@export var guide_move_m := 2.0
@export var guide_swipe_s := 1.0
## S5 Task 10 review: the Guide's label size, the ghost stick's height (fraction of the rect), its swipe reach (fraction of the
## ring radius), and the size of its edge arrow (the HUD lane arrows keep arrow_px).
@export var guide_font_px := 40.0
@export var guide_stick_y := 0.78
@export var guide_swipe_frac := 0.7
@export var guide_arrow_px := 64.0

## E5 tier 3 Task 3: the tier sign reads at phone size. Label font size, Label3D pixel size (m per px) and height (m, centre
## of the text block); tier_sign_min_px is the smallest projected height of ONE label line in base pixels (the project
## stretches a 720x1280 base: view heights 1680, 1280 and 1280 at 9:21, 9:16 and 16:9; tests/unit/test_tier_sign.gd).
@export var tier_sign_label_font := 56
@export var tier_sign_label_pixel_size := 0.01
@export var tier_sign_label_y := 4.27
@export var tier_sign_min_px := 36.0

## E5 tier 3 Task 17: the branch pads read at phone size and show information in stages (D-263.3, D-273.4). The focus spot is the
## branchable spot whose nearest pad is closest to the hero within branch_pad_near_m, kept until the hero is beyond
## branch_pad_leave_m. Glyph height (m): branch_pad_icon_m near and on the pad, branch_pad_far_icon_m for a far pad. Font sizes are the
## project's own (48 / 40); the WorldLabel pixel sizes set how large they read. The *_min_px floors are the smallest projected
## height in base pixels (the 720x1280 base: view heights 1680, 1280, 1280; tests/unit/test_branch_pads.gd).
@export var branch_pad_near_m := 3.5
@export var branch_pad_leave_m := 4.5
@export var branch_pad_icon_m := 0.9
@export var branch_pad_far_icon_m := 0.7
@export var branch_pad_label_font := 48
@export var branch_pad_cost_font := 48
@export var branch_pad_warn_font := 40
@export var branch_pad_label_pixel_size := 0.011
@export var branch_pad_cost_pixel_size := 0.0123
@export var branch_pad_warn_pixel_size := 0.0105
@export var branch_pad_icon_min_px := 28.0
@export var branch_pad_far_icon_min_px := 20.0
@export var branch_pad_label_min_px := 28.0
@export var branch_pad_warn_min_px := 20.0
