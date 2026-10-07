class_name BranchPad
extends Node3D
## One branch option of one level-3 building at tier 3 (E5 tier 3 Task 17, D-263, D-264, D-273): the player chooses by standing
## still on one of the spot's two pads, exactly as every other purchase. The world makes two per spot (index 0 = the first option
## of GameState.branch_options, index 1 the second) and each shows only while GameState.can_branch(spot_id) and it is DAY.
## All state comes from GameState (partial payments live in buildings[id].branch_paid); the pad only draws it and pays into IT
## (never into the other pad): GameState.pay_into_branch commits only on full payment and refunds the other pad's partial
## payment, which this node shows as coins flying back to the hero. Standing INSIDE the pad (before the stand-still threshold,
## before any gold moves) shows the preview of the effect; leaving hides it.

const LABEL_PIXEL := 0.01
## The label stack (see _build_stack): one row holds the glyph with the remaining cost beside it; the whole stack shifts by LABEL_SHIFT.
const ROW_GAP := 0.12
## The stack's bottom edge above the pad's ground point, and the air between two items, both in metres ON THE SCREEN (the hero
## stands on the pad and is about 1.0 m tall on screen: the stack starts over his head).
const STACK_BASE_M := 1.05
const STACK_GAP_M := 0.12
## The south cluster starts this far below the pad's ground point (just under the marker ring, which is about 0.75 m deep on screen).
const SOUTH_BASE_M := 0.8
const WARN_GAP := 0.1
## The width (font px) the warning wraps at.
const WARN_WRAP_PX := 150.0
## The width a branch name wraps at (font px) on the pads listed in WRAP_NAME: a two-word name then stands on two lines, so the pair
## of pads fits a phone screen where the ground between them is tight. The preview line never wraps.
const NAME_WRAP_PX := 150.0
## The coins of a refund flight (the exact amount is on the "+N" label) and the pause between two of them (s).
const REFUND_COINS := 5
const REFUND_GAP := 0.07
const REFUND_LABEL_RISE := 1.2
const REFUND_LABEL_TIME := 1.4

## Pads whose branch name wraps onto two lines (NAME_WRAP_PX): [spot, index].
const WRAP_NAME := [["fence_e", 1]]

## Pads whose glyph row and warning line stand above the hero (under the name) instead of below the pad: [spot, index]. Used where
## the ground south of the pad is taken (a telegraph row, another building's labels).
const ROW_NORTH := [["fence_w", 1], ["fence_e", 0], ["fence_sw", 1]]
## Fence pads whose "lost if broken" line wraps onto two lines (WARN_WRAP_PX): [spot, index]; the others show it on one line.
const WRAP_WARN := [["fence_w", 0], ["fence_w", 1], ["fence_e", 0]]

## Pads whose name label alone also moves sideways (m), keyed "spot:index": the whole stack cannot, the pad's other labels leave no room.
const NAME_DX := {"fence_sw:1": -0.5}

## Per spot and pad: where the pad's label stack sits relative to the pad (x right in m, y up in m). The pads stay where
## MapLayout puts them; only the labels move, where two label stacks would collide on screen (test_branch_pads.gd).
## Found by a search over every spot and both pads at 9:21, 9:16 and 16:9 with the hero on the pad (1 base px of air kept), then
## pinned by test_branch_pads.gd: no stack leaves the screen or touches the other pad's stack, a neighbouring spot's cost label or
## pips, the close-up sign's label or a telegraph row. Each entry is [pad 0, pad 1], as (x right, y up) in metres.
const LABEL_SHIFT := {
	"tower_nw": [Vector2(-1.5, -0.5), Vector2(0.0, 0.0)],
	"tower_ne": [Vector2(-1.0, -0.5), Vector2(1.0, -0.5)],
	"fence_w": [Vector2(0.5, 0.0), Vector2(-0.5, 2.0)],
	"fence_n": [Vector2(0.5, 0.0), Vector2(-0.5, 0.0)],
	"fence_e": [Vector2(0.5, 2.0), Vector2(0.0, 4.0)],
	"tower_w": [Vector2(-2.5, 0.0), Vector2(0.5, 0.0)],
	"tower_e": [Vector2(-0.5, 0.0), Vector2(1.5, 1.0)],
	"tower_sw": [Vector2(0.0, -0.5), Vector2(0.5, 0.0)],
	"fence_sw": [Vector2(-2.0, -0.5), Vector2(0.0, 0.5)],
}

