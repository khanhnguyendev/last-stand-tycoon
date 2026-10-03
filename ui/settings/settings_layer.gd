class_name SettingsLayer
extends CanvasLayer
## The settings gear (top-right, inside the safe area) and its panel: Sound, New game, Close (S5 Task 8b, D-216, D-217).
## Layer 25, PROCESS_MODE_ALWAYS. Main adds it after the card overlay, so its _input runs first: a press on the gear or
## anywhere on the open panel is consumed here and never reaches the overlay or the joystick. emulate_mouse_from_touch is off,
## so it hit-tests itself (the card overlay's press-and-release-on-the-same-target pattern, with the debug overlay's
## `_owned` fingers). The gear and the panel are custom-drawn from IconAtlas `backing` and `gear` cells (one texture, no
## style boxes); the texts are plain Labels. Opening and closing only emit; Main owns the `settings` pause reason (D-218).

signal opened
signal closed
signal mute_toggled(muted: bool)
signal new_game_requested

var confirm_armed := false

var _open := false
var _muted := false
var _armed_t := 0.0
var _owned := {}
var _gear_rect := Rect2()
var _panel_rect := Rect2()
var _buttons := {}
var _gear: Control
var _panel: Control
var _labels := {}
var _press_key := &""
var _press_k := 1.0
var _tween: Tween

func _init() -> void:
	name = "SettingsLayer"
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_gear = _make_control(&"gear")
	_panel = _make_control(&"panel")
	_panel.visible = false
	for k in [&"sound", &"new_game", &"close"]:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", 40)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_panel.add_child(l)
		_labels[k] = l
	_labels.close.text = tr("Close")
	_refresh_texts()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	set_process(false)

func _make_control(n: StringName) -> Control:
	var c := Control.new()
	c.name = String(n)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	c.draw.connect(_draw_gear if n == &"gear" else _draw_panel)
	add_child(c)
	return c

func gear_rect() -> Rect2:
	return _gear_rect

func panel_open() -> bool:
	return _open

func button_rects() -> Dictionary:
	return _buttons

func sound_text() -> String:
	return tr("Sound: Off") if _muted else tr("Sound: On")

func open() -> void:
	if _open:
		return
	_open = true
	_disarm()
	_panel.visible = true
	_panel.queue_redraw()
	opened.emit()

func close() -> void:
	if not _open:
		return
	_open = false
	_disarm()
	_panel.visible = false
	closed.emit()

func set_muted_display(m: bool) -> void:
	_muted = m
	_refresh_texts()

## Freed while open: release the pause reason through the same signal.
func _exit_tree() -> void:
	if _open:
		_open = false
		closed.emit()

func _disarm() -> void:
	confirm_armed = false
	_armed_t = 0.0
	set_process(false)
	_refresh_texts()
	if _panel != null:
		_panel.queue_redraw()

func _refresh_texts() -> void:
	if _labels.is_empty():
		return
	_labels.sound.text = sound_text()
	_labels.new_game.text = tr("Tap again to erase") if confirm_armed else tr("New game")

## Counts game time (delta), never wall clock: the layer is ALWAYS, so it runs while the tree is paused.
func _process(delta: float) -> void:
	if not confirm_armed:
		return
	_armed_t += delta
	if _armed_t > Balance.ui.new_game_confirm_s:
		_disarm()

func _relayout() -> void:
	var ui := Balance.ui
	var vp := get_viewport().get_visible_rect().size
	var ins := SafeArea.insets(vp)
	var safe := Rect2(float(ins.left), float(ins.top), vp.x - float(ins.left) - float(ins.right), vp.y - float(ins.top) - float(ins.bottom))
	_gear_rect = Rect2(Vector2(safe.end.x - ui.gear_margin - ui.gear_px, safe.position.y + ui.gear_margin), Vector2(ui.gear_px, ui.gear_px))
	var ps := Vector2(minf(ui.settings_panel_size.x, safe.size.x - 2.0 * ui.gear_margin), minf(ui.settings_panel_size.y, safe.size.y - 2.0 * ui.gear_margin))
	_panel_rect = Rect2(safe.get_center() - ps * 0.5, ps)
	# Three buttons share the panel height with equal gaps; the same gap is the side padding.
	var bh := minf(ui.settings_button_h, ps.y * 0.25)
	var gap := (ps.y - 3.0 * bh) / 4.0
	_buttons.clear()
	for i in 3:
		var k: StringName = [&"sound", &"new_game", &"close"][i]
		_buttons[k] = Rect2(_panel_rect.position + Vector2(gap, gap + float(i) * (bh + gap)), Vector2(ps.x - 2.0 * gap, bh))
		_labels[k].position = _buttons[k].position
		_labels[k].size = _buttons[k].size
		_labels[k].pivot_offset = _buttons[k].size * 0.5
	_gear.position = _gear_rect.position
	_gear.size = _gear_rect.size
	_panel.position = Vector2.ZERO
	_panel.size = vp
	_gear.queue_redraw()
	_panel.queue_redraw()

