class_name BranchPad
extends Node3D
## One branch option of one level-3 building at tier 3 (E5 tier 3 Task 17, D-263, D-264, D-273): the player chooses by standing
## still on one of the spot's two pads, exactly as every other purchase. The world makes two per spot (index 0 = the first option
## of GameState.branch_options, index 1 the second) and each shows only while GameState.can_branch(spot_id) and it is DAY.
## All state comes from GameState (partial payments live in buildings[id].branch_paid); the pad only draws it and pays into IT
## (never into the other pad): GameState.pay_into_branch commits only on full payment and refunds the other pad's partial
## payment, which this node shows as coins flying back to the hero.
##
## PROGRESSIVE DISCLOSURE (fix round 1): one focus spot at a time, so many level-3 buildings never pile their labels up.
##   FAR   (not the focus spot): the ground ring and the branch glyph on the pad, depth-tested (buildings hide it); no text. The glyph
##         is hidden (FAR_QUIET) while the hero stands on any pad.
##   NEAR  (the focus spot, hero not on this pad): ring, glyph and the remaining cost under it, one block at most 1.2 m wide.
##   QUIET (the other pad of the spot the hero stands on): ring and payment ring only; its glyph and cost come back when he leaves.
##   ON    (the hero is inside this pad): glyph and cost row, name, preview line, the fence warning line, and the preview at the
##         building (range rings, "x3", shield, spikes). It shows before the stand-still threshold and before any gold moves.
## The stage is VISUAL ONLY: _on_tick (the payment) never reads it.

const FAR := 0
const FAR_QUIET := 1
const NEAR := 2
const ON := 3
## The sibling of the pad the hero stands on: its ground ring and payment ring only (on a pad only the stood option speaks).
const SIBLING_QUIET := 4
## Metres ON THE SCREEN: the gap between the glyph and its cost, and between two stacked items.
const ROW_GAP := 0.12
const STACK_GAP_M := 0.08
## The ON stack starts this far above / below the pad's ground point on the screen: above clears the hero (about 1.0 m tall on
## screen), below clears the marker ring (about 0.75 m deep on screen).
const NORTH_BASE_M := 1.05
const SOUTH_BASE_M := 0.8
const WARN_GAP := 0.1
## The coins of a refund flight (the exact amount is on the "+N" label) and the pause between two of them (s).
const REFUND_COINS := 5
const REFUND_GAP := 0.07
const REFUND_LABEL_RISE := 1.2
const REFUND_LABEL_TIME := 1.4

## ON pads that do not use the default (name and preview line above the hero's head, glyph row and warning line below the pad):
## "spot:index" -> [row_north, name_south]. Chosen only where the default collides on screen (tests/unit/test_branch_pads.gd).
const ON_MODES := {
	"fence_n:0": [true, true], "tower_w:1": [false, true], "tower_e:0": [false, true], "tower_sw:1": [false, true], "fence_sw:1": [true, false],
}