## The texts, through tr() when shown: [name, preview line].
const TEXTS := {
	&"longbow": ["Longbow", "far, heavy, slow"],
	&"volley": ["Volley", "3 targets"],
	&"stone": ["Stone wall", "holds brutes"],
	&"spike": ["Spike fence", "hurts attackers"],
}
const WARN_TEXT := "lost if broken"

var spot_id := ""
var branch_id: StringName = &""
var index := 0
var zone: StationZone
## Hidden as a whole when the pad is not shown (the root stays: the refund effect outlives the pad).
var body: Node3D
var stack: Node3D
var marker: MeshInstance3D
var icon: MeshInstance3D
var name_label: WorldLabel
var effect_label: WorldLabel
var cost_label: WorldLabel
var warn_icon: MeshInstance3D
var warn_label: WorldLabel
var refund_label: WorldLabel
## The preview (top level, at the building): range rings (Longbow) or a glyph with its multiplier (Volley, Stone wall, Spike fence).
var preview: Node3D
var preview_rings: Array[MeshInstance3D] = []
var hint_icons: Array[MeshInstance3D] = []
var hint_label: WorldLabel
## What the last refund showed: the exact gold (the "+N" label) and how many coins flew for it.
var last_refund := 0
var refund_coins := 0
var _fx: FlyFx
var _paid_ticks := 0
var _was_shown := false
## Gold of this pad in GameState at the last refresh while the building could branch (a completion or a destroyed fence clears
## the state before branch_refunded fires; this is what the refund takes from this pad).
var _paid_seen := 0
var _refund_tween: Tween
var _coin_tween: Tween
var _warn_row_w := 0.0
## True when the name wraps (WRAP_NAME); rebuild with _build_stack() after changing it.
var wrap_name := false
## True when the fence pads' warning wraps onto two lines (WRAP_WARN); rebuild with _build_stack() after changing it.
var wrap_warn := false
## True when the glyph row stands above the hero (ROW_NORTH); rebuild with _build_stack() after changing it.
var row_north := false
## Extra x offset (m) of the name label (NAME_DX); rebuild with _build_stack() after changing it.
var name_dx := 0.0
var _cost_w := 0.0
var _sizes := {}  ## item id -> its rect size (camera metres): icon, cost, warn, name, effect

func setup(p_spot_id: String, p_index: int, world: World) -> void:
	spot_id = p_spot_id
	index = p_index
	branch_id = GameState.branch_options(spot_id)[index]
	_fx = world.fly_fx
	name = "BranchPad_%s_%s" % [spot_id, branch_id]
	position = MapLayout.to3((MapLayout.BRANCH_PADS[spot_id] as Array)[index])
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	marker = MeshInstance3D.new()
	marker.name = "Marker"
	marker.mesh = BranchIcons.ring_mesh(&"ice_blue", 0.82, 0.22)
	marker.material_override = BranchIcons.ground_material()
	marker.scale = Vector3(MapLayout.BRANCH_PAD_RADIUS, 1.0, MapLayout.BRANCH_PAD_RADIUS)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(marker)
	stack = Node3D.new()
	stack.name = "Stack"
	body.add_child(stack)
	var shift := label_shift()
	stack.position = Vector3(shift.x, shift.y, 0.0)
	wrap_name = [spot_id, index] in WRAP_NAME
	wrap_warn = [spot_id, index] in WRAP_WARN
	row_north = [spot_id, index] in ROW_NORTH
	name_dx = float(NAME_DX.get("%s:%d" % [spot_id, index], 0.0))
	_build_stack()
	_build_preview()
	refund_label = WorldLabel.make("", Balance.ui.branch_pad_cost_font)
	refund_label.name = "Refund"
	refund_label.modulate = Palette.color(&"gold")
	refund_label.visible = false
	add_child(refund_label)
	zone = StationZone.new()
	zone.radius = MapLayout.BRANCH_PAD_RADIUS
	zone.drive_ring = false  # the ring shows paid / cost
	add_child(zone)
	zone.ticked.connect(_on_tick)
	EventBus.building_changed.connect(_on_building_changed)
	EventBus.branch_refunded.connect(_on_branch_refunded)
	EventBus.phase_changed.connect(_on_phase_changed)  # after the zone's own connection (it syncs its phase first)
	EventBus.state_restored.connect(refresh)
	EventBus.tier_changed.connect(_on_tier_changed)
	refresh()

