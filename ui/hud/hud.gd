class_name Hud
extends CanvasLayer
## Listener-only HUD (spec 9.4). Gold, moons/day, diner bar, banners, edge arrows, safe-area inset.
## Reads GameState / EventBus only, never writes. Every Control ignores the mouse so the joystick
## (which listens in _input on InputLayer) is never blocked.

var root: Control
var gold_label: Label
var card_strip: CardStrip
var day_label: Label
## The moon layout cells (one per planned wave); the moons themselves are drawn by `icons`.
var moons: Array = []
var diner_bar: ProgressBar
var icons: HudIcons
var banner: Label
var banner_panel: PanelContainer
var arrows := {}
var _camera: Camera3D
var _lanes := {}
var _arrow_lane := {"main": "", "side": ""}
var _filled := 0
var _banner_queue: Array[String] = []
## Seconds left of the banner on screen; 0 when none is showing.
var _banner_left := 0.0
var _banner_tween: Tween
## Pixels the banner panel is currently shifted from its rest offsets by the slide-in (spec 5.3).
var _banner_slide := 0.0
var _gold_tween: Tween
var _bar_tween: Tween
var _flash_tween: Tween
var _punch_tween: Tween
var _moon_row: HBoxContainer
var _top_column: VBoxContainer
var _occluder_fade: OccluderFade
var _arrows_were_shown := false
var _dim_t := 0.0

## Layout constants in 720-base units (spec 9.4: slim diner bar under the moons).
const BAR_SIZE := Vector2(220, 12)
const BANNER_SIDE_MARGIN := 40.0
## Half the arrow's height, derived from arrow_px (the arrow is drawn centred 2 px below its origin), rounded up for the big one.
static func arrow_extent() -> float:
	return ceilf(Balance.ui.arrow_px * 0.5 + 2.0) + 2.0
## Task 15: HUD icons (rendered by tools/render_icons.gd).
const ICON_PX := HudIcons.ICON_PX
const ICON_GAP := HudIcons.ICON_GAP
const MOON_CELL_PX := HudIcons.MOON_CELL_PX
const MOON_LIT := HudIcons.MOON_LIT

func setup(main: Main) -> void:
	_camera = main.camera_rig.camera
	_lanes = main.world.lanes
	_occluder_fade = main.world.occluder_fade

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	# The coin icon takes the old label slot (24, 16); the label moves right by one icon (the 24 px margin cannot hold it).
	icons = HudIcons.new()  # coin, heart and moons in one custom draw (Task 16b)
	icons.z_index = 1  # the lane arrows draw above the other HUD Controls, as the Polygon2D arrows did
	root.add_child(icons)
	gold_label = _label(48, Vector2(24 + ICON_PX + ICON_GAP, 16), null, &"HudCounter")
	gold_label.pivot_offset = Vector2(0, 30)
	card_strip = CardStrip.new()
	card_strip.position = Vector2(24, 84)
	root.add_child(card_strip)
	# Day label / moons / diner bar sit in one column anchored to the top centre.
	var column := VBoxContainer.new()
	_top_column = column
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.offset_top = 16.0
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, 54)
	column.add_child(row)
	day_label = _label(40, Vector2.ZERO, row, &"HudCounter")
	_moon_row = HBoxContainer.new()
	_moon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moon_row.add_theme_constant_override("separation", 12)
	_moon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_moon_row)
	var bar_slot := Control.new()
	bar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_slot.custom_minimum_size = BAR_SIZE
	column.add_child(bar_slot)
	diner_bar = ProgressBar.new()
	diner_bar.show_percentage = false
	diner_bar.max_value = Balance.data.build.diner_max_hp
	diner_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_slot.add_child(diner_bar)
	diner_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The heart is drawn by `icons` left of the bar, centred on it, outside the layout slot (no layout shift).
	icons.heart_anchor = bar_slot
	for c in [column, _moon_row, bar_slot, root]:
		c.item_rect_changed.connect(icons.queue_redraw)
	# Fill and background come from the theme (ProgressBar: guard_green on ink).
	# Dark backing so the banner reads over the world (mouse-transparent, hides with the banner).
	banner_panel = PanelContainer.new()
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.theme_type_variation = &"BannerPanel"
	banner_panel.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	banner_panel.anchor_top = 0.4
	banner_panel.anchor_bottom = 0.4
	banner_panel.offset_left = BANNER_SIDE_MARGIN
	banner_panel.offset_right = -BANNER_SIDE_MARGIN
	banner_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner_panel.visible = false
	root.add_child(banner_panel)
	banner = _label(64, Vector2.ZERO, banner_panel, &"BannerLabel")
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.visible = false
	for key in ["main", "side"]:
		var p := HudArrow.new()
		p.scale = Vector2.ONE if key == "main" else Vector2.ONE * Balance.ui.arrow_side_scale
		p.visible = false
		root.add_child(p)
		arrows[key] = p
		icons.arrow_nodes.append(p)
	_set_moon_count(GameState.lane_plan.size())
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.wave_spawned_out.connect(_on_wave_spawned_out)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.card_offered.connect(_on_card_offered)
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.state_restored.connect(_refresh_all)
	EventBus.banner_requested.connect(_on_banner)
	_refresh_all()
	_paint_moons()

