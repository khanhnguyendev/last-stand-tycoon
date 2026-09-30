class_name Hud
extends CanvasLayer
## Listener-only HUD (spec 9.4). Gold, moons/day, diner bar, banners, edge arrows, safe-area inset.
## Reads GameState / EventBus only, never writes. Every Control ignores the mouse so the joystick
## (which listens in _input on InputLayer) is never blocked.

var root: Control
var gold_label: Label
var card_strip: CardStrip
var day_label: Label
var moons: Array = []
var diner_bar: ProgressBar
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
var _gold_tween: Tween
var _bar_tween: Tween
var _moon_row: HBoxContainer
var _top_column: VBoxContainer

## Layout constants in 720-base units (spec 9.4: slim diner bar under the moons).
const BAR_SIZE := Vector2(220, 12)
const BANNER_SIDE_MARGIN := 40.0
## Half the arrow's height (its polygon spans -16..20 at scale 1, rounded up for the big one).
const ARROW_EXTENT := 26.0

func setup(main: Main) -> void:
	_camera = main.camera_rig.camera
	_lanes = main.world.lanes

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	gold_label = _label(48, Vector2(24, 16))
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
	day_label = _label(40, Vector2.ZERO, row)
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
	# Explicit styles: the bar must read over the ground by day and night.
	var fill := StyleBoxFlat.new()
	fill.bg_color = Visuals.COLORS.diner_hp
	fill.set_corner_radius_all(6)
	fill.set_border_width_all(2)
	fill.border_color = Color(0, 0, 0, 0.8)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, Balance.ui.banner_panel_alpha)
	back.set_corner_radius_all(6)
	back.set_border_width_all(2)
	back.border_color = Color(0, 0, 0, 0.8)
	diner_bar.add_theme_stylebox_override("fill", fill)
	diner_bar.add_theme_stylebox_override("background", back)
	# Dark backing so the banner reads over the world (mouse-transparent, hides with the banner).
	banner_panel = PanelContainer.new()
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, Balance.ui.banner_panel_alpha)
	panel_style.set_corner_radius_all(24)
	panel_style.set_content_margin_all(20)
	banner_panel.add_theme_stylebox_override("panel", panel_style)
	banner_panel.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	banner_panel.anchor_top = 0.4
	banner_panel.anchor_bottom = 0.4
	banner_panel.offset_left = BANNER_SIDE_MARGIN
	banner_panel.offset_right = -BANNER_SIDE_MARGIN
	banner_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner_panel.visible = false
	root.add_child(banner_panel)
	banner = _label(64, Vector2.ZERO, banner_panel)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.visible = false
	for key in ["main", "side"]:
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(-20, -16), Vector2(20, -16), Vector2(0, 20)])
		p.color = Color("e03030")
		p.scale = Vector2.ONE if key == "main" else Vector2.ONE * Balance.ui.arrow_side_scale
		p.visible = false
		root.add_child(p)
		arrows[key] = p
	_set_moon_count(GameState.lane_plan.size())
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.wave_spawned_out.connect(_on_wave_spawned_out)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.card_offered.connect(_on_card_offered)
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

## One moon per planned wave (spec 7.9); created hidden, shown only at night.
func _set_moon_count(n: int) -> void:
	while moons.size() > n:
		moons.pop_back().queue_free()
	while moons.size() < n:
		var m := ColorRect.new()
		m.custom_minimum_size = Vector2(28, 28)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.visible = false
		_moon_row.add_child(m)
		moons.append(m)

func _label(size: int, pos: Vector2, parent: Control = null) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
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
	for m in moons:
		m.visible = night
	day_label.visible = not night
	day_label.text = tr("Day %d") % day
	diner_bar.value = GameState.diner_hp
	if night:
		_filled = 0
		_paint_moons()

## phase_changed(DAWN) carries the old day; the offer comes after advance_day (S2 spec 5.1).
func _on_card_offered(_offer: Array) -> void:
	day_label.text = tr("Day %d") % GameState.day

func _on_wave_cleared(w: int) -> void:
	_filled = clampi(w + 1, 0, moons.size())
	_paint_moons()

func _paint_moons() -> void:
	for i in moons.size():
		moons[i].color = Color("ffe066") if i < _filled else Color(0.25, 0.25, 0.35)

func _on_wave_incoming(_w: int, main_lane: StringName, side_lane: StringName) -> void:
	_arrow_lane.main = String(main_lane)
	_arrow_lane.side = String(side_lane)
	arrows.main.visible = _arrow_lane.main != ""
	arrows.side.visible = _arrow_lane.side != ""
	_place_arrows()

func _on_wave_spawned_out(_w: int) -> void:
	arrows.main.visible = false
	arrows.side.visible = false

func _on_diner_damaged(_amount: float, hp_left: float) -> void:
	diner_bar.value = hp_left
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
		return
	banner.text = _banner_queue.pop_front()
	banner.visible = true
	banner_panel.visible = true
	banner_panel.modulate.a = 1.0
	_banner_left = Balance.ui.banner_time

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

## Where arrow tips may sit: the safe root rect, inset by the edge margin, below the top HUD.
func _arrow_rect() -> Rect2:
	var rect := root.get_global_rect().grow(-Balance.ui.arrow_edge_margin)
	var hud_bottom := maxf(maxf(_top_column.get_global_rect().end.y, gold_label.get_global_rect().end.y), card_strip.get_global_rect().end.y if card_strip.text != "" else 0.0)
	var top := hud_bottom + Balance.ui.arrow_hud_gap + ARROW_EXTENT
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
	var rect := _arrow_rect()
	for key in ["main", "side"]:
		var arrow: Polygon2D = arrows[key]
		var lane: String = _arrow_lane[key]
		if not arrow.visible or lane == "" or not _lanes.has(lane):
			continue
		var world_pos: Vector3 = _lanes[lane].entrance_position()
		var p := _camera.unproject_position(world_pos)
		if _camera.is_position_behind(world_pos):
			p = rect.get_center() - (p - rect.get_center())
		if rect.has_point(p):
			arrow.position = _hover_point(p, rect) - root.position
			arrow.rotation = 0.0
		else:
			var c := rect.get_center()
			var dir := (p - c).normalized()
			var tx := INF if is_zero_approx(dir.x) else ((rect.end.x if dir.x > 0 else rect.position.x) - c.x) / dir.x
			var ty := INF if is_zero_approx(dir.y) else ((rect.end.y if dir.y > 0 else rect.position.y) - c.y) / dir.y
			arrow.position = c + dir * minf(tx, ty) - root.position
			arrow.rotation = dir.angle() - PI / 2.0