func label_shift() -> Vector2:
	var t: Array = LABEL_SHIFT.get(spot_id, [])
	return t[index] if t.size() == 2 else Vector2.ZERO

func _label(font_size: int, node_name: String) -> WorldLabel:
	var l := WorldLabel.make("", font_size)
	l.name = node_name
	stack.add_child(l)
	return l

func _glyph(kind: StringName, size_m: float, node_name: String, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = BranchIcons.mesh(kind)
	m.material_override = BranchIcons.material()
	m.scale = Vector3.ONE * size_m
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else stack).add_child(m)
	return m

func _font() -> Font:
	return load(WorldLabel.BOLD_PATH)

func _text_w(text: String, font_size: int) -> float:
	return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * LABEL_PIXEL

## Wraps `l` at `wrap_px` font px (a word never splits) and returns its box in metres, outline included.
func _wrap(l: WorldLabel, wrap_px: float) -> Vector2:
	l.width = wrap_px
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return _font().get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, wrap_px, l.font_size) * LABEL_PIXEL + Vector2.ONE * float(8) * LABEL_PIXEL

## World y (m) of a billboard that must stand `m` metres above its anchor on the SCREEN: the camera looks down at 55 degrees, so a
## height h shows as h * cos(pitch).
static func screen_to_y(m: float) -> float:
	return m / cos(deg_to_rad(absf(Balance.ui.camera_pitch)))

## The height (camera metres) one line of `font_size` takes, outline included.
func _line_h(font_size: int) -> float:
	return (_font().get_height(font_size) + float(8)) * LABEL_PIXEL