## Re-read the insets; called on start and whenever the viewport size changes (rotation, resize).
func _apply_safe_area() -> void:
	var ins := SafeArea.insets(root.get_viewport_rect().size)
	root.offset_top = ins.top
	root.offset_bottom = -ins.bottom
	root.offset_left = ins.left
	root.offset_right = -ins.right

## One moon per planned wave (spec 7.9): an empty layout cell each, so the row keeps its width; `icons` draws them,
## and only at night.
func _set_moon_count(n: int) -> void:
	while moons.size() > n:
		moons.pop_back().queue_free()
	while moons.size() < n:
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.custom_minimum_size = Vector2(MOON_CELL_PX, MOON_CELL_PX)
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.item_rect_changed.connect(icons.queue_redraw)
		_moon_row.add_child(cell)
		moons.append(cell)
	icons.moon_cells = moons
	icons.queue_redraw()

func moon_lit(i: int) -> bool:
	return icons.moon_lit(i)

func moon_color(i: int) -> Color:
	return icons.moon_color(i)

## True while the moons are drawn (night only).
func moons_shown() -> bool:
	return icons.night

func _label(size: int, pos: Vector2, parent: Control, variation: StringName) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(l)
	return l

func filled_moons() -> int:
	return _filled

func _refresh_all() -> void:
	gold_label.text = str(GameState.gold)
	diner_bar.value = GameState.diner_hp
	day_label.text = tr("Day %d") % GameState.day
	icons.boss_alive = false
	icons.boss_moon = boss_moon_index()
	icons.queue_redraw()

func _on_gold_changed(gold: int, _delta: int) -> void:
	gold_label.text = str(gold)
	if _gold_tween != null and _gold_tween.is_valid():
		_gold_tween.kill()
	gold_label.scale = Vector2.ONE * Balance.ui.gold_punch_scale
	_gold_tween = create_tween()
	_gold_tween.tween_property(gold_label, "scale", Vector2.ONE, Balance.ui.gold_punch_time)

func _on_phase_changed(phase: int, day: int) -> void:
	var night := phase == Phase.NIGHT
	if night:
		_set_moon_count(GameState.lane_plan.size())
	else:
		_arrow_lane.main = ""
		_arrow_lane.side = ""
		arrows.main.visible = false
		arrows.side.visible = false
	icons.night = night
	# The boss moon is set when the night's HUD is rebuilt: moons draw at night only, so a tier-up paid by day is read here.
	icons.boss_moon = boss_moon_index() if night else -1
	icons.boss_alive = false
	icons.queue_redraw()
	day_label.visible = not night
	day_label.text = tr("Day %d") % day
	diner_bar.value = GameState.diner_hp
	if night:
		_filled = 0
		_paint_moons()

## phase_changed(DAWN) carries the old day; the offer comes after advance_day (S2 spec 5.1).
func _on_card_offered(_offer: Array) -> void:
	day_label.text = tr("Day %d") % GameState.day

## The tier-up dawn delays the card offer by the reveal, so the new day shows from tier_reached.
func _on_tier_reached(_tier: int) -> void:
	day_label.text = tr("Day %d") % GameState.day

## The boss moon breathes from its wave's start until the boss dies.
func _on_wave_started(w: int, _main_lane: StringName, _side_lane: StringName) -> void:
	icons.boss_alive = w == icons.boss_moon
	icons.queue_redraw()

func _on_enemy_killed(_spawn_index: int, _lane: StringName, _position: Vector3, kind: StringName) -> void:
	if TierEffects.is_boss_kind(kind, Balance.data.tiers):
		icons.boss_alive = false
		icons.queue_redraw()

## The last moon on a boss night (-1 otherwise).
func boss_moon_index() -> int:
	return GameState.lane_plan.size() - 1 if GameState.is_boss_night() else -1

func _on_wave_cleared(w: int) -> void:
	_filled = clampi(w + 1, 0, moons.size())
	_paint_moons()

func _paint_moons() -> void:
	icons.filled = _filled
	icons.queue_redraw()