## The texts, through tr() when shown: [name, preview line]. The Volley's line is built from the balance count.
const TEXTS := {
	&"longbow": ["Longbow", "far, heavy, slow"],
	&"volley": ["Volley", "%d targets"],
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
## Where the preview glyph stands relative to its default (HINT_AT); call place_hint() after changing it.
var hint_at := Vector2.ZERO
## What the last refund showed: the exact gold (the "+N" label) and how many coins flew for it.
var last_refund := 0
var refund_coins := 0
## The stage shown now (FAR, FAR_QUIET, NEAR, ON, SIBLING_QUIET).
var stage := FAR
## Where the ON clusters stand (ON_MODES); call _layout_items() and re-apply the stage after changing them.
var row_north := false
var name_south := false
var _fx: FlyFx
var _paid_ticks := 0
var _was_shown := false
## Gold of this pad in GameState at the last refresh while the building could branch (a completion or a destroyed fence clears
## the state before branch_refunded fires; this is what the refund takes from this pad).
var _paid_seen := 0
var _refund_tween: Tween
var _coin_tween: Tween
## Local positions of the items per stage (built once, in screen metres): {NEAR: {node: Vector3}, ON: {node: Vector3}}.
var _pos := {}

# --- the focus spot (one per physics frame, shared by every pad) -------------------------------------------

## The pads on the map now (shown ones only: a hidden pad is not in it and does not process).
static var _shown_pads: Array = []
static var _cache_frame := -1
static var _focus_spot := ""
static var _on_pad: BranchPad = null
## Reused every frame (no allocation in update_focus): spot -> smallest distance to one of its pads; the spots of the tier, refreshed
## when the tier changes.
static var _nearest := {}
static var _spots: Array[String] = []
static var _spots_tier := -1

## Computes the focus spot and the pad the hero stands on, once per physics frame: one hero lookup and one distance per shown pad.
## The pad the hero stands on gives its spot; else the spot kept from before while the hero is within `branch_pad_leave_m` of its
## nearest pad (hysteresis); else the spot whose nearest pad is closest within `branch_pad_near_m` (ties: spots_for_tier order).
## With no pad shown (night, a new game, a load) nothing is focused.
static func update_focus(tree: SceneTree) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _cache_frame:
		return
	_cache_frame = frame
	_on_pad = null
	for i in range(_shown_pads.size() - 1, -1, -1):  # a pad freed since (a rebuild) leaves the registry
		if not is_instance_valid(_shown_pads[i]):
			_shown_pads.remove_at(i)
	var hero := tree.get_first_node_in_group(&"hero") as Node3D
	if hero == null or _shown_pads.is_empty():
		_focus_spot = ""
		return
	var hx := hero.global_position.x
	var hz := hero.global_position.z
	_nearest.clear()
	var best_on := INF
	for p: BranchPad in _shown_pads:
		var d := Vector2(hx - p.global_position.x, hz - p.global_position.z).length()
		if d < float(_nearest.get(p.spot_id, INF)):
			_nearest[p.spot_id] = d
		if d <= MapLayout.BRANCH_PAD_RADIUS and d < best_on:
			best_on = d
			_on_pad = p
	if _on_pad != null:
		_focus_spot = _on_pad.spot_id
		return
	if _focus_spot != "" and _nearest.has(_focus_spot) and float(_nearest[_focus_spot]) <= Balance.ui.branch_pad_leave_m:
		return
	_focus_spot = ""
	if _spots_tier != GameState.tier:
		_spots_tier = GameState.tier
		_spots = MapLayout.spots_for_tier(GameState.tier)
	var best := INF
	for id in _spots:
		if _nearest.has(id) and float(_nearest[id]) <= Balance.ui.branch_pad_near_m and float(_nearest[id]) < best:
			best = float(_nearest[id])
			_focus_spot = id

## Takes a pad out of the shown registry; the last one out clears the focus (night, a new game, a load: no stale focus survives).
static func _forget_shown(pad: BranchPad) -> void:
	_shown_pads.erase(pad)
	for i in range(_shown_pads.size() - 1, -1, -1):
		if not is_instance_valid(_shown_pads[i]):
			_shown_pads.remove_at(i)
	if _shown_pads.is_empty():
		_focus_spot = ""
		_on_pad = null
	elif _on_pad == pad:
		_on_pad = null
	_cache_frame = -1

static func focus_spot() -> String:
	return _focus_spot

static func pad_hero_stands_on() -> BranchPad:
	return _on_pad

## Forgets the shared focus (a new world, tests).
static func reset_focus() -> void:
	for i in range(_shown_pads.size() - 1, -1, -1):
		if not is_instance_valid(_shown_pads[i]):
			_shown_pads.remove_at(i)
	_cache_frame = -1
	_focus_spot = ""
	_on_pad = null

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
	_build_items()
	_build_preview()
	refund_label = WorldLabel.make("", Balance.ui.branch_pad_cost_font)
	refund_label.name = "Refund"
	refund_label.pixel_size = Balance.ui.branch_pad_cost_pixel_size
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
	set_physics_process(false)
	refresh()

func _exit_tree() -> void:
	_forget_shown(self)
	if _on_pad == self:
		_on_pad = null
	_cache_frame = -1

# --- items and their layout --------------------------------------------------------------------------

func _label(font_size: int, pixel: float, node_name: String, text := "") -> WorldLabel:
	var l := WorldLabel.make(text, font_size)
	l.name = node_name
	l.pixel_size = pixel
	l.visible = false
	body.add_child(l)
	return l

func _glyph(kind: StringName, size_m: float, node_name: String, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = BranchIcons.mesh(kind)
	m.material_override = BranchIcons.material()
	m.scale = Vector3.ONE * size_m
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else body).add_child(m)
	return m

static func _font() -> Font:
	return load(WorldLabel.BOLD_PATH)

## The box (m, camera-facing) a label draws, outline included, from its own font, size, text and wrap.
static func text_box(l: Label3D) -> Vector2:
	var wrap := float(l.width) if l.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var sz := _font().get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, wrap, l.font_size)
	return (sz + Vector2.ONE * float(l.outline_size)) * l.pixel_size