## The stack, in two clusters so nothing stands on the hero (he is about 1.0 m tall on screen): ABOVE his head the branch name and,
## only while he stands inside, the preview line; BELOW the pad the glyph with the cost beside it and, on a fence pad, the
## "lost if broken" line (broken-fence glyph and text). Each item has its own height on the screen (none touches another).
func _build_stack() -> void:
	for c in stack.get_children():
		stack.remove_child(c)
		c.free()
	_sizes = {}
	var ui := Balance.ui
	var icon_m: float = ui.branch_pad_icon_m
	_cost_w = _text_w("000", ui.branch_pad_cost_font)
	var icon_box := BranchIcons.mesh(branch_id).get_aabb().size * icon_m  # the glyph with its ink outline
	var row_h := maxf(icon_box.y, _line_h(ui.branch_pad_cost_font))
	var row_w := icon_box.x + ROW_GAP + _cost_w
	cost_label = _label(ui.branch_pad_cost_font, "Cost")
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon = _glyph(branch_id, icon_m, "Icon")
	name_label = _label(ui.branch_pad_label_font, "Name")
	name_label.text = tr(TEXTS[branch_id][0])
	effect_label = _label(ui.branch_pad_label_font, "Effect")
	effect_label.text = tr(TEXTS[branch_id][1])
	effect_label.visible = false
	warn_label = null
	warn_icon = null
	_sizes["icon"] = Vector2(icon_box.x, icon_box.y)
	_sizes["cost"] = Vector2(_cost_w + float(8) * LABEL_PIXEL, _line_h(ui.branch_pad_cost_font))
	_sizes["name"] = _wrap(name_label, NAME_WRAP_PX if wrap_name else 9999.0)
	_sizes["effect"] = _wrap(effect_label, 9999.0)
	# the glyph row and, on a fence pad, the warning line: below the pad (or above the hero on a ROW_NORTH pad)
	var m := STACK_BASE_M if row_north else SOUTH_BASE_M
	icon.position = _row_at(m, row_h, -row_w * 0.5 + icon_box.x * 0.5)
	cost_label.position = _row_at(m, row_h, -row_w * 0.5 + icon_box.x + ROW_GAP)
	m += row_h + STACK_GAP_M
	if MapLayout.spot_kind(spot_id) == "fence":
		var fs: int = ui.branch_pad_warn_font
		var wi := float(fs) * LABEL_PIXEL * 1.3
		var wbox := BranchIcons.mesh(&"broken").get_aabb().size * wi
		warn_label = _label(fs, "Warn")
		warn_label.text = tr(WARN_TEXT)
		var wrap_px := WARN_WRAP_PX if wrap_warn else 9999.0
		warn_label.width = wrap_px
		warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn_icon = _glyph(&"broken", wi, "WarnIcon")
		var box := _font().get_multiline_string_size(warn_label.text, HORIZONTAL_ALIGNMENT_CENTER, wrap_px, fs) * LABEL_PIXEL
		var wh := maxf(wbox.y, box.y + float(8) * LABEL_PIXEL)
		_warn_row_w = wbox.x + WARN_GAP + box.x + float(8) * LABEL_PIXEL
		_sizes["warn"] = Vector2(_warn_row_w, wh)
		warn_icon.position = _row_at(m, wh, -_warn_row_w * 0.5 + wbox.x * 0.5)
		warn_label.position = _row_at(m, wh, _warn_row_w * 0.5 - box.x * 0.5)
		m += wh + STACK_GAP_M
	# above the hero: the name, then the preview line (over the row on a ROW_NORTH pad)
	var top := m if row_north else STACK_BASE_M
	name_label.position = Vector3(name_dx, screen_to_y(top + _sizes.name.y * 0.5), 0.0)
	effect_label.position.y = screen_to_y(top + _sizes.name.y + STACK_GAP_M + _sizes.effect.y * 0.5)

## The position (relative to the stack) of an item `h` metres tall whose lower edge is `m` metres from the pad on the screen: above
## the hero's head on a ROW_NORTH pad, else below the pad on the ground (south).
func _row_at(m: float, h: float, x: float) -> Vector3:
	if row_north:
		return Vector3(x, screen_to_y(m + h * 0.5), 0.0)
	return Vector3(x, 0.0, south_z(m + h * 0.5))

## Metres south of the anchor on the ground that show `m` metres BELOW it on the screen (the pitch looks down at 55 degrees).
static func south_z(m: float) -> float:
	return m / sin(deg_to_rad(absf(Balance.ui.camera_pitch)))

# --- the preview (D-263.3) ---------------------------------------------------------------------------

func _build_preview() -> void:
	preview = Node3D.new()
	preview.name = "Preview"
	preview.top_level = true
	preview.visible = false
	add_child(preview)
	preview.global_position = MapLayout.to3(MapLayout.spot_position(spot_id))
	var bb: BranchBalance = Balance.data.branches
	var top := (TowerSpot.MODEL_HEIGHTS[TowerSpot.MODEL_HEIGHTS.size() - 1] if MapLayout.spot_kind(spot_id) == "tower" else FenceSpot.PIP_Y) + 1.0
	match branch_id:
		&"longbow":
			# the ring at today's level-3 range, and the Longbow's: the gain is the gap between them
			_ring(bb.tower(&"").attack_range, &"steel", "RangeNow")
			_ring(bb.tower(&"longbow").attack_range, &"ice_blue", "RangeLongbow")
		&"volley":
			_hint(&"volley", _mult_text(float(bb.tower(&"volley").count)), top)
		&"stone":
			_hint(&"stone", _mult_text(bb.fence(&"stone").hp / bb.fence(&"").hp), top)
		_:
			_hint(&"spike", "", top)

