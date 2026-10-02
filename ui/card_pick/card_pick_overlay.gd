class_name CardPickOverlay
extends CanvasLayer
## Dawn card pick (S2 spec 5.4, D-162). Tap a card (press and release on the same panel) or press 1/2/3.
## Main adds it after InputLayer, so its _input runs before the joystick's; it consumes only presses it owns
## (the fade-button ownership pattern), ignores emulated mouse events and every press in the first
## card_input_guard_s, and hides outside DAWN.

var offer: Array[StringName] = []
var _root: Control
var _heading: Label
var _panels: Array[Control] = []
var _rects: Array[Rect2] = []
var _owned := {}
var _guard_left := 0.0

const HEADING_H := 70.0
## Card portrait size in 720-base units (Task 15).
const PORTRAIT_PX := 160.0

func _init() -> void:
	name = "CardPickOverlay"
	layer = 15

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	var dim_c := Palette.color(&"night_sky")
	dim.color = Color(dim_c.r, dim_c.g, dim_c.b, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_heading = _label(44, _root, &"HudCounter")
	_heading.text = tr("Pick a card")
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false
	EventBus.card_offered.connect(show_offer)
	EventBus.card_picked.connect(_on_card_picked)
	EventBus.state_restored.connect(hide_overlay)
	EventBus.phase_changed.connect(_on_phase_changed)
	get_viewport().size_changed.connect(_relayout)

func show_offer(o: Array) -> void:
	if o.is_empty():
		return
	offer.assign(o)
	for p in _panels:
		p.queue_free()
	_panels.clear()
	for id in offer:
		_panels.append(_make_panel(id))
	_relayout()
	_owned.clear()
	_guard_left = Balance.ui.card_input_guard_s
	visible = true

func hide_overlay() -> void:
	visible = false
	_owned.clear()

func panel_rects() -> Array[Rect2]:
	return _rects

func accepting() -> bool:
	return visible and _guard_left <= 0.0

## Panel rects for n cards in a column centred in the safe area. Panels fit while the safe height >=
## HEADING_H + (n+1)·gap + n·card_panel_min_h; below that the column is top-aligned and may overflow
## (unreachable with canvas_items/expand at 1280 logical height). Width is clamped to the safe width
## minus side margins.
static func layout(vp: Vector2, insets: Dictionary, n: int, ui: UiTuning) -> Array[Rect2]:
	var top := float(insets.top)
	var bottom := vp.y - float(insets.bottom)
	var left := float(insets.left)
	var right := vp.x - float(insets.right)
	var gap := ui.card_panel_gap
	var avail_h := bottom - top - HEADING_H - gap * float(n + 1)
	var h := clampf(avail_h / float(n), ui.card_panel_min_h, ui.card_panel_size.y)
	var w := minf(ui.card_panel_size.x, right - left - 2.0 * (ui.edge_ignore_px + gap))
	var total := HEADING_H + gap + h * float(n) + gap * float(n - 1)
	var y := top + maxf((bottom - top - total) * 0.5, 0.0) + HEADING_H + gap
	var x := left + (right - left - w) * 0.5
	var out: Array[Rect2] = []
	for i in n:
		out.append(Rect2(Vector2(x, y + float(i) * (h + gap)), Vector2(w, h)))
	return out

func _relayout() -> void:
	if offer.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	_rects = CardPickOverlay.layout(vp, SafeArea.insets(vp), offer.size(), Balance.ui)
	for i in _panels.size():
		_panels[i].position = _rects[i].position
		_panels[i].size = _rects[i].size
	_heading.size = Vector2(vp.x, HEADING_H)
	_heading.position = Vector2(0, _rects[0].position.y - HEADING_H - Balance.ui.card_panel_gap)

func _make_panel(id: StringName) -> Control:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme_type_variation = &"CardPanelAdventurer" if CardCatalog.kind(id) == &"adventurer" else &"CardPanelUpgrade"
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_top = 16
	row.offset_right = -20
	row.offset_bottom = -16
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	# The portrait (Task 15): the panel is fixed at card_panel_size (560x220), so 160 px does not fit above the
	# text; it leads the row, top-aligned.
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = load(CardCatalog.ICONS[id])
	portrait.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(box)
	_label(40, box, &"").text = CardCatalog.display_name(id)
	_label(28, box, &"").text = CardCatalog.effect_text(id, Balance.data.cards)
	_label(26, box, &"").text = CardCatalog.level_text(GameState.card_level(id))
	return panel

func _label(size: int, parent: Control, variation: StringName) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _physics_process(delta: float) -> void:
	if visible and _guard_left > 0.0:
		_guard_left = maxf(_guard_left - delta, 0.0)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and accepting():
			var i := [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
			if i >= 0 and i < offer.size():
				get_viewport().set_input_as_handled()
				_choose(i)
		return
	var idx := -1
	var pressed := false
	if event is InputEventScreenTouch:
		idx = event.index
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	else:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if pressed:
		_owned.erase(idx)
		var p := _panel_at(event.position)
		if p >= 0 and accepting():
			_owned[idx] = p
			get_viewport().set_input_as_handled()
	elif _owned.has(idx):
		if event is InputEventScreenTouch and event.canceled:
			_owned.erase(idx)
			get_viewport().set_input_as_handled()
			return
		var p: int = _owned[idx]
		_owned.erase(idx)
		get_viewport().set_input_as_handled()
		if _panel_at(event.position) == p and accepting():
			_choose(p)

func _panel_at(pos: Vector2) -> int:
	for i in _rects.size():
		if _rects[i].has_point(pos):
			return i
	return -1

func _choose(i: int) -> void:
	EventBus.card_chosen.emit(offer[i])

func _on_card_picked(_id: StringName, _level: int) -> void:
	hide_overlay()

func _on_phase_changed(phase: int, _day: int) -> void:
	if phase != Phase.DAWN:
		hide_overlay()

## D-147: a paused tree drops touch releases, so forget every owned finger.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_owned.clear()