## The box (m) a glyph node draws, its ink outline included.
static func glyph_box(g: MeshInstance3D) -> Vector2:
	var sz := g.mesh.get_aabb().size
	return Vector2(sz.x, sz.y) * g.scale.x

## World y (m) of a billboard that must stand `m` metres above (below, when negative) its anchor ON THE SCREEN: the camera looks
## down at 55 degrees, so a height h shows as h * cos(pitch).
static func screen_to_y(m: float) -> float:
	return m / cos(deg_to_rad(absf(Balance.ui.camera_pitch)))

## Creates the items and lays out the NEAR block and the ON stack once, in screen metres.
func _build_items() -> void:
	var ui := Balance.ui
	var pix: float = ui.branch_pad_label_pixel_size
	icon = _glyph(branch_id, ui.branch_pad_icon_m, "Icon")
	cost_label = _label(ui.branch_pad_cost_font, ui.branch_pad_cost_pixel_size, "Cost", "000")  # "000": the widest cost fixes the block widths
	name_label = _label(ui.branch_pad_label_font, pix, "Name", tr(TEXTS[branch_id][0]))
	var effect := tr(TEXTS[branch_id][1])
	if branch_id == &"volley":
		effect = effect % int(Balance.data.branches.tower(&"volley").count)
	effect_label = _label(ui.branch_pad_label_font, pix, "Effect", effect)
	var fence := MapLayout.spot_kind(spot_id) == "fence"
	if fence:
		warn_label = _label(ui.branch_pad_warn_font, ui.branch_pad_warn_pixel_size, "Warn", tr(WARN_TEXT))
		warn_icon = _glyph(&"broken", float(ui.branch_pad_warn_font) * ui.branch_pad_warn_pixel_size * 1.3, "WarnIcon")
		warn_icon.visible = false
	var mode: Array = ON_MODES.get("%s:%d" % [spot_id, index], [false, false])
	row_north = mode[0]
	name_south = mode[1]
	_layout_items()
	cost_label.text = ""

## Lays out the NEAR block and the ON stack (positions only), in screen metres.
func _layout_items() -> void:
	var ibox := glyph_box(icon)
	var cbox := _cost_box()
	# NEAR: the glyph with the cost centred under it; the block (at most 1.2 m wide) centred on the pad
	var block_h := ibox.y + STACK_GAP_M + cbox.y
	_pos[NEAR] = {
		icon: _at(block_h * 0.5 - ibox.y * 0.5, true),
		cost_label: _at(block_h * 0.5 - cbox.y * 0.5, false),
	}
	# ON: the glyph row (and the fence warning) on one side of the pad, the name and the preview line on one side; each cluster
	# stands above the hero's head (north) or below the pad (south). Where both share a side the row is nearest the pad.
	var on := {}
	var m := {true: NORTH_BASE_M, false: SOUTH_BASE_M}  # north? -> the next free edge on that side
	m[row_north] = _place_row(on, m[row_north], row_north)
	m[row_north] = _place_warn(on, m[row_north], row_north)
	var name_north := not name_south
	m[name_north] = _place_text(on, name_label, m[name_north], name_north)
	m[name_north] = _place_text(on, effect_label, m[name_north], name_north)
	_pos[ON] = on