func _ring(radius: float, colour: StringName, node_name: String) -> void:
	var r := MeshInstance3D.new()
	r.name = node_name
	r.mesh = BranchIcons.ring_mesh(colour, 0.985, 0.0)
	r.material_override = BranchIcons.ground_material()
	r.scale = Vector3(radius, 1.0, radius)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(r)
	preview_rings.append(r)

## A glyph and, if `mult` is not empty, its multiplier beside it, centred at height `y` above the building.
func _hint(kind: StringName, mult: String, y: float) -> void:
	var size_m: float = Balance.ui.branch_pad_icon_m
	var fs: int = Balance.ui.branch_pad_cost_font
	var tw := _text_w(mult, fs) if mult != "" else 0.0
	var total := size_m + (WARN_GAP + tw if mult != "" else 0.0)
	var g := _glyph(kind, size_m, "HintIcon", preview)
	g.position = Vector3(-total * 0.5 + size_m * 0.5, y, 0.0)
	hint_icons.append(g)
	if mult != "":
		hint_label = WorldLabel.make(mult, fs)
		hint_label.name = "HintMult"
		hint_label.position = Vector3(total * 0.5 - tw * 0.5, y, 0.0)
		preview.add_child(hint_label)

## "x3", "x2", "x1.5": a whole number without a decimal.
static func _mult_text(m: float) -> String:
	return "x%d" % int(roundf(m)) if is_equal_approx(m, roundf(m)) else "x%s" % String.num(m, 1)

## The radius (m) a ring of the preview draws.
static func ring_radius(ring: MeshInstance3D) -> float:
	return ring.mesh.get_aabb().size.x * 0.5 * ring.scale.x

# --- state -------------------------------------------------------------------------------------------

## True while this pad is on the map: the building can branch (tier 3, level 3, no branch, a fence that stands) and it is DAY.
func is_shown() -> bool:
	return zone != null and zone.is_active() and GameState.can_branch(spot_id)

func hero_inside() -> bool:
	if not is_shown():
		return false
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if hero == null:
		return false
	return Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length() <= MapLayout.BRANCH_PAD_RADIUS

## Gold paid into this pad (0 when the building cannot branch).
func paid() -> int:
	var rem := GameState.branch_remaining(spot_id, branch_id)
	return GameState.branch_cost(spot_id) - rem if rem >= 0 else 0

func preview_shown() -> bool:
	return preview.visible

func _physics_process(_delta: float) -> void:
	_sync_preview()

func _sync_preview() -> void:
	preview.visible = hero_inside()
	effect_label.visible = preview.visible
	if warn_label != null:  # the fence pads' "lost if broken" is part of the preview (D-273.4): it shows while the hero stands inside
		warn_label.visible = preview.visible
		warn_icon.visible = preview.visible

func _on_tick() -> void:
	if not is_shown():
		return  # DAY only, and only while the building can branch (a Stone wall is never a cheap mid-night repair)
	var cost := GameState.branch_cost(spot_id)
	var took := GameState.pay_into_branch(spot_id, branch_id, Economy.drain_per_tick(cost, Balance.data.build))
	if took > 0:
		# A completing tick leaves a branch chosen: the next purchase would start counting again.
		_paid_ticks = PayFx.paid_tick(self, _fx, _paid_ticks, GameState.branch_of(spot_id) != &"", 0.3)

func _on_building_changed(id: StringName, _level: int, _paid: int) -> void:
	if String(id) == spot_id:
		refresh()

func _on_phase_changed(_phase: int, _day: int) -> void:
	refresh()

func _on_tier_changed(_tier: int, _paid: int, _boss_pending: bool) -> void:
	refresh()