func _on_wave_incoming(w: int, main_lane: StringName, side_lane: StringName) -> void:
	_arrow_lane.main = String(main_lane)
	_arrow_lane.side = String(side_lane)
	arrows.main.visible = _arrow_lane.main != ""
	arrows.side.visible = _arrow_lane.side != ""
	_mark_brute_arrows(w)
	_place_arrows()
	_punch_arrows()

## E5 tier 3 Task 14 (D-264): an arrow whose lane brings a brute in this wave or a later one tonight gets the heavy mark (not
## once its last brute has come). Arrows show only from wave_incoming, at night (today's timing, unchanged).
func _mark_brute_arrows(w: int) -> void:
	var comp := LanePlanner.composition_by_lane(GameState.lane_plan.slice(maxi(w, 0)), GameState.tier)
	for key in ["main", "side"]:
		arrows[key].heavy = int(comp.get(_arrow_lane[key], {}).get("brute", 0)) > 0

## S5 Task 5: the arrows pop when a wave is announced (visual only).
func _punch_arrows() -> void:
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = create_tween().set_parallel(true)
	for key in ["main", "side"]:
		var rest := Vector2.ONE if key == "main" else Vector2.ONE * Balance.ui.arrow_side_scale
		arrows[key].scale = rest * Balance.ui.arrow_punch_scale
		_punch_tween.tween_property(arrows[key], "scale", rest, Balance.ui.arrow_punch_time)

func _on_wave_spawned_out(_w: int) -> void:
	arrows.main.visible = false
	arrows.side.visible = false

func _on_diner_damaged(_amount: float, hp_left: float) -> void:
	diner_bar.value = hp_left
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	diner_bar.modulate = Palette.color(&"enemy_red")
	_flash_tween = create_tween()
	_flash_tween.tween_property(diner_bar, "modulate", Color.WHITE, Balance.ui.bar_flash_time)
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	# The bar sits in a layout slot; shake its x inside the slot so the layout never matters.
	diner_bar.position.x = 0.0
	_bar_tween = create_tween()
	_bar_tween.tween_property(diner_bar, "position:x", Balance.ui.diner_bar_shake_px, Balance.ui.diner_bar_shake_time)
	_bar_tween.tween_property(diner_bar, "position:x", 0.0, Balance.ui.diner_bar_shake_time)

## S3 (D-175): a new banner shortens the current one to banner_min_s, then plays in full.
func _on_banner(text: String) -> void:
	_banner_queue.append(text)
	if _banner_left <= 0.0:
		_show_next_banner()
	else:
		_banner_left = minf(_banner_left, Balance.ui.banner_min_s)

func _show_next_banner() -> void:
	if _banner_queue.is_empty():
		_banner_left = 0.0
		banner.visible = false
		banner_panel.visible = false
		_banner_motion_stop()
		return
	banner.text = _banner_queue.pop_front()
	banner.visible = true
	banner_panel.visible = true
	banner_panel.modulate.a = 1.0
	_banner_motion_start()
	# A banner shown while others wait plays banner_min_s (the fail path: "The diner fell" -> "The monsters return" -> flavor).
	_banner_left = Balance.ui.banner_time if _banner_queue.is_empty() else minf(Balance.ui.banner_time, Balance.ui.banner_min_s)

## Slide-in (spec 5.3): the panel's offset_top/offset_bottom move together, so the label (not the panel, whose alpha
## _tick_banner owns) fades in. Shifts are applied as deltas over whatever rest offsets the panel has.
func _banner_motion_stop() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_set_slide(0.0)
	banner.modulate.a = 1.0

func _banner_motion_start() -> void:
	_banner_motion_stop()
	var ui := Balance.ui
	if ui.banner_in_s <= 0.0:
		return
	_banner_set_slide(-ui.banner_slide_px)
	banner.modulate.a = 0.0
	_banner_tween = create_tween().set_parallel(true)
	_banner_tween.tween_method(_banner_set_slide, -ui.banner_slide_px, 0.0, ui.banner_in_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, ui.banner_in_s)

func _banner_set_slide(v: float) -> void:
	var d := v - _banner_slide
	banner_panel.offset_top += d
	banner_panel.offset_bottom += d
	_banner_slide = v

func _tick_banner(delta: float) -> void:
	if _banner_left <= 0.0:
		return
	_banner_left -= delta
	banner_panel.modulate.a = clampf(_banner_left / (Balance.ui.banner_time * 0.25), 0.0, 1.0)
	if _banner_left <= 0.0:
		_show_next_banner()