## The local position of an item whose centre stands `c` metres ON THE SCREEN above (north) or below (south) the pad: above it is a
## height (a billboard over the hero), below it is a point on the ground south of the pad (the camera looks down at 55 degrees).
static func _at(c: float, north: bool) -> Vector3:
	if north:
		return Vector3(0, screen_to_y(c), 0)
	return Vector3(0, 0, c / sin(deg_to_rad(absf(Balance.ui.camera_pitch))))

## `m`: the edge of the item nearest the pad, in metres on the screen; north: the item stands above (its lower edge at m), else
## below (its upper edge at m below the pad). Returns the next edge.
func _place_text(on: Dictionary, l: Label3D, m: float, north: bool) -> float:
	var h := text_box(l).y
	on[l] = _at(m + h * 0.5, north)
	return m + h + STACK_GAP_M

## The glyph with its cost beside it (left aligned, widest cost "000"), centred on the pad's x.
func _place_row(on: Dictionary, m: float, north: bool) -> float:
	var ibox := glyph_box(icon)
	var cbox := _cost_box()
	var w := ibox.x + ROW_GAP + cbox.x
	var h := maxf(ibox.y, cbox.y)
	var at := _at(m + h * 0.5, north)
	on[icon] = at + Vector3(-w * 0.5 + ibox.x * 0.5, 0, 0)
	on[cost_label] = at + Vector3(-w * 0.5 + ibox.x + ROW_GAP, 0, 0)
	return m + h + STACK_GAP_M

func _place_warn(on: Dictionary, m: float, north: bool) -> float:
	if warn_label == null:
		return m
	var ibox := glyph_box(warn_icon)
	var tbox := text_box(warn_label)
	var w := ibox.x + WARN_GAP + tbox.x
	var h := maxf(ibox.y, tbox.y)
	var at := _at(m + h * 0.5, north)
	on[warn_icon] = at + Vector3(-w * 0.5 + ibox.x * 0.5, 0, 0)
	on[warn_label] = at + Vector3(w * 0.5 - tbox.x * 0.5, 0, 0)
	return m + h + STACK_GAP_M

## The box of the widest cost ("000"): it fixes the widths of the NEAR block and the ON row, whatever the cost reads now.
func _cost_box() -> Vector2:
	var t := cost_label.text
	cost_label.text = "000"
	var b := text_box(cost_label)
	cost_label.text = t
	return b

# --- the preview (D-263.3) ---------------------------------------------------------------------------

func _build_preview() -> void:
	preview = Node3D.new()
	preview.name = "Preview"
	preview.top_level = true
	preview.visible = false
	add_child(preview)
	preview.global_position = MapLayout.to3(MapLayout.spot_position(spot_id))
	var bb: BranchBalance = Balance.data.branches
	match branch_id:
		&"longbow":
			# the ring at today's level-3 range, and the Longbow's: the gain is the gap between them
			_ring(bb.tower(&"").attack_range, &"steel", "RangeNow")
			_ring(bb.tower(&"longbow").attack_range, &"ice_blue", "RangeLongbow")
		&"volley":
			_hint(&"volley", _mult_text(float(bb.tower(&"volley").count)))
		&"stone":
			_hint(&"stone", _mult_text(bb.fence(&"stone").hp / bb.fence(&"").hp))
		_:
			_hint(&"spike", "")

func _ring(radius: float, colour: StringName, node_name: String) -> void:
	var r := MeshInstance3D.new()
	r.name = node_name
	r.mesh = BranchIcons.ring_mesh(colour, 0.985, 0.0)
	r.material_override = BranchIcons.ground_material()
	r.scale = Vector3(radius, 1.0, radius)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(r)
	preview_rings.append(r)

## The preview glyph stands on the ground in front of (south of) the building, clear of its pips and of the stacks that rise over the
## hero's head from the pads north of it.
const HINT_Z := 1.7
const HINT_Y := 0.35
## Spots whose preview glyph stands elsewhere: spot -> Vector2(x, extra z) added to (0, HINT_Z). Picked with the test, where the
## default lands on a pad, a pip row or a stack (tests/unit/test_branch_pads.gd).
const HINT_AT := {"tower_w": Vector2(0.0, -1.5), "tower_sw": Vector2(-1.0, 0.0), "fence_sw": Vector2(0.0, 1.0)}