func _scaled(r: Rect2, key: StringName) -> Rect2:
	if key != _press_key:
		return r
	var c := r.get_center()
	var s := r.size * _press_k
	return Rect2(c - s * 0.5, s)

func _draw_gear() -> void:
	var r := _scaled(Rect2(Vector2.ZERO, _gear_rect.size), &"gear")
	_gear.draw_texture_rect_region(IconAtlas.texture(), IconAtlas.shape_dest(r), IconAtlas.region(&"gear"))

## The backing cell is a square with fixed-radius corners, so a wide rect cannot stretch it whole (the border would
## balloon). Draw it as a nine-patch: the four corners 1:1 at card scale, the straight edges and the middle stretched.
const SLICE_SRC := 48.0
const SLICE_DST := 22.0

func _draw_backing(r: Rect2, tint := Color.WHITE) -> void:
	var cell := IconAtlas.region(&"backing")
	var d := IconAtlas.shape_dest(r)
	var xs_s := [0.0, SLICE_SRC, float(IconAtlas.CELL) - SLICE_SRC, float(IconAtlas.CELL)]
	var xs_d := [d.position.x, d.position.x + SLICE_DST, d.end.x - SLICE_DST, d.end.x]
	var ys_d := [d.position.y, d.position.y + SLICE_DST, d.end.y - SLICE_DST, d.end.y]
	for j in 3:
		for i in 3:
			var dst := Rect2(xs_d[i], ys_d[j], xs_d[i + 1] - xs_d[i], ys_d[j + 1] - ys_d[j])
			var src := Rect2(cell.position + Vector2(xs_s[i], xs_s[j]), Vector2(xs_s[i + 1] - xs_s[i], xs_s[j + 1] - xs_s[j]))
			_panel.draw_texture_rect_region(IconAtlas.texture(), dst, src, tint)

func _draw_panel() -> void:
	var dim := Palette.color(&"night_sky")
	_panel.draw_rect(Rect2(Vector2.ZERO, _panel.size), Color(dim.r, dim.g, dim.b, 0.45))
	_draw_backing(_panel_rect)
	var armed_tint := Palette.color(&"enemy_snout").lerp(Color.WHITE, 0.45)
	for k in _buttons:
		var tint := armed_tint if k == &"new_game" and confirm_armed else Palette.color(&"ink_soft").lerp(Color.WHITE, 0.82)
		_draw_backing(_scaled(_buttons[k], k), tint)

func _target_at(pos: Vector2) -> StringName:
	if _open:
		for k in _buttons:
			if _buttons[k].has_point(pos):
				return k
		return &"panel"  # any other press while open is swallowed
	return &"gear" if _gear_rect.has_point(pos) else &""

func _input(event: InputEvent) -> void:
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
		_owned.erase(idx)  # a new press of this index means its old touch ended (a dropped release)
		var t := _target_at(event.position)
		if t != &"":
			_owned[idx] = t
			get_viewport().set_input_as_handled()
	elif _owned.has(idx):
		var t: StringName = _owned[idx]
		_owned.erase(idx)
		get_viewport().set_input_as_handled()
		if event is InputEventScreenTouch and event.canceled:
			return
		if _target_at(event.position) == t:
			_activate(t)

func _activate(t: StringName) -> void:
	if t == &"panel":
		return
	EventBus.sfx_requested.emit(&"click")
	_pulse(t)
	match t:
		&"gear": open()
		&"sound":
			set_muted_display(not _muted)
			mute_toggled.emit(_muted)
		&"new_game": _new_game_tap()
		&"close": close()

func _new_game_tap() -> void:
	if not confirm_armed:
		confirm_armed = true
		_armed_t = 0.0
		set_process(true)
		_refresh_texts()
		_panel.queue_redraw()
		return
	if _armed_t < Balance.ui.card_input_guard_s:
		return  # a double tap does not confirm
	_disarm()
	new_game_requested.emit()

## Press feedback: the backing (and its label) shrink to button_press_scale and come back. Visual only.
func _pulse(key: StringName) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_press.bind(key), 1.0, Balance.ui.button_press_scale, 0.05)
	_tween.tween_method(_set_press.bind(key), Balance.ui.button_press_scale, 1.0, 0.08)
	_tween.tween_callback(func(): _press_key = &"")

func _set_press(k: float, key: StringName) -> void:
	_press_key = key
	_press_k = k
	if _labels.has(key):
		_labels[key].scale = Vector2.ONE * k
	_gear.queue_redraw()
	_panel.queue_redraw()

## D-147: a paused tree drops touch releases, so forget every owned finger.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_owned.clear()