func _process(delta: float) -> void:
	_tick_banner(delta)
	_place_arrows()
	_layout_strip()
	_tick_label_dim(delta)
	# The arrows are drawn by `icons`; redraw while one shows (and once more when the last one hides).
	var any: bool = arrows.main.visible or arrows.side.visible
	if any or _arrows_were_shown:
		icons.queue_redraw()
	_arrows_were_shown = any

## The card strip sits strip_gap_px below the lowest of the coin row and the diner bar (spec 7).
func _layout_strip() -> void:
	var bottom := maxf(maxf(gold_label.get_global_rect().end.y, icons.coin_rect().end.y), diner_bar.get_global_rect().end.y)
	var y := bottom + Balance.ui.strip_gap_px - root.get_global_rect().position.y
	if not is_equal_approx(card_strip.position.y, y):
		card_strip.position.y = y

## Screen rects of the HUD blocks that world labels dim under, grown by label_dim_grow_px.
func _dim_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [_top_column.get_global_rect(), gold_label.get_global_rect().merge(icons.coin_rect()), icons.heart_rect()]
	if card_strip.text != "":
		out.append(card_strip.get_global_rect())
	if reserved_rect.is_valid():
		out.append(reserved_rect.call())
	for i in out.size():
		out[i] = out[i].grow(Balance.ui.label_dim_grow_px)
	return out

## label_dim_hz times a second: a WorldLabel whose screen point is under a HUD block gets label_dim_alpha, else 1.0.
## The alpha snaps (a modulate change rebuilds the label mesh); labels OccluderFade owns are skipped.
func _tick_label_dim(delta: float) -> void:
	_dim_t += delta
	if _dim_t < 1.0 / maxf(Balance.ui.label_dim_hz, 0.01) or _camera == null:
		return
	_dim_t = 0.0
	var rects := _dim_rects()
	for n in get_tree().get_nodes_in_group(&"world_labels"):
		var l := n as Label3D
		if l == null or not l.is_inside_tree() or (_occluder_fade != null and _occluder_fade.owns_label(l)):
			continue
		var target := 1.0
		if not _camera.is_position_behind(l.global_position):
			var p := _camera.unproject_position(l.global_position)
			for r in rects:
				if r.has_point(p):
					target = Balance.ui.label_dim_alpha
					break
		if l.modulate.a != target or l.outline_modulate.a != target:
			l.modulate.a = target
			l.outline_modulate.a = target

## Rect of a widget that sits over the top of the HUD (the settings gear, S5 Task 8b); arrow tips stay below it.
var reserved_rect: Callable

## Where arrow tips may sit: the safe root rect, inset by the edge margin, below the top HUD.
func arrow_rect() -> Rect2:
	var rect := root.get_global_rect().grow(-Balance.ui.arrow_edge_margin)
	var hud_bottom := maxf(maxf(_top_column.get_global_rect().end.y, gold_label.get_global_rect().end.y), card_strip.get_global_rect().end.y if card_strip.text != "" else 0.0)
	if reserved_rect.is_valid():
		hud_bottom = maxf(hud_bottom, (reserved_rect.call() as Rect2).end.y)
	var top := hud_bottom + Balance.ui.arrow_hud_gap + arrow_extent()
	if top > rect.position.y:
		rect.size.y -= top - rect.position.y
		rect.position.y = top
	return rect

## Tip position for an on-screen entrance: hover above it, but never above the arrow rect.
func _hover_point(entrance: Vector2, rect: Rect2) -> Vector2:
	return Vector2(entrance.x, maxf(entrance.y - Balance.ui.arrow_hover_px, rect.position.y))

func _place_arrows() -> void:
	if _camera == null:
		return
	var base_rect := arrow_rect()
	for key in ["main", "side"]:
		var arrow: HudArrow = arrows[key]
		var lane: String = _arrow_lane[key]
		if not arrow.visible or lane == "" or not _lanes.has(lane):
			continue
		var rect := base_rect
		if arrow.heavy:  # the mark sits behind the arrow: keep it below the top HUD too
			var extra := maxf(Balance.ui.arrow_heavy_px, Balance.ui.arrow_heavy_min_px) + Balance.ui.arrow_heavy_gap_px
			rect = Rect2(base_rect.position + Vector2(0, extra), base_rect.size - Vector2(0, extra))
		var world_pos: Vector3 = _lanes[lane].entrance_position()
		var p := _camera.unproject_position(world_pos)
		if _camera.is_position_behind(world_pos):
			p = rect.get_center() - (p - rect.get_center())
		if rect.has_point(p):
			arrow.position = _hover_point(p, rect) - root.position
			arrow.rotation = 0.0
		else:
			var e := EdgeClamp.clamp_to_rect(p, rect)
			arrow.position = (e.position as Vector2) - root.position
			arrow.rotation = e.rotation