## A glyph and, if `mult` is not empty, its multiplier beside it, in front of the building.
func _hint(kind: StringName, mult: String) -> void:
	var g := _glyph(kind, Balance.ui.branch_pad_icon_m, "HintIcon", preview)
	hint_icons.append(g)
	if mult != "":
		hint_label = WorldLabel.make(mult, Balance.ui.branch_pad_cost_font)
		hint_label.name = "HintMult"
		hint_label.pixel_size = Balance.ui.branch_pad_label_pixel_size
		preview.add_child(hint_label)
	hint_at = HINT_AT.get(spot_id, Vector2.ZERO)
	place_hint()

## Puts the preview glyph (and its multiplier) at (hint_at.x, HINT_Y, HINT_Z + hint_at.y) from the building.
func place_hint() -> void:
	if hint_icons.is_empty():  # the Longbow previews with rings only
		return
	var g := hint_icons[0]
	var z := HINT_Z + hint_at.y
	var gw := glyph_box(g).x
	if hint_label == null:
		g.position = Vector3(hint_at.x, HINT_Y, z)
		return
	var tw := text_box(hint_label).x
	var total := gw + WARN_GAP + tw
	g.position = Vector3(hint_at.x - total * 0.5 + gw * 0.5, HINT_Y, z)
	hint_label.position = Vector3(hint_at.x + total * 0.5 - tw * 0.5, HINT_Y, z)

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
	update_focus(get_tree())
	var want := _stage_now()
	if want != stage:
		_apply_stage(want)

func _stage_now() -> int:
	if _on_pad == self:
		return ON
	if _on_pad != null and _on_pad.spot_id == spot_id:
		return SIBLING_QUIET
	if _focus_spot == spot_id:
		return NEAR
	return FAR if _on_pad == null else FAR_QUIET

## Writes the items of `st`: only when the stage changes (visibility, positions, glyph size and material).
func _apply_stage(st: int) -> void:
	stage = st
	var ui := Balance.ui
	icon.visible = st != FAR_QUIET and st != SIBLING_QUIET
	if st <= FAR_QUIET or st == SIBLING_QUIET:
		icon.material_override = BranchIcons.far_material()
		icon.scale = Vector3.ONE * ui.branch_pad_far_icon_m
		icon.position = Vector3(0, 0.45, 0)
	else:
		icon.material_override = BranchIcons.material()
		icon.scale = Vector3.ONE * ui.branch_pad_icon_m
	cost_label.visible = st == NEAR or st == ON
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if st == NEAR else HORIZONTAL_ALIGNMENT_LEFT
	var on := st == ON
	name_label.visible = on
	effect_label.visible = on
	preview.visible = on
	if warn_label != null:  # the fence pads' "lost if broken" is part of the preview (D-273.4)
		warn_label.visible = on
		warn_icon.visible = on
	if st == NEAR or st == ON:
		for n in _pos[st]:
			(n as Node3D).position = _pos[st][n]

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

## Rebuilds everything from GameState. Safe before the first new_game (buildings is empty then). A hidden pad does not process.
func refresh() -> void:
	var shown := is_shown() and is_inside_tree()  # a pad a rebuild took out of the tree is never shown
	if shown and not _was_shown:
		zone.disarm()  # D-121: a hero already standing here when the pad appears must leave and come back
		_shown_pads.append(self)
	elif _was_shown and not shown:
		_forget_shown(self)
	if shown != _was_shown:
		_cache_frame = -1
	_was_shown = shown
	body.visible = shown
	set_physics_process(shown)
	if GameState.can_branch(spot_id):
		_paid_seen = paid()
	elif GameState.branch_of(spot_id) == branch_id:
		_paid_seen = 0  # the chosen pad: nothing to refund
	if _paid_seen == 0:
		_paid_ticks = 0
	var cost := GameState.branch_cost(spot_id)
	if shown:
		cost_label.text = str(GameState.branch_remaining(spot_id, branch_id))
		if is_inside_tree():
			update_focus(get_tree())
		_apply_stage(_stage_now())
	else:
		preview.visible = false
		stage = FAR
	zone.ring.visible = shown and _paid_seen > 0
	zone.ring.set_progress(float(_paid_seen) / float(cost) if shown and cost > 0 else 0.0)

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