## Rebuilds everything from GameState. Safe before the first new_game (buildings is empty then).
func refresh() -> void:
	var shown := is_shown()
	if shown and not _was_shown:
		zone.disarm()  # D-121: a hero already standing here when the pad appears must leave and come back
	_was_shown = shown
	body.visible = shown
	if GameState.can_branch(spot_id):
		_paid_seen = paid()
	elif GameState.branch_of(spot_id) == branch_id:
		_paid_seen = 0  # the chosen pad: nothing to refund
	if _paid_seen == 0:
		_paid_ticks = 0
	var cost := GameState.branch_cost(spot_id)
	if shown:
		cost_label.text = str(GameState.branch_remaining(spot_id, branch_id))
	zone.ring.visible = shown and _paid_seen > 0
	zone.ring.set_progress(float(_paid_seen) / float(cost) if shown and cost > 0 else 0.0)
	_sync_preview()

# --- the refund (D-263.1) ----------------------------------------------------------------------------

## The other pad's partial payment went back to gold: coins fly from THIS pad to the hero, the exact amount on a "+N" label.
## A destroyed fence's dawn refund is shared by both of its pads, each flying what it held.
func _on_branch_refunded(id: StringName, _amount: int) -> void:
	if String(id) != spot_id or GameState.branch_of(spot_id) == branch_id:
		return
	var held := _paid_seen
	_paid_seen = 0
	if held <= 0:
		return
	last_refund = held
	refund_coins = mini(REFUND_COINS, held)
	_show_refund_label(held)
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if _fx == null or hero == null:
		return
	_launch_coin(hero)
	if refund_coins > 1:
		if _coin_tween != null and _coin_tween.is_valid():
			_coin_tween.kill()
		_coin_tween = create_tween()
		for i in range(1, refund_coins):
			_coin_tween.tween_interval(REFUND_GAP)
			_coin_tween.tween_callback(_launch_coin.bind(hero))

func _launch_coin(hero: Node3D) -> void:
	if is_instance_valid(hero) and _fx != null:
		_fx.fly("coin", global_position + Vector3(0, 0.4, 0), hero.global_position + Vector3(0, 1.2, 0))

func _show_refund_label(amount: int) -> void:
	if _refund_tween != null and _refund_tween.is_valid():
		_refund_tween.kill()
	refund_label.text = "+%d" % amount
	refund_label.visible = true
	refund_label.position = Vector3(0, 1.0, 0)
	refund_label.modulate.a = 1.0
	_refund_tween = create_tween()
	_refund_tween.set_parallel(true)
	_refund_tween.tween_property(refund_label, "position:y", 1.0 + REFUND_LABEL_RISE, REFUND_LABEL_TIME)
	_refund_tween.tween_property(refund_label, "modulate:a", 0.0, REFUND_LABEL_TIME)
	_refund_tween.chain().tween_callback(func(): refund_label.visible = false)

# --- screen layout (tests) ---------------------------------------------------------------------------

## What the pad shows now, as world rectangles for the readability tests: [{id, center: Vector3, size: Vector2 (m, camera-facing)}].
## `with_effect` adds the preview lines (the pad the hero stands on): the effect line and, on a fence pad, "lost if broken". Label boxes carry their outline.
func layout(with_effect: bool) -> Array:
	var out: Array = []
	var sp := stack.global_position
	out.append({"id": "icon", "center": sp + icon.position, "size": _sizes.icon})
	out.append({"id": "name", "center": sp + name_label.position, "size": _sizes.name})
	out.append({"id": "cost", "center": sp + cost_label.position + Vector3(_cost_w * 0.5, 0, 0), "size": _sizes.cost})
	if with_effect:
		out.append({"id": "effect", "center": sp + effect_label.position, "size": _sizes.effect})
	if warn_label != null and with_effect:
		out.append({"id": "warn", "center": sp + Vector3(0, 0, warn_label.position.z), "size": _sizes.warn})
	return out
